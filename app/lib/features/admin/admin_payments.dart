import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

final _payStatusProvider = StateProvider.autoDispose<String>((ref) => '');
final _payKindProvider = StateProvider.autoDispose<String>((ref) => '');

/// Төлбөр (зөвхөн харах): эрх авалт ба барааны төлбөр.
class AdminPaymentsScreen extends ConsumerWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pays = ref.watch(adminPaymentsProvider);
    final status = ref.watch(_payStatusProvider);
    final kind = ref.watch(_payKindProvider);
    return AdminPage(children: [
      AdminPageHeader(
        title: 'Төлбөр',
        subtitle: 'Сүүлийн 200 төлбөр',
        actions: [
          AdminSegments<String>(
            options: const [
              ('', 'Бүгд'),
              ('topup', 'Эрх авалт'),
              ('order', 'Барааны төлбөр'),
            ],
            value: kind,
            onChanged: (v) => ref.read(_payKindProvider.notifier).state = v,
          ),
          AdminSegments<String>(
            options: const [
              ('', 'Бүгд'),
              ('paid', 'Төлсөн'),
              ('pending', 'Хүлээгдэж буй'),
            ],
            value: status,
            onChanged: (v) => ref.read(_payStatusProvider.notifier).state = v,
          ),
        ],
      ),
      pays.when(
        loading: () => const AdminListSkeleton(),
        error: (e, _) =>
            AdminError(e, onRetry: () => ref.invalidate(adminPaymentsProvider)),
        data: (all) {
          final rows = all
              .where((p) =>
                  (status.isEmpty || jStr(p, 'status') == status) &&
                  (kind.isEmpty || jStr(p, 'kind') == kind))
              .toList();
          return AdminTable<Json>(
            rows: rows,
            empty: 'Төлбөр алга',
            columns: [
              AdminColumn(
                  'Хэрэглэгч',
                  (p) => cellText(
                      '${jStr(jMap(p, 'user'), 'name')} · ${jStr(jMap(p, 'user'), 'phone')}',
                      bold: true),
                  flex: 3),
              AdminColumn('Төрөл', (p) {
                final tokens = jInt(jMap(p, 'package'), 'tokens');
                return cellText(jStr(p, 'kind') == 'topup'
                    ? 'Эрх авалт${tokens > 0 ? ' · $tokens эрх' : ''}'
                    : 'Барааны төлбөр');
              }, flex: 2),
              AdminColumn('Дүн',
                  (p) => cellText(fmtMnt(jInt(p, 'amountMnt')), num: true),
                  right: true),
              AdminColumn('Төлөв', (p) => pillFor(jStr(p, 'status'))),
              AdminColumn(
                  'Үүссэн', (p) => cellText(fmtDate(p['createdAt']), num: true),
                  flex: 2),
              AdminColumn(
                  'Төлсөн',
                  (p) => cellText(fmtDate(p['paidAt']),
                      num: true, color: AdminColors.muted),
                  flex: 2),
            ],
          );
        },
      ),
    ]);
  }
}
