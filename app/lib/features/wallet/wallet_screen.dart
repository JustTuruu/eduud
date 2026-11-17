import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/invoice_sheet.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';

final packagesProvider = FutureProvider<List<TokenPackage>>((ref) async {
  final res = await ref.watch(dioProvider).get('/wallet/packages');
  return (res.data as List)
      .map((e) => TokenPackage.fromJson(e as Map<String, dynamic>))
      .toList();
});

final walletTxProvider = FutureProvider<List<WalletTx>>((ref) async {
  final res = await ref.watch(dioProvider).get('/wallet/transactions');
  return (res.data as List)
      .map((e) => WalletTx.fromJson(e as Map<String, dynamic>))
      .toList();
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final packages = ref.watch(packagesProvider);
    final txs = ref.watch(walletTxProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/profile'),
        title: Text('Данс', style: Theme.of(context).textTheme.displaySmall),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: PageFrame(
            maxWidth: 720,
            child: RefreshIndicator(
              color: AppColors.coral,
              backgroundColor: AppColors.surfaceHi,
              onRefresh: () async {
                ref.invalidate(walletTxProvider);
                await ref.read(authProvider.notifier).refreshProfile();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                children: [
                  // Үлдэгдлийн premium карт
                  GlowCard(
                    glow: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.8,
                          colors: [Color(0xFF2E1D45), Color(0xFF1A1024)],
                        ),
                      ),
                      child: Column(children: [
                        const SectionLabel('Үлдэгдэл'),
                        const SizedBox(height: 18),
                        // Опал цагираг — дансны гол дүр.
                        CoralRing(
                          size: 176,
                          strokeWidth: 4,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.gem,
                                  size: 24, color: AppColors.coral),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 26),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('${user?.balance ?? 0}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayLarge),
                                ),
                              ),
                              Text('token',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SectionLabel('Цэнэглэх'),
                  const SizedBox(height: 12),
                  packages.when(
                    loading: () => GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: const [
                        Skeleton(height: 90, radius: 20),
                        Skeleton(height: 90, radius: 20),
                        Skeleton(height: 90, radius: 20),
                        Skeleton(height: 90, radius: 20),
                      ],
                    ),
                    error: (e, _) => EmptyState(
                        icon: LucideIcons.wifiOff, title: apiErrorMessage(e)),
                    data: (list) {
                      // Хамгийн ашигтай багц (нэг token-ы үнэ хамгийн бага)
                      String? bestId;
                      double best = double.infinity;
                      for (final p in list) {
                        final per = p.priceMnt / p.tokens;
                        if (per < best) {
                          best = per;
                          bestId = p.id;
                        }
                      }
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: list
                            .map((p) =>
                                _PackageCard(pkg: p, popular: p.id == bestId))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  const SectionLabel('Гүйлгээний түүх'),
                  const SizedBox(height: 12),
                  txs.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Text(apiErrorMessage(e)),
                    data: (list) => list.isEmpty
                        ? const EmptyState(
                            icon: LucideIcons.receipt,
                            title: 'Гүйлгээ алга',
                            subtitle: 'Цэнэглэлт хийснээр энд харагдана.',
                          )
                        : Column(
                            children: list
                                .map((tx) => Padding(
                                      padding: const EdgeInsets.only(bottom: 9),
                                      child: _TxTile(tx: tx),
                                    ))
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends ConsumerWidget {
  const _PackageCard({required this.pkg, this.popular = false});

  final TokenPackage pkg;
  final bool popular;

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    try {
      final res = await ref
          .read(dioProvider)
          .post('/wallet/topup', data: {'packageId': pkg.id});
      final invoice = TopupInvoice.fromJson(res.data as Map<String, dynamic>);
      if (!context.mounted) return;
      final paid = await showAppSheet<bool>(
        context,
        builder: (_) => PaymentInvoiceSheet(
          invoice: invoice,
          checkPath: '/wallet/topup/${invoice.paymentId}/check',
        ),
      );
      if (paid == true) {
        await ref.read(authProvider.notifier).refreshProfile();
        ref.invalidate(walletTxProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Цэнэглэлт амжилттай! Token нэмэгдлээ.')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlowCard(
      radius: 20,
      glow: popular,
      onTap: () => _buy(context, ref),
      child: Stack(children: [
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.gem, size: 16, color: AppColors.ink),
                  const SizedBox(width: 8),
                  Text('${pkg.tokens}',
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 6),
              Text(formatMnt(pkg.priceMnt),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        ),
        if (popular)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                gradient: AppColors.ctaGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Text('АШИГТАЙ',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: Colors.white,
                  )),
            ),
          ),
      ]),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});

  final WalletTx tx;

  IconData get _icon => switch (tx.type) {
        'purchase' => LucideIcons.circleArrowDown,
        'bid' => LucideIcons.gavel,
        'refund' => LucideIcons.rotateCcw,
        _ => LucideIcons.settings2,
      };

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceHi,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_icon,
                size: 17, color: positive ? AppColors.success : AppColors.ink),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.note ?? tx.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${tx.createdAt.toLocal()}'.substring(0, 16),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}${tx.amount}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: positive ? AppColors.success : AppColors.inkSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
