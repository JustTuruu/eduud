import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/invoice_sheet.dart';
import '../../shared/widgets.dart';

final ordersProvider = FutureProvider<List<OrderItem>>((ref) async {
  final res = await ref.watch(dioProvider).get('/orders');
  return (res.data as List)
      .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

const _statusLabels = {
  'pending': 'Төлбөр хүлээгдэж буй',
  'paid': 'Төлөгдсөн',
  'expired': 'Хугацаа хэтэрсэн',
  'cancelled': 'Цуцлагдсан',
};

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Text('Миний ялалтууд',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.sapphire,
                  backgroundColor: AppColors.surfaceHi,
                  onRefresh: () => ref.refresh(ordersProvider.future),
                  child: orders.when(
                    loading: () => ListView(
                      padding: const EdgeInsets.all(18),
                      children: const [
                        Skeleton(height: 110, radius: 24),
                        SizedBox(height: 12),
                        Skeleton(height: 110, radius: 24),
                      ],
                    ),
                    error: (e, _) => ListView(children: [
                      EmptyState(
                          icon: LucideIcons.wifiOff, title: apiErrorMessage(e)),
                    ]),
                    data: (list) => list.isEmpty
                        ? ListView(children: const [
                            EmptyState(
                              icon: LucideIcons.trophy,
                              title: 'Ялалт хараахан алга',
                              subtitle:
                                  'Дуудлага худалдаанд санал өгч түрүүлээрэй — ялсан бараа тань энд гарч ирнэ.',
                            ),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 13),
                            itemBuilder: (context, i) =>
                                _OrderCard(order: list[i]),
                          ),
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

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.order});

  final OrderItem order;

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _paying = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final res =
          await ref.read(dioProvider).post('/orders/${widget.order.id}/pay');
      final invoice = TopupInvoice.fromJson(res.data as Map<String, dynamic>);
      if (!mounted) return;
      final paid = await showAppSheet<bool>(
        context,
        builder: (_) => PaymentInvoiceSheet(
          invoice: invoice,
          checkPath:
              '/orders/${widget.order.id}/payments/${invoice.paymentId}/check',
        ),
      );
      if (paid == true) {
        ref.invalidate(ordersProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Төлбөр амжилттай. Захиалга баталгаажлаа!')));
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
    final paid = o.status == 'paid';
    return GlowCard(
      glow: pending,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              AuctionImage(
                url: o.auctionImages.isEmpty ? null : o.auctionImages.first,
                height: 58,
                borderRadius: BorderRadius.circular(14),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.auctionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(
                        pending
                            ? LucideIcons.clock
                            : paid
                                ? LucideIcons.circleCheck
                                : LucideIcons.circleX,
                        size: 13,
                        color: pending
                            ? AppColors.gold
                            : paid
                                ? AppColors.success
                                : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(_statusLabels[o.status] ?? o.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pending
                                ? AppColors.gold
                                : paid
                                    ? AppColors.success
                                    : AppColors.muted,
                          )),
                    ]),
                  ],
                ),
              ),
              PriceText(
                amount: o.finalPrice,
                fontSize: 17,
                gradient: paid ? AppColors.winGradient : null,
              ),
            ]),
            if (pending) ...[
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Төлбөр төлөх',
                sublabel:
                    'Хугацаа: ${'${o.payDeadline.toLocal()}'.substring(0, 16)}',
                icon: LucideIcons.creditCard,
                loading: _paying,
                onPressed: _pay,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
