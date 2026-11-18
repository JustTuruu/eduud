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
import '../../shared/top_toast.dart';

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
          showTopToast(context, 'Цэнэглэлт амжилттай. Эрх нэмэгдлээ.',
              kind: TopToastKind.success);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, apiErrorMessage(e), kind: TopToastKind.error);
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
      appBar: subPageAppBar(context, 'Эрх цэнэглэх'),
      body: AppBackground(
        seed: 'wallet',
        child: SafeArea(
          bottom: false,
          child: PageFrame(
            maxWidth: 720,
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                ref.invalidate(walletTxProvider);
                ref.invalidate(packagesProvider);
                await ref.read(authProvider.notifier).refreshProfile();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + safeBottom),
                children: [
                  _Balance(balance: user?.balance ?? 0),
                  const SizedBox(height: 28),
                  packages.when(
                    loading: () => const Skeleton(height: 176, radius: 16),
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
                  const SizedBox(height: 28),
                  txs.when(
                    loading: () => const Skeleton(height: 56, radius: 16),
                    error: (e, _) => _Retry(
                      message: apiErrorMessage(e),
                      onRetry: () => ref.invalidate(walletTxProvider),
                    ),
                    data: (list) => list.isEmpty
                        ? GroupSection(title: 'Гүйлгээний түүх', children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: const EmptyState(
                                icon: LucideIcons.receipt,
                                title: 'Гүйлгээ алга',
                                subtitle:
                                    'Эрх цэнэглэсний дараа энд харагдана.',
                              ),
                            ),
                          ])
                        : GroupSection(
                            title: 'Гүйлгээний түүх',
                            children: [for (final t in list) _TxRow(tx: t)],
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

/// Одоогийн үлдэгдэл — дэлгэцийн гол тоо.
class _Balance extends StatelessWidget {
  const _Balance({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Таны эрх',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text('$balance эрх', style: AppTheme.price(size: 34)),
          const SizedBox(height: 6),
          Text('Үнэ илгээх бүрт 1 эрх зарцуулагдана.',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Ногоон текст — light дээр уншигдахын тулд арай бараан.
Color get _greenText =>
    AppColors.isDark ? AppColors.accent : const Color(0xFF1E8E3E);

class _Packages extends StatelessWidget {
  const _Packages(
      {required this.list, required this.buying, required this.onBuy});

  final List<TokenPackage> list;
  final String? buying;
  final ValueChanged<TokenPackage> onBuy;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return const EmptyState(
          icon: LucideIcons.package, title: 'Багц одоохондоо алга');
    }
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
    return GroupSection(
      title: 'Багц сонгох',
      children: [
        for (final p in list)
          _PackageRow(
            pkg: p,
            best: p.id == bestId && list.length > 1,
            busy: buying == p.id,
            disabled: buying != null,
            onTap: () => onBuy(p),
          ),
      ],
    );
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
    final pill = Container(
      constraints: const BoxConstraints(minWidth: 84, minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent),
            )
          : Text(formatMnt(pkg.priceMnt),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _greenText,
                  fontFeatures: const [FontFeature.tabularFigures()])),
    );
    return Opacity(
      opacity: disabled && !busy ? 0.5 : 1,
      child: Semantics(
        button: true,
        label: '${pkg.tokens} эрх, ${formatMnt(pkg.priceMnt)}',
        child: AnimatedPressable(
          onPressed: disabled ? null : onTap,
          scale: 0.99,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.transparent,
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${pkg.tokens} эрх',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text('Нэг эрх ${formatMnt(per)}',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.muted)),
                        if (best)
                          Text('Хамгийн хямд',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _greenText)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              pill,
            ]),
          ),
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
        Icon(LucideIcons.wifiOff, size: 18, color: AppColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message,
              style: TextStyle(color: AppColors.inkSoft, height: 1.4)),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('Дахин оролдох',
              style: TextStyle(color: _greenText, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

String _txLabel(WalletTx tx) {
  if (tx.note != null && tx.note!.trim().isNotEmpty) return tx.note!;
  return switch (tx.type) {
    'purchase' => 'Эрх цэнэглэсэн',
    'bid' => 'Оролцсон',
    'refund' => 'Эрх буцаасан',
    _ => 'Тохируулга',
  };
}

/// Гүйлгээний мөр — нэр, огноо, баруун талд +/− тоо.
class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});

  final WalletTx tx;

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount > 0;
    final sign = positive ? '+' : (tx.amount < 0 ? '−' : '');
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_txLabel(tx),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(_dateFmt.format(tx.createdAt.toLocal()),
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text('$sign${tx.amount.abs()}',
            style: AppTheme.price(
                size: 17, color: positive ? _greenText : AppColors.ink)),
      ]),
    );
  }
}
