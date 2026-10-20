import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';

final auctionListProvider =
    FutureProvider.family<List<AuctionSummary>, String>((ref, status) async {
  final res = await ref.watch(dioProvider).get('/auctions', queryParameters: {'status': status});
  return (res.data as List)
      .map((e) => AuctionSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  static const _statuses = ['live', 'scheduled', 'ended'];
  static const _labels = ['Идэвхтэй', 'Удахгүй', 'Дууссан'];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final display = Theme.of(context).textTheme.displayMedium;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wordmark + balance
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: 'E-', style: display?.copyWith(fontSize: 19)),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.opalGradient.createShader(b),
                          child: Text('DUUD',
                              style: display?.copyWith(
                                  fontSize: 19, color: Colors.white)),
                        ),
                      ),
                    ])),
                    if (user != null)
                      TokenBalanceChip(
                        balance: user.balance,
                        onTap: () => context.go('/wallet'),
                      ),
                  ],
                ),
              ),
              if (user != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сайн уу, ${user.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(fontSize: 26),
                      ),
                      const SizedBox(height: 4),
                      Text('Нэг цохилт л ялалтаас тусгаарлана.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SegmentedTabs(
                  labels: _labels,
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.base,
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  child: _AuctionList(
                    key: ValueKey(_tab),
                    status: _statuses[_tab],
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

/// Шилжих pill-тэй segmented таб.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final segW = constraints.maxWidth / labels.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: AppMotion.base,
            curve: AppMotion.fluid,
            left: segW * index,
            top: 0,
            bottom: 0,
            width: segW,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.ctaGradient,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.sapphire.withValues(alpha: 0.4),
                      blurRadius: 16),
                ],
              ),
            ),
          ),
          Row(
            children: List.generate(labels.length, (i) {
              final selected = i == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: AppMotion.fast,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? Colors.white : AppColors.muted,
                      ),
                      child: Text(labels[i]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ]);
      }),
    );
  }
}

class _AuctionList extends ConsumerWidget {
  const _AuctionList({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(auctionListProvider(status));
    return RefreshIndicator(
      color: AppColors.sapphire,
      backgroundColor: AppColors.surfaceHi,
      onRefresh: () => ref.refresh(auctionListProvider(status).future),
      child: list.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, __) => const SkeletonCard(),
        ),
        error: (e, _) => ListView(children: [
          EmptyState(
            icon: LucideIcons.wifiOff,
            title: apiErrorMessage(e),
            subtitle: 'Доош чирж дахин ачаална уу.',
          ),
        ]),
        data: (auctions) => auctions.isEmpty
            ? ListView(children: [
                EmptyState(
                  icon: status == 'live'
                      ? LucideIcons.gavel
                      : status == 'scheduled'
                          ? LucideIcons.calendarClock
                          : LucideIcons.archive,
                  title: status == 'live'
                      ? 'Идэвхтэй дуудлага худалдаа алга'
                      : status == 'scheduled'
                          ? 'Удахгүй эхлэх зүйл алга'
                          : 'Дууссан дуудлага худалдаа алга',
                  subtitle: status == 'live'
                      ? 'Шинэ дуудлага худалдаа эхлэхэд энд гарч ирнэ.'
                      : null,
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: auctions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) => _StaggerIn(
                  index: i,
                  child: _AuctionCard(auction: auctions[i]),
                ),
              ),
      ),
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

class _AuctionCard extends StatelessWidget {
  const _AuctionCard({required this.auction});

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
                        size: 12, color: AppColors.sapphireSoft),
                    SizedBox(width: 6),
                    Text('УДАХГҮЙ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: AppColors.sapphireSoft,
                        )),
                  ]),
                ),
              ),
            Positioned(
              bottom: 12,
              right: 14,
              child: GlassChip(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.timer, size: 13, color: AppColors.sapphireSoft),
                  const SizedBox(width: 6),
                  CountdownText(
                    endsAt: auction.endsAt,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
                        const SectionLabel('Одоогийн үнэ'),
                        const SizedBox(height: 2),
                        PriceText(amount: auction.currentPrice, fontSize: 22),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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
