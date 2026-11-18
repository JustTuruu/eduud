import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

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

/// Хуучин ambient дэвсгэр — одоо зүгээр л энгийн grouped дэвсгэр өнгө.
/// Blob, blur, animation байхгүй. Параметрүүд зөвхөн нийцлийн үүднээс үлдсэн.
class AmbientBackdrop extends StatelessWidget {
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
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.bg, child: const SizedBox.expand());
}
