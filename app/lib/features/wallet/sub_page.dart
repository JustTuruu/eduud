import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';

/// Профайлаас push хийсэн дэлгэцүүдийн дээд хэсэг: буцах товч + гарчиг.
/// Web дээр шууд холбоосоор орсон бол буцах түүх байхгүй тул [fallback] руу очно.
class SubPageHeader extends StatelessWidget {
  const SubPageHeader({
    super.key,
    required this.title,
    this.fallback = '/profile',
  });

  final String title;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Буцах',
          child: AnimatedPressable(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(fallback),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceHi.withValues(alpha: 0.7),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(LucideIcons.chevronLeft,
                  size: 22, color: AppColors.ink),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
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

/// Хэсгийн гарчиг — 13/700, жижиг үсэг, зай тавьсан.
class PlainLabel extends StatelessWidget {
  const PlainLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft));
  }
}
