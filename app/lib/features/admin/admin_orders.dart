import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

const _deliveryOptions = [
  ('preparing', 'Бэлтгэж буй'),
  ('shipped', 'Хүргэлтэд гарсан'),
  ('delivered', 'Хүргэгдсэн'),
];

/// Захиалга: төлбөрийн төлөв ба хүргэлтийн явц.
class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(adminOrdersProvider);
    return AdminPage(children: [
      const AdminPageHeader(
          title: 'Захиалга', subtitle: 'Ялагчдын захиалга, хүргэлтийн төлөв'),
      orders.when(
        loading: () => const AdminListSkeleton(),
        error: (e, _) =>
            AdminError(e, onRetry: () => ref.invalidate(adminOrdersProvider)),
        data: (rows) => AdminTable<Json>(
          rows: rows,
          empty: 'Захиалга алга',
          columns: [
            AdminColumn('Бараа',
                (o) => cellText(jStr(jMap(o, 'auction'), 'title'), bold: true),
                flex: 3),
            AdminColumn(
                'Ялагч',
                (o) => cellText(
                    '${jStr(jMap(o, 'winner'), 'name')} · ${jStr(jMap(o, 'winner'), 'phone')}'),
                flex: 3),
            AdminColumn('Үнэ',
                (o) => cellText(fmtMnt(jInt(o, 'finalPrice')), num: true),
                right: true),
            AdminColumn('Төлбөр', (o) => pillFor(jStr(o, 'status')), flex: 2),
            AdminColumn('Хүргэлт', (o) {
              final s = jStr(jMap(o, 'deliveryInfo'), 'status');
              return s.isEmpty ? const StatusPill('Тохируулаагүй') : pillFor(s);
            }, flex: 2),
            AdminColumn(
              '',
              (o) => jStr(o, 'status') == 'paid'
                  ? AdminButton('Хүргэлт',
                      icon: LucideIcons.truck,
                      onPressed: () => _edit(context, ref, o))
                  : const SizedBox.shrink(),
              flex: 2,
              right: true,
            ),
          ],
        ),
      ),
    ]);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Json o) async {
    final res = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _DeliveryDialog(order: o),
    );
    if (res == null || !context.mounted) return;
    final ok = await runAdminAction(
        context,
        () => ref.read(adminApiProvider).updateDelivery(jStr(o, 'id'), {
              ...jMap(o, 'deliveryInfo'),
              'status': res.$1,
              if (res.$2.isNotEmpty) 'note': res.$2,
            }),
        success: 'Хүргэлтийн төлөв шинэчлэгдлээ');
    if (ok) ref.invalidate(adminOrdersProvider);
  }
}

class _DeliveryDialog extends StatefulWidget {
  const _DeliveryDialog({required this.order});
  final Json order;

  @override
  State<_DeliveryDialog> createState() => _DeliveryDialogState();
}

class _DeliveryDialogState extends State<_DeliveryDialog> {
  late String _status = () {
    final s = jStr(jMap(widget.order, 'deliveryInfo'), 'status');
    return _deliveryOptions.any((o) => o.$1 == s) ? s : 'preparing';
  }();
  late final _note = TextEditingController(
      text: jStr(jMap(widget.order, 'deliveryInfo'), 'note'));

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Хүргэлтийн төлөв',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AdminSegments<String>(
                    options: _deliveryOptions,
                    value: _status,
                    onChanged: (v) => setState(() => _status = v)),
              ),
            ),
            FieldLabel('Тэмдэглэл (заавал биш)',
                child: TextField(controller: _note, maxLines: 3)),
          ]),
        ),
        actions: [
          AdminButton('Болих', onPressed: () => Navigator.pop(context)),
          AdminButton('Хадгалах',
              kind: BtnKind.primary,
              onPressed: () =>
                  Navigator.pop(context, (_status, _note.text.trim()))),
        ],
      );
}
