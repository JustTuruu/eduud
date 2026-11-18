import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/api/socket_client.dart';
import '../../core/models.dart';
import '../../core/router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/avatars.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../home/auction_tiles.dart' show ArtPlaceholder;
import '../home/auction_timing.dart';

/// Auction-ы дэлгэрэнгүй + realtime төлөв.
/// REST-ээр эхний байдлыг татаад Socket.IO room-д нэгдэж event-ээр шинэчилнэ.
class AuctionDetailController
    extends AutoDisposeFamilyAsyncNotifier<AuctionDetail, String> {
  int _serverOffsetMs = 0;
  int get serverOffsetMs => _serverOffsetMs;

  @override
  Future<AuctionDetail> build(String auctionId) async {
    final socket = ref.watch(socketProvider);

    void onBid(dynamic data) {
      final d = data as Map<String, dynamic>;
      if (d['auctionId'] != auctionId) return;
      final current = state.valueOrNull;
      if (current == null) return;
      _syncOffset(d);
      final bidder = Bidder.fromJson(d['bidder'] as Map<String, dynamic>);
      state = AsyncData(current.copyWith(
        currentPrice: d['price'] as int,
        bidCount: (d['bidCount'] ?? current.bidCount + 1) as int,
        endsAt: DateTime.parse(d['endsAt'] as String),
        lastBidder: bidder,
        bids: [
          BidItem(
            id: 'live-${DateTime.now().microsecondsSinceEpoch}',
            price: d['price'] as int,
            createdAt: DateTime.now(),
            user: bidder,
          ),
          ...current.bids.take(19),
        ],
      ));
    }

    void onExtended(dynamic data) {
      final d = data as Map<String, dynamic>;
      if (d['auctionId'] != auctionId) return;
      final current = state.valueOrNull;
      if (current == null) return;
      state = AsyncData(
          current.copyWith(endsAt: DateTime.parse(d['endsAt'] as String)));
    }

    void onEnded(dynamic data) {
      final d = data as Map<String, dynamic>;
      if (d['auctionId'] != auctionId) return;
      final current = state.valueOrNull;
      if (current == null) return;
      state = AsyncData(current.copyWith(status: 'ended'));
    }

    socket.on('bid_placed', onBid);
    socket.on('auction_extended', onExtended);
    socket.on('auction_ended', onEnded);
    // Нэвтрээгүй зочин (landing-оос орж ирсэн) ч realtime үнэ/хугацааг
    // харна: token-гүй холболт нээлттэй room-д орж чадна. Холбогдсоны
    // дараа join илгээнэ — холбогдохоос өмнө emit хийвэл алдагдана.
    void onConnect(dynamic _) =>
        socket.emit('join_auction', {'auctionId': auctionId});
    socket.on('connect', onConnect);
    if (socket.connected) {
      socket.emit('join_auction', {'auctionId': auctionId});
    } else {
      socket.connect();
    }

    ref.onDispose(() {
      socket.emit('leave_auction', {'auctionId': auctionId});
      socket.off('bid_placed', onBid);
      socket.off('auction_extended', onExtended);
      socket.off('auction_ended', onEnded);
      socket.off('connect', onConnect);
    });

    final res = await ref.read(dioProvider).get('/auctions/$auctionId');
    final detail = AuctionDetail.fromJson(res.data as Map<String, dynamic>);
    _serverOffsetMs = detail.serverTime - DateTime.now().millisecondsSinceEpoch;
    return detail;
  }

  void _syncOffset(Map<String, dynamic> d) {
    final st = d['serverTime'];
    if (st is int) _serverOffsetMs = st - DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> placeBid() async {
    await ref.read(dioProvider).post('/auctions/$arg/bid');
    // Шинэ үнэ/хугацаа socket event-ээр ирнэ; balance-ыг профайлаас сэргээнэ
    unawaited(ref.read(authProvider.notifier).refreshProfile());
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}

final auctionDetailProvider = AsyncNotifierProvider.autoDispose
    .family<AuctionDetailController, AuctionDetail, String>(
        AuctionDetailController.new);


class AuctionDetailScreen extends ConsumerStatefulWidget {
  const AuctionDetailScreen({super.key, required this.auctionId});

  final String auctionId;

  @override
  ConsumerState<AuctionDetailScreen> createState() =>
      _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends ConsumerState<AuctionDetailScreen> {
  bool _bidding = false;
  String? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  /// Зочин "Нэвтэрч оролцох" дарвал нэвтрэх дэлгэц рүү — нэвтэрсний дараа яг энэ
  /// auction руугаа буцна.
  void _requireLogin() {
    context.push(loginLocation(next: '/auctions/${widget.auctionId}'));
  }

  Future<void> _bid() async {
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _bidding = true);
    try {
      await ref
          .read(auctionDetailProvider(widget.auctionId).notifier)
          .placeBid();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _bidding = false);
    }
  }

  /// Хугацаа сунгагдсан бол түр мэдэгдэл харуулна.
  void _onDetailChanged(
      AsyncValue<AuctionDetail>? prev, AsyncValue<AuctionDetail> next) {
    final a = prev?.valueOrNull;
    final b = next.valueOrNull;
    if (a == null || b == null || a.id != b.id) return;
    final secs = b.endsAt.difference(a.endsAt).inSeconds;
    if (secs <= 0 || b.status != 'live') return;
    _toastTimer?.cancel();
    setState(() => _toast = 'Хугацаа $secs секундээр сунгагдлаа');
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(auctionDetailProvider(widget.auctionId), _onDetailChanged);
    final detailAsync = ref.watch(auctionDetailProvider(widget.auctionId));
    final me = ref.watch(authProvider).valueOrNull;
    final wide = Breakpoints.isWide(context);
    final a = detailAsync.valueOrNull;

    Widget body;
    Widget? bottomBar;
    if (a != null) {
      final bid = a.status == 'live'
          ? _BidControl(
              auction: a,
              meId: me?.id,
              busy: _bidding,
              onBid: _bid,
              onLogin: _requireLogin,
            )
          : null;
      body = _buildData(a, me?.id, wide, bid);
      if (bid != null && !wide) bottomBar = _BidBar(child: bid);
    } else if (detailAsync.hasError) {
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(
                icon: LucideIcons.triangleAlert,
                title: apiErrorMessage(detailAsync.error!),
              ),
              SizedBox(
                width: 220,
                child: PrimaryButton(
                  label: 'Дахин оролдох',
                  onPressed: () =>
                      ref.invalidate(auctionDetailProvider(widget.auctionId)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = _DetailSkeleton(wide: wide);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Дуудлага'),
      ),
      bottomNavigationBar: bottomBar,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          // Хугацаа сунгагдсан мэдэгдэл
          Positioned(
            top: 8,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Center(child: _ExtendedToast(message: _toast)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildData(AuctionDetail a, String? meId, bool wide, Widget? bid) {
    final controller =
        ref.read(auctionDetailProvider(widget.auctionId).notifier);
    final live = a.status == 'live';
    final ended = a.status == 'ended' || a.status == 'settled';
    final iWon = ended && meId != null && a.lastBidder?.id == meId;
    final text = Theme.of(context).textTheme;

    final info = <Widget>[
      Text(a.title, style: text.titleLarge),
      const SizedBox(height: 8),
      _StatusLine(auction: a, ended: ended, iWon: iWon),
      const SizedBox(height: 12),
      if (!ended || a.lastBidder != null)
        Align(
          alignment: Alignment.centerLeft,
          child: AnimatedPrice(amount: a.currentPrice, fontSize: 34),
        ),
      const SizedBox(height: 16),
      if (live)
        _DetailTimer(
          startsAt: a.startsAt,
          endsAt: a.endsAt,
          bidCount: a.bidCount,
          offsetMs: controller.serverOffsetMs,
          onFinished: () => Future.delayed(const Duration(seconds: 2), () {
            if (mounted) unawaited(controller.reload());
          }),
        )
      else if (ended)
        Text('${a.bidCount} санал',
            style: TextStyle(
                fontSize: 15,
                color: AppColors.muted,
                fontFeatures: const [FontFeature.tabularFigures()])),
      if (ended && iWon) ...[
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Хожсон бараа руу очих',
          onPressed: () => context.go('/orders'),
        ),
      ],
    ];

    final details = <Widget>[
      if (a.description.isNotEmpty) ...[
        const _SectionTitle('Тайлбар'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Text(a.description,
              style: TextStyle(
                  fontSize: 15, height: 1.5, color: AppColors.inkSoft)),
        ),
      ],
      if (a.bids.isNotEmpty) ...[
        const _SectionTitle('Сүүлийн саналууд'),
        _BidHistory(bids: a.bids),
      ],
    ];

    final gallery = _Gallery(auctionId: a.id, images: a.images);

    if (wide) {
      return PageFrame(
        maxWidth: 1100,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 16, 40, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: gallery,
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                flex: 5,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 48),
                  children: [
                    ...info,
                    if (bid != null) ...[
                      const SizedBox(height: 24),
                      bid,
                    ],
                    ...details,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PageFrame(
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          gallery,
          const SizedBox(height: 20),
          ...info,
          ...details,
        ],
      ),
    );
  }
}

/// Хэсгийн гарчиг — 13/600 хоёрдогч өнгө, жижиг үсэг.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

/// Доод тогтмол хэсэг: гадаргуу + 0.5px дээд зураас + бага зэрэг blur.
class _BidBar extends StatelessWidget {
  const _BidBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(color: AppColors.borderHi, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Хугацаа сунгагдсан мэдэгдэл — дээрээс зөөлөн орж ирнэ.
class _ExtendedToast extends StatelessWidget {
  const _ExtendedToast({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final reduce = reducedMotion(context);
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : AppMotion.base,
      switchInCurve: AppMotion.enter,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.6), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: message == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Semantics(
              liveRegion: true,
              child: Container(
                key: ValueKey(message),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHi,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.timer, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}

/// Том зураг (inset, радиус 16). Хэд хэдэн зураг байвал шударч, доор нь цэг гарна.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.auctionId, required this.images});

  final String auctionId;
  final List<String> images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final placeholder = ArtPlaceholder(seed: widget.auctionId, iconSize: 64);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AspectRatio(
            aspectRatio: 1,
            child: images.isEmpty
                ? placeholder
                : PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      semanticLabel: 'Зураг ${i + 1}',
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : placeholder,
                      errorBuilder: (_, __, ___) => placeholder,
                    ),
                  ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                AnimatedContainer(
                  duration: AppMotion.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        i == _index ? AppColors.accent : AppColors.borderHi,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Тэргүүлж буй хүн / ялагч / эхлэх цаг. Алт зөвхөн "Ялагч"-д.
class _StatusLine extends StatelessWidget {
  const _StatusLine(
      {required this.auction, required this.ended, required this.iWon});

  final AuctionDetail auction;
  final bool ended;
  final bool iWon;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    IconData? icon;
    String text;
    Color color = AppColors.muted;
    if (ended) {
      icon = LucideIcons.trophy;
      if (iWon) {
        text = 'Та яллаа!';
        color = AppColors.gold;
      } else if (a.lastBidder != null) {
        text = 'Ялагч: ${a.lastBidder!.name}';
        color = AppColors.gold;
      } else {
        text = 'Ялагч байхгүй';
        icon = null;
      }
    } else if (a.status == 'live') {
      text = a.lastBidder != null
          ? 'Тэргүүлж байна: ${a.lastBidder!.name}'
          : 'Анхны санал хүлээж байна';
    } else {
      text = 'Удахгүй эхлэх · ${formatStartLabel(a.startsAt, DateTime.now())}';
    }
    return Semantics(
      liveRegion: true,
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: ended && a.lastBidder != null
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: color,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Үлдсэн хугацааны нимгэн (4px) зураас: урт = үлдсэн / нийт. Сүүлийн 10 секунд
/// улаан. Секунд тутам зөвхөн энэ жижиг widget дахин бүтнэ.
class _DetailTimer extends StatefulWidget {
  const _DetailTimer({
    required this.startsAt,
    required this.endsAt,
    required this.bidCount,
    required this.offsetMs,
    required this.onFinished,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final int bidCount;
  final int offsetMs;
  final VoidCallback onFinished;

  @override
  State<_DetailTimer> createState() => _DetailTimerState();
}

class _DetailTimerState extends State<_DetailTimer> {
  Timer? _ticker;
  late DateTime _now = _clock();
  bool _fired = false;

  DateTime _clock() =>
      DateTime.now().add(Duration(milliseconds: widget.offsetMs));

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _DetailTimer old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt) _fired = false;
    _now = _clock();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = _clock());
    if (!_fired && widget.endsAt.difference(_now).inMilliseconds <= 0) {
      _fired = true;
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(_now);
    final urgent = remaining.inMilliseconds > 0 && remaining.inSeconds < 10;
    final frac = remainingFraction(
        startsAt: widget.startsAt, endsAt: widget.endsAt, now: _now);
    const tab = [FontFeature.tabularFigures()];
    return Semantics(
      label: 'Үлдсэн хугацаа ${formatRemaining(remaining)}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: LayoutBuilder(builder: (context, box) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(end: frac),
                    duration: reducedMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 1000),
                    curve: Curves.linear,
                    builder: (context, v, _) => Stack(
                      children: [
                        Positioned.fill(
                            child: ColoredBox(color: AppColors.fill)),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: (box.maxWidth * v).clamp(0.0, box.maxWidth),
                          child: ColoredBox(
                              color: urgent
                                  ? AppColors.danger
                                  : AppColors.accent),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatRemaining(remaining),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tab,
                    color: urgent ? AppColors.danger : AppColors.ink,
                  ),
                ),
                Text(
                  '${widget.bidCount} санал',
                  style: TextStyle(
                    fontSize: 15,
                    fontFeatures: tab,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Дэлгэц дээрх ганц үндсэн үйлдэл — ногоон "Дуудлага худалдаанд оролцох".
class _BidControl extends StatelessWidget {
  const _BidControl({
    required this.auction,
    required this.meId,
    required this.busy,
    required this.onBid,
    required this.onLogin,
  });

  final AuctionDetail auction;
  final String? meId;
  final bool busy;
  final VoidCallback onBid;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final guest = meId == null;
    final mine = !guest && auction.lastBidder?.id == meId;
    final label = guest
        ? 'Нэвтэрч оролцох'
        : mine
            ? 'Та тэргүүлж байна'
            : 'Дуудлага худалдаанд оролцох';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          label: label,
          loading: busy,
          onPressed: mine ? null : (guest ? onLogin : onBid),
        ),
        const SizedBox(height: 8),
        Text(
          mine
              ? 'Өөр хүн оролцохыг хүлээнэ үү'
              : '1 эрх зарцуулна · үнэ ${formatMnt(auction.increment)}-өөр өснө',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }
}

String _timeAgo(DateTime t) {
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 10) return 'дөнгөж сая';
  if (s < 60) return '$s секундын өмнө';
  if (s < 3600) return '${s ~/ 60} минутын өмнө';
  if (s < 86400) return '${s ~/ 3600} цагийн өмнө';
  return '${s ~/ 86400} өдрийн өмнө';
}

/// Саналын түүх — grouped inset жагсаалт. "Хэдийн өмнө" шошго 15с тутам шинэчлэгдэнэ.
class _BidHistory extends StatefulWidget {
  const _BidHistory({required this.bids});

  final List<BidItem> bids;

  @override
  State<_BidHistory> createState() => _BidHistoryState();
}

class _BidHistoryState extends State<_BidHistory> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: ColoredBox(
        color: AppColors.surface,
        child: Column(
          children: [
            for (var i = 0; i < widget.bids.length; i++)
              _BidRow(
                key: ValueKey(widget.bids[i].id),
                bid: widget.bids[i],
                isTop: i == 0,
                last: i == widget.bids.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _BidRow extends StatelessWidget {
  const _BidRow(
      {super.key, required this.bid, required this.isTop, required this.last});

  final BidItem bid;
  final bool isTop;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        AppAvatar(name: bid.user.name, avatarUrl: bid.user.avatarUrl, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bid.user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: AppColors.ink),
              ),
              Text(
                _timeAgo(bid.createdAt),
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatMnt(bid.price),
          style: AppTheme.price(
              size: 17, color: isTop ? AppColors.accent : AppColors.ink),
        ),
      ]),
    );

    // 0.5px хуваагч — аватарын зүүн ирмэгээс эхэлнэ.
    final withDivider = Stack(
      children: [
        row,
        if (!last)
          Positioned(
            left: 64,
            right: 0,
            bottom: 0,
            child: Container(height: 0.5, color: AppColors.border),
          ),
      ],
    );

    if (reducedMotion(context)) return withDivider;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.base,
      curve: AppMotion.fluid,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, -12 * (1 - t)), child: child),
      ),
      child: withDivider,
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      maxWidth: wide ? 1100 : 560,
      child: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 8, wide ? 40 : 20, 0),
        child: LayoutBuilder(builder: (context, box) {
          final side = wide ? (box.maxWidth - 48) / 2 : box.maxWidth;
          final art = Skeleton(
              height: side.clamp(0, 560), width: side, radius: AppRadius.card);
          final lines = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Skeleton(height: 24, width: 240),
              SizedBox(height: 16),
              Skeleton(height: 34, width: 160),
              SizedBox(height: 16),
              Skeleton(height: 4),
            ],
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [art, const SizedBox(width: 48), Expanded(child: lines)],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [art, const SizedBox(height: 20), lines],
          );
        }),
      ),
    );
  }
}
