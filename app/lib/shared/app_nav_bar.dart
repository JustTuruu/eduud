import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import 'widgets.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Доод навигаци.
///
/// Идэвхтэй байдлыг **гулсдаг градиент дэвсгэр**-ээр илэрхийлнэ — хаанаас
/// хаашаа шилжсэнийг нүд дагаж чадна. Icon нь сонгогдох агшинд нэг удаа
/// пүршин үсэрнэ. Шошго үргэлж харагдана (icon дангаараа таагдахгүй).
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
    final count = destinations.length;
    final calm = reducedMotion(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Stack(
                  children: [
                    // Гулсагч дэвсгэр
                    AnimatedAlign(
                      alignment: Alignment(
                        count <= 1 ? 0 : -1 + 2 * currentIndex / (count - 1),
                        0,
                      ),
                      duration: calm ? Duration.zero : AppMotion.base,
                      curve: AppMotion.spring,
                      child: FractionallySizedBox(
                        widthFactor: 1 / count,
                        // heightFactor-гүй бол хүүхэд DecoratedBox нь агуулгагүй
                        // учраас 0 өндөртэй болж дэвсгэр огт харагдахгүй.
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 7),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.ctaGradient,
                              borderRadius: BorderRadius.circular(19),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.sapphire.withValues(alpha: 0.42),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                                // Аврорагийн зөөлөн туяа — сонгогдсон таб "амьд" гэрэлтэнэ.
                                BoxShadow(
                                  color:
                                      AppColors.lavender.withValues(alpha: 0.16),
                                  blurRadius: 30,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(count, (i) {
                        final d = destinations[i];
                        final selected = i == currentIndex;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: selected,
                            label: d.label,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onSelected(i);
                              },
                              borderRadius: BorderRadius.circular(19),
                              splashColor: Colors.white.withValues(alpha: 0.06),
                              highlightColor: Colors.transparent,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _BouncyIcon(
                                    icon: d.icon,
                                    selected: selected,
                                    calm: calm,
                                  ),
                                  const SizedBox(height: 3),
                                  AnimatedDefaultTextStyle(
                                    duration: AppMotion.fast,
                                    curve: AppMotion.enter,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : AppColors.muted,
                                    ),
                                    child: Text(d.label),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
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

/// Сонгогдох агшинд нэг удаа пүршин үсэрдэг icon.
class _BouncyIcon extends StatelessWidget {
  const _BouncyIcon({
    required this.icon,
    required this.selected,
    required this.calm,
  });

  final IconData icon;
  final bool selected;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    final child = Icon(
      icon,
      size: 21,
      color: selected ? Colors.white : AppColors.muted,
    );

    if (!selected || calm) return child;

    // key нь сонголт солигдох бүрд шинэчлэгдэж, хөдөлгөөнийг дахин эхлүүлнэ.
    return TweenAnimationBuilder<double>(
      key: ValueKey(icon),
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: Curves.elasticOut,
      builder: (context, scale, c) => Transform.scale(scale: scale, child: c),
      child: child,
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
