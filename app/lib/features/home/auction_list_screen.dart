import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import 'auction_tiles.dart';
import 'home_screen.dart' show auctionListProvider;

/// "Бүгд" — Удахгүй эхлэх / Дууссан дуудлагуудын бүтэн жагсаалт.
/// Нүүрийн хэвтээ мөрүүдтэй ижил зураг-картуудын сүлжээ.
class AuctionListScreen extends ConsumerWidget {
  const AuctionListScreen({super.key, required this.status});

  final String status;

  String get _title => status == 'scheduled' ? 'Удахгүй эхлэх' : 'Дууссан';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auctionListProvider(status));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBackground(
        seed: 'list-$status',
        child: SafeArea(
          bottom: false,
          child: PageFrame(
            maxWidth: 1120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(children: [
                    IconButton(
                      tooltip: 'Буцах',
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                      icon: const Icon(LucideIcons.chevronLeft,
                          size: 24, color: AppColors.ink),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: async.when(
                    loading: () => const _GridSkeleton(),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EmptyState(
                            icon: LucideIcons.triangleAlert,
                            title: apiErrorMessage(e),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 220,
                            child: PrimaryButton(
                              label: 'Дахин оролдох',
                              icon: LucideIcons.refreshCw,
                              onPressed: () =>
                                  ref.invalidate(auctionListProvider(status)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    data: (list) {
                      final items = [...list]..sort((a, b) =>
                          status == 'scheduled'
                              ? a.startsAt.compareTo(b.startsAt)
                              : b.endsAt.compareTo(a.endsAt));
                      if (items.isEmpty) {
                        return EmptyState(
                          icon: LucideIcons.gavel,
                          title: status == 'scheduled'
                              ? 'Удахгүй эхлэх дуудлага алга'
                              : 'Дууссан дуудлага алга',
                        );
                      }
                      return RefreshIndicator(
                        color: AppColors.coral,
                        backgroundColor: AppColors.surfaceHi,
                        onRefresh: () async {
                          ref.invalidate(auctionListProvider(status));
                          await ref.read(auctionListProvider(status).future);
                        },
                        child: GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisExtent: 270,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 24,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, i) => AuctionTile(
                            auction: items[i],
                            onTap: () =>
                                context.push('/auctions/${items[i].id}'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 270,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
      ),
      itemCount: 6,
      itemBuilder: (context, i) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Skeleton(height: 160, radius: 20),
          ),
          SizedBox(height: 10),
          Skeleton(height: 14, width: 110),
          SizedBox(height: 6),
          Skeleton(height: 12, width: 70),
        ],
      ),
    );
  }
}
