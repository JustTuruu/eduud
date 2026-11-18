import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

final _reqStatusProvider = StateProvider.autoDispose<String>((ref) => '');

const _reqFilters = [
  ('', 'Бүгд'),
  ('pending', 'Шинэ'),
  ('reviewing', 'Хянаж байна'),
  ('info_requested', 'Мэдээлэл хүссэн'),
  ('approved', 'Зөвшөөрсөн'),
  ('rejected', 'Татгалзсан'),
];

/// Хэрэглэгчийн дуудлага зохион байгуулах хүсэлтүүд.
class AdminRequestsScreen extends ConsumerWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(_reqStatusProvider);
    final list = ref.watch(adminRequestsProvider(status));
    return AdminPage(children: [
      AdminPageHeader(
        title: 'Хүсэлтүүд',
        subtitle: 'Хэрэглэгчид өөрийн бараагаар дуудлага хийх хүсэлт',
        actions: [
          AdminSegments<String>(
            options: _reqFilters,
            value: status,
            onChanged: (v) => ref.read(_reqStatusProvider.notifier).state = v,
          ),
        ],
      ),
      list.when(
        skipLoadingOnRefresh: true,
        loading: () => const AdminListSkeleton(),
        error: (e, _) =>
            AdminError(e, onRetry: () => ref.invalidate(adminRequestsProvider)),
        data: (rows) => AdminTable<Json>(
          rows: rows,
          empty: 'Хүсэлт алга',
          onTap: (r) => showAdminPanel(context,
              title: 'Хүсэлт', child: _RequestDetail(item: r)),
          columns: [
            AdminColumn('Гарчиг', (r) => cellText(jStr(r, 'title'), bold: true),
                flex: 4),
            AdminColumn(
                'Хэрэглэгч', (r) => cellText(jStr(jMap(r, 'user'), 'name')),
                flex: 2),
            AdminColumn('Ангилал', (r) => cellText(jStr(r, 'category'))),
            AdminColumn('Эхлэх үнэ',
                (r) => cellText(fmtMnt(jInt(r, 'startPrice')), num: true),
                right: true),
            AdminColumn('Төлөв', (r) => pillFor(jStr(r, 'status')), flex: 2),
            AdminColumn(
                'Огноо', (r) => cellText(fmtDate(r['createdAt']), num: true),
                flex: 2),
          ],
        ),
      ),
    ]);
  }
}

class _RequestDetail extends ConsumerStatefulWidget {
  const _RequestDetail({required this.item});
  final Json item;

  @override
  ConsumerState<_RequestDetail> createState() => _RequestDetailState();
}

class _RequestDetailState extends ConsumerState<_RequestDetail> {
  late final _note =
      TextEditingController(text: jStr(widget.item, 'adminNote'));
  String? _busy;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide(String status, String label) async {
    final note = _note.text.trim();
    if ((status == 'rejected' || status == 'info_requested') && note.isEmpty) {
      adminToast(context, 'Хэрэглэгчид харагдах тэмдэглэл бичнэ үү.');
      return;
    }
    final yes = await confirmDialog(context,
        title: '"$label" гэж шийдэх үү?',
        message: jStr(widget.item, 'title'),
        confirmLabel: label,
        danger: status == 'rejected');
    if (!yes || !mounted) return;
    setState(() => _busy = status);
    final ok = await runAdminAction(
        context,
        () => ref
            .read(adminApiProvider)
            .decideRequest(jStr(widget.item, 'id'), status, note),
        success: 'Шийдвэр хадгалагдлаа');
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok) {
      ref.invalidate(adminRequestsProvider);
      Navigator.pop(context);
    }
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 110,
              child: Text(k,
                  style:
                      const TextStyle(fontSize: 13, color: AdminColors.muted))),
          Expanded(
              child: SelectableText(v.isEmpty ? '—' : v,
                  style: const TextStyle(fontSize: 13))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.item;
    final u = jMap(r, 'user');
    final decidable = const ['pending', 'reviewing', 'info_requested']
        .contains(jStr(r, 'status'));
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        Expanded(
            child: Text(jStr(r, 'title'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600))),
        pillFor(jStr(r, 'status')),
      ]),
      const SizedBox(height: 16),
      _row('Хэрэглэгч', '${jStr(u, 'name')} · ${jStr(u, 'phone')}'),
      _row('Ангилал', jStr(r, 'category')),
      _row('Эхлэх үнэ', fmtMnt(jInt(r, 'startPrice'))),
      _row('Хүссэн огноо', jStr(r, 'preferredDate')),
      _row('Илгээсэн', fmtDate(r['createdAt'])),
      const Divider(),
      const SizedBox(height: 12),
      _row('Тайлбар', jStr(r, 'description')),
      _row('Бусад мэдээлэл', jStr(r, 'otherInfo')),
      const SizedBox(height: 12),
      if (decidable) ...[
        FieldLabel('Админы тэмдэглэл',
            hint: 'Татгалзах, мэдээлэл хүсэх үед заавал бичнэ',
            child: TextField(controller: _note, maxLines: 4)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          AdminButton('Хянаж эхлэх',
              busy: _busy == 'reviewing',
              onPressed: _busy != null
                  ? null
                  : () => _decide('reviewing', 'Хянаж эхлэх')),
          AdminButton('Мэдээлэл хүсэх',
              busy: _busy == 'info_requested',
              onPressed: _busy != null
                  ? null
                  : () => _decide('info_requested', 'Мэдээлэл хүсэх')),
          AdminButton('Зөвшөөрөх',
              kind: BtnKind.primary,
              busy: _busy == 'approved',
              onPressed: _busy != null
                  ? null
                  : () => _decide('approved', 'Зөвшөөрөх')),
          AdminButton('Татгалзах',
              kind: BtnKind.danger,
              busy: _busy == 'rejected',
              onPressed: _busy != null
                  ? null
                  : () => _decide('rejected', 'Татгалзах')),
        ]),
      ] else if (jStr(r, 'adminNote').isNotEmpty)
        _row('Тэмдэглэл', jStr(r, 'adminNote')),
    ]);
  }
}
