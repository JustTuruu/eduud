import 'dart:async';
import 'dart:ui' show ImageFilter, FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/api/api_client.dart';
import '../../core/api/socket_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/app_nav_bar.dart';
import '../../shared/responsive.dart';
import '../../shared/live_countdown_text.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../auction/consent_sheet.dart';
import 'auction_tiles.dart';
import 'auction_timing.dart';

final auctionListProvider =
    FutureProvider.family<List<AuctionSummary>, String>((ref, status) async {
  final res = await ref
      .watch(dioProvider)
      .get('/auctions', queryParameters: {'status': status});
  return (res.data as List)
      .map((e) => AuctionSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Live auction-уудын локал төлөв: REST-ээр ирсэн жагсаалтыг socket
/// event-ээр шинэчилнэ. Зөвхөн hero хэсэг үүнийг сонсоно.
class _LiveStore extends ChangeNotifier {
  List<AuctionSummary> items = const [];
  List<AuctionSummary>? _source;
  int serverOffsetMs = 0;

  /// build() дотроос дуудагдана — мэдэгдэл (notify) илгээхгүй.
  void sync(List<AuctionSummary> source) {
    if (identical(_source, source)) return;
    _source = source;
    items = [...source]..sort((a, b) => a.endsAt.compareTo(b.endsAt));
  }

  void patch(String id, AuctionSummary Function(AuctionSummary) f) {
    final i = items.indexWhere((a) => a.id == id);
    if (i < 0) return;
    items = [...items]..[i] = f(items[i]);
    notifyListeners();
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _store = _LiveStore();
  late final io.Socket _socket;
  final Set<String> _joined = {};

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketProvider);
    _socket
      ..on('bid_placed', _onBid)
      ..on('auction_extended', _onExtended)
      ..on('auction_ended', _onEnded)
      ..on('connect', _onConnect);
    if (!_socket.connected) _socket.connect();

    ref.listenManual(auctionListProvider('live'), (_, next) {
      final list = next.valueOrNull;
      if (list != null) _syncRooms(list);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _socket
      ..off('bid_placed', _onBid)
      ..off('auction_extended', _onExtended)
      ..off('auction_ended', _onEnded)
      ..off('connect', _onConnect);
    for (final id in _joined) {
      _socket.emit('leave_auction', {'auctionId': id});
    }
    _store.dispose();
    super.dispose();
  }

  // --- Realtime -------------------------------------------------------

  /// Жагсаалт өөрчлөгдөхөд шинэ өрөөнд нэгдэж, хасагдсанаас гарна.
  void _syncRooms(List<AuctionSummary> list) {
    final ids = list.map((a) => a.id).toSet();
    for (final id in _joined.difference(ids)) {
      _socket.emit('leave_auction', {'auctionId': id});
    }
    _joined
      ..removeWhere((id) => !ids.contains(id))
      ..addAll(ids);
    if (_socket.connected) _joinAll();
  }

  void _joinAll() {
    for (final id in _joined) {
      _socket.emit('join_auction', {'auctionId': id});
    }
  }

  // Холбогдсоны дараа л join илгээнэ — өмнө нь emit хийвэл алдагдана.
  void _onConnect(dynamic _) => _joinAll();

  void _syncOffset(Map<String, dynamic> d) {
    final st = d['serverTime'];
    if (st is int) {
      _store.serverOffsetMs = st - DateTime.now().millisecondsSinceEpoch;
    }
  }

  void _onBid(dynamic data) {
    if (!mounted || data is! Map) return;
    final d = Map<String, dynamic>.from(data);
    final id = d['auctionId'];
    if (id is! String) return;
    _syncOffset(d);
    Bidder? bidder;
    try {
      bidder = Bidder.fromJson(Map<String, dynamic>.from(d['bidder'] as Map));
    } catch (_) {}
    _store.patch(
      id,
      (a) => a.copyWith(
        currentPrice: d['price'] as int?,
        bidCount: (d['bidCount'] as int?) ?? a.bidCount + 1,
        endsAt: d['endsAt'] is String
            ? DateTime.parse(d['endsAt'] as String)
            : null,
        lastBidder: bidder,
      ),
    );
  }

  void _onExtended(dynamic data) {
    if (!mounted || data is! Map) return;
    final d = Map<String, dynamic>.from(data);
    final id = d['auctionId'];
    if (id is! String || d['endsAt'] is! String) return;
    _store.patch(
        id, (a) => a.copyWith(endsAt: DateTime.parse(d['endsAt'] as String)));
  }

  void _onEnded(dynamic _) {
    if (!mounted) return;
    ref
      ..invalidate(auctionListProvider('live'))
      ..invalidate(auctionListProvider('ended'));
  }

  // --- Үйлдэл -----------------------------------------------------------

  /// Дэлгэрэнгүй дэлгэц хаагдахдаа өрөөнөөс гарах тул буцаж ирэхэд дахин нэгдэнэ.
  Future<void> _open(String id) async {
    await context.push('/auctions/$id');
    if (mounted && _socket.connected) _joinAll();
  }

  /// Явагдаж буй hero-ийн "Оролцох" товч: дүрмийн зөвшөөрлийг түрүүлж авч,
  /// зөвшөөрсөн тохиолдолд л дэлгэрэнгүй рүү орно. Болих/хаавал нүүрэнд үлдэнэ.
  Future<void> _enter(String id) async {
    final ok = await ensureAuctionConsent(context, ref, auctionId: id);
    if (!ok || !mounted) return;
    await _open(id);
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(auctionListProvider('live'))
      ..invalidate(auctionListProvider('scheduled'))
      ..invalidate(auctionListProvider('ended'));
    await ref.read(auctionListProvider('live').future);
  }

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final user = ref.watch(authProvider).valueOrNull;
    final liveAsync = ref.watch(auctionListProvider('live'));
    liveAsync.whenData(_store.sync);
    final bottom = wide ? 40.0 : NavMetrics.bottomInset(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: PageFrame(
          maxWidth: 1100,
          child: RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // iOS large title + эрхийн үлдэгдэл
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text('Нүүр', style: text.headlineMedium)),
                        // Өргөн дэлгэц дээр chip дээд навигацид байдаг.
                        if (!wide && user != null)
                          TokenBalanceChip(
                            balance: user.balance,
                            onTap: () => context.push('/wallet'),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: liveAsync.when(
                    loading: () => const _HeroSkeleton(),
                    error: (e, _) => _ErrorPanel(
                      message: apiErrorMessage(e),
                      onRetry: () =>
                          ref.invalidate(auctionListProvider('live')),
                    ),
                    data: (_) => _store.items.isEmpty
                        ? _FallbackHero(
                            offsetMs: _store.serverOffsetMs,
                            onOpen: _open,
                          )
                        : _Hero(
                            store: _store,
                            onOpen: _open,
                            onEnter: _enter,
                          ),
                  ),
                ),
                // Бусад явагдаж буй — 2 баганатай (өргөн дэлгэц дээр 3–4) тор.
                if (liveAsync.hasValue)
                  SliverListenable(
                    listenable: _store,
                    builder: (context) => _OtherLive(
                      store: _store,
                      onOpen: _open,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _AuctionRow(
                    title: 'Удахгүй эхлэх',
                    status: 'scheduled',
                    onOpen: _open,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _AuctionRow(
                    title: 'Дууссан',
                    status: 'ended',
                    onOpen: _open,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: bottom)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Явагдаж буй дуудлагын карт
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero(
      {required this.store, required this.onOpen, required this.onEnter});

  final _LiveStore store;
  final Future<void> Function(String id) onOpen;
  final Future<void> Function(String id) onEnter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // Хамгийн түрүүнд дуусах нь онцлогдоно (store эрэмбэлсэн).
        final items = store.items;
        if (items.isEmpty) return const SizedBox.shrink();
        final a = items.first;
        final offsetMs = store.serverOffsetMs;
        final wide = Breakpoints.isWide(context);

        return LayoutBuilder(builder: (context, box) {
          final twoCol = wide && box.maxWidth >= 760;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _LiveCard(
              key: ValueKey(a.id),
              auction: a,
              offsetMs: offsetMs,
              wide: twoCol,
              onOpen: () => onOpen(a.id),
              onEnter: () => onEnter(a.id),
            ),
          );
        });
      },
    );
  }
}

/// Нэг явагдаж буй дуудлагын цэвэр карт: хүрээгүй, зураг нь бүтэн өргөнтэй,
/// мэдээлэл нь шууд хуудасны дэвсгэр дээр. Шинэ санал орохад бага зэрэг (1.02)
/// томорч буцна. Карт бүхлээрээ дарагдана.
class _LiveCard extends StatefulWidget {
  const _LiveCard({
    super.key,
    required this.auction,
    required this.offsetMs,
    required this.wide,
    required this.onOpen,
    this.onEnter,
    this.kind = _HeroKind.live,
    this.onStarted,
  });

  final AuctionSummary auction;
  final int offsetMs;
  final bool wide;
  final VoidCallback onOpen;

  /// Live hero-ийн "Оролцох" товч (зөвшөөрөл авсны дараа нээх). Өгөөгүй бол onOpen.
  final VoidCallback? onEnter;

  /// Hero-ийн төрөл: явагдаж буй / удахгүй эхлэх / дууссан.
  final _HeroKind kind;

  /// Эхлэх тоолуур 0 болоход дуудагдана (scheduled үед).
  final VoidCallback? onStarted;

  @override
  State<_LiveCard> createState() => _LiveCardState();
}

class _LiveCardState extends State<_LiveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));

  static final _curve = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.02)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40),
    TweenSequenceItem(
        tween: Tween(begin: 1.02, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60),
  ]);

  @override
  void didUpdateWidget(covariant _LiveCard old) {
    super.didUpdateWidget(old);
    if (old.auction.bidCount != widget.auction.bidCount &&
        !reducedMotion(context)) {
      unawaited(_beat.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.auction;
    final art = Stack(
      children: [
        AuctionArt(
          auctionId: a.id,
          url: a.images.isEmpty ? null : a.images.first,
          radius: 22,
          aspect: widget.wide ? 1 : 1.2,
        ),
        Positioned(top: 12, left: 12, child: _HeroBadge(kind: widget.kind)),
      ],
    );
    final info = _LiveInfo(
      auction: a,
      offsetMs: widget.offsetMs,
      onOpen: widget.onOpen,
      onEnter: widget.onEnter,
      big: widget.wide,
      kind: widget.kind,
      onStarted: widget.onStarted,
    );

    return ScaleTransition(
      scale: _beat.drive(_curve),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: widget.wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 380, child: art),
                  const SizedBox(width: 32),
                  Expanded(child: info),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [art, const SizedBox(height: 16), info],
              ),
      ),
    );
  }
}

/// Hero-ийн төрөл.
enum _HeroKind { live, scheduled, ended }

/// Зураг дээрх шилэн (glass) шошго: явагдаж буй бол лугшдаг цэгтэй,
/// удахгүй эхлэх бол календарийн дүрстэй, дууссан бол бүдэг.
class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.kind});

  final _HeroKind kind;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
          color: Colors.black.withValues(alpha: 0.42),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              switch (kind) {
                _HeroKind.live => const _PulseDot(),
                _HeroKind.scheduled => const Icon(LucideIcons.calendarClock,
                    size: 14, color: Colors.white),
                _HeroKind.ended => Icon(LucideIcons.flag,
                    size: 14, color: Colors.white.withValues(alpha: 0.7)),
              },
              const SizedBox(width: 7),
              Text(
                switch (kind) {
                  _HeroKind.live => 'Явагдаж буй',
                  _HeroKind.scheduled => 'Удахгүй эхэлнэ',
                  _HeroKind.ended => 'Дууссан',
                },
                style: TextStyle(
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: kind == _HeroKind.ended
                      ? Colors.white.withValues(alpha: 0.75)
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Лугших ногоон цэг (reducedMotion үед хөдөлгөөнгүй).
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t) * 0.55,
                child: Container(
                  width: 8 + 6 * t,
                  height: 8 + 6 * t,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.accent),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.accent),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Нэр, тэргүүлэгч, үнэ + хугацаа, "Дуудлага худалдаанд оролцох" товч
/// (товч нь үнэ илгээхгүй — дэлгэрэнгүй дэлгэц рүү нээнэ).
class _LiveInfo extends StatelessWidget {
  const _LiveInfo({
    required this.auction,
    required this.offsetMs,
    required this.onOpen,
    this.onEnter,
    required this.big,
    this.kind = _HeroKind.live,
    this.onStarted,
  });

  final AuctionSummary auction;
  final int offsetMs;
  final VoidCallback onOpen;
  final VoidCallback? onEnter;
  final bool big;
  final _HeroKind kind;
  final VoidCallback? onStarted;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    final now = DateTime.now().add(Duration(milliseconds: offsetMs));
    final subtitle = switch (kind) {
      _HeroKind.live => a.lastBidder == null
          ? 'Анхны оролцогч болоорой'
          : 'Тэргүүлж байна: ${a.lastBidder!.name}',
      _HeroKind.scheduled => 'Эхлэх: ${formatStartLabel(a.startsAt, now)}',
      _HeroKind.ended =>
        a.lastBidder == null ? 'Санал ирээгүй' : 'Ялагч: ${a.lastBidder!.name}',
    };
    final priceLabel = switch (kind) {
      _HeroKind.live => null,
      _HeroKind.scheduled => 'Эхлэх үнэ',
      _HeroKind.ended => 'Эцсийн үнэ',
    };
    final price = _RollingPrice(amount: a.currentPrice, size: big ? 40 : 32);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: big ? 26 : 20,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, height: 1.3, color: AppColors.muted),
        ),
        SizedBox(height: big ? 24 : 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: priceLabel == null
                  ? price
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          priceLabel,
                          maxLines: 1,
                          style:
                              TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                        const SizedBox(height: 4),
                        price,
                      ],
                    ),
            ),
            const SizedBox(width: 12),
            switch (kind) {
              _HeroKind.live => _TimerRow(auction: a, offsetMs: offsetMs),
              _HeroKind.scheduled => _StartCountdown(
                  auction: a, offsetMs: offsetMs, onStarted: onStarted),
              _HeroKind.ended => _EndedAt(endsAt: a.endsAt, now: now),
            },
          ],
        ),
        SizedBox(height: big ? 28 : 18),
        _EnterButton(
          onPressed: kind == _HeroKind.live ? (onEnter ?? onOpen) : onOpen,
          label: kind == _HeroKind.live
              ? 'Дуудлага худалдаанд оролцох'
              : 'Дэлгэрэнгүй үзэх',
        ),
      ],
    );
  }
}

/// Хөнгөн (tinted) capsule товч — дэлгэрэнгүй рүү нээнэ.
class _EnterButton extends StatelessWidget {
  const _EnterButton({
    required this.onPressed,
    this.label = 'Дуудлага худалдаанд оролцох',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Light горимд ногоон текст бүдэг тул бага зэрэг бараанаар авна.
    final fg = AppColors.isDark
        ? AppColors.accent
        : Color.lerp(AppColors.accent, Colors.black, 0.32)!;
    return AnimatedPressable(
      onPressed: onPressed,
      scale: 0.98,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent
              .withValues(alpha: AppColors.isDark ? 0.18 : 0.16),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: fg),
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}

/// Үнэ шинэчлэгдэхэд хуучин нь дээш гарч, шинэ нь доороос орж ирнэ.
class _RollingPrice extends StatelessWidget {
  const _RollingPrice({required this.amount, required this.size});

  final int amount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final calm = reducedMotion(context);
    return AnimatedSwitcher(
      duration: calm ? Duration.zero : const Duration(milliseconds: 300),
      switchInCurve: AppMotion.fluid,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, anim) {
        final incoming = child.key == ValueKey(amount);
        final slide = Tween<Offset>(
          begin: Offset(0, incoming ? 0.5 : -0.5),
          end: Offset.zero,
        );
        return ClipRect(
          child: SlideTransition(
            position: anim.drive(slide),
            child: FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      child: Align(
        key: ValueKey(amount),
        alignment: Alignment.centerLeft,
        child: Text(formatMnt(amount), style: AppTheme.price(size: size)),
      ),
    );
  }
}

/// Үлдсэн хугацааны хураангуй pill + дээр нь "Round N" / "Дуусах HH:mm".
/// Секунд тутам л шинэчлэгддэг тул зөвхөн энэ жижиг widget дахин бүтнэ.
/// Сүүлийн 10с улаан.
class _TimerRow extends StatefulWidget {
  const _TimerRow({required this.auction, required this.offsetMs});

  final AuctionSummary auction;
  final int offsetMs;

  @override
  State<_TimerRow> createState() => _TimerRowState();
}

class _TimerRowState extends State<_TimerRow> {
  Timer? _ticker;
  late DateTime _now = _clock();

  DateTime _clock() =>
      DateTime.now().add(Duration(milliseconds: widget.offsetMs));

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = _clock());
    });
  }

  @override
  void didUpdateWidget(covariant _TimerRow old) {
    super.didUpdateWidget(old);
    _now = _clock();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.auction;
    final remaining = a.endsAt.difference(_now);
    final urgent = remaining.inMilliseconds > 0 && remaining.inSeconds < 10;
    const tab = [FontFeature.tabularFigures()];
    final rounds = a.rounds;
    final hasRounds = rounds != null && rounds.isNotEmpty;
    final waiting = hasRounds && a.bidCount == 0;
    final roundLabel = hasRounds
        ? 'Round ${(roundIndexAt(rounds, _now) ?? 0) + 1}'
        : 'Дуусах ${DateFormat('HH:mm').format(a.endsAt.toLocal())}';
    final hot = urgent && !waiting;
    final fg = hot ? AppColors.danger : AppColors.ink;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          roundLabel,
          maxLines: 1,
          style: TextStyle(
              fontSize: 13, fontFeatures: tab, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: hot ? AppColors.dangerBg : AppColors.fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!waiting) ...[
                Icon(LucideIcons.clock, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              if (waiting)
                Text(
                  'Хүлээж байна',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tab,
                    color: AppColors.muted,
                  ),
                )
              else
                LiveCountdownText(
                  endsAt: a.endsAt,
                  serverOffsetMs: widget.offsetMs,
                  urgentColor: AppColors.danger,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Эхлэх хүртэлх тоолуур (scheduled hero). 0 болмогц `onStarted` дуудна.
class _StartCountdown extends StatelessWidget {
  const _StartCountdown({
    required this.auction,
    required this.offsetMs,
    this.onStarted,
  });

  final AuctionSummary auction;
  final int offsetMs;
  final VoidCallback? onStarted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Эхлэхэд',
          maxLines: 1,
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.clock, size: 15, color: AppColors.ink),
              const SizedBox(width: 6),
              LiveCountdownText(
                endsAt: auction.startsAt,
                serverOffsetMs: offsetMs,
                onFinished: onStarted,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Дууссан hero-ийн дуусгавар болсон цаг.
class _EndedAt extends StatelessWidget {
  const _EndedAt({required this.endsAt, required this.now});

  final DateTime endsAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Дууссан',
          maxLines: 1,
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            formatDateTimeLabel(endsAt, now),
            maxLines: 1,
            style: TextStyle(
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Явагдаж буй дуудлага байхгүй үед: хамгийн ойрхон эхлэх, байхгүй бол
/// хамгийн сүүлд дууссан дуудлагыг hero хэлбэрээр харуулна.
class _FallbackHero extends ConsumerWidget {
  const _FallbackHero({required this.offsetMs, required this.onOpen});

  final int offsetMs;
  final Future<void> Function(String id) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sched = ref.watch(auctionListProvider('scheduled'));
    final ended = ref.watch(auctionListProvider('ended'));
    final scheduledList = sched.valueOrNull ?? const <AuctionSummary>[];
    final endedList = ended.valueOrNull ?? const <AuctionSummary>[];
    final picked = pickFallbackHero(scheduledList, endedList);

    // Ачаалж дуусаагүй байхад хоосон төлөв анивчихаас сэргийлнэ.
    final scheduledPending = sched.isLoading && !sched.hasValue;
    final endedPending = ended.isLoading && !ended.hasValue;
    if (picked == null && (scheduledPending || endedPending)) {
      return const _HeroSkeleton();
    }
    if (picked == null) return const _EmptyHero();
    // Эхлэх жагсаалт ачаалагдаагүй байхад дууссан нь түр гарахаас сэргийлнэ.
    if (scheduledPending) return const _HeroSkeleton();

    final isScheduled = scheduledList.any((a) => a.id == picked.id);
    final kind = isScheduled ? _HeroKind.scheduled : _HeroKind.ended;

    return LayoutBuilder(builder: (context, box) {
      final twoCol = Breakpoints.isWide(context) && box.maxWidth >= 760;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _LiveCard(
          key: ValueKey('${kind.name}:${picked.id}'),
          auction: picked,
          offsetMs: offsetMs,
          wide: twoCol,
          kind: kind,
          onOpen: () => onOpen(picked.id),
          onStarted: () {
            ref.invalidate(auctionListProvider('live'));
            ref.invalidate(auctionListProvider('scheduled'));
          },
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Бусад явагдаж буй дуудлага (тор)
// ---------------------------------------------------------------------------

/// Store өөрчлөгдөх бүрт sliver-ээ дахин бүтээнэ.
class SliverListenable extends StatelessWidget {
  const SliverListenable(
      {super.key, required this.listenable, required this.builder});

  final Listenable listenable;
  final Widget Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: listenable, builder: (c, _) => builder(c));
}

/// "Бусад явагдаж буй" хэсэгт харуулах дээд хэмжээ (бүтэн мөрөөр тасална).
const _maxShown = 6;

/// Хавтангийн зургийн доорх текстийн өндөр (гарчиг 2 мөр + үнэ + хугацаа).
const _tileTextH = 86.0;

/// Бүх хэсгийн нэг ижил гарчиг: 22/700 + баруун талд "Бүгд ›".
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onAll});

  final String title;
  final VoidCallback? onAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 12, 12),
      child: Row(
        children: [
          Expanded(
            child:
                Text(title, style: Theme.of(context).textTheme.displayMedium),
          ),
          if (onAll != null)
            AnimatedPressable(
              onPressed: onAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Бүгд',
                      style: TextStyle(fontSize: 17, color: AppColors.accent)),
                  const SizedBox(width: 2),
                  Icon(LucideIcons.chevronRight,
                      size: 18, color: AppColors.accent),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _OtherLive extends StatelessWidget {
  const _OtherLive({required this.store, required this.onOpen});

  final _LiveStore store;
  final Future<void> Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final all = store.items.skip(1).toList();
    if (all.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    const gapX = 16.0;
    const gapY = 24.0;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Бусад явагдаж буй',
            onAll: all.length > 2 ? () => context.push('/lists/live') : null,
          ),
        ),
        SliverLayoutBuilder(builder: (context, constraints) {
          final inner = constraints.crossAxisExtent - 40;
          final cols = !Breakpoints.isWide(context)
              ? 2
              : (constraints.crossAxisExtent >= 1000 ? 4 : 3);
          final tileW = (inner - gapX * (cols - 1)) / cols;
          // Сүүлийн мөрөнд ганц хавтан үлдэхгүйн тулд бүтэн мөрөөр хязгаарлана.
          final limit = cols * (_maxShown ~/ cols);
          var n = all.length > limit ? limit : all.length;
          if (n > cols) n -= n % cols;
          final rest = all.take(n).toList();
          // Зураг + гарчиг (2 мөр) + үнэ + хугацаа
          final tileH = tileW + 8 + _tileTextH * scale;
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: gapX,
                mainAxisSpacing: gapY,
                mainAxisExtent: tileH,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _LiveGridTile(
                  key: ValueKey(rest[i].id),
                  auction: rest[i],
                  offsetMs: store.serverOffsetMs,
                  onTap: () => onOpen(rest[i].id),
                ),
                childCount: rest.length,
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Тор дахь жижиг хавтан: зураг, нэр, үнэ, үлдсэн хугацаа.
class _LiveGridTile extends StatefulWidget {
  const _LiveGridTile(
      {super.key,
      required this.auction,
      required this.offsetMs,
      required this.onTap});

  final AuctionSummary auction;
  final int offsetMs;
  final VoidCallback onTap;

  @override
  State<_LiveGridTile> createState() => _LiveGridTileState();
}

class _LiveGridTileState extends State<_LiveGridTile> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.auction;
    final now = DateTime.now().add(Duration(milliseconds: widget.offsetMs));
    final remaining = a.endsAt.difference(now);
    final urgent = remaining.inMilliseconds > 0 && remaining.inSeconds < 60;
    const tab = [FontFeature.tabularFigures()];
    final timeColor = urgent ? AppColors.danger : AppColors.muted;
    return AnimatedPressable(
      onPressed: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuctionArt(
            auctionId: a.id,
            url: a.images.isEmpty ? null : a.images.first,
            radius: 16,
          ),
          const SizedBox(height: 8),
          Text(
            a.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 15,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            formatMnt(a.currentPrice),
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFeatures: tab,
                color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(LucideIcons.clock, size: 13, color: timeColor),
              const SizedBox(width: 4),
              LiveCountdownText(
                endsAt: a.endsAt,
                serverOffsetMs: widget.offsetMs,
                urgentColor: AppColors.danger,
                urgentBelow: const Duration(seconds: 60),
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cardW = (box.maxWidth - 40).clamp(0.0, 420.0);
      return Center(
        child: SizedBox(
          width: cardW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: cardW / 1.2, radius: 22),
              const SizedBox(height: 16),
              const Skeleton(height: 22, width: 200),
              const SizedBox(height: 10),
              const Skeleton(height: 32, width: 140),
              const SizedBox(height: 18),
              const Skeleton(height: 48, radius: 24),
            ],
          ),
        ),
      );
    });
  }
}

/// Явагдаж буй, удахгүй эхлэх, дууссан дуудлага огт байхгүй үед.
class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.gavel, size: 32, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              'Одоо явагдаж буй дуудлага алга',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        children: [
          Icon(LucideIcons.triangleAlert, size: 28, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.muted)),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            child: SecondaryButton(label: 'Дахин оролдох', onPressed: onRetry),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Хэвтээ мөрүүд (App Store маягийн)
// ---------------------------------------------------------------------------

/// Картаар snap хийдэг хэвтээ scroll — зогсохдоо дөт картын зах руу тогтоно.
class _CardSnapPhysics extends ScrollPhysics {
  const _CardSnapPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  _CardSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _CardSnapPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  double _target(ScrollMetrics m, double velocity) {
    final tol = toleranceFor(m);
    var page = m.pixels / itemExtent;
    if (velocity < -tol.velocity) {
      page -= 0.5;
    } else if (velocity > tol.velocity) {
      page += 0.5;
    }
    return (page.roundToDouble() * itemExtent)
        .clamp(m.minScrollExtent, m.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _target(position, velocity);
    if ((target - position.pixels).abs() < 0.5) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

class _AuctionRow extends ConsumerWidget {
  const _AuctionRow(
      {required this.title, required this.status, required this.onOpen});

  final String title;
  final String status;
  final Future<void> Function(String id) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auctionListProvider(status));
    const cardW = 156.0;
    const gap = 16.0;
    // Картын өндөр = зураг + 2 мөр нэр + дэд мэдээлэл (текстийн томруулалттай).
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    final cardH = cardW + 8 + _tileTextH * scale;

    final Widget body = async.when(
      loading: () => SizedBox(
        height: cardH,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: gap),
          itemBuilder: (_, __) => SizedBox(
            width: cardW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(height: cardW, width: cardW, radius: 16),
                SizedBox(height: 10),
                Skeleton(height: 14, width: 100),
                SizedBox(height: 8),
                Skeleton(height: 12, width: 70),
              ],
            ),
          ),
        ),
      ),
      error: (e, _) => _ErrorPanel(
        message: apiErrorMessage(e),
        onRetry: () => ref.invalidate(auctionListProvider(status)),
      ),
      data: (list) {
        final items = [...list]..sort((a, b) => status == 'scheduled'
            ? a.startsAt.compareTo(b.startsAt)
            : b.endsAt.compareTo(a.endsAt));
        final shown = items.take(12).toList();
        if (shown.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              status == 'scheduled'
                  ? 'Удахгүй эхлэх дуудлага алга'
                  : 'Дууссан дуудлага алга',
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
          );
        }
        return SizedBox(
          height: cardH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const _CardSnapPhysics(itemExtent: cardW + gap),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemExtent: cardW + gap,
            itemCount: shown.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: gap),
              child: AuctionTile(
                auction: shown[i],
                onTap: () => onOpen(shown[i].id),
              ),
            ),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          onAll: () => context.push('/lists/$status'),
        ),
        body,
      ],
    );
  }
}
