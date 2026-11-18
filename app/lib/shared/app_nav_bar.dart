import 'dart:math' as math;
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

/// Saturation-ыг [s] дахин нэмэгдүүлэх өнгөний матриц — шилэн материалын ард
/// байгаа агуулга бүдгэрэхгүй, харин "амьд" өнгөтэй хэвээр харагдана.
ColorFilter _saturation(double s) => ColorFilter.matrix(<double>[
      0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
      0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
      0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
      0, 0, 0, 1, 0,
    ]);

/// Шилэн материалын хүрээ — зүүн дээд тал тод, баруун доод тал бараг үл
/// харагдах 1px gradient (specular rim).
class _RimPainter extends CustomPainter {
  const _RimPainter({required this.radius, required this.dark});

  final double radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: dark ? 0.35 : 0.80),
          Colors.white.withValues(alpha: dark ? 0.04 : 0.10),
          Colors.white.withValues(alpha: dark ? 0.10 : 0.25),
        ],
        stops: const [0, 0.6, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius || old.dark != dark;
}

/// iOS 26 "Liquid Glass" материал — бага blur (sigma 5) + saturation 1.7,
/// тунгалаг дүүргэлт, specular хүрээ, дээд ирмэгийн highlight, зөөлөн сүүдэр.
class _Glass extends StatelessWidget {
  const _Glass({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final fill = dark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.34);
    final highlight = Colors.white.withValues(alpha: dark ? 0.30 : 0.70);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.30 : 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.compose(
            outer: _saturation(1.7),
            inner: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Stack(
              children: [
                child,
                // Дээд ирмэгийн дотоод гэрэл
                Positioned(
                  top: 1,
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
                // Specular хүрээ
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                        painter: _RimPainter(radius: radius, dark: dark)),
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
    final dark = AppColors.isDark;
    final pillFill = dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.55);
    final pillRim = Colors.white.withValues(alpha: dark ? 0.16 : 0.45);
    return SizedBox(
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
                        border: Border.all(color: pillRim, width: 0.5),
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
    );
  }
}

/// Доод навигаци — Apple Music (iOS 26) маягийн хөвөгч шилэн капсул.
/// Өргөн: хажуу тал 16, доод = safe area + 8.
///
/// [collapsed] үед (агуулгыг доош гүйлгэхэд) зүүн доод буланд зөвхөн идэвхтэй
/// табын icon-той жижиг капсул болж хураагдана; дарвал [onExpand] дуудагдана.
class AppNavBar extends StatefulWidget {
  const AppNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    this.collapsed = false,
    this.onExpand,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool collapsed;
  final VoidCallback? onExpand;

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar>
    with SingleTickerProviderStateMixin {
  static const _collapsedWidth = 56.0;
  static const _collapsedHeight = 48.0;

  /// 0 = бүтэн капсул, 1 = хураагдсан.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: widget.collapsed ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant AppNavBar old) {
    super.didUpdateWidget(old);
    if (old.collapsed != widget.collapsed) {
      final target = widget.collapsed ? 1.0 : 0.0;
      if (reducedMotion(context)) {
        _c.value = target;
      } else {
        _c.animateTo(target, curve: Curves.easeOutCubic);
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
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // Слотын өндөр тогтмол — хураагдахад агуулгын padding үсрэхгүй.
    return SizedBox(
      height: NavMetrics.barHeight + NavMetrics.bottomGap + bottomSafe,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(16, 0, 16, NavMetrics.bottomGap + bottomSafe),
        child: LayoutBuilder(
          builder: (context, box) {
            final full = math.min(box.maxWidth, 480.0);
            return AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                final width = full + (_collapsedWidth - full) * t;
                final height = NavMetrics.barHeight +
                    (_collapsedHeight - NavMetrics.barHeight) * t;
                final left = (box.maxWidth - full) / 2 * (1 - t);
                final radius = 32 - 8 * t;
                final dest = widget.destinations[widget.currentIndex];
                // Бусад icon/шошго эхэлж бүдгэрч, жижиг icon дараа нь орж ирнэ.
                final fullOpacity = (1 - t * 1.6).clamp(0.0, 1.0);
                final miniOpacity = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
                return Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: left),
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: _Glass(
                        radius: radius,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (fullOpacity > 0)
                              IgnorePointer(
                                ignoring: widget.collapsed,
                                child: Opacity(
                                  opacity: fullOpacity,
                                  child: Transform.scale(
                                    alignment: Alignment.centerLeft,
                                    scale: 1 - 0.12 * t,
                                    child: OverflowBox(
                                      alignment: Alignment.centerLeft,
                                      minWidth: full,
                                      maxWidth: full,
                                      minHeight: NavMetrics.barHeight,
                                      maxHeight: NavMetrics.barHeight,
                                      child: _GlassTabs(
                                        destinations: widget.destinations,
                                        currentIndex: widget.currentIndex,
                                        onSelected: widget.onSelected,
                                        radius: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (miniOpacity > 0)
                              Opacity(
                                opacity: miniOpacity,
                                child: Semantics(
                                  button: true,
                                  label: dest.label,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: widget.collapsed
                                        ? () {
                                            HapticFeedback.selectionClick();
                                            widget.onExpand?.call();
                                          }
                                        : null,
                                    child: Center(
                                      child: Transform.scale(
                                        scale: 0.8 + 0.2 * t,
                                        child: Icon(dest.icon,
                                            size: 24, color: AppColors.accent),
                                      ),
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
              },
            );
          },
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
                _Glass(
                  radius: 26,
                  child: _GlassTabs(
                    destinations: destinations,
                    currentIndex: currentIndex,
                    onSelected: onSelected,
                    radius: 26,
                    horizontal: true,
                  ),
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
