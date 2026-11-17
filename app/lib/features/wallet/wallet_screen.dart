import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/invoice_sheet.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import 'sub_page.dart';

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

final _dateFmt = DateFormat('MM.dd HH:mm');

/// Эрх цэнэглэх — одоогийн үлдэгдэл, багц сонголт, гүйлгээний түүх.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  /// Нэхэмжлэх үүсгэж буй багцын id — давхар дарагдахаас сэргийлнэ.
  String? _buying;

  Future<void> _buy(TokenPackage pkg) async {
    if (_buying != null) return;
    setState(() => _buying = pkg.id);
    try {
      final res = await ref
          .read(dioProvider)
          .post('/wallet/topup', data: {'packageId': pkg.id});
      final invoice = TopupInvoice.fromJson(res.data as Map<String, dynamic>);
      if (!mounted) return;
      final paid = await showInvoiceSheet(
        context,
        invoice: invoice,
        checkPath: '/wallet/topup/${invoice.paymentId}/check',
      );
      if (paid == true) {
        await ref.read(authProvider.notifier).refreshProfile();
        ref.invalidate(walletTxProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Цэнэглэлт амжилттай. Эрх нэмэгдлээ.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final packages = ref.watch(packagesProvider);
    final txs = ref.watch(walletTxProvider);
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBackground(
        seed: 'wallet',
        child: SafeArea(
          bottom: false,
          child: PageFrame(
            maxWidth: 720,
            child: RefreshIndicator(
              color: AppColors.coral,
              backgroundColor: AppColors.surfaceHi,
              onRefresh: () async {
                ref.invalidate(walletTxProvider);
                ref.invalidate(packagesProvider);
                await ref.read(authProvider.notifier).refreshProfile();
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 40 + safeBottom),
                children: [
                  const SubPageHeader(title: 'Эрх цэнэглэх'),
                  const SizedBox(height: 32),
                  Reveal(index: 0, child: _Balance(balance: user?.balance ?? 0)),
                  const SizedBox(height: 40),
                  Reveal(
                    index: 1,
                    child: const Text('Багц сонгох',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                  ),
                  const SizedBox(height: 14),
                  packages.when(
                    loading: () => const Column(children: [
                      Skeleton(height: 76, radius: 20),
                      SizedBox(height: 10),
                      Skeleton(height: 76, radius: 20),
                      SizedBox(height: 10),
                      Skeleton(height: 76, radius: 20),
                    ]),
                    error: (e, _) => _Retry(
                      message: apiErrorMessage(e),
                      onRetry: () => ref.invalidate(packagesProvider),
                    ),
                    data: (list) => _Packages(
                      list: list,
                      buying: _buying,
                      onBuy: _buy,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Reveal(
                    index: 4,
                    child: const Text('Гүйлгээний түүх',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                  ),
                  const SizedBox(height: 8),
                  txs.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Skeleton(height: 56, radius: 14),
                    ),
                    error: (e, _) => _Retry(
                      message: apiErrorMessage(e),
                      onRetry: () => ref.invalidate(walletTxProvider),
                    ),
                    data: (list) => list.isEmpty
                        ? const EmptyState(
                            icon: LucideIcons.receipt,
                            title: 'Гүйлгээ алга',
                            subtitle: 'Эрх цэнэглэсний дараа энд харагдана.',
                          )
                        : Column(children: [
                            for (var i = 0; i < list.length; i++)
                              _TxRow(tx: list[i], last: i == list.length - 1),
                          ]),
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

/// Одоогийн үлдэгдэл — дэлгэцийн гол тоо.
class _Balance extends StatelessWidget {
  const _Balance({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Таны эрх',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('$balance',
                    style: AppTheme.price(size: 72).copyWith(height: 1)),
              ),
            ),
            const SizedBox(width: 10),
            const Text('эрх',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkSoft)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Санал өгөх бүрт 1 эрх зарцуулагдана.',
            style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
      ],
    );
  }
}

class _Packages extends StatelessWidget {
  const _Packages(
      {required this.list, required this.buying, required this.onBuy});

  final List<TokenPackage> list;
  final String? buying;
  final ValueChanged<TokenPackage> onBuy;

  @override
  Widget build(BuildContext context) {
    // Хамгийн хямд нэг эрхтэй багцыг тэмдэглэнэ.
    String? bestId;
    var best = double.infinity;
    for (final p in list) {
      final per = p.priceMnt / p.tokens;
      if (per < best) {
        best = per;
        bestId = p.id;
      }
    }
    if (list.isEmpty) {
      return const EmptyState(
          icon: LucideIcons.package, title: 'Багц одоохондоо алга');
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 2 : 1;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < list.length; i++)
            SizedBox(
              width: w,
              child: Reveal(
                index: 2 + (i > 1 ? 1 : i),
                child: _PackageRow(
                  pkg: list[i],
                  best: list[i].id == bestId && list.length > 1,
                  busy: buying == list[i].id,
                  disabled: buying != null,
                  onTap: () => onBuy(list[i]),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({
    required this.pkg,
    required this.best,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  final TokenPackage pkg;
  final bool best;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final per = (pkg.priceMnt / pkg.tokens).round();
    return Semantics(
      button: true,
      label: '${pkg.tokens} эрх, ${formatMnt(pkg.priceMnt)}',
      child: AnimatedPressable(
        onPressed: disabled ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: best
                  ? AppColors.coral.withValues(alpha: 0.5)
                  : AppColors.border,
              width: best ? 1.4 : 1,
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('${pkg.tokens} эрх',
                        style: AppTheme.price(size: 24)),
                    if (best) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Хамгийн хямд',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.coralLight)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text('Нэг эрх ${formatMnt(per)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: AppColors.coral),
              )
            else
              Text(formatMnt(pkg.priceMnt), style: AppTheme.price(size: 18)),
            const SizedBox(width: 6),
            const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        const Icon(LucideIcons.wifiOff, size: 18, color: AppColors.inkSoft),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: AppColors.inkSoft, height: 1.4)),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('Дахин оролдох',
              style: TextStyle(
                  color: AppColors.coralLight, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

String _txLabel(WalletTx tx) {
  if (tx.note != null && tx.note!.trim().isNotEmpty) return tx.note!;
  return switch (tx.type) {
    'purchase' => 'Эрх цэнэглэсэн',
    'bid' => 'Санал өгсөн',
    'refund' => 'Эрх буцаасан',
    _ => 'Тохируулга',
  };
}

/// Гүйлгээний мөр — карт биш, 1px хуваагчтай жагсаалт.
class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx, required this.last});

  final WalletTx tx;
  final bool last;

  IconData get _icon => switch (tx.type) {
        'purchase' => LucideIcons.circleArrowDown,
        'bid' => LucideIcons.gavel,
        'refund' => LucideIcons.rotateCcw,
        _ => LucideIcons.settings2,
      };

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount > 0;
    final sign = positive ? '+' : (tx.amount < 0 ? '−' : '');
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Icon(_icon,
            size: 20, color: positive ? AppColors.success : AppColors.inkSoft),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_txLabel(tx),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(_dateFmt.format(tx.createdAt.toLocal()),
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
        ),
        Text('$sign${tx.amount.abs()}',
            style: AppTheme.price(
                size: 18,
                color: positive ? AppColors.success : AppColors.ink)),
      ]),
    );
  }
}
