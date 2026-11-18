import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';

/// Профайлаас push хийсэн дэлгэцүүдийн стандарт дээд мөр: буцах сум + гарчиг.
/// Web дээр шууд холбоосоор орсон бол буцах түүх байхгүй тул [fallback] руу очно.
PreferredSizeWidget subPageAppBar(
  BuildContext context,
  String title, {
  String fallback = '/profile',
}) {
  return AppBar(
    centerTitle: true,
    leading: Semantics(
      button: true,
      label: 'Буцах',
      child: IconButton(
        icon: Icon(LucideIcons.chevronLeft, size: 28, color: AppColors.accent),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(fallback),
      ),
    ),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

/// iOS Settings маягийн өнгөт дөрвөлжин icon (29px, радиус 7, цагаан дүрс).
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 17, color: Colors.white),
    );
  }
}

/// Бүлэглэсэн жагсаалт — карт (радиус 16), мөр хоорондын 0.5px хуваагч.
/// [dividerInset] нь хуваагчийн зүүн талын зай (icon-ийн дараа эхэлнэ).
class GroupSection extends StatelessWidget {
  const GroupSection({
    super.key,
    required this.children,
    this.title,
    this.footer,
    this.dividerInset = 16,
  });

  final List<Widget> children;
  final String? title;
  final String? footer;
  final double dividerInset;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(title!,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            color: AppColors.surface,
            child: Column(children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.only(left: dividerInset),
                    child: Container(height: 0.5, color: AppColors.borderHi),
                  ),
                children[i],
              ],
            ]),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(footer!, style: muted),
          ),
      ],
    );
  }
}

/// Бүлгийн мөр: [leading] + гарчиг (+ тайлбар) + [trailing] (+ сум).
class GroupRow extends StatelessWidget {
  const GroupRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.minHeight = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final String title;
  final Widget? leading;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      color: Colors.transparent,
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: AppColors.ink)),
              if (subtitle != null)
                Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ],
          ),
        ),
        if (value != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, color: AppColors.muted)),
            ),
          ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (onTap != null && chevron) ...[
          const SizedBox(width: 6),
          Icon(LucideIcons.chevronRight, size: 18, color: AppColors.borderHi),
        ],
      ]),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: title,
      child: AnimatedPressable(onPressed: onTap, scale: 0.99, child: row),
    );
  }
}

/// Дэлгэц нээгдэхэд хэсгүүд нэг нэгээрээ дээш хөөрч гарч ирнэ — дэлгэц
/// бүрийн цорын ганц зохион байгуулалттай хөдөлгөөн. Reduced motion үед шууд.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.slow);
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reducedMotion(context)) {
      _c.value = 1;
      return;
    }
    _delay = Timer(AppMotion.stagger * widget.index.clamp(0, 8), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: AppMotion.fluid);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Хэсгийн гарчиг — 13/600, энгийн жижиг үсэг.
class PlainLabel extends StatelessWidget {
  const PlainLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted));
  }
}
