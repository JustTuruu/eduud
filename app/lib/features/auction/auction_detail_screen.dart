import 'dart:async';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
import '../../shared/live_countdown_text.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../home/auction_tiles.dart' show ArtPlaceholder;
import 'consent_sheet.dart';
import '../home/auction_timing.dart';
import 'image_peek.dart';
import '../wallet/sub_page.dart' show GroupSection;
import '../../shared/top_toast.dart';

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

  /// [step] — сонгосон үнийн алхам (1..5 ₮); 1 эрх зарцуулж, үнэ зөвхөн step-ээр өснө.
  Future<void> placeBid({int step = 1}) async {
    await ref
        .read(dioProvider)
        .post('/auctions/$arg/bid', data: {'step': step});
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
  int _step = 1; // энэ дуудлагад сүүлд сонгосон алхам (₮)
  String? _bidError; // "Үнэ илгээх" хэсэгт inline харагдах алдаа

  /// Зочин "Нэвтэрч оролцох" дарвал нэвтрэх дэлгэц рүү — нэвтэрсний дараа яг энэ
  /// auction руугаа буцна.
  void _requireLogin() {
    context.push(loginLocation(next: '/auctions/${widget.auctionId}'));
  }

  Future<void> _bid() async {
    // Энэ дуудлагад анх удаа үнэ илгээхийн өмнө дүрмийн зөвшөөрөл авна.
    final ok = await ensureAuctionConsent(
      context,
      ref,
      auctionId: widget.auctionId,
    );
    if (!ok || !mounted) return;
    setState(() {
      _bidding = true;
      _bidError = null;
    });
    try {
      await ref
          .read(auctionDetailProvider(widget.auctionId).notifier)
          .placeBid(step: _step);
      // Бодит шинэчлэлт socket event-ээр ирнэ — энд зөвхөн товч баталгаажуулна.
      unawaited(HapticFeedback.mediumImpact());
      _showToast('Таны үнэ илгээгдлээ');
    } catch (e) {
      if (mounted) setState(() => _bidError = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _bidding = false);
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    showTopToast(context, message, kind: TopToastKind.success);
  }

  /// Хугацаа сунгагдсан бол түр мэдэгдэл харуулна.
  void _onDetailChanged(
      AsyncValue<AuctionDetail>? prev, AsyncValue<AuctionDetail> next) {
    final a = prev?.valueOrNull;
    final b = next.valueOrNull;
    if (a == null || b == null || a.id != b.id) return;
    final secs = b.endsAt.difference(a.endsAt).inSeconds;
    if (secs <= 0 || b.status != 'live') return;
    _showToast('Хугацаа $secs секундээр сунгагдлаа');
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
          ? BidControl(
              meId: me?.id,
              balance: me?.balance ?? 0,
              error: _bidError,
              busy: _bidding,
              step: _step,
              onStep: (v) => setState(() => _step = v),
              onBid: _bid,
              onLogin: _requireLogin,
              onTopUp: () => context.push('/wallet'),
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
      body: body,
    );
  }

  Widget _buildData(AuctionDetail a, String? meId, bool wide, Widget? bid) {
    final controller =
        ref.read(auctionDetailProvider(widget.auctionId).notifier);
    final ended = a.status == 'ended' || a.status == 'settled';
    final iWon = ended && meId != null && a.lastBidder?.id == meId;
    final text = Theme.of(context).textTheme;

    // Зургийн доор: гарчиг + тайлбар
    final intro = <Widget>[
      Text(a.title, style: text.titleLarge),
      if (a.description.isNotEmpty) ...[
        const SizedBox(height: 8),
        _Description(text: a.description),
      ],
      const SizedBox(height: 12),
    ];

    final info = <Widget>[
      _StatusLine(auction: a, ended: ended, iWon: iWon),
      const SizedBox(height: 12),
      if (!ended || a.lastBidder != null)
        Align(
          alignment: Alignment.centerLeft,
          child: AnimatedPrice(amount: a.currentPrice, fontSize: 34),
        ),
      const SizedBox(height: 16),
      TimingCard(
        auction: a,
        offsetMs: controller.serverOffsetMs,
        onFinished: () => Future.delayed(const Duration(seconds: 2), () {
          if (mounted) unawaited(controller.reload());
        }),
      ),
      if (a.prizes.isNotEmpty) ...[
        const SizedBox(height: 16),
        PrizesCard(
          mainTitle: a.title,
          prizes: a.prizes,
          placements: ended && a.placements.isNotEmpty
              ? a.placements
              : currentPlacements(a.bids),
          meId: meId,
          isFinal: ended,
        ),
      ],
      if (ended && iWon) ...[
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Хожсон бараа руу очих',
          onPressed: () => context.go('/orders'),
        ),
      ],
    ];

    final details = <Widget>[
      if (a.bids.isNotEmpty) ...[
        const _SectionTitle('Сүүлийн саналууд'),
        BidHistory(bids: a.bids, meId: meId),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      gallery,
                      const SizedBox(height: 20),
                      ...intro,
                    ],
                  ),
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

    // Утсан дээр зураг хоёр талдаа ирмэг хүртэл (full-bleed), текст 20px padding-тай.
    return PageFrame(
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _Gallery(auctionId: a.id, images: a.images, fullBleed: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...intro, ...info, ...details],
            ),
          ),
        ],
      ),
    );
  }
}

/// Бүтээгдэхүүний тайлбар — 4 мөрөөс урт бол "Цааш унших"-аар нээгдэнэ.
class _Description extends StatefulWidget {
  const _Description({required this.text});

  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  static const _maxLines = 4;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style =
        TextStyle(fontSize: 15.5, height: 1.4, color: AppColors.muted);
    return LayoutBuilder(builder: (context, c) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: _maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: c.maxWidth);
      final overflow = tp.didExceedMaxLines;
      tp.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: reducedMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Text(
              widget.text,
              style: style,
              maxLines: _open ? null : _maxLines,
              overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
          if (overflow)
            Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                key: const ValueKey('desc-toggle'),
                onTap: () => setState(() => _open = !_open),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_open ? 'Хураах' : 'Цааш унших',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent)),
                  ),
                ),
              ),
            ),
        ],
      );
    });
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

/// Том зураг (inset, радиус 16). Хэд хэдэн зураг байвал шударч, доор нь цэг гарна.
class _Gallery extends StatefulWidget {
  const _Gallery(
      {required this.auctionId, required this.images, this.fullBleed = false});

  final String auctionId;
  final List<String> images;

  /// Утсан дээр: ирмэг хүртэл, радиусгүй.
  final bool fullBleed;

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
          borderRadius: widget.fullBleed
              ? BorderRadius.zero
              : BorderRadius.circular(AppRadius.card),
          child: AspectRatio(
            aspectRatio: 1,
            child: images.isEmpty
                ? placeholder
                : PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          showImagePeek(context, images: images, initial: i),
                      child: Image.network(
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
                    color: i == _index ? AppColors.accent : AppColors.borderHi,
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

/// Хугацааны бүлэг (iOS inset-grouped): эхэлсэн/дуусах цаг, одоогийн шатны
/// тоолуур, сунгалтын дүрэм, саналын тоо. Секунд тутам зөвхөн энэ widget дахин
/// бүтнэ; endsAt (auction_extended-ээр шинэчлэгдэнэ) өөрчлөгдвөл onFinished дахин зэвсэглэнэ.
class TimingCard extends StatefulWidget {
  const TimingCard({
    super.key,
    required this.auction,
    required this.offsetMs,
    required this.onFinished,
  });

  final AuctionDetail auction;
  final int offsetMs;
  final VoidCallback onFinished;

  @override
  State<TimingCard> createState() => TimingCardState();
}

class TimingCardState extends State<TimingCard> {
  Timer? _ticker;
  late DateTime _now = _clock();
  bool _fired = false;

  DateTime _clock() =>
      DateTime.now().add(Duration(milliseconds: widget.offsetMs));

  bool get _running =>
      widget.auction.status == 'live' || widget.auction.status == 'scheduled';

  @override
  void initState() {
    super.initState();
    if (_running) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void didUpdateWidget(covariant TimingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auction.endsAt != widget.auction.endsAt) _fired = false;
    _now = _clock();
    if (_running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!_running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = _clock());
    final a = widget.auction;
    if (a.status == 'live' &&
        !_fired &&
        a.endsAt.difference(_now).inMilliseconds <= 0) {
      _fired = true;
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(fontSize: 13, height: 1.3, color: AppColors.muted));

  /// Доод мөрийн нэг нүд: жижиг шошго + нэг мөр утга (багтахгүй бол жижгэрнэ).
  Widget _dateCell(String title, String value, EdgeInsets pad) {
    const tab = [FontFeature.tabularFigures()];
    return Expanded(
      child: Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(title),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      fontFeatures: tab,
                      color: AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datesRow(
      String startLabel, String startValue, String endLabel, String endValue) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dateCell(startLabel, startValue,
              const EdgeInsets.fromLTRB(16, 14, 12, 14)),
          Container(width: 0.5, color: AppColors.borderHi),
          _dateCell(
              endLabel, endValue, const EdgeInsets.fromLTRB(16, 14, 16, 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.auction;
    final live = a.status == 'live';
    final scheduled = a.status == 'scheduled';
    final ended = a.status == 'ended' || a.status == 'settled';
    final rounds = a.rounds;
    final hasRounds = rounds != null && rounds.isNotEmpty;
    final waitingFirst = hasRounds && live && a.bidCount == 0;

    final rows = <Widget>[];
    if (live || scheduled) {
      rows.add(_splitBox(a, rounds, hasRounds, waitingFirst));
    }
    rows.add(_datesRow(
      scheduled ? 'Эхлэх' : 'Эхэлсэн',
      formatExactDateTime(a.startsAt),
      ended
          ? 'Дууссан'
          : waitingFirst
              ? 'Хамгийн оройдоо'
              : 'Дуусах',
      formatExactDateTime(waitingFirst ? _lastEnd(rounds) : a.endsAt),
    ));
    if ((live || scheduled) && hasRounds && live && !waitingFirst) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Text('Үнэ ирэх бүрт тухайн round-ын хугацаагаар дахин эхэлнэ',
            style:
                TextStyle(fontSize: 12, height: 1.35, color: AppColors.muted)),
      ));
    }

    if (live && a.randomCloseSec > 0) {
      final inWindow = inRandomCloseWindow(a.randomCloseFrom, _now);
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: inWindow
            ? Row(children: [
                Icon(LucideIcons.triangleAlert,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Санамсаргүй хаалтын үе — хэзээ ч хаагдаж болно',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger)),
                ),
              ])
            : a.hardCloseAt != null
                ? Text(
                    'Эцсийн хаалтаас өмнөх сүүлийн ${(a.randomCloseSec / 60).ceil()} минутад санамсаргүй агшинд хаагдана',
                    style: TextStyle(
                        fontSize: 12, height: 1.35, color: AppColors.muted))
                : const SizedBox.shrink(),
      ));
    }

    final card = GroupSection(children: rows);
    if (!hasRounds || ended) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        const SizedBox(height: 20),
        RoundsList(
          rounds: rounds,
          currentIndex: live ? roundIndexAt(rounds, _now) : null,
        ),
      ],
    );
  }

  DateTime _lastEnd(List<AuctionRound> r) => r.last.endsAt;

  Widget _small(String text, {Color? color, FontWeight? weight}) => Text(text,
      style: TextStyle(
          fontSize: 12,
          height: 1.35,
          fontWeight: weight,
          color: color ?? AppColors.muted));

  /// 2×2 картын дээд мөр, хоёр тэнцүү хагас: зүүн — тоолуур, баруун — одоогийн round
  /// (round байхгүй бол сунгалтын шат). Дунд нь нимгэн босоо зураас.
  Widget _splitBox(AuctionDetail a, List<AuctionRound>? rounds, bool hasRounds,
      bool waitingFirst) {
    const tab = [FontFeature.tabularFigures()];
    final live = a.status == 'live';
    final scheduled = a.status == 'scheduled';
    final target = scheduled ? a.startsAt : a.endsAt;
    final remaining = target.difference(_now);
    final soft = live && inSoftClose(remaining, a.softCloseSec);

    // Зүүн хагас
    final leftLabel = scheduled ? 'Эхлэх хүртэл' : 'Үлдсэн хугацаа';
    final Widget leftValue = waitingFirst
        ? Text('—',
            style: TextStyle(
                fontSize: 32,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink))
        : FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: LiveCountdownText(
              endsAt: target,
              serverOffsetMs: widget.offsetMs,
              urgentColor: live ? AppColors.danger : null,
              style: TextStyle(
                fontSize: 32,
                height: 1.15,
                fontWeight: FontWeight.w700,
                fontFeatures: tab,
                color: AppColors.ink,
              ),
            ),
          );

    // Баруун хагас
    String rightLabel;
    String rightValue;
    Color rightColor = AppColors.accent;
    String rightNote;
    String semRight;
    if (hasRounds) {
      final idx = roundIndexAt(rounds!, _now) ?? 0;
      final r = rounds[idx];
      rightLabel = scheduled ? 'Эхний round' : 'Одоогийн round';
      rightValue = 'Round ${idx + 1}';
      rightNote =
          '${formatRoundDuration(r.durationSec)} · ${formatTimeRange(r.startsAt, r.endsAt)}';
      semRight = rightValue;
    } else {
      rightLabel = 'Үе шат';
      if (scheduled) {
        rightValue = 'Товлосон';
        rightColor = AppColors.ink;
      } else {
        rightValue = soft ? 'Сунгалтын шат' : 'Үндсэн хугацаа';
        rightColor = soft ? AppColors.danger : AppColors.accent;
      }
      final b = StringBuffer();
      if (live && a.softCloseSec > 0 && a.extendSec > 0) {
        b.write('Сүүлийн ${a.softCloseSec}с-д үнэ ирвэл +${a.extendSec}с');
        if (a.hardCloseAt != null) {
          b.write(
              ' · Эцсийн хаалт ${DateFormat('HH:mm').format(a.hardCloseAt!.toLocal())}');
        }
      }
      rightNote = b.toString();
      semRight = rightValue;
    }

    final label = waitingFirst
        ? '$leftLabel: анхны үнэ хүлээж байна, $semRight'
        : '$leftLabel ${formatRemaining(remaining)}, $semRight';

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(leftLabel),
                      const SizedBox(height: 4),
                      leftValue,
                      if (waitingFirst) ...[
                        const SizedBox(height: 4),
                        _small('Анхны үнэ ирмэгц эхэлнэ'),
                      ],
                    ],
                  ),
                ),
              ),
              Container(width: 0.5, color: AppColors.borderHi),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(rightLabel),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(rightValue,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: hasRounds ? 32 : 22,
                              height: hasRounds ? 1.15 : 1.5,
                              fontWeight: FontWeight.w700,
                              color: rightColor,
                            )),
                      ),
                      if (rightNote.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _small(rightNote),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Шагнал" карт: 1-р байр = үндсэн бараа, 2/3-р байр = нэмэлт шагнал.
/// [placements] байвал байр бүрийн эзнийг (дууссан бол эцсийн, эс бөгөөс
/// одоогийн) харуулж, өөрийгөө "Та" гэж тодруулна.
class PrizesCard extends StatelessWidget {
  const PrizesCard({
    super.key,
    required this.mainTitle,
    required this.prizes,
    this.placements = const [],
    this.meId,
    this.isFinal = false,
  });

  final String mainTitle;
  final List<AuctionPrize> prizes;
  final List<AuctionPlacement> placements;
  final String? meId;

  /// true бол байрууд эцсийн (дууссан), false бол "одоогоор".
  final bool isFinal;

  @override
  Widget build(BuildContext context) {
    final rows = <(int, String)>[
      (1, mainTitle),
      for (final p in prizes)
        if (p.place == 2 || p.place == 3) (p.place, p.label),
    ];
    Bidder? holder(int place) {
      for (final p in placements) {
        if (p.place == place) return p.user;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Icon(LucideIcons.trophy, size: 15, color: AppColors.accent),
            const SizedBox(width: 6),
            Text('Шагнал',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
          ]),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ColoredBox(
            color: AppColors.surface,
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Container(height: 0.5, color: AppColors.borderHi),
                  ),
                _PrizeRow(
                  place: rows[i].$1,
                  label: rows[i].$2,
                  holder: holder(rows[i].$1),
                  meId: meId,
                ),
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('Сүүлд санал өгсөн 3 өөр оролцогч шагнал авна',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ),
      ],
    );
  }
}

class _PrizeRow extends StatelessWidget {
  const _PrizeRow({
    required this.place,
    required this.label,
    this.holder,
    this.meId,
  });

  final int place;
  final String label;
  final Bidder? holder;
  final String? meId;

  @override
  Widget build(BuildContext context) {
    final me = holder != null && holder!.id == meId;
    return Container(
      color: me ? AppColors.accent.withValues(alpha: 0.13) : null,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 64,
          child: Text('$place-р байр',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: AppColors.ink)),
              if (holder != null)
                Text(me ? 'Та' : holder!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: me ? FontWeight.w700 : FontWeight.w400,
                        color: me ? AppColors.accent : AppColors.muted)),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Round-уудын жагсаалт (grouped card): нэг мөр = шат. Одоогийн шат тодорно,
/// өнгөрсөн нь бүдэг. Мөрийн зураас нь шатны уртыг (хамгийн урт шатад харьцуулан)
/// статикаар харуулна — секунд тутам шинэчлэгдэхгүй.
class RoundsList extends StatefulWidget {
  const RoundsList({super.key, required this.rounds, this.currentIndex});

  final List<AuctionRound> rounds;
  final int? currentIndex;

  @override
  State<RoundsList> createState() => _RoundsListState();
}

class _RoundsListState extends State<RoundsList> {
  // Хураангуй (анхдагч): зөвхөн одоогийн round. Төлөв зөвхөн widget-д хадгалагдана.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rounds = widget.rounds;
    final cur = widget.currentIndex;
    final maxSec =
        rounds.fold<int>(1, (m, r) => r.durationSec > m ? r.durationSec : m);
    // Одоогийн round байхгүй бол (эхлээгүй) эхний мөрийг харуулна.
    final focus = (cur ?? 0).clamp(0, rounds.length - 1);
    final reduce = reducedMotion(context);

    Widget rowAt(int i) => _RoundRow(
          key: ValueKey('round-$i'),
          index: i,
          round: rounds[i],
          fraction: rounds[i].durationSec / maxSec,
          current: i == cur,
          past: cur != null && i < cur,
        );

    final visible =
        _expanded ? [for (var i = 0; i < rounds.length; i++) i] : <int>[focus];
    final body = Column(children: [
      for (var k = 0; k < visible.length; k++) ...[
        if (k > 0)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(height: 0.5, color: AppColors.borderHi),
          ),
        rowAt(visible[k]),
      ],
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: 'Round-ууд, бүгд ${rounds.length}',
          child: ExcludeSemantics(
            child: InkWell(
              key: const ValueKey('rounds-toggle'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                  child: Row(children: [
                    Expanded(
                      child: Text('Round-ууд',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted)),
                    ),
                    Text('Бүгд (${rounds.length})',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent)),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: reduce ? Duration.zero : AppMotion.fast,
                      curve: AppMotion.enter,
                      child: Icon(LucideIcons.chevronDown,
                          size: 18, color: AppColors.accent),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ColoredBox(
            color: AppColors.surface,
            child: AnimatedSize(
              duration:
                  reduce ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: body,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({
    super.key,
    required this.index,
    required this.round,
    required this.fraction,
    required this.current,
    required this.past,
  });

  final int index;
  final AuctionRound round;
  final double fraction;
  final bool current;
  final bool past;

  @override
  Widget build(BuildContext context) {
    const tab = [FontFeature.tabularFigures()];
    final dur = formatRoundDuration(round.durationSec);
    final range = formatTimeRange(round.startsAt, round.endsAt);
    final row = Container(
      color: current ? AppColors.accent.withValues(alpha: 0.13) : null,
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Round ${index + 1}',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                    color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(range,
                style: TextStyle(
                    fontSize: 15, fontFeatures: tab, color: AppColors.muted)),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth * fraction).clamp(8.0, c.maxWidth);
              return Container(
                height: 8,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Container(
                  width: w,
                  height: 8,
                  decoration: BoxDecoration(
                    color: current
                        ? AppColors.accent
                        : AppColors.muted.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(
          width: 78,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(dur,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                    color: current ? AppColors.ink : AppColors.muted)),
          ),
        ),
      ]),
    );
    return Semantics(
      label: 'Round ${index + 1}, $range, $dur',
      child: ExcludeSemantics(
        child: past ? Opacity(opacity: 0.5, child: row) : row,
      ),
    );
  }
}

/// "Үнэ илгээх" хэсэг — зөвхөн товч (нэвтрээгүй / эрхгүй үед тохирох үйлдэл) + алдааны мөр.
@visibleForTesting
class BidControl extends StatelessWidget {
  const BidControl({
    required this.meId,
    required this.balance,
    required this.error,
    required this.busy,
    required this.onBid,
    required this.onLogin,
    required this.onTopUp,
    this.step = 1,
    this.onStep,
  });

  final String? meId;
  final int balance;
  final String? error;
  final bool busy;
  final VoidCallback onBid;
  final VoidCallback onLogin;
  final VoidCallback onTopUp;
  final int step;
  final ValueChanged<int>? onStep;

  @override
  Widget build(BuildContext context) {
    final guest = meId == null;
    final noBalance = !guest && balance <= 0;
    final showSteps = !guest && !noBalance;

    final Widget control;
    if (showSteps) {
      control = _FusedBidControl(
        step: step,
        label: 'Үнэ илгээх · +${formatMnt(step)}',
        busy: busy,
        onStep: (v) => onStep?.call(v),
        onBid: onBid,
      );
    } else {
      control = PrimaryButton(
        label: guest ? 'Нэвтэрч оролцох' : 'Эрх цэнэглэх',
        loading: busy,
        onPressed: guest ? onLogin : onTopUp,
        radius: bidControlRadius,
        minHeight: 52,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        control,
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

/// Үнэ илгээх товч ба алхам сонгогчийн нийтлэг булан (capsule).
const double bidControlRadius = 28;
const double bidControlPadding = 4;

const double _tabHeight = 44;
const double _sendHeight = 52;
const double _sendRadius = bidControlRadius - bidControlPadding;
const double _tabRadius = 20;
const double _filletRadius = 10;

/// Алхам сонгогч + илгээх товч — сонгосон "+N" нь товчтой нэг ногоон дүрс
/// болж (folder tab шиг) товчноос ургана: "энэ дүн → энэ товч".
class _FusedBidControl extends StatelessWidget {
  const _FusedBidControl({
    required this.step,
    required this.label,
    required this.busy,
    required this.onStep,
    required this.onBid,
  });

  static const steps = [1, 2, 3, 4, 5];

  final int step;
  final String label;
  final bool busy;
  final ValueChanged<int> onStep;
  final VoidCallback onBid;

  @override
  Widget build(BuildContext context) {
    final reduce = reducedMotion(context);
    final index = steps.indexOf(step).clamp(0, steps.length - 1);
    return Container(
      padding: const EdgeInsets.all(bidControlPadding),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(bidControlRadius),
      ),
      child: Semantics(
        container: true,
        label: 'Үнийн алхам сонгох',
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: index.toDouble()),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          builder: (context, pos, _) {
            return CustomPaint(
              painter: _FusedShapePainter(
                position: pos,
                count: steps.length,
                color: AppColors.accent,
              ),
              child: SizedBox(
                height: _tabHeight + _sendHeight,
                child: Column(
                  children: [
                    SizedBox(
                      height: _tabHeight,
                      child: Row(
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            Expanded(
                              child: _StepSegment(
                                step: steps[i],
                                // 0..1 — tab-ийн доор байх хэмжээ
                                weight: (1 - (pos - i).abs()).clamp(0.0, 1.0),
                                dimmed: busy,
                                onTap: !busy && steps[i] != step
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        onStep(steps[i]);
                                      }
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                        child:
                            _SendArea(label: label, busy: busy, onBid: onBid)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Ногоон дүрсийн дээрх "Үнэ илгээх" хэсэг (өнгийг painter зурна).
class _SendArea extends StatefulWidget {
  const _SendArea(
      {required this.label, required this.busy, required this.onBid});

  final String label;
  final bool busy;
  final VoidCallback onBid;

  @override
  State<_SendArea> createState() => _SendAreaState();
}

class _SendAreaState extends State<_SendArea> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                HapticFeedback.lightImpact();
                widget.onBid();
              }
            : null,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.8 : 1,
          duration: AppMotion.fast,
          child: Center(
            child: widget.busy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppColors.ctaInk),
                  )
                : ExcludeSemantics(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ctaInk,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Товч (доод) ба сонгосон сегментийн tab (дээд)-ийг нэг Path болгож зурна.
/// Tab-ийн хажуу ба товчны дээд ирмэгийн уулзвар нь гүдгэр биш (concave) fillet;
/// tab зах руу очвол тэр талын булан/fillet нь шугаман багасч шулуун ирмэг болно.
class _FusedShapePainter extends CustomPainter {
  _FusedShapePainter({
    required this.position,
    required this.count,
    required this.color,
  });

  final double position;
  final int count;
  final Color color;

  @visibleForTesting
  static Path buildPath(Size size, double position, int count) {
    final w = size.width;
    final h = size.height;
    final by = _tabHeight; // товчны дээд ирмэг
    final sw = w / count;
    final left = position * sw;
    final right = left + sw;

    // Хажуугийн зай < булан + fillet бол пропорциональ багасгана
    const need = _sendRadius + _filletRadius;
    final kl = (left / need).clamp(0.0, 1.0);
    final kr = ((w - right) / need).clamp(0.0, 1.0);
    final rl = _sendRadius * kl, fl = _filletRadius * kl;
    final rr = _sendRadius * kr, fr = _filletRadius * kr;
    const rt = _tabRadius;
    const pi = 3.141592653589793;

    final p = Path()..moveTo(rl, by);
    p.lineTo(left - fl, by);
    if (fl > 0.01) {
      p.arcTo(Rect.fromCircle(center: Offset(left - fl, by - fl), radius: fl),
          pi / 2, -pi / 2, false);
    }
    p.lineTo(left, rt);
    p.arcTo(Rect.fromCircle(center: Offset(left + rt, rt), radius: rt), pi,
        pi / 2, false);
    p.lineTo(right - rt, 0);
    p.arcTo(Rect.fromCircle(center: Offset(right - rt, rt), radius: rt),
        -pi / 2, pi / 2, false);
    p.lineTo(right, by - fr);
    if (fr > 0.01) {
      p.arcTo(Rect.fromCircle(center: Offset(right + fr, by - fr), radius: fr),
          pi, -pi / 2, false);
    }
    p.lineTo(w - rr, by);
    if (rr > 0.01) {
      p.arcTo(Rect.fromCircle(center: Offset(w - rr, by + rr), radius: rr),
          -pi / 2, pi / 2, false);
    }
    p.lineTo(w, h - _sendRadius);
    p.arcTo(
        Rect.fromCircle(
            center: Offset(w - _sendRadius, h - _sendRadius),
            radius: _sendRadius),
        0,
        pi / 2,
        false);
    p.lineTo(_sendRadius, h);
    p.arcTo(
        Rect.fromCircle(
            center: Offset(_sendRadius, h - _sendRadius), radius: _sendRadius),
        pi / 2,
        pi / 2,
        false);
    p.lineTo(0, by + rl);
    if (rl > 0.01) {
      p.arcTo(Rect.fromCircle(center: Offset(rl, by + rl), radius: rl), pi,
          pi / 2, false);
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      buildPath(size, position, count),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_FusedShapePainter old) =>
      old.position != position || old.count != count || old.color != color;
}

class _StepSegment extends StatelessWidget {
  const _StepSegment({
    required this.step,
    required this.weight,
    required this.dimmed,
    required this.onTap,
  });

  final int step;

  /// 0 = сонгогдоогүй (accent), 1 = tab-ийн яг дээр (ctaInk).
  final double weight;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(AppColors.accent, AppColors.ctaInk, weight)!;
    return Semantics(
      button: true,
      selected: weight > 0.5,
      label: '+$step₮',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: dimmed ? 0.5 : 1,
              child: Text(
                '+$step',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: weight > 0.5 ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Саналын түүх — тогтмол дээд өндөртэй grouped карт, дотроо гүйлгэгдэнэ.
/// Жагсаалт богино бол хайрцаг агуулгаараа багтана.
@visibleForTesting
class BidHistory extends StatefulWidget {
  const BidHistory({super.key, required this.bids, this.meId});

  static const rowHeight = 52.0;
  // ~10.5 мөр — сүүлийн мөр хагас харагдаж гүйлгэх боломжийг сануулна
  static const maxHeight = rowHeight * 10.5;

  final List<BidItem> bids;

  /// Нэвтэрсэн хэрэглэгчийн id — өөрийн санал "Та" гэж тодрно.
  final String? meId;

  @override
  State<BidHistory> createState() => _BidHistoryState();
}

class _BidHistoryState extends State<BidHistory> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bids = widget.bids;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: ColoredBox(
        color: AppColors.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: BidHistory.maxHeight),
          child: Scrollbar(
            controller: _scroll,
            child: ListView.builder(
              controller: _scroll,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              itemCount: bids.length,
              itemBuilder: (_, i) => _BidRow(
                key: ValueKey(bids[i].id),
                bid: bids[i],
                isTop: i == 0,
                mine: widget.meId != null && bids[i].user.id == widget.meId,
                last: i == bids.length - 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BidRow extends StatelessWidget {
  const _BidRow({
    super.key,
    required this.bid,
    required this.isTop,
    required this.mine,
    required this.last,
  });

  final BidItem bid;
  final bool isTop;
  final bool mine;
  final bool last;

  @override
  Widget build(BuildContext context) {
    // Эрэмбэ: тэргүүлэгч (хамгийн тод) > миний санал (бага зэрэг) > бусад.
    final Color? tint = isTop
        ? AppColors.accent.withValues(alpha: 0.14)
        : mine
            ? AppColors.accent.withValues(alpha: 0.07)
            : null;
    final row = Container(
      color: tint,
      constraints: const BoxConstraints(minHeight: BidHistory.rowHeight),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(children: [
        AppAvatar(name: bid.user.name, avatarUrl: bid.user.avatarUrl, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mine ? 'Та' : bid.user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: isTop
                        ? FontWeight.w700
                        : mine
                            ? FontWeight.w600
                            : FontWeight.w400,
                    color: (isTop || mine) ? AppColors.ink : AppColors.inkSoft),
              ),
              Text(
                formatBidTime(bid.createdAt, DateTime.now()),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
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
              children: [
                art,
                const SizedBox(width: 48),
                Expanded(child: lines)
              ],
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
