import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'admin_api.dart';
import 'admin_auction_form.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

final _aucStatusProvider = StateProvider.autoDispose<String>((ref) => '');
final _aucQueryProvider = StateProvider.autoDispose<String>((ref) => '');

const _aucFilters = [
  ('', 'Бүгд'),
  ('draft', 'Ноорог'),
  ('scheduled', 'Товлогдсон'),
  ('live', 'Явагдаж буй'),
  ('ended', 'Дууссан'),
  ('settled', 'Шийдвэрлэсэн'),
  ('cancelled', 'Цуцлагдсан'),
];

/// Дуудлага худалдаа: жагсаалт, шүүлтүүр, үүсгэх/засах, нийтлэх/цуцлах.
class AdminAuctionsScreen extends ConsumerWidget {
  const AdminAuctionsScreen({super.key});

  Future<void> _openForm(BuildContext context, WidgetRef ref, [Json? a]) async {
    await showAdminPanel<void>(
      context,
      title: a == null ? 'Шинэ дуудлага' : 'Дуудлага засах',
      width: 680,
      child: AuctionForm(initial: a),
    );
    ref.invalidate(adminAuctionsProvider);
  }

  Future<void> _publish(BuildContext context, WidgetRef ref, Json a) async {
    final yes = await confirmDialog(context,
        title: 'Нийтлэх үү?',
        message:
            '"${jStr(a, 'title')}" хэрэглэгчдэд харагдаж, хуваарийн дагуу эхэлнэ.',
        confirmLabel: 'Нийтлэх');
    if (!yes || !context.mounted) return;
    final ok = await runAdminAction(
        context, () => ref.read(adminApiProvider).publishAuction(jStr(a, 'id')),
        success: 'Нийтэллээ');
    if (ok) ref.invalidate(adminAuctionsProvider);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Json a) async {
    final yes = await confirmDialog(context,
        title: 'Цуцлах уу?',
        message: '"${jStr(a, 'title')}" дуудлагыг цуцална. Буцаах боломжгүй.',
        confirmLabel: 'Цуцлах',
        danger: true);
    if (!yes || !context.mounted) return;
    final ok = await runAdminAction(
        context, () => ref.read(adminApiProvider).cancelAuction(jStr(a, 'id')),
        success: 'Цуцаллаа');
    if (ok) ref.invalidate(adminAuctionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(_aucStatusProvider);
    final q = ref.watch(_aucQueryProvider).toLowerCase();
    final list = ref.watch(adminAuctionsProvider(status));
    return AdminPage(children: [
      AdminPageHeader(
        title: 'Дуудлага худалдаа',
        subtitle: 'Сүүлд үүссэн 200 хүртэл дуудлага',
        actions: [
          AdminSearchField(
            hint: 'Нэрээр хайх',
            onChanged: (v) =>
                ref.read(_aucQueryProvider.notifier).state = v.trim(),
          ),
          AdminButton('Шинэ дуудлага',
              icon: LucideIcons.plus,
              kind: BtnKind.primary,
              onPressed: () => _openForm(context, ref)),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AdminSegments<String>(
            options: _aucFilters,
            value: status,
            onChanged: (v) => ref.read(_aucStatusProvider.notifier).state = v,
          ),
        ),
      ),
      list.when(
        skipLoadingOnRefresh: true,
        loading: () => const AdminListSkeleton(),
        error: (e, _) =>
            AdminError(e, onRetry: () => ref.invalidate(adminAuctionsProvider)),
        data: (all) {
          final rows = q.isEmpty
              ? all
              : all
                  .where((a) => jStr(a, 'title').toLowerCase().contains(q))
                  .toList();
          return AdminTable<Json>(
            rows: rows,
            empty: 'Дуудлага олдсонгүй',
            columns: [
              AdminColumn('Нэр', (a) => cellText(jStr(a, 'title'), bold: true),
                  flex: 4),
              AdminColumn(
                  'Ангилал',
                  (a) => cellText(jStr(a, 'categoryName').isEmpty
                      ? '—'
                      : jStr(a, 'categoryName')),
                  flex: 2),
              AdminColumn('Төлөв', (a) => pillFor(jStr(a, 'status')), flex: 2),
              AdminColumn(
                  'Эхлэх', (a) => cellText(fmtDate(a['startsAt']), num: true),
                  flex: 2),
              AdminColumn(
                  'Дуусах', (a) => cellText(fmtDate(a['endsAt']), num: true),
                  flex: 2),
              AdminColumn('Үнэ',
                  (a) => cellText(fmtMnt(jInt(a, 'currentPrice')), num: true),
                  right: true),
              AdminColumn('Санал',
                  (a) => cellText(fmtInt(jInt(a, 'bidCount')), num: true),
                  right: true),
              AdminColumn('', (a) {
                final s = jStr(a, 'status');
                return Wrap(spacing: 4, children: [
                  if (s == 'draft')
                    IconButton(
                      tooltip: 'Засах',
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      onPressed: () => _openForm(context, ref, a),
                    ),
                  if (s == 'draft')
                    IconButton(
                      tooltip: 'Нийтлэх',
                      icon: const Icon(LucideIcons.send,
                          size: 16, color: AdminColors.accentDark),
                      onPressed: () => _publish(context, ref, a),
                    ),
                  if (const ['draft', 'scheduled', 'live'].contains(s))
                    IconButton(
                      tooltip: 'Цуцлах',
                      icon: const Icon(LucideIcons.ban,
                          size: 16, color: AdminColors.red),
                      onPressed: () => _cancel(context, ref, a),
                    ),
                ]);
              }, flex: 2, right: true),
            ],
          );
        },
      ),
    ]);
  }
}
