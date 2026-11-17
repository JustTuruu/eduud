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
import '../../shared/ambient_backdrop.dart';
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
  int _page = 0;
  String? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  /// Зочин "Санал өгөх" дарвал нэвтрэх дэлгэц рүү — нэвтэрсний дараа яг энэ
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

  void _back() => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    ref.listen(auctionDetailProvider(widget.auctionId), _onDetailChanged);
    final detailAsync = ref.watch(auctionDetailProvider(widget.auctionId));
    final me = ref.watch(authProvider).valueOrNull;
    final wide = Breakpoints.isWide(context);
    final a = detailAsync.valueOrNull;

    Widget body;
    if (a != null) {
      body = _buildData(a, me?.id, wide);
    } else if (detailAsync.hasError) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(
                icon: LucideIcons.triangleAlert,
                title: apiErrorMessage(detailAsync.error!),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 220,
                child: PrimaryButton(
                  label: 'Дахин оролдох',
                  icon: LucideIcons.refreshCw,
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

    final images = a?.images ?? const <String>[];
    final url = images.isEmpty ? null : images[_page.clamp(0, images.length - 1)];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AmbientBackdrop(
              image: url == null ? null : NetworkImage(url),
              imageKey: url,
              seed: widget.auctionId,
            ),
          ),
          Positioned.fill(child: SafeArea(bottom: false, child: body)),
          // Хугацаа сунгагдсан мэдэгдэл
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 72,
            right: 72,
            child: IgnorePointer(
              child: Center(child: _ExtendedToast(message: _toast)),
            ),
          ),
          // Буцах — шилэн дугуй
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            child: _GlassBackButton(onPressed: _back),
          ),
        ],
      ),
    );
  }

  Widget _buildData(AuctionDetail a, String? meId, bool wide) {
    final controller =
        ref.read(auctionDetailProvider(widget.auctionId).notifier);
    final live = a.status == 'live';
    final ended = a.status == 'ended' || a.status == 'settled';
    final iWon = ended && meId != null && a.lastBidder?.id == meId;

    final bidButton = live
        ? _BidControl(
            auction: a,
            meId: meId,
            busy: _bidding,
            onBid: _bid,
            onLogin: _requireLogin,
          )
        : null;

    final info = <Widget>[
      Text(
        a.title,
        style: const TextStyle(
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: AppColors.ink,
        ),
      ),
      const SizedBox(height: 12),
      _StatusLine(auction: a, ended: ended, iWon: iWon),
      const SizedBox(height: 8),
      if (!ended)
        Align(
          alignment: Alignment.centerLeft,
          child: AnimatedPrice(amount: a.currentPrice, fontSize: 44),
        )
      else if (a.lastBidder != null)
        Text(formatMnt(a.currentPrice),
            style: AppTheme.price(size: 44, color: AppColors.gold)),
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
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
                fontFeatures: [FontFeature.tabularFigures()])),
      if (ended && iWon) ...[
        const SizedBox(height: 20),
        _WonAction(onTap: () => context.go('/orders')),
      ],
    ];

    final details = <Widget>[
      if (a.description.isNotEmpty) ...[
        const _SectionTitle('Тайлбар'),
        Text(a.description,
            style: const TextStyle(
                fontSize: 15, height: 1.65, color: AppColors.inkSoft)),
      ],
      if (a.bids.isNotEmpty) ...[
        const _SectionTitle('Сүүлийн саналууд'),
        _BidHistory(bids: a.bids),
      ],
    ];

    final gallery = _Gallery(
      auctionId: a.id,
      images: a.images,
      onPageChanged: (i) => setState(() => _page = i),
    );

    if (wide) {
      return PageFrame(
        maxWidth: 1120,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 72, 40, 0),
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
                    if (bidButton != null) ...[
                      const SizedBox(height: 24),
                      bidButton,
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

    return Stack(
      children: [
        PageFrame(
          maxWidth: 560,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 64, 20, live ? 148 : 48),
            children: [
              gallery,
              const SizedBox(height: 24),
              ...info,
              ...details,
            ],
          ),
        ),
        if (bidButton != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00140B1C), AppColors.bg],
                  stops: [0, 0.4],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                  child: PageFrame(maxWidth: 560, child: bidButton),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Хэсгийн гарчиг — дээр нь илүү зай, доор нь бага.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Буцах',
      child: AnimatedPressable(
        onPressed: onPressed,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bg.withValues(alpha: 0.45),
                border: Border.all(color: AppColors.borderHi),
              ),
              child: const Icon(LucideIcons.chevronLeft,
                  size: 22, color: AppColors.ink),
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
                  border: Border.all(
                      color: AppColors.coral.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.timer,
                      size: 16, color: AppColors.coralLight),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
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

/// Том зураг. Хэд хэдэн зураг байвал хуруугаар шударч, доор нь цэг гарна.
class _Gallery extends StatefulWidget {
  const _Gallery({
    required this.auctionId,
    required this.images,
    required this.onPageChanged,
  });

  final String auctionId;
  final List<String> images;
  final ValueChanged<int> onPageChanged;

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
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.art),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.art),
            child: AspectRatio(
              aspectRatio: 1,
              child: images.isEmpty
                  ? placeholder
                  : PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) {
                        setState(() => _index = i);
                        widget.onPageChanged(i);
                      },
                      itemBuilder: (context, i) => Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        semanticLabel: 'Зураг ${i + 1}',
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : placeholder,
                        errorBuilder: (_, __, ___) => placeholder,
                      ),
                    ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                AnimatedContainer(
                  duration: AppMotion.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.coral
                        : AppColors.ink.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Тэргүүлж буй хүн / ялагч / эхлэх цаг.
class _StatusLine extends StatelessWidget {
  const _StatusLine(
      {required this.auction, required this.ended, required this.iWon});

  final AuctionDetail auction;
  final bool ended;
  final bool iWon;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    IconData icon;
    String text;
    Color color = AppColors.inkSoft;
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
      }
    } else if (a.status == 'live') {
      icon = LucideIcons.crown;
      text = a.lastBidder != null
          ? 'Тэргүүлж байна: ${a.lastBidder!.name}'
          : 'Анхны санал хүлээж байна';
    } else {
      icon = LucideIcons.clock;
      text = 'Удахгүй эхлэх · ${formatStartLabel(a.startsAt, DateTime.now())}';
    }
    return Semantics(
      liveRegion: true,
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ]),
    );
  }
}

class _WonAction extends StatelessWidget {
  const _WonAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: 'Хожсон бараа руу очих',
      icon: LucideIcons.trophy,
      onPressed: onTap,
    );
  }
}

/// Үлдсэн хугацааны зураас: урт = үлдсэн / нийт. Сүүлийн 10 секундэд шүрэн
/// лугшино. Секунд тутам зөвхөн энэ жижиг widget дахин бүтнэ.
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

class _DetailTimerState extends State<_DetailTimer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  Timer? _ticker;
  late DateTime _now = _clock();
  bool _urgent = false;
  bool _fired = false;

  DateTime _clock() =>
      DateTime.now().add(Duration(milliseconds: widget.offsetMs));

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _updateUrgent();
  }

  @override
  void didUpdateWidget(covariant _DetailTimer old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt) _fired = false;
    _now = _clock();
    _updateUrgent();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = _clock());
    _updateUrgent();
    if (!_fired && widget.endsAt.difference(_now).inMilliseconds <= 0) {
      _fired = true;
      widget.onFinished();
    }
  }

  void _updateUrgent() {
    final ms = widget.endsAt.difference(_now).inMilliseconds;
    final urgent = ms > 0 && ms <= 10000;
    if (urgent == _urgent) return;
    _urgent = urgent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_urgent && !reducedMotion(context)) {
        unawaited(_pulse.repeat(reverse: true));
      } else {
        _pulse.stop();
        _pulse.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(_now);
    final frac = remainingFraction(
        startsAt: widget.startsAt, endsAt: widget.endsAt, now: _now);
    const tab = [FontFeature.tabularFigures()];
    return Semantics(
      label: 'Үлдсэн хугацаа ${formatRemaining(remaining)}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: 6,
              child: LayoutBuilder(builder: (context, box) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(end: frac),
                  duration: reducedMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 1000),
                  curve: Curves.linear,
                  builder: (context, v, _) => AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final p = _pulse.value;
                      final fill =
                          Color.lerp(AppColors.coral, AppColors.coralLight, p)!;
                      final x = (box.maxWidth * v).clamp(0.0, box.maxWidth);
                      return Stack(
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.ink.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Container(
                            height: 6,
                            width: x,
                            decoration: BoxDecoration(
                              color: fill,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: _urgent
                                  ? [
                                      BoxShadow(
                                        color: AppColors.coral.withValues(
                                            alpha: 0.25 + 0.45 * p),
                                        blurRadius: 6 + 8 * p,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatRemaining(remaining),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFeatures: tab,
                    color: _urgent ? AppColors.coralLight : AppColors.ink,
                  ),
                ),
                Text(
                  '${widget.bidCount} санал',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tab,
                    color: AppColors.inkSoft,
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

/// Дэлгэц дээрх ганц, тусгаарлагдсан үндсэн үйлдэл.
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
    final disabled = mine || busy;
    final label = guest
        ? 'Нэвтэрч санал өгөх · 1 эрх'
        : mine
            ? 'Та тэргүүлж байна'
            : 'Санал өгөх · 1 эрх';
    final icon = guest
        ? LucideIcons.logIn
        : mine
            ? LucideIcons.crown
            : LucideIcons.gavel;
    final fg = mine ? AppColors.muted : AppColors.ctaInk;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: !disabled,
          label: label,
          child: ExcludeSemantics(
            child: AnimatedPressable(
              haptic: false,
              scale: 0.96,
              onPressed: disabled ? null : (guest ? onLogin : onBid),
              child: Container(
                height: 56,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: disabled ? null : AppColors.ctaGradient,
                  color: disabled ? AppColors.surfaceHi : null,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: disabled
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.coral.withValues(alpha: 0.38),
                            blurRadius: 26,
                            offset: const Offset(0, 10),
                          ),
                        ],
                ),
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: AppColors.coral),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 20, color: fg),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: fg,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          mine
              ? 'Өөр хүн санал өгөхийг хүлээнэ үү'
              : 'Санал бүр үнийг ${formatMnt(auction.increment)}-аар өсгөнө',
          style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
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

/// Саналын түүх — цэвэр жагсаалт. "Хэдийн өмнө" шошго 15с тутам шинэчлэгдэнэ.
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
    return Column(
      children: [
        for (var i = 0; i < widget.bids.length; i++)
          _BidRow(
            key: ValueKey(widget.bids[i].id),
            bid: widget.bids[i],
            isTop: i == 0,
            last: i == widget.bids.length - 1,
          ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
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
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink),
              ),
              Text(
                _timeAgo(bid.createdAt),
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatMnt(bid.price),
          style: AppTheme.price(
              size: 16, color: isTop ? AppColors.coralLight : AppColors.ink),
        ),
      ]),
    );

    if (reducedMotion(context)) return row;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.base,
      curve: AppMotion.fluid,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, -12 * (1 - t)), child: child),
      ),
      child: row,
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      maxWidth: wide ? 1120 : 560,
      child: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 64, wide ? 40 : 20, 0),
        child: LayoutBuilder(builder: (context, box) {
          final side = wide ? (box.maxWidth - 48) / 2 : box.maxWidth;
          final art = Skeleton(
              height: side.clamp(0, 560), width: side, radius: AppRadius.art);
          final lines = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Skeleton(height: 28, width: 240),
              SizedBox(height: 16),
              Skeleton(height: 44, width: 180),
              SizedBox(height: 16),
              Skeleton(height: 10),
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
            children: [art, const SizedBox(height: 24), lines],
          );
        }),
      ),
    );
  }
}
