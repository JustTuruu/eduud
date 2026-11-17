import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import 'auction_tiles.dart';
import 'home_screen.dart' show auctionListProvider;

/// "Бүгд" — Удахгүй эхлэх / Дууссан дуудлагуудын бүтэн жагсаалт.
class AuctionListScreen extends ConsumerWidget {
  const AuctionListScreen({super.key, required this.status});

  final String status;

  String get _title => status == 'scheduled' ? 'Удахгүй эхлэх' : 'Дууссан';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auctionListProvider(status));
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(_title, style: text.displaySmall),
      ),
      body: AppBackground(
        seed: 'list-$status',
        child: SafeArea(
          top: false,
          child: PageFrame(
            maxWidth: 1120,
            child: async.when(
              loading: () => const Center(
                  child: Skeleton(height: 120, width: 220, radius: 20)),
              error: (e, _) => EmptyState(
                icon: LucideIcons.triangleAlert,
                title: apiErrorMessage(e),
              ),
              data: (list) {
                final items = [...list]..sort((a, b) => status == 'scheduled'
                    ? a.startsAt.compareTo(b.startsAt)
                    : b.endsAt.compareTo(a.endsAt));
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: LucideIcons.gavel,
                    title: 'Одоогоор алга',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(auctionListProvider(status));
                    await ref.read(auctionListProvider(status).future);
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 190,
                      mainAxisExtent: 292,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => AuctionTile(
                      auction: items[i],
                      onTap: () => context.push('/auctions/${items[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
