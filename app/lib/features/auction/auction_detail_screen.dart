import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/api/socket_client.dart';
import '../../core/models.dart';
import '../../core/router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';

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
      state = AsyncData(current.copyWith(endsAt: DateTime.parse(d['endsAt'] as String)));
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
    void onConnect(dynamic _) => socket.emit('join_auction', {'auctionId': auctionId});
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
    .family<AuctionDetailController, AuctionDetail, String>(AuctionDetailController.new);

class AuctionDetailScreen extends ConsumerStatefulWidget {
  const AuctionDetailScreen({super.key, required this.auctionId});

  final String auctionId;

  @override
  ConsumerState<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends ConsumerState<AuctionDetailScreen> {
  bool _bidding = false;

  /// Зочин "Санал өгөх" дарвал нэвтрэх дэлгэц рүү — нэвтэрсний дараа яг энэ
  /// auction руугаа буцна.
  void _requireLogin() {
    context.push(loginLocation(next: '/auctions/${widget.auctionId}'));
  }

  Future<void> _bid() async {
    setState(() => _bidding = true);
    try {
      await ref.read(auctionDetailProvider(widget.auctionId).notifier).placeBid();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _bidding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(auctionDetailProvider(widget.auctionId));
    final me = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      body: AppBackground(
        child: detailAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.sapphire)),
          error: (e, _) => Center(
            child: EmptyState(
              icon: LucideIcons.triangleAlert,
              title: apiErrorMessage(e),
            ),
          ),
          data: (a) {
            final controller =
                ref.read(auctionDetailProvider(widget.auctionId).notifier);
            final isLive = a.status == 'live';
            final ended = a.status == 'ended' || a.status == 'settled';
            final iWon = ended && me != null && a.lastBidder?.id == me.id;

            return PageFrame(
              maxWidth: 760,
              child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: AppColors.bg,
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AnimatedPressable(
                      // Web дээр холбоосоор шууд орж ирсэн бол буцах
                      // түүх байхгүй — нүүр/landing руу очно.
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                      child: const GlassChip(
                        padding: EdgeInsets.all(9),
                        child: Icon(LucideIcons.chevronLeft,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(fit: StackFit.expand, children: [
                      Hero(
                        tag: 'auction-img-${a.id}',
                        child: AuctionImage(
                            url: a.images.isEmpty ? null : a.images.first),
                      ),
                      // Зураг navy руу уусна
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.55, 1],
                            colors: [Colors.transparent, AppColors.bg],
                          ),
                        ),
                      ),
                      if (isLive)
                        const Positioned(bottom: 18, left: 18, child: LiveBadge()),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 140),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(a.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 18),
                      // Countdown — дэлгэцийн гол жүжигчин
                      CountdownPanel(
                        label: ended ? 'Дууссан' : 'Дуусахад',
                        endsAt: ended ? null : a.endsAt,
                        serverOffsetMs: controller.serverOffsetMs,
                        onFinished: () => Future.delayed(
                            const Duration(seconds: 2), controller.reload),
                        child: ended
                            ? ShaderMask(
                                shaderCallback: (b) => (iWon
                                        ? AppColors.winGradient
                                        : AppColors.priceGradient)
                                    .createShader(b),
                                child: Text(
                                  iWon
                                      ? 'Та яллаа!'
                                      : a.lastBidder != null
                                          ? 'Ялагч: ${a.lastBidder!.name}'
                                          : 'Ялагч тодроогүй',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 18),
                      GlowCard(
                        radius: AppRadius.card,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SectionLabel('Одоогийн үнэ'),
                                  const SizedBox(height: 4),
                                  AnimatedPrice(amount: a.currentPrice),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 44,
                                color: AppColors.border,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const SectionLabel('Нийт санал'),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(LucideIcons.gavel,
                                        size: 17, color: AppColors.sapphireSoft),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${a.bidCount}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(fontSize: 24),
                                    ),
                                  ]),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (a.bids.isNotEmpty) ...[
                        const SectionLabel('Сүүлийн саналууд'),
                        const SizedBox(height: 12),
                        ...a.bids.asMap().entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: _BidTile(
                                bid: entry.value,
                                isTop: entry.key == 0,
                              ),
                            )),
                        const SizedBox(height: 14),
                      ],
                      if (a.description.isNotEmpty) ...[
                        const SectionLabel('Тайлбар'),
                        const SizedBox(height: 10),
                        Text(a.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.inkSoft, height: 1.7)),
                      ],
                    ]),
                  ),
                ),
              ],
              ),
            );
          },
        ),
      ),
      bottomSheet: detailAsync.valueOrNull?.status == 'live'
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
              decoration: BoxDecoration(
                color: AppColors.bg.withValues(alpha: 0.72),
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: PageFrame(
                  maxWidth: 760,
                  child: Builder(builder: (context) {
                    final a = detailAsync.valueOrNull!;
                    if (me == null) {
                      return PrimaryButton(
                        label: 'Санал өгөхийн тулд нэвтрэх',
                        sublabel: '1 token · үнэ +${formatMnt(a.increment)}',
                        icon: LucideIcons.logIn,
                        onPressed: _requireLogin,
                      );
                    }
                    final mine = a.lastBidder?.id == me.id;
                    return PrimaryButton(
                      label: mine ? 'Та тэргүүлж байна' : 'Санал өгөх',
                      sublabel: mine
                          ? 'Өөр хүн санал өгөхийг хүлээнэ үү'
                          : '1 token · үнэ +${formatMnt(a.increment)}',
                      icon: mine ? LucideIcons.crown : LucideIcons.gavel,
                      loading: _bidding,
                      onPressed: mine ? null : _bid,
                    );
                  }),
                ),
              ),
                ),
              ),
            )
          : null,
    );
  }
}

class _BidTile extends StatelessWidget {
  const _BidTile({required this.bid, required this.isTop});

  final BidItem bid;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final Widget tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: isTop
              ? AppColors.sapphire.withValues(alpha: 0.55)
              : AppColors.border,
        ),
        gradient: isTop
            ? const LinearGradient(colors: [Color(0xFF12234A), Color(0xFF0B1220)])
            : null,
        boxShadow: isTop
            ? [
                BoxShadow(
                    color: AppColors.sapphire.withValues(alpha: 0.14),
                    blurRadius: 20),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isTop ? AppColors.ctaGradient : AppColors.balGradient,
                border: Border.all(color: AppColors.borderHi),
              ),
              child: bid.user.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(bid.user.avatarUrl!, fit: BoxFit.cover))
                  : Center(
                      child: Text(
                        bid.user.name.isEmpty ? '?' : bid.user.name[0],
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
            ),
            const SizedBox(width: 11),
            Text(bid.user.name,
                style: TextStyle(
                  color: isTop ? AppColors.inkSoft : AppColors.muted,
                  fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                )),
            if (isTop) ...[
              const SizedBox(width: 8),
              const Icon(LucideIcons.crown, size: 13, color: AppColors.sapphireSoft),
            ],
          ]),
          Text(
            formatMnt(bid.price),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isTop ? AppColors.sapphireSoft : AppColors.inkSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (reducedMotion(context)) return tile;
    return TweenAnimationBuilder<double>(
      key: ValueKey(bid.id),
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.base,
      curve: AppMotion.fluid,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, -10 * (1 - t)), child: child),
      ),
      child: tile,
    );
  }
}
