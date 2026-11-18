
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Нэг горимын (light/dark) өнгөний багц — iOS system colors.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.fill,
    required this.border,
    required this.borderHi,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.accent,
    required this.danger,
    required this.warn,
    required this.gold,
    required this.goldLight,
  });

  final Brightness brightness;
  final Color bg, surface, surfaceHi, fill, border, borderHi;
  final Color ink, inkSoft, muted;
  final Color accent, danger, warn, gold, goldLight;

  /// iOS grouped background #F2F2F7, карт #FFFFFF.
  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    surfaceHi: Color(0xFFE9E9EE),
    fill: Color(0x1F767680), // tertiary fill — оролтын талбар
    border: Color(0x293C3C43), // separator ~16%
    borderHi: Color(0x4A3C3C43), // separator 29%
    ink: Color(0xFF000000),
    inkSoft: Color(0xCC3C3C43),
    muted: Color(0x993C3C43), // secondary label 60%
    accent: Color(0xFF34C759),
    danger: Color(0xFFFF3B30),
    warn: Color(0xFFFF9500),
    gold: Color(0xFFC99A1B),
    goldLight: Color(0xFFE6C15A),
  );

  /// iOS dark: хар дэвсгэр, карт #1C1C1E, elevated #2C2C2E.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceHi: Color(0xFF2C2C2E),
    fill: Color(0x3D767680),
    border: Color(0x33545458),
    borderHi: Color(0x59545458),
    ink: Color(0xFFFFFFFF),
    inkSoft: Color(0xCCEBEBF5),
    muted: Color(0x99EBEBF5),
    accent: Color(0xFF30D158),
    danger: Color(0xFFFF453A),
    warn: Color(0xFFFF9F0A),
    gold: Color(0xFFF2C14E),
    goldLight: Color(0xFFF8DB90),
  );
}

/// Дэлгэцүүдээс `AppColors.ink` маягаар уншигддаг өнгөнүүд — const БИШ.
/// Идэвхтэй багцыг [apply] root дээрээс системийн brightness-ээр сольдог.
abstract class AppColors {
  static AppPalette _p = AppPalette.light;

  static AppPalette get palette => _p;
  static bool get isDark => _p.brightness == Brightness.dark;

  /// Системийн brightness-ийн дагуу багцыг сольно (EduudApp дуудна).
  static void apply(Brightness b) =>
      _p = b == Brightness.dark ? AppPalette.dark : AppPalette.light;

  // Дэвсгэр давхаргууд
  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get surfaceHi => _p.surfaceHi;

  /// Оролт, skeleton-ийн саарал дүүргэлт (iOS tertiary fill).
  static Color get fill => _p.fill;

  // Хуваагч / хүрээ
  static Color get border => _p.border;
  static Color get borderHi => _p.borderHi;

  // Гол accent — ногоон (coral нь хуучин нэрийн alias)
  static Color get accent => _p.accent;
  static Color get coral => _p.accent;
  static Color get coralLight => _p.accent;

  // Текст
  static Color get ink => _p.ink;
  static Color get inkSoft => _p.inkSoft;
  static Color get muted => _p.muted;

  /// Accent товч дээрх бэх — цагаан.
  static Color get ctaInk => const Color(0xFFFFFFFF);

  // Семантик — улаан зөвхөн алдаа / сүүлийн секунд
  static Color get live => _p.danger;
  static Color get liveSoft => _p.danger;
  static Color get success => _p.accent;
  static Color get gold => _p.gold; // зөвхөн ялагч
  static Color get goldLight => _p.goldLight;

  static Color get danger => _p.danger;
  static Color get dangerSoft => _p.danger;
  static Color get dangerBg => _p.danger.withValues(alpha: 0.12);
  static Color get warn => _p.warn;
  static Color get warnBg => _p.warn.withValues(alpha: 0.14);
  static Color get successBg => _p.accent.withValues(alpha: 0.14);

  /// Нууц үгийн бат бөх байдлын шат: сул → дунд → сайн → хүчтэй.
  static List<Color> get strength => [danger, warn, accent, success];

  // Gradient-үүд хассан — нийцлийн үүднээс хавтгай (нэг өнгөтэй) хэвээр.
  static LinearGradient get dangerGradient =>
      LinearGradient(colors: [danger, danger]);
  static LinearGradient get ctaGradient =>
      LinearGradient(colors: [accent, accent]);
  static LinearGradient get winGradient =>
      LinearGradient(colors: [gold, gold]);
  static LinearGradient get cardGradient =>
      LinearGradient(colors: [surface, surface]);
  static LinearGradient get balGradient =>
      LinearGradient(colors: [surfaceHi, surfaceHi]);
}

/// Хөдөлгөөний токен — бүх animation нэг хэмнэлтэй байна.
abstract class AppMotion {
  static const fast = Duration(milliseconds: 200);
  static const base = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 480);

  /// Гарах хөдөлгөөн орж ирэхээсээ богино байх нь илүү шуурхай мэдрэгддэг.
  static const exitFast = Duration(milliseconds: 200);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const fluid = Curves.easeOutQuint;

  /// Пүршин мэдрэмж — сонголт, идэвхжилт зэрэг "барьж авах" хөдөлгөөнд.
  static const spring = Curves.easeOutBack;

  /// Жагсаалтын элемент бүрийн хоцролт.
  static const stagger = Duration(milliseconds: 45);
}

abstract class AppRadius {
  static const chip = 12.0;
  static const control = 14.0;
  static const card = 16.0;
  static const art = 20.0;
  static const sheet = 20.0;
}

abstract class AppTheme {
  /// Үнэ, тоо — системийн фонт, tabular figures, 700 жин.
  static TextStyle price({double size = 28, Color? color}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.ink,
        height: 1.1,
        letterSpacing: -0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData get light => _build(AppPalette.light);
  static ThemeData get dark => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final isDark = p.brightness == Brightness.dark;
    // Web дээр системийн фонтын жагсаалт; iOS/Android-д платформын default.
    final fallback =
        kIsWeb ? const ['system-ui', '-apple-system', 'Roboto'] : null;
    final scheme = (isDark ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(
      primary: p.accent,
      onPrimary: Colors.white,
      secondary: p.accent,
      surface: p.surface,
      error: p.danger,
      onSurface: p.ink,
      outline: p.borderHi,
      outlineVariant: p.border,
    );
    final base = ThemeData(
      brightness: p.brightness,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      fontFamilyFallback: fallback,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
    );

    final body = base.textTheme.apply(
      bodyColor: p.ink,
      displayColor: p.ink,
      fontFamilyFallback: fallback,
    );

    TextStyle? w(TextStyle? s, double size, FontWeight weight,
            {Color? color, double? height, double? spacing}) =>
        s?.copyWith(
          fontSize: size,
          fontWeight: weight,
          color: color ?? p.ink,
          height: height,
          letterSpacing: spacing,
        );

    return base.copyWith(
      textTheme: body.copyWith(
        // 34/700 — iOS large title (том тоо, countdown)
        displayLarge: w(body.displayLarge, 34, FontWeight.w700, spacing: -0.4)
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        displayMedium: w(body.displayMedium, 22, FontWeight.w700, spacing: -0.3),
        displaySmall: w(body.displaySmall, 17, FontWeight.w600),
        headlineMedium: w(body.headlineMedium, 34, FontWeight.w700, spacing: -0.4),
        headlineSmall: w(body.headlineSmall, 28, FontWeight.w700, spacing: -0.3),
        titleLarge: w(body.titleLarge, 22, FontWeight.w700, height: 1.25),
        titleMedium: w(body.titleMedium, 17, FontWeight.w600),
        titleSmall: w(body.titleSmall, 15, FontWeight.w600),
        bodyLarge: w(body.bodyLarge, 17, FontWeight.w400),
        bodyMedium: w(body.bodyMedium, 15, FontWeight.w400),
        bodySmall:
            w(body.bodySmall, 13, FontWeight.w400, color: p.muted, height: 1.4),
        // Eyebrow хэв маяг хориотой — энгийн, том үсэг, зайгүй.
        labelSmall: w(body.labelSmall, 13, FontWeight.w600, color: p.inkSoft),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.3),
        selectionHandleColor: p.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        foregroundColor: p.ink,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: p.ink,
          fontFamilyFallback: fallback,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.fill,
        hintStyle: TextStyle(color: p.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: BorderSide(color: p.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
        // Алдааны текстийг AppField өөрөө зурдаг тул энд орон зай эзлүүлэхгүй.
        errorStyle: const TextStyle(fontSize: 0, height: 0),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? p.surfaceHi : const Color(0xFF2C2C2E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        // Хөвөгч навын дээгүүр харагдана.
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 0.5, space: 0.5),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      tabBarTheme: base.tabBarTheme.copyWith(dividerColor: Colors.transparent),
    );
  }
}
