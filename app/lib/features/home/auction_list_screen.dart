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
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(_title),
      ),
      body: PageFrame(
        maxWidth: 1100,
        child: async.when(
          loading: () => const _Grid(count: 6),
          error: (e, _) => Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmptyState(
                    icon: LucideIcons.triangleAlert,
                    title: apiErrorMessage(e),
                  ),
                  SizedBox(
                    width: 220,
                    child: PrimaryButton(
                      label: 'Дахин оролдох',
                      onPressed: () =>
                          ref.invalidate(auctionListProvider(status)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (list) {
            final items = [...list]..sort((a, b) => status == 'scheduled'
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
              color: AppColors.accent,
              onRefresh: () async {
                ref.invalidate(auctionListProvider(status));
                await ref.read(auctionListProvider(status).future);
              },
              child: _Grid(
                count: items.length,
                builder: (i) => AuctionTile(
                  auction: items[i],
                  onTap: () => context.push('/auctions/${items[i].id}'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Дөрвөлжин зурагтай картуудын сүлжээ; [builder] байхгүй бол skeleton.
class _Grid extends StatelessWidget {
  const _Grid({required this.count, this.builder});

  final int count;
  final Widget Function(int i)? builder;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    return LayoutBuilder(builder: (context, box) {
      const pad = 20.0;
      const gap = 16.0;
      final cols =
          ((box.maxWidth - pad * 2 + gap) / (170 + gap)).floor().clamp(2, 6);
      final w = (box.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
      return GridView.builder(
        physics: builder == null
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(pad, 8, pad, 40),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisExtent: w + 76 * scale,
          crossAxisSpacing: gap,
          mainAxisSpacing: 20,
        ),
        itemCount: count,
        itemBuilder: (context, i) => builder != null
            ? builder!(i)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: w, width: w, radius: 14),
                  const SizedBox(height: 10),
                  const Skeleton(height: 14, width: 110),
                  const SizedBox(height: 6),
                  const Skeleton(height: 12, width: 70),
                ],
              ),
      );
    });
  }
}
