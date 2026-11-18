import 'package:flutter/material.dart';

/// Web/desktop болон утасны нэг кодын responsive дүрэм.
///
/// Утас болон web **яг ижил** үйлдэлтэй — зөвхөн зай хуваарилалт өөр:
/// өргөн дэлгэц дээр доод навигацийн оронд дээд навигац, жагсаалт grid болно,
/// агуулга төвдөө хязгаарлагдана.
abstract class Breakpoints {
  /// Үүнээс өргөн бол "өргөн" (web/tablet landscape) горим.
  static const wide = 900.0;

  /// Жагсаалтын карт 2 багана болох өргөн.
  static const twoColumns = 700.0;

  /// 3 багана.
  static const threeColumns = 1080.0;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;

  static int gridColumns(double width) {
    if (width >= threeColumns) return 3;
    if (width >= twoColumns) return 2;
    return 1;
  }
}

/// Хуудасны агуулгыг өргөн дэлгэц дээр төвд, [maxWidth]-ээс хэтрүүлэхгүй.
/// Утас дээр (өргөн нь [maxWidth]-ээс бага) юу ч өөрчлөхгүй.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
