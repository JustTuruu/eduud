import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'widgets.dart' show reducedMotion;

/// Зургийн өнгийг (cache-тэй) гаргаж авах — URL бүрт нэг л удаа.
abstract class AmbientPalette {
  static final Map<String, List<Color>> _cache = {};

  /// Seed тэмдэгт мөрөөс тогтмол (deterministic) 3 өнгө.
  static List<Color> fromSeed(String seed) {
    final cached = _cache['seed:$seed'];
    if (cached != null) return cached;
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final hue = (h % 360).toDouble();
    Color at(double dh, double s, double l) =>
        HSLColor.fromAHSL(1, (hue + dh) % 360, s, l).toColor();
    return _cache['seed:$seed'] = [
      at(0, 0.55, 0.42),
      at(48, 0.5, 0.36),
      at(-52, 0.5, 0.34)
    ];
  }

  /// Seed өнгөнөөс 3 өнгө.
  static List<Color> fromColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    Color at(double dh) => hsl
        .withHue((hsl.hue + dh) % 360)
        .withSaturation(hsl.saturation.clamp(0.4, 0.7))
        .toColor();
    return [at(0), at(40), at(-40)];
  }

  /// Зургаас өнгө гаргана. Алдаа гарвал null.
  static Future<List<Color>?> fromImage(
      String key, ImageProvider provider) async {
    final cached = _cache['img:$key'];
    if (cached != null) return cached;
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: ResizeImage(provider, width: 96),
        brightness: Brightness.dark,
      );
      final colors = [scheme.primary, scheme.tertiary, scheme.secondary];
      _cache['img:$key'] = colors;
      return colors;
    } catch (_) {
      return null;
    }
  }
}

/// Ambient дэвсгэр — чавганы суурь дээр зургийн өнгөөр будагдсан, маш
/// бүдэг, удаан хөвөгч хэдэн толбо. Эх сурвалж солигдоход ~900мс-д уусна.
///
/// Зураг байвал [image] (+ cache түлхүүр [imageKey]), байхгүй бол [seed]
/// тэмдэгт мөрөөс (жиш. auction id) тогтмол өнгө гаргана.
class AmbientBackdrop extends StatefulWidget {
  const AmbientBackdrop({
    super.key,
    this.image,
    this.imageKey,
    this.seed = 'e-duud',
    this.seedColor,
  });

  final ImageProvider? image;
  final String? imageKey;
  final String seed;
  final Color? seedColor;

  @override
  State<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<AmbientBackdrop>
    with TickerProviderStateMixin {
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 40));
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: AppMotion.ambient, value: 1);

  late List<Color> _from;
  late List<Color> _to;
  int _token = 0;

  List<Color> _fallback() => widget.seedColor != null
      ? AmbientPalette.fromColor(widget.seedColor!)
      : AmbientPalette.fromSeed(widget.seed);

  @override
  void initState() {
    super.initState();
    _from = _to = _fallback();
    // Зураггүй бол fallback өнгө хангалттай; зурагтай үед л асинхрон гаргана.
    if (widget.image != null) unawaited(_resolve());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !reducedMotion(context)) _drift.repeat();
    });
  }

  @override
  void didUpdateWidget(covariant AmbientBackdrop old) {
    super.didUpdateWidget(old);
    if (old.imageKey != widget.imageKey ||
        old.seed != widget.seed ||
        old.seedColor != widget.seedColor) {
      unawaited(_resolve());
    }
  }

  Future<void> _resolve() async {
    final token = ++_token;
    var next = _fallback();
    if (widget.image != null && widget.imageKey != null) {
      final fromImg =
          await AmbientPalette.fromImage(widget.imageKey!, widget.image!);
      if (!mounted || token != _token) return;
      if (fromImg != null) next = fromImg;
    }
    _setPalette(next);
  }

  void _setPalette(List<Color> next) {
    final current = _currentColors();
    _from = current;
    _to = next;
    if (reducedMotion(context)) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
    setState(() {});
  }

  List<Color> _currentColors() {
    final t = Curves.easeInOut.transform(_fade.value);
    return [
      for (var i = 0; i < 3; i++) Color.lerp(_from[i], _to[i], t)!,
    ];
  }

  @override
  void dispose() {
    _drift.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _AmbientPainter(
            drift: _drift,
            fade: _fade,
            from: _from,
            to: _to,
          ),
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.drift,
    required this.fade,
    required this.from,
    required this.to,
  }) : super(repaint: Listenable.merge([drift, fade]));

  final Animation<double> drift;
  final Animation<double> fade;
  final List<Color> from;
  final List<Color> to;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg);
    final t = drift.value * 2 * math.pi;
    final f = Curves.easeInOut.transform(fade.value);
    final base = size.longestSide;

    void blob(Offset c, double r, Color color, double alpha) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [
            Color.lerp(AppColors.bg, color, 0.8)!.withValues(alpha: alpha),
            Color.lerp(AppColors.bg, color, 0.8)!.withValues(alpha: 0),
          ]).createShader(rect),
      );
    }

    Color c(int i) => Color.lerp(from[i], to[i], f)!;
    blob(
        Offset(size.width * (0.2 + 0.06 * math.sin(t)),
            size.height * (0.16 + 0.04 * math.cos(t))),
        base * 0.62,
        c(0),
        0.62);
    blob(
        Offset(size.width * (0.88 + 0.05 * math.cos(t * 1.0 + 1.3)),
            size.height * (0.42 + 0.05 * math.sin(t + 1.3))),
        base * 0.5,
        c(1),
        0.42);
    blob(
        Offset(size.width * (0.3 + 0.07 * math.sin(t + 3.1)),
            size.height * (0.86 + 0.03 * math.cos(t + 3.1))),
        base * 0.55,
        c(2),
        0.4);

    // Доош уусах чавганы scrim — текст/нав дээрх контрастыг хамгаална.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bg.withValues(alpha: 0.1),
            AppColors.bg.withValues(alpha: 0.72),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.from != from || old.to != to;
}
