import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

final _userQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Хэрэглэгчид: хайх, хориглох/сэргээх, эрх нэмэх/хасах.
class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  Future<void> _ban(BuildContext context, WidgetRef ref, Json u) async {
    final banned = jStr(u, 'status') == 'banned';
    final name = jStr(u, 'name');
    final yes = await confirmDialog(context,
        title: banned ? '$name-г сэргээх үү?' : '$name-г хориглох уу?',
        message: banned
            ? 'Хэрэглэгч дахин нэвтэрч, саналаа өгөх боломжтой болно.'
            : 'Хэрэглэгч нэвтрэх, санал өгөх боломжгүй болно.',
        confirmLabel: banned ? 'Сэргээх' : 'Хориглох',
        danger: !banned);
    if (!yes || !context.mounted) return;
    final ok = await runAdminAction(context,
        () => ref.read(adminApiProvider).banUser(jStr(u, 'id'), !banned),
        success: banned ? 'Сэргээлээ' : 'Хориглолоо');
    if (ok) ref.invalidate(adminUsersProvider);
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref, Json u) async {
    final res = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _AdjustDialog(name: jStr(u, 'name')),
    );
    if (res == null || !context.mounted) return;
    final sign = res.$1 > 0 ? '+${res.$1}' : '${res.$1}';
    final yes = await confirmDialog(context,
        title: '${jStr(u, 'name')}: $sign эрх',
        message: 'Тайлбар: ${res.$2}',
        confirmLabel: 'Батлах');
    if (!yes || !context.mounted) return;
    final ok = await runAdminAction(
        context,
        () => ref
            .read(adminApiProvider)
            .adjustTokens(jStr(u, 'id'), res.$1, res.$2),
        success: 'Эрх шинэчлэгдлээ');
    if (ok) ref.invalidate(adminUsersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(_userQueryProvider);
    final users = ref.watch(adminUsersProvider(q));
    return AdminPage(children: [
      AdminPageHeader(
        title: 'Хэрэглэгчид',
        subtitle: 'Сүүлд бүртгүүлсэн 100 хүртэл хэрэглэгч',
        actions: [
          AdminSearchField(
            hint: 'Нэр эсвэл утас',
            onChanged: (v) =>
                ref.read(_userQueryProvider.notifier).state = v.trim(),
          ),
        ],
      ),
      users.when(
        skipLoadingOnRefresh: true,
        loading: () => const AdminListSkeleton(),
        error: (e, _) =>
            AdminError(e, onRetry: () => ref.invalidate(adminUsersProvider)),
        data: (rows) => AdminTable<Json>(
          rows: rows,
          empty: 'Хэрэглэгч олдсонгүй',
          columns: [
            AdminColumn('Нэр', (u) => cellText(jStr(u, 'name'), bold: true),
                flex: 3),
            AdminColumn('Утас', (u) => cellText(jStr(u, 'phone'), num: true),
                flex: 2),
            AdminColumn(
                'Эрх',
                (u) => cellText(fmtInt(jInt(jMap(u, 'wallet'), 'balance')),
                    num: true),
                right: true),
            AdminColumn(
                'Төлөв',
                (u) => Wrap(spacing: 6, children: [
                      pillFor(jStr(u, 'status')),
                      if (jStr(u, 'role') == 'admin')
                        const StatusPill('Админ', tone: PillTone.blue),
                    ]),
                flex: 2),
            AdminColumn('Бүртгүүлсэн',
                (u) => cellText(fmtDate(u['createdAt']), num: true),
                flex: 2),
            AdminColumn(
              '',
              (u) => Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Эрх нэмэх/хасах',
                  icon: const Icon(LucideIcons.gem, size: 16),
                  onPressed: () => _adjust(context, ref, u),
                ),
                if (jStr(u, 'role') != 'admin')
                  IconButton(
                    tooltip:
                        jStr(u, 'status') == 'banned' ? 'Сэргээх' : 'Хориглох',
                    icon: Icon(
                        jStr(u, 'status') == 'banned'
                            ? LucideIcons.userCheck
                            : LucideIcons.userX,
                        size: 16,
                        color: jStr(u, 'status') == 'banned'
                            ? AdminColors.accentDark
                            : AdminColors.red),
                    onPressed: () => _ban(context, ref, u),
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

class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.name});
  final String name;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_amount.text.trim());
    if (n == null || n == 0) {
      setState(() => _err = '0-ээс өөр бүхэл тоо бичнэ үү (хасахдаа -)');
      return;
    }
    final note = _note.text.trim();
    if (note.isEmpty) {
      setState(() => _err = 'Тайлбараа бичнэ үү');
      return;
    }
    Navigator.pop(context, (n, note));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.name}: эрх тохируулах',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FieldLabel(
              'Тоо',
              hint: 'Нэмэхэд 50, хасахад -50',
              child: TextField(
                controller: _amount,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
              ),
            ),
            FieldLabel('Тайлбар',
                child: TextField(controller: _note, maxLength: 200)),
            if (_err != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_err!,
                    style:
                        const TextStyle(fontSize: 12, color: AdminColors.red)),
              ),
          ]),
        ),
        actions: [
          AdminButton('Болих', onPressed: () => Navigator.pop(context)),
          AdminButton('Үргэлжлүүлэх',
              kind: BtnKind.primary, onPressed: _submit),
        ],
      );
}
