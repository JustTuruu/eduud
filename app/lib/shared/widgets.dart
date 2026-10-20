import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';

final _mnt = NumberFormat('#,###', 'en');

String formatMnt(int amount) => '${_mnt.format(amount)}₮';

bool reducedMotion(BuildContext context) => MediaQuery.of(context).disableAnimations;

// ---------------------------------------------------------------------------
// Interaction primitives
// ---------------------------------------------------------------------------

/// Дарахад зөөлөн агшиж (0.97) буцдаг wrapper — бүх tappable элементийн
/// нэгдсэн press feedback. Хуруунд мэдрэгдэх зөөлөн haptic-тэй.
class AnimatedPressable extends StatefulWidget {
  const AnimatedPressable({
    super.key,
    required this.child,
    this.onPressed,
    this.scale = 0.97,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double scale;
  final bool haptic;

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _down && !reducedMotion(context) ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

class _HairlinePainter extends CustomPainter {
  _HairlinePainter({required this.radius, required this.gradient});

  final double radius;
  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _HairlinePainter old) =>
      old.radius != radius || old.gradient != gradient;
}

/// Premium карт: gradient гадаргуу + дээрээсээ туяарсан gradient hairline
/// хүрээ + зөөлөн сүүдэр. Дарахад агшина.
class GlowCard extends StatelessWidget {
  const GlowCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = AppRadius.card,
    this.glow = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final card = CustomPaint(
      foregroundPainter: _HairlinePainter(
        radius: radius,
        gradient: AppColors.hairlineGradient,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            if (glow)
              BoxShadow(
                color: AppColors.sapphire.withValues(alpha: 0.12),
                blurRadius: 40,
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
    if (onTap == null) return card;
    return AnimatedPressable(onPressed: onTap, scale: 0.98, child: card);
  }
}

/// Шилэн chip — зурган дээр тавихад blur хийж доод давхаргаа нэвт харуулна.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Гарын үсэг — эргэдэг опал цагираг.
///
/// Опал солонгорсон sweep gradient нь тайван хэмнэлээр эргэж, доторх
/// агуулгыг (countdown, үлдэгдэл, аватар) "амьд" мэт харагдуулна.
/// Хөдөлгөөн багасгах тохиргоотой үед эргэлгүй зогсоно.
class OpalRing extends StatefulWidget {
  const OpalRing({
    super.key,
    required this.size,
    required this.child,
    this.strokeWidth = 3.5,
    this.glow = true,
  });

  final double size;
  final Widget child;
  final double strokeWidth;
  final bool glow;

  @override
  State<OpalRing> createState() => _OpalRingState();
}

class _OpalRingState extends State<OpalRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.opalSpin);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !reducedMotion(context)) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => CustomPaint(
          painter: _OpalRingPainter(
            rotation: _c.value * 2 * math.pi,
            strokeWidth: widget.strokeWidth,
            glow: widget.glow,
          ),
          child: child,
        ),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

class _OpalRingPainter extends CustomPainter {
  _OpalRingPainter({
    required this.rotation,
    required this.strokeWidth,
    required this.glow,
  });

  final double rotation;
  final double strokeWidth;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final shader = AppColors.opalSweep.createShader(rect);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    if (glow) {
      // Цагирагийн ард уусдаг туяа — дэлгэцээс "гэрэлтэж" буй мэдрэмж.
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OpalRingPainter old) =>
      old.rotation != rotation ||
      old.strokeWidth != strokeWidth ||
      old.glow != glow;
}

/// Ambient дэвсгэр — опалын гурван туяа (нил ягаан, мажента, циан)
/// булангуудад маш удаан хөвж, дэлгэц бүрийг "амьсгалуулна".
class AppBackground extends StatefulWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 26));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !reducedMotion(context)) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value * 2 * math.pi;
                  return Stack(
                    children: [
                      Positioned(
                        top: -150 + math.sin(t) * 24,
                        left: -110 + math.cos(t) * 18,
                        child: const _Glow(
                            size: 400, color: AppColors.sapphire, alpha: 0.16),
                      ),
                      Positioned(
                        top: 140 + math.cos(t * 0.8 + 2.1) * 30,
                        right: -170 + math.sin(t * 0.8 + 2.1) * 20,
                        child: const _Glow(
                            size: 340, color: AppColors.lavender, alpha: 0.07),
                      ),
                      Positioned(
                        bottom: -170 + math.sin(t * 0.6 + 4.2) * 26,
                        left: 40 + math.cos(t * 0.6 + 4.2) * 30,
                        child: const _Glow(
                            size: 440, color: AppColors.cyan, alpha: 0.06),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Нэвтрэх/бүртгүүлэх дэлгэцийн амьд дэвсгэр.
///
/// Гарын үсэг: алхны цохилтоос тархах **давалгаа**. Дуудлага худалдаа бүр
/// нэг цохилтоор шийдэгддэг — тэр агшинг дэвсгэр давтан сануулна. Түүн дээр
/// удаан хөвөх сапфир/цайвар цэнхэр туяа нэмэгдэнэ.
///
/// Хөдөлгөөн багасгах тохиргоо асаалттай үед бүх хөдөлгөөн зогсож, зөвхөн
/// статик давхарга үлдэнэ.
class AuthBackground extends StatefulWidget {
  const AuthBackground({
    super.key,
    required this.child,
    this.ringCenter = const Alignment(0, -0.12),
  });

  final Widget child;

  /// Давалгаа хаанаас тарах вэ — ихэвчлэн маягтын арын төв.
  final Alignment ringCenter;

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 18));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !reducedMotion(context)) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value;
                  // Хоёр туяа хоорондоо давтагдахгүй хэмнэлээр хөвнө.
                  final a = Offset(
                    math.sin(t * 2 * math.pi) * 34,
                    math.cos(t * 2 * math.pi) * 26,
                  );
                  final b = Offset(
                    math.cos(t * 2 * math.pi * 0.7 + 1.2) * 40,
                    math.sin(t * 2 * math.pi * 0.7 + 1.2) * 30,
                  );
                  return Stack(
                    children: [
                      Positioned(
                        top: -170 + a.dy,
                        left: -120 + a.dx,
                        child: _Glow(
                            size: 440, color: AppColors.sapphire, alpha: 0.18),
                      ),
                      Positioned(
                        bottom: -200 + b.dy,
                        right: -150 + b.dx,
                        child:
                            _Glow(size: 480, color: AppColors.cyan, alpha: 0.11),
                      ),
                      Positioned(
                        top: 220 + b.dx * 0.5,
                        right: -160 + a.dy * 0.6,
                        child: const _Glow(
                            size: 340, color: AppColors.lavender, alpha: 0.07),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _StrikeRingsPainter(
                            progress: (t * 4) % 1.0,
                            center: widget.ringCenter,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.alpha});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// Төвөөсөө тэлж бүдгэрэх цагираг — алхны цохилтын давалгаа.
class _StrikeRingsPainter extends CustomPainter {
  _StrikeRingsPainter({required this.progress, required this.center});

  final double progress;
  final Alignment center;

  static const _count = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = center.alongSize(size);
    final span = size.shortestSide;

    for (var i = 0; i < _count; i++) {
      final t = (progress + i / _count) % 1.0;
      // Эхлэхдээ зөөлөн гарч ирээд, тэлэх тусам уусна.
      final fadeIn = t < 0.1 ? t / 0.1 : 1.0;
      final alpha = (1 - t) * 0.16 * fadeIn;
      if (alpha < 0.004) continue;

      canvas.drawCircle(
        origin,
        span * (0.22 + t * 0.95),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = AppColors.sapphireLight.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StrikeRingsPainter old) =>
      old.progress != progress || old.center != center;
}

// ---------------------------------------------------------------------------
// Badges & labels
// ---------------------------------------------------------------------------

/// LIVE badge — цэг нь амьсгалж цохилно.
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key});

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !reducedMotion(context)) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassChip(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(
                  (_c.value < 0.5 ? _c.value : 1 - _c.value) * 2);
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.live,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.live.withValues(alpha: 0.5 + 0.4 * t),
                      blurRadius: 4 + 8 * t,
                      spreadRadius: 1 + 2 * t,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 7),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: AppColors.liveSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// Хэсгийн eyebrow гарчиг.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
  }
}

/// Token үлдэгдлийн chip — очир алмаз icon + тоо.
class TokenBalanceChip extends StatelessWidget {
  const TokenBalanceChip({super.key, required this.balance, this.onTap});

  final int balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppColors.balGradient,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderHi),
        boxShadow: [
          BoxShadow(color: AppColors.sapphire.withValues(alpha: 0.15), blurRadius: 18),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (b) => AppColors.opalGradient.createShader(b),
            child: const Icon(LucideIcons.gem, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 7),
          Text(
            '$balance',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.sapphireSoft,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return AnimatedPressable(onPressed: onTap, child: chip);
  }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

/// Gradient CTA — дарахад агшиж glow тархана; icon өгвөл алх шиг "цохих"
/// хөдөлгөөн хийнэ.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.sublabel,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.gradient,
    this.foreground,
  });

  final String label;
  final String? sublabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Gradient? gradient;

  /// Товчны текст/icon-ы өнгө. Мөсөн цэнхэр CTA дээр бараан бэх тод
  /// уншигддаг тул default нь [AppColors.ctaInk]; бараан gradient (жиш.
  /// danger) өгвөл цагаан дамжуулна.
  final Color? foreground;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with TickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _strike =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  /// Гадаргуу дээгүүр хааяа нэг шүргэж өнгөрөх гэрэл — CTA "амьд" мэдрэгдэнэ.
  late final AnimationController _sheen =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !reducedMotion(context)) _sheen.repeat();
    });
  }

  @override
  void dispose() {
    _strike.dispose();
    _sheen.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    if (!reducedMotion(context)) _strike.forward(from: 0);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final fg = widget.foreground ?? AppColors.ctaInk;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                _handleTap();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed && !reducedMotion(context) ? 0.97 : 1,
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          child: AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.enter,
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              gradient: enabled ? (widget.gradient ?? AppColors.ctaGradient) : null,
              color: enabled ? null : AppColors.surfaceHi,
              borderRadius: BorderRadius.circular(AppRadius.control),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.sapphire
                            .withValues(alpha: _pressed ? 0.55 : 0.3),
                        blurRadius: _pressed ? 38 : 26,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Stack(children: [
                if (enabled && !widget.loading)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _sheen,
                        builder: (context, _) {
                          final t = _sheen.value;
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1.6 + 3.2 * t, -0.4),
                                end: Alignment(-0.4 + 3.2 * t, 0.4),
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.13),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Center(
              child: widget.loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: fg),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          AnimatedBuilder(
                            animation: _strike,
                            builder: (context, child) {
                              // Алхны цохилт: эргээд elastic-ээр буцна
                              final t = _strike.value;
                              final angle = t < 0.4
                                  ? -0.55 * Curves.easeOut.transform(t / 0.4)
                                  : -0.55 *
                                      (1 -
                                          Curves.elasticOut
                                              .transform((t - 0.4) / 0.6));
                              return Transform.rotate(angle: angle, child: child);
                            },
                            child: Icon(widget.icon,
                                size: 20,
                                color: enabled ? fg : AppColors.muted),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.label,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: enabled ? fg : AppColors.muted,
                              ),
                            ),
                            if (widget.sublabel != null)
                              Text(
                                widget.sublabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: (enabled ? fg : AppColors.muted)
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Countdown
// ---------------------------------------------------------------------------

class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.endsAt,
    this.serverOffsetMs = 0,
    this.style,
    this.onFinished,
  });

  final DateTime endsAt;
  final int serverOffsetMs;
  final TextStyle? style;
  final VoidCallback? onFinished;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  Duration _left = Duration.zero;
  bool _pulse = false;
  bool _finishedFired = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant CountdownText old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt) {
      _finishedFired = false;
      _tick();
    }
  }

  void _tick() {
    final now = DateTime.now().add(Duration(milliseconds: widget.serverOffsetMs));
    final left = widget.endsAt.difference(now);
    if (!mounted) return;
    setState(() {
      _left = left.isNegative ? Duration.zero : left;
      if (_left.inSeconds <= 15 && _left.inSeconds > 0) _pulse = !_pulse;
    });
    if (left.inMilliseconds <= 0 && !_finishedFired) {
      _finishedFired = true;
      widget.onFinished?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours >= 24) return '${d.inDays}ө ${two(d.inHours % 24)}:${two(d.inMinutes % 60)}';
    if (d.inHours > 0) return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _left.inSeconds <= 15 && _left > Duration.zero;
    final base = widget.style ??
        Theme.of(context).textTheme.displayLarge ??
        const TextStyle(fontSize: 34);
    return AnimatedScale(
      scale: urgent && _pulse && !reducedMotion(context) ? 1.05 : 1,
      duration: const Duration(milliseconds: 300),
      curve: AppMotion.enter,
      child: Text(
        _format(_left),
        style: base.copyWith(
          color: urgent ? AppColors.live : base.color,
          shadows: [
            Shadow(
              color: (urgent ? AppColors.live : AppColors.sapphire)
                  .withValues(alpha: urgent ? 0.6 : 0.4),
              blurRadius: 24,
            ),
          ],
        ),
      ),
    );
  }
}

/// Дэлгэцийн "гол жүжигчин" — амьсгалдаг glow-той countdown самбар.
class CountdownPanel extends StatefulWidget {
  const CountdownPanel({
    super.key,
    required this.label,
    this.endsAt,
    this.serverOffsetMs = 0,
    this.onFinished,
    this.child,
  });

  final String label;
  final DateTime? endsAt;
  final int serverOffsetMs;
  final VoidCallback? onFinished;

  /// endsAt-гүй үед (дууссан г.м.) харуулах агуулга.
  final Widget? child;

  @override
  State<CountdownPanel> createState() => _CountdownPanelState();
}

class _CountdownPanelState extends State<CountdownPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !reducedMotion(context)) _breath.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_breath.value);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              center: Alignment.topCenter,
              radius: 1.6,
              colors: [Color(0xFF14213D), Color(0xFF0B1220)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderHi),
            boxShadow: [
              BoxShadow(
                color: AppColors.sapphire.withValues(alpha: 0.10 + 0.10 * t),
                blurRadius: 30 + 20 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          SectionLabel(widget.label),
          if (widget.endsAt != null) ...[
            const SizedBox(height: 16),
            // Гарын үсэг: эргэдэг опал цагираг доторх countdown.
            OpalRing(
              size: 196,
              strokeWidth: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: CountdownText(
                    endsAt: widget.endsAt!,
                    serverOffsetMs: widget.serverOffsetMs,
                    onFinished: widget.onFinished,
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 34),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ] else if (widget.child != null) ...[
            const SizedBox(height: 6),
            widget.child!,
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Price
// ---------------------------------------------------------------------------

class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.amount,
    this.fontSize = 20,
    this.gradient,
  });

  final int amount;
  final double fontSize;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          (gradient ?? AppColors.priceGradient).createShader(bounds),
      child: Text(
        formatMnt(amount),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Үнэ өөрчлөгдөхөд нэг агшин томорч цэнхэрээр гэрэлтдэг хувилбар.
class AnimatedPrice extends StatelessWidget {
  const AnimatedPrice({super.key, required this.amount, this.fontSize = 28});

  final int amount;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(amount),
      tween: Tween(begin: reducedMotion(context) ? 1 : 1.14, end: 1),
      duration: AppMotion.slow,
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, alignment: Alignment.centerLeft, child: child),
      child: PriceText(amount: amount, fontSize: fontSize),
    );
  }
}

// ---------------------------------------------------------------------------
// Images
// ---------------------------------------------------------------------------

class AuctionImage extends StatelessWidget {
  const AuctionImage({
    super.key,
    this.url,
    this.height,
    this.borderRadius,
    this.scrim = false,
  });

  final String? url;
  final double? height;
  final BorderRadius? borderRadius;

  /// true үед доод хэсэгт нь харанхуй gradient scrim нэмнэ (текст уншигдана).
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    Widget child = url == null || url!.isEmpty
        ? Container(
            height: height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF12203C), Color(0xFF23406F), Color(0xFF16294A)],
              ),
            ),
            child: Center(
              child: Icon(LucideIcons.package,
                  size: 44, color: Colors.white.withValues(alpha: 0.14)),
            ),
          )
        : Image.network(
            url!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(height: height, color: AppColors.surfaceHi),
          );

    if (scrim) {
      child = Stack(fit: StackFit.passthrough, children: [
        child,
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.45, 1],
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
              ),
            ),
          ),
        ),
      ]);
    }
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

// ---------------------------------------------------------------------------
// Loading / empty
// ---------------------------------------------------------------------------

/// Shimmer skeleton — navy дээгүүр мөнгөлөг гэрэл шүргэж өнгөрнө.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 10});

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !reducedMotion(context)) _c.repeat();
    });
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
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * _c.value, 0),
              end: Alignment(-0.5 + 3 * _c.value, 0),
              colors: const [
                Color(0xFF121D33),
                Color(0xFF1E3050),
                Color(0xFF121D33),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Auction картын skeleton.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 160, radius: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(height: 16, width: 200),
                SizedBox(height: 12),
                Skeleton(height: 24, width: 110),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.balGradient,
              border: Border.all(color: AppColors.borderHi),
              boxShadow: [
                BoxShadow(
                    color: AppColors.sapphire.withValues(alpha: 0.15),
                    blurRadius: 30),
              ],
            ),
            child: Icon(icon, size: 30, color: AppColors.sapphireSoft),
          ),
          const SizedBox(height: 18),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheets & dialogs
// ---------------------------------------------------------------------------

/// Нэгдсэн bottom sheet — chip бариул, glass гадаргуу, зөөлөн орж ирэх хөдөлгөөн.
///
/// `useRootNavigator: true` нь чухал: үгүй бол sheet нь shell-ийн салбар
/// navigator дотор нээгдэж, доод навигацийн мөр түүний доод хэсгийг дарна.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.92,
    ),
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        border: Border.all(color: AppColors.borderHi),
        boxShadow: [
          BoxShadow(
              color: AppColors.sapphire.withValues(alpha: 0.10), blurRadius: 40),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.borderHi,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: builder(context)),
        ],
      ),
    ),
  );
}

/// Нэгдсэн dialog — glow хүрээтэй, төвд нь орж ирнэ.
Future<T?> showAppDialog<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Хаах',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: AppMotion.base,
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: AppMotion.fluid);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, __) => Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: Colors.transparent,
          child: GlowCard(glow: true, child: builder(context)),
        ),
      ),
    ),
  );
}
