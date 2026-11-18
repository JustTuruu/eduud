import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

/// Ангилал: нэмэх, нэр/эрэмбэ засах, идэвхгүй болгох, устгах.
class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref,
      [AdminCategory? c]) async {
    final res = await showDialog<(String, int)>(
      context: context,
      builder: (_) => _CategoryDialog(initial: c),
    );
    if (res == null || !context.mounted) return;
    final api = ref.read(adminApiProvider);
    final ok = await runAdminAction(
      context,
      () => c == null
          ? api.createCategory(res.$1, res.$2)
          : api.updateCategory(c.id, {'name': res.$1, 'sortOrder': res.$2}),
      success: c == null ? 'Ангилал нэмэгдлээ' : 'Хадгаллаа',
    );
    if (ok) ref.invalidate(adminCategoriesProvider);
  }

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, AdminCategory c, bool v) async {
    final ok = await runAdminAction(context,
        () => ref.read(adminApiProvider).updateCategory(c.id, {'active': v}));
    if (ok) ref.invalidate(adminCategoriesProvider);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, AdminCategory c) async {
    final yes = await confirmDialog(context,
        title: '"${c.name}" ангиллыг устгах уу?',
        message: 'Энэ үйлдлийг буцаах боломжгүй.',
        confirmLabel: 'Устгах',
        danger: true);
    if (!yes || !context.mounted) return;
    // 409 үед сервер "ашиглагдаж байна" гэсэн мессеж буцаана — шууд харуулна.
    final ok = await runAdminAction(
        context, () => ref.read(adminApiProvider).deleteCategory(c.id),
        success: 'Устгалаа');
    if (ok) ref.invalidate(adminCategoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(adminCategoriesProvider);
    return AdminPage(children: [
      AdminPageHeader(
        title: 'Ангилал',
        subtitle: 'Дуудлага ба хүсэлтийн ангилал',
        actions: [
          AdminButton('Ангилал нэмэх',
              icon: LucideIcons.plus,
              kind: BtnKind.primary,
              onPressed: () => _edit(context, ref)),
        ],
      ),
      cats.when(
        loading: () => const AdminListSkeleton(),
        error: (e, _) => AdminError(e,
            onRetry: () => ref.invalidate(adminCategoriesProvider)),
        data: (rows) => AdminTable<AdminCategory>(
          rows: rows,
          empty: 'Ангилал алга. Дээрх товчоор нэмнэ үү.',
          columns: [
            AdminColumn('Нэр', (c) => cellText(c.name, bold: true), flex: 4),
            AdminColumn('Эрэмбэ', (c) => cellText('${c.sortOrder}', num: true)),
            AdminColumn(
                'Дуудлага', (c) => cellText(fmtInt(c.auctionCount), num: true)),
            AdminColumn(
              'Идэвхтэй',
              (c) => Switch(
                value: c.active,
                onChanged: (v) => _toggle(context, ref, c, v),
              ),
            ),
            AdminColumn(
              '',
              (c) => Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Засах',
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  onPressed: () => _edit(context, ref, c),
                ),
                IconButton(
                  tooltip: 'Устгах',
                  icon: const Icon(LucideIcons.trash2,
                      size: 16, color: AdminColors.red),
                  onPressed: () => _delete(context, ref, c),
                ),
              ]),
              flex: 2,
              right: true,
            ),
          ],
        ),
      ),
    ]);
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.initial});
  final AdminCategory? initial;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _sort =
      TextEditingController(text: '${widget.initial?.sortOrder ?? 0}');
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _sort.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'Нэрээ бичнэ үү');
      return;
    }
    Navigator.pop(context, (name, int.tryParse(_sort.text.trim()) ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Ангилал нэмэх' : 'Ангилал засах',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FieldLabel(
            'Нэр',
            child: TextField(
              controller: _name,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(errorText: _err),
            ),
          ),
          FieldLabel(
            'Эрэмбэ',
            hint: 'Бага тоотой нь эхэнд гарна',
            child: TextField(
              controller: _sort,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _submit(),
            ),
          ),
        ]),
      ),
      actions: [
        AdminButton('Болих', onPressed: () => Navigator.pop(context)),
        AdminButton('Хадгалах', kind: BtnKind.primary, onPressed: _submit),
      ],
    );
  }
}
