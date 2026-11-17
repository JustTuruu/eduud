import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import 'ambient_backdrop.dart';

final _mnt = NumberFormat('#,###', 'en');

String formatMnt(int amount) => '${_mnt.format(amount)}₮';

bool reducedMotion(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

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

/// Карт: чавганы гадаргуу + 1px цөцгий hairline + зөөлөн сүүдэр.
/// Дарахад агшина.
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
        gradient:
            const LinearGradient(colors: [AppColors.border, AppColors.border]),
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

/// Шүрэн цагираг — дансны үлдэгдэл, аватар, countdown-ийн хүрээ.
/// Статик: нимгэн шүрэн зураас + зөөлөн туяа (хөдөлгөөнгүй).
class CoralRing extends StatelessWidget {
  const CoralRing({
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
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CoralRingPainter(strokeWidth: strokeWidth, glow: glow),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _CoralRingPainter extends CustomPainter {
  _CoralRingPainter({required this.strokeWidth, required this.glow});

  final double strokeWidth;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    if (glow) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = AppColors.coral.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.coral
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _CoralRingPainter old) =>
      old.strokeWidth != strokeWidth || old.glow != glow;
}

/// Бүх дэлгэцийн нийтлэг дэвсгэр — чавганы ambient талбар.
/// [seed] өгвөл (жиш. auction id) түүнээс тогтсон өнгө гаргана.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.seed});

  final Widget child;
  final String? seed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: AmbientBackdrop(seed: seed ?? 'e-duud')),
        child,
      ],
    );
  }
}

/// Нэвтрэх/бүртгүүлэх дэлгэцийн дэвсгэр — ижил ambient талбар.
class AuthBackground extends StatelessWidget {
  const AuthBackground({
    super.key,
    required this.child,
    this.ringCenter = const Alignment(0, -0.12),
  });

  final Widget child;

  /// Хуучин API-тай нийцүүлэх; ашиглагдахгүй.
  final Alignment ringCenter;

  @override
  Widget build(BuildContext context) =>
      AppBackground(seed: 'auth', child: child);
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

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

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
              final t = Curves.easeInOut
                  .transform((_c.value < 0.5 ? _c.value : 1 - _c.value) * 2);
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

/// Хэсгийн гарчиг (энгийн жижиг гарчиг — eyebrow биш).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelSmall);
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
        color: AppColors.surfaceHi.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderHi),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.gem, size: 14, color: AppColors.coral),
          const SizedBox(width: 7),
          Text(
            '$balance',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.ink,
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
  late final AnimationController _strike = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void dispose() {
    _strike.dispose();
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
              gradient:
                  enabled ? (widget.gradient ?? AppColors.ctaGradient) : null,
              color: enabled ? null : AppColors.surfaceHi,
              borderRadius: BorderRadius.circular(AppRadius.control),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.coral
                            .withValues(alpha: _pressed ? 0.55 : 0.3),
                        blurRadius: _pressed ? 30 : 22,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Center(
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
                                      ? -0.55 *
                                          Curves.easeOut.transform(t / 0.4)
                                      : -0.55 *
                                          (1 -
                                              Curves.elasticOut
                                                  .transform((t - 0.4) / 0.6));
                                  return Transform.rotate(
                                      angle: angle, child: child);
                                },
                                child: Icon(widget.icon,
                                    size: 20,
                                    color: enabled ? fg : AppColors.muted),
                              ),
                              const SizedBox(width: 10),
                            ],
                            // Flexible: нарийн товч (web grid, landing CTA) дээр
                            // урт шошго overflow хийхгүй, ellipsis болно.
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
    final now =
        DateTime.now().add(Duration(milliseconds: widget.serverOffsetMs));
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
    if (d.inHours >= 24) {
      return '${d.inDays}ө ${two(d.inHours % 24)}:${two(d.inMinutes % 60)}';
    }
    if (d.inHours > 0) {
      return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    }
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
              color: (urgent ? AppColors.live : AppColors.coral)
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
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderHi),
            boxShadow: [
              BoxShadow(
                color: AppColors.coral.withValues(alpha: 0.10 + 0.10 * t),
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
            // Шүрэн цагираг доторх countdown.
            CoralRing(
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
    this.color = AppColors.ink,
  });

  final int amount;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(formatMnt(amount),
        style: AppTheme.price(size: fontSize, color: color));
  }
}

/// Үнэ өөрчлөгдөхөд нэг агшин томорч буцдаг хувилбар.
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
      builder: (context, scale, child) => Transform.scale(
          scale: scale, alignment: Alignment.centerLeft, child: child),
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
                colors: [
                  Color(0xFF241634),
                  Color(0xFF3A2755),
                  Color(0xFF241634)
                ],
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
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55)
                ],
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

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

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
                Color(0xFF241634),
                Color(0xFF33224A),
                Color(0xFF241634),
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
              color: AppColors.surfaceHi.withValues(alpha: 0.6),
              border: Border.all(color: AppColors.borderHi),
            ),
            child: Icon(icon, size: 30, color: AppColors.coralLight),
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
Future<T?> showAppSheet<T>(BuildContext context,
    {required WidgetBuilder builder}) {
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
              color: AppColors.coral.withValues(alpha: 0.10), blurRadius: 40),
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
Future<T?> showAppDialog<T>(BuildContext context,
    {required WidgetBuilder builder}) {
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

/// Push хийсэн дэлгэцийн буцах товч. Web дээр холбоосоор шууд орж ирсэн бол
/// буцах түүх байхгүй — [fallback] руу очно.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback = '/'});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return BackButton(
      onPressed: () => context.canPop() ? context.pop() : context.go(fallback),
    );
  }
}
