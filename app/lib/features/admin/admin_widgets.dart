import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import 'admin_theme.dart';

const double kAdminWide = 900;

bool adminIsWide(BuildContext c) => MediaQuery.sizeOf(c).width >= kAdminWide;

// ---------- Карт ----------

/// Саарал (#F5F5F7) дэвсгэртэй, нимгэн хүрээтэй самбар.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
    required this.child,
  });

  final String? title, subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            LayoutBuilder(builder: (context, c) {
              final head = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title!,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 12, color: AdminColors.muted)),
                    ),
                ],
              );
              if (trailing == null) return head;
              // Нарийн дээр тайлбар (legend, төлөв) гарчгийн доор буудаг.
              if (c.maxWidth < 480) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [head, const SizedBox(height: 10), trailing!]);
              }
              return Row(children: [Expanded(child: head), trailing!]);
            }),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Хянах самбарын үзүүлэлтийн карт: гарчиг, том тоо, жижиг тайлбар.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.icon,
    this.onTap,
  });

  final String label, value;
  final String? sub;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 118,
        child: Material(
          color: AdminColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AdminColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: AdminColors.muted),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(label,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 13, color: AdminColors.muted)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: adminNumber(size: 30, weight: FontWeight.w600)
                            .copyWith(letterSpacing: -0.8, height: 1.1)),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(sub ?? ' ',
                        maxLines: 1,
                        style: adminNumber(size: 12, color: AdminColors.muted)),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}

// ---------- Pill ----------

enum PillTone { green, blue, orange, red, gray }

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.gray});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.green => (AdminColors.accentSoft, AdminColors.accentDark),
      PillTone.blue => (AdminColors.blueSoft, const Color(0xFF0060C7)),
      PillTone.orange => (AdminColors.orangeSoft, AdminColors.orange),
      PillTone.red => (AdminColors.redSoft, AdminColors.red),
      PillTone.gray => (AdminColors.graySoft, AdminColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

/// Backend-ийн төлөвийн нэрийг монгол нэр, өнгө болгоно.
StatusPill pillFor(String status) {
  final (label, tone) = switch (status) {
    'live' => ('Явагдаж байна', PillTone.green),
    'scheduled' => ('Товлогдсон', PillTone.blue),
    'draft' => ('Ноорог', PillTone.gray),
    'ended' => ('Дууссан', PillTone.orange),
    'settled' => ('Шийдвэрлэсэн', PillTone.gray),
    'cancelled' => ('Цуцлагдсан', PillTone.red),
    'pending' => ('Шинэ', PillTone.orange),
    'reviewing' => ('Хянаж байна', PillTone.blue),
    'info_requested' => ('Мэдээлэл хүссэн', PillTone.orange),
    'approved' => ('Зөвшөөрсөн', PillTone.green),
    'rejected' => ('Татгалзсан', PillTone.red),
    'paid' => ('Төлсөн', PillTone.green),
    'expired' => ('Хугацаа дууссан', PillTone.red),
    'failed' => ('Амжилтгүй', PillTone.red),
    'open' => ('Нээлттэй', PillTone.orange),
    'resolved' => ('Шийдсэн', PillTone.green),
    'closed' => ('Хаасан', PillTone.gray),
    'active' => ('Идэвхтэй', PillTone.green),
    'banned' => ('Хориглосон', PillTone.red),
    'preparing' => ('Бэлтгэж буй', PillTone.blue),
    'shipped' => ('Хүргэлтэд гарсан', PillTone.blue),
    'delivered' => ('Хүргэгдсэн', PillTone.green),
    _ => (status.isEmpty ? '—' : status, PillTone.gray),
  };
  return StatusPill(label, tone: tone);
}

// ---------- Хуудасны толгой ----------

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(subtitle!,
                style: const TextStyle(fontSize: 13, color: AdminColors.muted)),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: adminIsWide(context)
          ? Row(children: [
              Expanded(child: head),
              ...actions.expand((a) => [const SizedBox(width: 8), a]),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              head,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ]),
    );
  }
}

// ---------- Товч ----------

enum BtnKind { primary, outline, danger }

class AdminButton extends StatelessWidget {
  const AdminButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.kind = BtnKind.outline,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BtnKind kind;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (kind) {
      BtnKind.primary => (AdminColors.ink, Colors.white, AdminColors.ink),
      BtnKind.danger => (AdminColors.bg, AdminColors.red, AdminColors.border),
      BtnKind.outline => (AdminColors.bg, AdminColors.ink, AdminColors.border),
    };
    final disabled = onPressed == null || busy;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: side),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else if (icon != null)
                Icon(icon, size: 15, color: fg),
              if (busy || icon != null) const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------- Шүүлтүүр ----------

/// Цөөн сонголттой (7/14/30/90, төлөв гэх мэт) segmented шүүлтүүр.
class AdminSegments<T> extends StatelessWidget {
  const AdminSegments({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AdminColors.border),
      ),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final (v, label) in options)
            GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: v == value ? AdminColors.bg : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color:
                          v == value ? AdminColors.border : Colors.transparent),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            v == value ? FontWeight.w600 : FontWeight.w400,
                        color:
                            v == value ? AdminColors.ink : AdminColors.muted)),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Хайх',
    this.width = 260,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(LucideIcons.search,
              size: 16, color: AdminColors.faint),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
        ),
      ),
    );
  }
}

// ---------- Хүснэгт ----------

class AdminColumn<T> {
  const AdminColumn(
    this.label,
    this.cell, {
    this.flex = 1,
    this.right = false,
  });

  final String label;
  final Widget Function(T row) cell;
  final int flex;
  final bool right;
}

/// Өргөн дэлгэц дээр хүснэгт, нарийн дээр мөр бүр нэг карт болно
/// (эхний багана гарчиг, бусад нь "нэр: утга").
class AdminTable<T> extends StatelessWidget {
  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onTap,
    this.empty = 'Мэдээлэл алга',
    this.compactBelow = 700,
  });

  final List<AdminColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onTap;
  final String empty;
  final double compactBelow;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return AdminEmpty(empty);
    final compact = MediaQuery.sizeOf(context).width < compactBelow;
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        if (!compact)
          Container(
            color: AdminColors.panel,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              for (final c in columns)
                Expanded(
                  flex: c.flex,
                  child: Text(c.label,
                      textAlign: c.right ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AdminColors.muted)),
                ),
            ]),
          ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0 || !compact) const Divider(),
          InkWell(
            onTap: onTap == null ? null : () => onTap!(rows[i]),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: compact ? 12 : 11),
              child: compact ? _compactRow(rows[i]) : _wideRow(rows[i]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _wideRow(T r) => Row(children: [
        for (final c in columns)
          Expanded(
            flex: c.flex,
            child: Align(
              alignment: c.right ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: c.cell(r),
              ),
            ),
          ),
      ]);

  Widget _compactRow(T r) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          columns.first.cell(r),
          const SizedBox(height: 6),
          for (final c in columns.skip(1))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                SizedBox(
                  width: 96,
                  child: Text(c.label,
                      style: const TextStyle(
                          fontSize: 12, color: AdminColors.muted)),
                ),
                Expanded(
                  child:
                      Align(alignment: Alignment.centerLeft, child: c.cell(r)),
                ),
              ]),
            ),
        ],
      );
}

/// Хүснэгтийн энгийн текст нүд.
Widget cellText(String s,
        {bool bold = false, Color? color, bool num = false}) =>
    Text(s,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: (num ? adminNumber(size: 13) : const TextStyle(fontSize: 13))
            .copyWith(
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: color ?? AdminColors.ink,
        ));

// ---------- Төлөв ----------

class AdminEmpty extends StatelessWidget {
  const AdminEmpty(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        decoration: BoxDecoration(
          color: AdminColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(children: [
          const Icon(LucideIcons.inbox, size: 26, color: AdminColors.faint),
          const SizedBox(height: 10),
          Text(text,
              style: const TextStyle(fontSize: 14, color: AdminColors.muted)),
        ]),
      );
}

class AdminError extends StatelessWidget {
  const AdminError(this.error, {super.key, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        decoration: BoxDecoration(
          color: AdminColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(children: [
          const Icon(LucideIcons.circleAlert, size: 26, color: AdminColors.red),
          const SizedBox(height: 10),
          Text(apiErrorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AdminColors.muted)),
          const SizedBox(height: 14),
          AdminButton('Дахин оролдох',
              icon: LucideIcons.refreshCw, onPressed: onRetry),
        ]),
      );
}

/// Ачаалж байх үеийн саарал хайрцаг (зөөлөн анивчина).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width});
  final double height;
  final double? width;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color:
                Color.lerp(AdminColors.graySoft, AdminColors.border, _c.value),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
}

/// Жагсаалтын ачаалж буй хэсэг.
class AdminListSkeleton extends StatelessWidget {
  const AdminListSkeleton({super.key, this.rows = 6});
  final int rows;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Skeleton(height: 44),
          ),
      ]);
}

// ---------- Dialog / panel ----------

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Тийм',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      content: message == null
          ? null
          : Text(message,
              style: const TextStyle(fontSize: 14, color: AdminColors.muted)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        AdminButton('Болих', onPressed: () => Navigator.pop(ctx, false)),
        AdminButton(confirmLabel,
            kind: danger ? BtnKind.danger : BtnKind.primary,
            onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return ok == true;
}

/// Өргөн дэлгэц дээр баруун талаас гарах самбар, утсан дээр доороос
/// бүтэн өндөртэй sheet.
Future<T?> showAdminPanel<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  double width = 460,
}) {
  final wide = adminIsWide(context);
  Widget body(BuildContext ctx) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
          child: Row(children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () => Navigator.pop(ctx),
            ),
          ]),
        ),
        const Divider(),
        Expanded(child: child),
      ]);
  if (wide) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Хаах',
      barrierColor: const Color(0x33000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: AdminColors.bg,
          child: Container(
            width: width,
            height: double.infinity,
            decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AdminColors.border))),
            child: body(ctx),
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, c) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(anim),
        child: c,
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AdminColors.bg,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.92,
      child: body(ctx),
    ),
  );
}

// ---------- Мэдэгдэл ----------

void adminToast(BuildContext context, String msg) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Үйлдлийг ажиллуулж, алдааг монгол мессежээр харуулна. Амжилттай бол true.
Future<bool> runAdminAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) adminToast(context, success);
    return true;
  } catch (e) {
    if (context.mounted) adminToast(context, apiErrorMessage(e));
    return false;
  }
}

/// Формын нэг талбар: гарчигтай оролт.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key, required this.child, this.hint});
  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AdminColors.muted)),
            const SizedBox(height: 6),
            child,
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(hint!,
                    style: const TextStyle(
                        fontSize: 12, color: AdminColors.faint)),
              ),
          ],
        ),
      );
}

/// Хуудасны агуулга: гүйлгэгддэг, дээд талдаа 1280px хүртэл төвлөрнө.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pad = adminIsWide(context) ? 28.0 : 16.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 48),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}
