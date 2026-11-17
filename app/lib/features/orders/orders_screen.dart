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
      'paid' => AppColors.success,
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
          padding: EdgeInsets.fromLTRB(20, 12, 20, 40 + safeBottom),
          children: [
            const SubPageHeader(title: 'Хожсон бараа'),
            const SizedBox(height: 24),
            ...children,
          ],
        );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBackground(
        seed: 'orders',
        child: SafeArea(
          bottom: false,
          child: PageFrame(
            maxWidth: 720,
            child: RefreshIndicator(
              color: AppColors.coral,
              backgroundColor: AppColors.surfaceHi,
              onRefresh: () => ref.refresh(ordersProvider.future),
              child: orders.when(
                loading: () => scroll(const [
                  Skeleton(height: 96, radius: 20),
                  SizedBox(height: 14),
                  Skeleton(height: 96, radius: 20),
                  SizedBox(height: 14),
                  Skeleton(height: 96, radius: 20),
                ]),
                error: (e, _) => scroll([
                  EmptyState(
                      icon: LucideIcons.wifiOff, title: apiErrorMessage(e)),
                  Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(ordersProvider),
                      child: const Text('Дахин оролдох',
                          style: TextStyle(
                              color: AppColors.coralLight,
                              fontWeight: FontWeight.w800)),
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
                  final due = list.where((o) => o.status == 'pending').length;
                  return scroll([
                    Reveal(
                      index: 0,
                      child: Text(
                        due > 0
                            ? '$due бараа төлбөр хүлээж байна'
                            : 'Бүх төлбөр хийгдсэн',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < list.length; i++)
                      Reveal(
                        index: i + 1,
                        child: _OrderRow(
                            order: list[i], last: i == list.length - 1),
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

/// Хожсон барааны мөр — карт биш, хуваагчтай; төлөх шаардлагатай үед төлөх товчтой.
class _OrderRow extends ConsumerStatefulWidget {
  const _OrderRow({required this.order, required this.last});

  final OrderItem order;
  final bool last;

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
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Төлбөр амжилттай. Баярлалаа!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final pending = o.status == 'pending';
    final color = _statusColor(o.status);
    final img = o.auctionImages.isEmpty ? null : o.auctionImages.first;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: widget.last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 76,
                height: 76,
                child: AuctionImage(url: img, height: 76),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.auctionTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const SizedBox(height: 6),
                  Text(formatMnt(o.finalPrice),
                      style: AppTheme.price(
                          size: 20,
                          color: o.status == 'paid'
                              ? AppColors.gold
                              : AppColors.ink)),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(_statusLabels[o.status] ?? o.status,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: color)),
                  ),
                ],
              ),
            ),
          ]),
          if (pending) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(LucideIcons.clock, size: 16, color: AppColors.coralLight),
              const SizedBox(width: 8),
              const Text('Төлөх хугацаа:',
                  style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
              const SizedBox(width: 8),
              CountdownText(
                endsAt: o.payDeadline,
                style: AppTheme.price(size: 16, color: AppColors.ink),
              ),
            ]),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Төлөх',
              icon: LucideIcons.creditCard,
              loading: _paying,
              onPressed: _paying ? null : _pay,
            ),
          ],
        ],
      ),
    );
  }
}
