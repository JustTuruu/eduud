import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/invoice_sheet.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../wallet/sub_page.dart';
import '../../shared/top_toast.dart';

final ordersProvider = FutureProvider<List<OrderItem>>((ref) async {
  final res = await ref.watch(dioProvider).get('/orders');
  return (res.data as List)
      .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

const _statusLabels = {
  'pending': 'Төлөх',
  'paid': 'Төлсөн',
  'expired': 'Хугацаа дууссан',
  'cancelled': 'Цуцлагдсан',
};

Color _statusColor(String s) => switch (s) {
      'pending' => AppColors.warn,
      'expired' => AppColors.danger,
      _ => AppColors.muted,
    };

/// Хожсон бараа — ялсан дуудлага бүр, төлбөрийн төлөвтэй.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    Widget scroll(List<Widget> children) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + safeBottom),
          children: children,
        );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subPageAppBar(context, 'Хожсон бараа'),
      body: AppBackground(
        seed: 'orders',
        child: SafeArea(
          bottom: false,
          child: PageFrame(
            maxWidth: 720,
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: () => ref.refresh(ordersProvider.future),
              child: orders.when(
                loading: () => scroll(const [
                  Skeleton(height: 120, radius: 16),
                  SizedBox(height: 12),
                  Skeleton(height: 120, radius: 16),
                ]),
                error: (e, _) => scroll([
                  EmptyState(
                      icon: LucideIcons.wifiOff, title: apiErrorMessage(e)),
                  Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(ordersProvider),
                      child: Text('Дахин оролдох',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
                data: (list) {
                  if (list.isEmpty) {
                    return scroll(const [
                      EmptyState(
                        icon: LucideIcons.trophy,
                        title: 'Хожсон бараа алга',
                        subtitle:
                            'Дуудлага худалдаанд ялвал барааны чинь төлбөр энд гарна.',
                      ),
                    ]);
                  }
                  final due = list.where((o) => o.needsPayment).length;
                  return scroll([
                    GroupSection(
                      dividerInset: 84,
                      footer: due > 0
                          ? '$due бараа төлбөр хүлээж байна'
                          : 'Бүх төлбөр хийгдсэн',
                      children: [for (final o in list) _OrderRow(order: o)],
                    ),
                  ]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Хожсон барааны мөр — зураг, нэр, үнэ, төлөв; төлөх шаардлагатай үед товчтой.
class _OrderRow extends ConsumerStatefulWidget {
  const _OrderRow({required this.order});

  final OrderItem order;

  @override
  ConsumerState<_OrderRow> createState() => _OrderRowState();
}

class _OrderRowState extends ConsumerState<_OrderRow> {
  bool _paying = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final res =
          await ref.read(dioProvider).post('/orders/${widget.order.id}/pay');
      final invoice = TopupInvoice.fromJson(res.data as Map<String, dynamic>);
      if (!mounted) return;
      final paid = await showInvoiceSheet(
        context,
        invoice: invoice,
        checkPath:
            '/orders/${widget.order.id}/payments/${invoice.paymentId}/check',
      );
      if (paid == true) {
        ref.invalidate(ordersProvider);
        if (mounted) {
          showTopToast(context, 'Төлбөр амжилттай. Баярлалаа!',
              kind: TopToastKind.success);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, apiErrorMessage(e), kind: TopToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final pending = o.needsPayment;
    final color = _statusColor(o.status);
    final img = o.auctionImages.isEmpty ? null : o.auctionImages.first;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: AuctionImage(url: img, height: 56),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      o.isPrize && (o.prizeTitle ?? '').isNotEmpty
                          ? o.prizeTitle!
                          : o.auctionTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                      o.isPrize
                          ? 'Шагнал · ${o.prizePlace}-р байр'
                          : formatMnt(o.finalPrice),
                      style: TextStyle(
                          fontSize: 15,
                          color: AppColors.inkSoft,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
                o.finalPrice == 0 && o.status == 'pending'
                    ? 'Үнэгүй'
                    : (_statusLabels[o.status] ?? o.status),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ]),
          if (pending) ...[
            const SizedBox(height: 12),
            Row(children: [
              Text('Төлөх хугацаа:',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(width: 6),
              CountdownText(
                endsAt: o.payDeadline,
                style: AppTheme.price(size: 13, color: AppColors.ink)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ]),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Төлөх',
              loading: _paying,
              onPressed: _paying ? null : _pay,
            ),
          ],
        ],
      ),
    );
  }
}
