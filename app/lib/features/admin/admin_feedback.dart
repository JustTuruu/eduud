import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

final _fbStatusProvider = StateProvider.autoDispose<String>((ref) => '');

const _fbStatuses = [
  ('open', 'Нээлттэй'),
  ('reviewing', 'Хянаж байна'),
  ('resolved', 'Шийдсэн'),
  ('closed', 'Хаасан'),
];

const _types = {
  'bug': 'Алдаа',
  'idea': 'Санаа',
  'improvement': 'Сайжруулалт',
  'complaint': 'Гомдол',
  'suggestion': 'Санал',
  'praise': 'Талархал',
  'other': 'Бусад',
};

/// Хэрэглэгчийн санал хүсэлт: төлөв, тэмдэглэл шинэчлэх.
class AdminFeedbackScreen extends ConsumerWidget {
  const AdminFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(_fbStatusProvider);
    final list = ref.watch(adminFeedbackProvider(status));
    return AdminPage(children: [
      AdminPageHeader(
        title: 'Санал хүсэлт',
        subtitle: 'Хэрэглэгчдийн илгээсэн санал, гомдол',
        actions: [
          AdminSegments<String>(
            options: [('', 'Бүгд'), ..._fbStatuses],
            value: status,
            onChanged: (v) => ref.read(_fbStatusProvider.notifier).state = v,
          ),
        ],
      ),
      list.when(
        skipLoadingOnRefresh: true,
        loading: () => const AdminListSkeleton(),
        error: (e, _) =>
            AdminError(e, onRetry: () => ref.invalidate(adminFeedbackProvider)),
        data: (rows) => AdminTable<Json>(
          rows: rows,
          empty: 'Санал хүсэлт алга',
          onTap: (f) => showAdminPanel(context,
              title: 'Санал хүсэлт',
              child: _FeedbackDetail(item: f, listStatus: status)),
          columns: [
            AdminColumn('Хэрэглэгч',
                (f) => cellText(jStr(jMap(f, 'user'), 'name'), bold: true),
                flex: 2),
            AdminColumn('Төрөл',
                (f) => cellText(_types[jStr(f, 'type')] ?? jStr(f, 'type'))),
            AdminColumn('Зурвас', (f) => cellText(jStr(f, 'message')), flex: 5),
            AdminColumn('Төлөв', (f) => pillFor(jStr(f, 'status')), flex: 2),
            AdminColumn(
                'Огноо', (f) => cellText(fmtDate(f['createdAt']), num: true),
                flex: 2),
          ],
        ),
      ),
    ]);
  }
}

class _FeedbackDetail extends ConsumerStatefulWidget {
  const _FeedbackDetail({required this.item, required this.listStatus});
  final Json item;
  final String listStatus;

  @override
  ConsumerState<_FeedbackDetail> createState() => _FeedbackDetailState();
}

class _FeedbackDetailState extends ConsumerState<_FeedbackDetail> {
  late String _status = jStr(widget.item, 'status');
  late final _note =
      TextEditingController(text: jStr(widget.item, 'adminNote'));
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runAdminAction(
        context,
        () => ref.read(adminApiProvider).updateFeedback(
            jStr(widget.item, 'id'), _status, _note.text.trim()),
        success: 'Хадгаллаа');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(adminFeedbackProvider);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.item;
    final u = jMap(f, 'user');
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('${jStr(u, 'name')} · ${jStr(u, 'phone')}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(
          '${_types[jStr(f, 'type')] ?? jStr(f, 'type')} · ${jStr(f, 'category')} · ${fmtDate(f['createdAt'])}',
          style: adminNumber(size: 12, color: AdminColors.muted)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AdminColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminColors.border)),
        child: SelectableText(jStr(f, 'message'),
            style: const TextStyle(fontSize: 14, height: 1.45)),
      ),
      const SizedBox(height: 20),
      FieldLabel('Төлөв',
          child: AdminSegments<String>(
              options: _fbStatuses,
              value: _status,
              onChanged: (v) => setState(() => _status = v))),
      FieldLabel('Админы тэмдэглэл',
          child: TextField(controller: _note, maxLines: 4, maxLength: 1000)),
      Align(
        alignment: Alignment.centerLeft,
        child: AdminButton('Хадгалах',
            kind: BtnKind.primary, busy: _busy, onPressed: _save),
      ),
    ]);
  }
}
