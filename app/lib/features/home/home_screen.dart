import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/api/api_client.dart';
import '../../core/api/socket_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/ambient_backdrop.dart';
import '../../shared/app_nav_bar.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Нэг удаагийн зохион байгуулалттай орж ирэлт: hero → мөр 1 → мөр 2.
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
  late final Animation<double> _heroIn = CurvedAnimation(
      parent: _enter, curve: const Interval(0, 0.5, curve: AppMotion.fluid));
  late final Animation<double> _row1In = CurvedAnimation(
      parent: _enter, curve: const Interval(0.3, 0.75, curve: AppMotion.fluid));
  late final Animation<double> _row2In = CurvedAnimation(
      parent: _enter, curve: const Interval(0.5, 1, curve: AppMotion.fluid));

  final _store = _LiveStore();
  final _page = ValueNotifier<int>(0);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (reducedMotion(context)) {
        _enter.value = 1;
      } else {
        unawaited(_enter.forward());
      }
    });
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
    _enter.dispose();
    _store.dispose();
    _page.dispose();
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

  Future<void> _bid(String id) async {
    try {
      await ref.read(dioProvider).post('/auctions/$id/bid');
      unawaited(ref.read(authProvider.notifier).refreshProfile());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Ambient: идэвхтэй барааны зургаас өнгө — зөвхөн энэ хэсэг
          // page/store өөрчлөгдөхөд дахин бүтнэ.
          Positioned.fill(
            child: ListenableBuilder(
              listenable: Listenable.merge([_page, _store]),
              builder: (context, _) {
                final items = _store.items;
                if (items.isEmpty) {
                  return const AmbientBackdrop(seed: 'e-duud-idle');
                }
                final a = items[_page.value.clamp(0, items.length - 1)];
                final url = a.images.isEmpty ? null : a.images.first;
                return AmbientBackdrop(
                  image: url == null ? null : NetworkImage(url),
                  imageKey: url,
                  seed: a.id,
                );
              },
            ),
          ),
          SafeArea(
            bottom: false,
            child: PageFrame(
              maxWidth: 1120,
              child: RefreshIndicator(
                color: AppColors.coral,
                backgroundColor: AppColors.surfaceHi,
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Одоо явагдаж буй',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    Theme.of(context).textTheme.displayMedium,
                              ),
                            ),
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
                      child: _Reveal(
                        animation: _heroIn,
                        dy: 24,
                        scaleFrom: 0.94,
                        child: liveAsync.when(
                          loading: () => const _HeroSkeleton(),
                          error: (e, _) => _ErrorPanel(
                            message: apiErrorMessage(e),
                            onRetry: () =>
                                ref.invalidate(auctionListProvider('live')),
                          ),
                          data: (_) => _store.items.isEmpty
                              ? const _EmptyHero()
                              : _Hero(
                                  store: _store,
                                  onPage: (i) => _page.value = i,
                                  onOpen: _open,
                                  onBid: _bid,
                                ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    SliverToBoxAdapter(
                      child: _Reveal(
                        animation: _row1In,
                        dy: 20,
                        child: _AuctionRow(
                          title: 'Удахгүй эхлэх',
                          status: 'scheduled',
                          onOpen: _open,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    SliverToBoxAdapter(
                      child: _Reveal(
                        animation: _row2In,
                        dy: 20,
                        child: _AuctionRow(
                          title: 'Дууссан',
                          status: 'ended',
                          onOpen: _open,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: bottom)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Нэг удаагийн орж ирэлт: бүдэг → тод, доороос дээш, (сонголтоор) томрох.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.child,
    this.dy = 16,
    this.scaleFrom = 1,
  });

  final Animation<double> animation;
  final Widget child;
  final double dy;
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        if (t >= 1) return child!;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy * (1 - t)),
            child: Transform.scale(
                scale: scaleFrom + (1 - scaleFrom) * t, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Hero — Now Playing
// ---------------------------------------------------------------------------

class _Hero extends StatefulWidget {
  const _Hero({
    required this.store,
    required this.onPage,
    required this.onOpen,
    required this.onBid,
  });

  final _LiveStore store;
  final ValueChanged<int> onPage;
  final Future<void> Function(String id) onOpen;
  final Future<void> Function(String id) onBid;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  PageController? _pc;
  int _index = 0;
  final Set<String> _busy = {};

  @override
  void dispose() {
    _pc?.dispose();
    super.dispose();
  }

  PageController _controller(double fraction) {
    final current = _pc;
    if (current != null &&
        (current.viewportFraction - fraction).abs() < 0.001) {
      return current;
    }
    _pc = PageController(viewportFraction: fraction, initialPage: _index);
    if (current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    }
    return _pc!;
  }

  Future<void> _bid(String id) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await widget.onBid(id);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _go(PageController pc, int to, int count) {
    if (to < 0 || to >= count) return;
    HapticFeedback.selectionClick();
    unawaited(pc.animateToPage(to,
        duration: AppMotion.slow, curve: AppMotion.fluid));
  }

  /// Өргөн дэлгэц: зүүн талд дөрвөлжин зураг (+ сум, цэг), баруун талд
  /// мэдээлэл — босоогоор төвлөрсөн.
  Widget _wideLayout(
      BuildContext context, List<AuctionSummary> items, int index, double w) {
    final current = items[index];
    final calm = reducedMotion(context);
    final side = ((w - 48) * 0.44).clamp(280.0, 480.0);
    final pc = _controller(1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: side + 128,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: side + 128,
                  child: PageView.builder(
                    controller: pc,
                    itemCount: items.length,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = i);
                      widget.onPage(i);
                    },
                    // Сүүдэр хайрцагт хайчлагдахгүйн тулд хангалттай зайтай.
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.all(64),
                      child: GestureDetector(
                        onTap: () => widget.onOpen(items[i].id),
                        child: _NowArtwork(
                            key: ValueKey(items[i].id), auction: items[i]),
                      ),
                    ),
                  ),
                ),
                if (items.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ArrowButton(
                        icon: LucideIcons.chevronLeft,
                        label: 'Өмнөх',
                        onPressed: index > 0
                            ? () => _go(pc, index - 1, items.length)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      _Dots(count: items.length, index: index),
                      const SizedBox(width: 16),
                      _ArrowButton(
                        icon: LucideIcons.chevronRight,
                        label: 'Дараах',
                        onPressed: index < items.length - 1
                            ? () => _go(pc, index + 1, items.length)
                            : null,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 0),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedSwitcher(
                duration: calm ? Duration.zero : AppMotion.base,
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                child: KeyedSubtree(
                  key: ValueKey(current.id),
                  child: _NowInfo(
                    auction: current,
                    offsetMs: widget.store.serverOffsetMs,
                    busy: _busy.contains(current.id),
                    onBid: () => _bid(current.id),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final items = widget.store.items;
        if (items.isEmpty) return const SizedBox.shrink();
        final index = _index.clamp(0, items.length - 1);
        final current = items[index];

        return LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          // Өргөн дэлгэц: хоёр баганатай бүтэц (зүүн — зураг, баруун — мэдээлэл).
          if (Breakpoints.isWide(context) && w >= 760) {
            return _wideLayout(context, items, index, w);
          }
          final pageW = (w * 0.82).clamp(0.0, 400.0);
          final pc = _controller(pageW / w);
          final side = pageW - 24;
          final calm = reducedMotion(context);

          return Column(
            children: [
              SizedBox(
                height: side + 28,
                child: PageView.builder(
                  controller: pc,
                  clipBehavior: Clip.none,
                  itemCount: items.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _index = i);
                    widget.onPage(i);
                  },
                  itemBuilder: (context, i) {
                    final a = items[i];
                    return AnimatedBuilder(
                      animation: pc,
                      builder: (context, child) {
                        var delta = 0.0;
                        if (pc.hasClients && pc.position.haveDimensions) {
                          delta = ((pc.page ?? i.toDouble()) - i)
                              .abs()
                              .clamp(0.0, 1.0);
                        } else {
                          delta = (i - index).abs().clamp(0, 1).toDouble();
                        }
                        return Center(
                          child: Opacity(
                            opacity: calm ? 1 : 1 - 0.5 * delta,
                            child: Transform.scale(
                              scale: calm ? 1 : 1 - 0.1 * delta,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: GestureDetector(
                        onTap: () => widget.onOpen(a.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _NowArtwork(
                            key: ValueKey(a.id),
                            auction: a,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (items.length > 1) ...[
                const SizedBox(height: 4),
                _Dots(count: items.length, index: index),
              ],
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: calm ? Duration.zero : AppMotion.base,
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                child: Center(
                  key: ValueKey(current.id),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: side.clamp(280.0, 400.0)),
                    child: _NowInfo(
                      auction: current,
                      offsetMs: widget.store.serverOffsetMs,
                      busy: _busy.contains(current.id),
                      onBid: () => _bid(current.id),
                    ),
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}

/// Өргөн дэлгэцийн өмнөх/дараах сум — бага зэрэг тунгалаг дугуй товч.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton(
      {required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      child: AnimatedPressable(
        onPressed: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.ink.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.borderHi),
          ),
          child: Icon(icon,
              size: 20,
              color: onPressed == null ? AppColors.muted : AppColors.ink),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.fast,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? AppColors.coral : AppColors.borderHi,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Том дөрвөлжин "цомгийн хавтас". Шинэ санал орох агшинд "beat" хийнэ.
class _NowArtwork extends StatefulWidget {
  const _NowArtwork({super.key, required this.auction});

  final AuctionSummary auction;

  @override
  State<_NowArtwork> createState() => _NowArtworkState();
}

class _NowArtworkState extends State<_NowArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  static final _curve = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.03)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40),
    TweenSequenceItem(
        tween: Tween(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60),
  ]);

  @override
  void didUpdateWidget(covariant _NowArtwork old) {
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
    return ScaleTransition(
      scale: _beat.drive(_curve),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.art),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: AuctionArt(
          auctionId: a.id,
          url: a.images.isEmpty ? null : a.images.first,
          radius: AppRadius.art,
        ),
      ),
    );
  }
}

/// Нэр, тэргүүлэгч, үнэ, таймер, bid товч.
class _NowInfo extends StatelessWidget {
  const _NowInfo({
    required this.auction,
    required this.offsetMs,
    required this.busy,
    required this.onBid,
  });

  final AuctionSummary auction;
  final int offsetMs;
  final bool busy;
  final VoidCallback onBid;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        const SizedBox(height: 4),
        a.lastBidder == null
            ? const Text(
                'Анхны санал өгч эхлээрэй',
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
              )
            : Text.rich(
                TextSpan(children: [
                  const TextSpan(
                    text: 'Тэргүүлж байна: ',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                  TextSpan(
                    text: a.lastBidder!.name,
                    style: const TextStyle(
                        color: AppColors.ink, fontWeight: FontWeight.w700),
                  ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
        const SizedBox(height: 12),
        _RollingPrice(amount: a.currentPrice),
        const SizedBox(height: 16),
        _TimerBar(auction: a, offsetMs: offsetMs),
        const SizedBox(height: 24),
        _BidButton(busy: busy, onPressed: onBid),
      ],
    );
  }
}

/// Үнэ шинэчлэгдэхэд хуучин нь дээш гарч, шинэ нь доороос орж ирнэ.
class _RollingPrice extends StatelessWidget {
  const _RollingPrice({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final calm = reducedMotion(context);
    return AnimatedSwitcher(
      duration: calm ? Duration.zero : const Duration(milliseconds: 340),
      switchInCurve: AppMotion.fluid,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, anim) {
        final incoming = child.key == ValueKey(amount);
        final slide = Tween<Offset>(
          begin: Offset(0, incoming ? 0.6 : -0.6),
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
        child: Text(formatMnt(amount), style: AppTheme.price(size: 44)),
      ),
    );
  }
}

/// Таймер progress: урт = үлдсэн хугацаа / нийт хугацаа. Секунд тутам л
/// шинэчлэгддэг тул зөвхөн энэ жижиг widget дахин бүтнэ. Сүүлийн 10с шүрэн лугшино.
class _TimerBar extends StatefulWidget {
  const _TimerBar({required this.auction, required this.offsetMs});

  final AuctionSummary auction;
  final int offsetMs;

  @override
  State<_TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<_TimerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  Timer? _ticker;
  late DateTime _now = _clock();
  bool _urgent = false;

  DateTime _clock() =>
      DateTime.now().add(Duration(milliseconds: widget.offsetMs));

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _updateUrgent();
  }

  @override
  void didUpdateWidget(covariant _TimerBar old) {
    super.didUpdateWidget(old);
    _now = _clock();
    _updateUrgent();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = _clock());
    _updateUrgent();
  }

  void _updateUrgent() {
    final left = widget.auction.endsAt.difference(_now);
    final urgent = left.inMilliseconds > 0 && left.inSeconds < 10 ||
        (left.inMilliseconds > 0 && left.inMilliseconds <= 10000);
    if (urgent == _urgent) return;
    _urgent = urgent;
    // reducedMotion context-ээс хамаарна; initState дээр хүрэхгүй тул
    // өөрчлөлтийг дараагийн frame-д хийнэ.
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
    final a = widget.auction;
    final remaining = a.endsAt.difference(_now);
    final frac =
        remainingFraction(startsAt: a.startsAt, endsAt: a.endsAt, now: _now);
    const tab = [FontFeature.tabularFigures()];
    return Column(
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
                                    color: AppColors.coral
                                        .withValues(alpha: 0.25 + 0.45 * p),
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: tab,
                color: _urgent ? AppColors.coral : AppColors.inkSoft,
              ),
            ),
            Text(
              '${a.bidCount} санал',
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
    );
  }
}

/// Дэлгэц дээрх ганц, тусгаарлагдсан үндсэн үйлдэл.
class _BidButton extends StatelessWidget {
  const _BidButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !busy,
      label: 'Санал өгөх',
      child: AnimatedPressable(
        haptic: false,
        onPressed: busy
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onPressed();
              },
        scale: 0.96,
        child: Container(
          height: 56,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: busy ? null : AppColors.ctaGradient,
            color: busy ? AppColors.surfaceHi : null,
            borderRadius: BorderRadius.circular(28),
            boxShadow: busy
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
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.gavel, size: 20, color: AppColors.ctaInk),
                    SizedBox(width: 10),
                    Text(
                      'Санал өгөх',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ctaInk,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final side = ((box.maxWidth * 0.82).clamp(0.0, 400.0)) - 24;
      return Center(
        child: SizedBox(
          width: side,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: side, width: side, radius: AppRadius.art),
              const SizedBox(height: 20),
              const Skeleton(height: 22, width: 200),
              const SizedBox(height: 12),
              const Skeleton(height: 44, width: 160),
              const SizedBox(height: 18),
              const Skeleton(height: 6),
            ],
          ),
        ),
      );
    });
  }
}

/// Live дуудлага байхгүй үед: ертөнцөөсөө гарахгүй хоосон "хавтас".
class _EmptyHero extends ConsumerWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(auctionListProvider('scheduled')).valueOrNull;
    AuctionSummary? first;
    if (next != null && next.isNotEmpty) {
      first =
          ([...next]..sort((a, b) => a.startsAt.compareTo(b.startsAt))).first;
    }
    return LayoutBuilder(builder: (context, box) {
      final side = ((box.maxWidth * 0.78).clamp(0.0, 360.0));
      return Center(
        child: SizedBox(
          width: side,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.art),
                child: SizedBox(
                  width: side,
                  height: side,
                  child:
                      const ArtPlaceholder(seed: 'e-duud-idle', iconSize: 56),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Одоо явагдаж буй дуудлага алга',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              if (first != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Дараагийнх: ${first.title} · '
                  '${formatStartLabel(first.startsAt, DateTime.now())}',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.inkSoft),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          const Icon(LucideIcons.triangleAlert,
              size: 28, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          AnimatedPressable(
            onPressed: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderHi),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.refreshCw, size: 15, color: AppColors.ink),
                SizedBox(width: 8),
                Text('Дахин оролдох',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.ink)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Хэвтээ мөрүүд
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
    final wide = Breakpoints.isWide(context);
    final cardW = wide ? 184.0 : 148.0;
    const gap = 14.0;
    // Картын өндөр = зураг + нэр/дэд мэдээллийн мөрүүд (текстийн томруулалтыг
    // тооцсон) — илүү хоосон зай үлдээхгүй.
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    final cardH = cardW + 8 + 4 + (20 + 17 + 21) * scale;

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
              children: [
                Skeleton(height: cardW, width: cardW, radius: 20),
                const SizedBox(height: 10),
                const Skeleton(height: 14, width: 100),
                const SizedBox(height: 8),
                const Skeleton(height: 12, width: 70),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              status == 'scheduled'
                  ? 'Удахгүй эхлэх дуудлага алга'
                  : 'Дууссан дуудлага алга',
              style: const TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          );
        }
        return SizedBox(
          height: cardH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: _CardSnapPhysics(itemExtent: cardW + gap),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.displayMedium),
              ),
              AnimatedPressable(
                onPressed: () => context.push('/lists/$status'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Бүгд',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.coralLight)),
                    SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight,
                        size: 16, color: AppColors.coralLight),
                  ]),
                ),
              ),
            ],
          ),
        ),
        body,
      ],
    );
  }
}

/// Auction картуудыг дэлгэцийн өргөнөөс хамааран 1/2/3 баганаар
/// байрлуулна. Scroll хийдэггүй — эцэг ListView/CustomScrollView дотор
/// хэрэглэнэ. Нүүр болон landing хоёулаа үүнийг ашигладаг тул карт,
/// анимаци, товшилт бүгд ижил.
class AuctionGrid extends StatelessWidget {
  const AuctionGrid({
    super.key,
    required this.auctions,
    this.padding = EdgeInsets.zero,
  });

  final List<AuctionSummary> auctions;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(builder: (context, c) {
        final cols = Breakpoints.gridColumns(c.maxWidth);
        const gap = 16.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < auctions.length; i++)
              SizedBox(
                width: w,
                child: _StaggerIn(
                  index: i,
                  child: AuctionCard(auction: auctions[i]),
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Жагсаалтын мөрүүд 40ms зөрүүтэй дороос нь гулсаж орж ирнэ.
class _StaggerIn extends StatelessWidget {
  const _StaggerIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + 40 * (index.clamp(0, 6))),
      curve: AppMotion.fluid,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

class AuctionCard extends StatelessWidget {
  const AuctionCard({super.key, required this.auction});

  final AuctionSummary auction;

  @override
  Widget build(BuildContext context) {
    final isLive = auction.status == 'live';
    final isScheduled = auction.status == 'scheduled';
    return GlowCard(
      glow: isLive,
      onTap: () => context.push('/auctions/${auction.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            Hero(
              tag: 'auction-img-${auction.id}',
              child: AuctionImage(
                url: auction.images.isEmpty ? null : auction.images.first,
                height: 168,
                scrim: true,
              ),
            ),
            if (isLive) const Positioned(top: 14, left: 14, child: LiveBadge()),
            if (isScheduled)
              const Positioned(
                top: 14,
                left: 14,
                child: GlassChip(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.calendarClock,
                        size: 12, color: AppColors.ink),
                    SizedBox(width: 6),
                    Text('Удахгүй эхлэх',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        )),
                  ]),
                ),
              ),
            Positioned(
              bottom: 12,
              right: 14,
              child: GlassChip(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.timer, size: 13, color: AppColors.ink),
                  const SizedBox(width: 6),
                  CountdownText(
                    endsAt: auction.endsAt,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ]),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Одоогийн үнэ',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 2),
                        PriceText(amount: auction.currentPrice, fontSize: 22),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHi,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.gavel,
                            size: 12, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Text(
                          '${auction.bidCount}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
