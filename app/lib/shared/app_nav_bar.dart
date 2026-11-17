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
  static const bottomGap = 16.0;

  /// Өргөн дэлгэцийн дээд навын өндөр (SafeArea-гүй) — агуулга дээд padding-д нэмнэ.
  static const topHeight = 84.0;

  static double bottomInset(BuildContext context) =>
      barHeight + bottomGap + 16 + MediaQuery.paddingOf(context).bottom;
}

/// Шилэн хөвөгч гадаргуу — nav-ын цорын ганц blur (функциональ).
class _Glass extends StatelessWidget {
  const _Glass({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.borderHi),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Доод навигаци — Apple Music маягийн хөвөгч шилэн капсул.
///
/// Идэвхтэй таб: шүрэн pill пүршин (spring) хөдөлгөөнөөр гулсана, icon нэг
/// удаа үсэрч шүрэн болно, шошго жин нэмнэ. Таб бүр шошготой.
class AppNavBar extends StatefulWidget {
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
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar>
    with SingleTickerProviderStateMixin {
  static const _spring =
      SpringDescription(mass: 1, stiffness: 320, damping: 26);

  late final AnimationController _pos = AnimationController.unbounded(
      vsync: this, value: widget.currentIndex.toDouble());

  @override
  void didUpdateWidget(covariant AppNavBar old) {
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        NavMetrics.bottomGap + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _Glass(
            radius: 30,
            child: SizedBox(
              height: NavMetrics.barHeight,
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = (box.maxWidth - 12) / count;
                  return Padding(
                    padding: const EdgeInsets.all(6),
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
                                color: AppColors.coral.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: AppColors.coral
                                        .withValues(alpha: 0.28)),
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
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  /// Icon нэг удаа үсрэх: 1 → 1.22 → 1.
  late final AnimationController _bounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(covariant _NavItem old) {
    super.didUpdateWidget(old);
    if (!old.selected && widget.selected && !reducedMotion(context)) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? AppColors.coral : AppColors.muted;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _bounce,
              builder: (context, child) {
                final t = _bounce.value;
                final scale = 1 + 0.22 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                return Transform.scale(scale: scale, child: child);
              },
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: AppMotion.fast,
                builder: (context, c, _) =>
                    Icon(widget.destination.icon, size: 22, color: c),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                color: widget.selected ? AppColors.ink : AppColors.muted,
              ),
              child: Text(widget.destination.label, maxLines: 1),
            ),
          ],
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

/// Өргөн дэлгэц (web/desktop) дээрх дээд навигац — ижил ертөнц: дээр нь
/// хөвөх шилэн капсул, доод навтай яг ижил 3 чиглэл + token chip.
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
    final display = Theme.of(context).textTheme.displayMedium;
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: _Glass(
              radius: 30,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Wordmark(size: 20, display: display),
                    const SizedBox(width: 32),
                    ...List.generate(destinations.length, (i) {
                      final d = destinations[i];
                      final selected = i == currentIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: AnimatedPressable(
                          onPressed: () => onSelected(i),
                          scale: 0.96,
                          child: AnimatedContainer(
                            duration: AppMotion.base,
                            curve: AppMotion.enter,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.coral.withValues(alpha: 0.16)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected
                                    ? AppColors.coral.withValues(alpha: 0.28)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(children: [
                              Icon(d.icon,
                                  size: 17,
                                  color: selected
                                      ? AppColors.coral
                                      : AppColors.muted),
                              const SizedBox(width: 8),
                              Text(
                                d.label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: selected
                                      ? AppColors.ink
                                      : AppColors.muted,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      );
                    }),
                    const Spacer(),
                    if (trailing != null) trailing!,
                    const SizedBox(width: 4),
                  ],
                ),
              ),
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
