import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import 'widgets.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Хөвөгч шилэн навигацийн өндөр (margin-тай) — дэлгэцүүд доод padding-даа
/// үүнийг нэмж агуулгыг нав дарахаас сэргийлнэ.
abstract class NavMetrics {
  static const barHeight = 64.0;
  static const bottomGap = 8.0;

  /// Өргөн дэлгэцийн дээд навын өндөр (SafeArea-гүй) — агуулга дээд padding-д нэмнэ.
  static const topHeight = 84.0;

  static double bottomInset(BuildContext context) =>
      barHeight + bottomGap + 16 + MediaQuery.paddingOf(context).bottom;
}

/// iOS 26 "Liquid Glass" капсул — blur 24, хагас тунгалаг дүүргэлт, нимгэн
/// гэрэлтсэн хүрээ, дээд ирмэгийн highlight, зөөлөн сүүдэр.
class _Glass extends StatelessWidget {
  const _Glass({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final fill = dark
        ? const Color(0xFF2C2C2E).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.72);
    final rim = Colors.white.withValues(alpha: dark ? 0.14 : 0.50);
    final highlight = Colors.white.withValues(alpha: dark ? 0.22 : 0.85);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.25 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: rim),
            ),
            child: Stack(
              children: [
                child,
                // Дээд ирмэгийн дотоод гэрэл
                Positioned(
                  top: 0,
                  left: radius * 0.6,
                  right: radius * 0.6,
                  height: 1,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          highlight.withValues(alpha: 0),
                          highlight,
                          highlight.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Шилэн капсул доторх таб мөр: идэвхтэй таб дотор цайвар шилэн pill пүршин
/// (spring) хөдөлгөөнээр гулсана. [horizontal] үед icon+шошго нэг мөрөнд
/// (өргөн дэлгэцийн дээд нав), үгүй бол icon дээр, шошго доор (доод нав).
class _GlassTabs extends StatefulWidget {
  const _GlassTabs({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    required this.radius,
    this.horizontal = false,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final double radius;
  final bool horizontal;

  @override
  State<_GlassTabs> createState() => _GlassTabsState();
}

class _GlassTabsState extends State<_GlassTabs>
    with SingleTickerProviderStateMixin {
  static const _spring =
      SpringDescription(mass: 1, stiffness: 320, damping: 26);
  static const _inset = 6.0;

  late final AnimationController _pos = AnimationController.unbounded(
      vsync: this, value: widget.currentIndex.toDouble());

  @override
  void didUpdateWidget(covariant _GlassTabs old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      if (reducedMotion(context)) {
        _pos.value = widget.currentIndex.toDouble();
      } else {
        _pos.animateWith(SpringSimulation(
          _spring,
          _pos.value,
          widget.currentIndex.toDouble(),
          _pos.velocity,
        ));
      }
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.destinations.length;
    final pillFill = AppColors.isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.90);
    return _Glass(
      radius: widget.radius,
      child: SizedBox(
        height: widget.horizontal ? 52 : NavMetrics.barHeight,
        width: widget.horizontal ? count * 128.0 + _inset * 2 : null,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - _inset * 2) / count;
            return Padding(
              padding: const EdgeInsets.all(_inset),
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _pos,
                    builder: (context, _) => Positioned(
                      left: _pos.value * w,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: pillFill,
                          borderRadius:
                              BorderRadius.circular(widget.radius - _inset),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < count; i++)
                        Expanded(
                          child: _NavItem(
                            destination: widget.destinations[i],
                            selected: i == widget.currentIndex,
                            horizontal: widget.horizontal,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onSelected(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Доод навигаци — Apple Music (iOS 26) маягийн хөвөгч шилэн капсул.
/// Өргөн: хажуу тал 16, доод = safe area + 8.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        NavMetrics.bottomGap + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _GlassTabs(
            destinations: destinations,
            currentIndex: currentIndex,
            onSelected: onSelected,
            radius: 32,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.horizontal,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool horizontal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Идэвхгүй = үндсэн текстийн ~85%, идэвхтэй = accent.
    final color =
        selected ? AppColors.accent : AppColors.ink.withValues(alpha: 0.85);
    final icon = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: AppMotion.fast,
      builder: (context, c, _) =>
          Icon(destination.icon, size: horizontal ? 20 : 24, color: c),
    );
    final label = AnimatedDefaultTextStyle(
      duration: AppMotion.fast,
      style: TextStyle(
        fontSize: horizontal ? 14 : 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      child: Text(destination.label, maxLines: 1),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: horizontal
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  icon,
                  const SizedBox(width: 6),
                  label,
                ])
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [icon, const SizedBox(height: 2), label],
                ),
        ),
      ),
    );
  }
}

/// Таб солигдоход агуулгыг зөөлөн оруулж ирнэ.
///
/// IndexedStack-ийг орлуулахгүй, зөвхөн дээрээс нь тунгалаг байдал/шилжилт
/// нэмнэ — тиймээс салбар бүрийн scroll болон төлөв хэвээр хадгалагдана.
class AnimatedShellBody extends StatefulWidget {
  const AnimatedShellBody({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<AnimatedShellBody> createState() => _AnimatedShellBodyState();
}

class _AnimatedShellBodyState extends State<AnimatedShellBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.base,
    value: 1,
  );

  /// Урагш шилжвэл баруунаас, ухарвал зүүнээс орж ирнэ.
  double _direction = 1;

  @override
  void didUpdateWidget(covariant AnimatedShellBody old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _direction = widget.index > old.index ? 1 : -1;
      if (reducedMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        if (_c.isCompleted) return child!;
        final t = AppMotion.fluid.transform(_c.value);
        return Opacity(
          opacity: 0.25 + 0.75 * t,
          child: Transform.translate(
            offset: Offset((1 - t) * 22 * _direction, 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Өргөн дэлгэц (web/desktop) дээрх дээд навигац — төвд нь доод навтай ижил
/// шилэн капсул (3 таб хэвтээ), зүүн талд wordmark, баруун талд token chip.
class AppTopNav extends StatelessWidget {
  const AppTopNav({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    this.trailing,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Баруун талд — жиш. token үлдэгдлийн chip.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wordmark(size: 20),
                  ),
                ),
                _GlassTabs(
                  destinations: destinations,
                  currentIndex: currentIndex,
                  onSelected: onSelected,
                  radius: 26,
                  horizontal: true,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// E-DUUD wordmark — нүүр, нэвтрэх, landing, дээд нав бүгд нэг хэлбэртэй.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 19, this.display, this.onTap});

  final double size;
  final TextStyle? display;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = (display ?? Theme.of(context).textTheme.displayMedium)
        ?.copyWith(fontSize: size);
    final mark = Text.rich(TextSpan(children: [
      TextSpan(text: 'E-', style: style),
      TextSpan(text: 'DUUD', style: style?.copyWith(color: AppColors.coral)),
    ]));
    if (onTap == null) return mark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: mark),
    );
  }
}
