import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Now Playing — "Одоо тоглож буй" дизайн систем.
///
/// Гүн чавга (plum) дэвсгэр, цөцгий (cream) текст, шүрэн (coral) accent:
/// bid товч, progress, идэвхтэй таб. Барааны зургаас гаргасан өнгө дэлгэцийн
/// ambient талбар болж тархана (AmbientBackdrop). Манропе — үнэ 800 tabular.
abstract class AppColors {
  // Дэвсгэр давхаргууд — чавганы гүн
  static const bg = Color(0xFF140B1C);
  static const surface = Color(0xFF1A1024);
  static const surfaceHi = Color(0xFF2A1B3D);

  // Хуваагч / хүрээ — цөцгий 8% ба 16%
  static const border = Color(0x14F3E9DC);
  static const borderHi = Color(0x29F3E9DC);

  // Гол accent — шүрэн
  static const coral = Color(0xFFFF6B4A);
  static const coralLight = Color(0xFFFF9275);

  // Текст — цөцгийн ястай (саарал биш)
  static const ink = Color(0xFFF3E9DC);
  static const inkSoft = Color(0xFFD8CCD6);
  static const muted = Color(0xFFA999B4);

  /// Шүрэн CTA дээрх бараан чавга бэх — контраст ~6:1.
  static const ctaInk = Color(0xFF1C0C16);

  // Семантик
  static const live = Color(0xFFFF4F7B);
  static const liveSoft = Color(0xFFFF8FA9);
  static const success = Color(0xFF63D9A4);
  static const gold = Color(0xFFF2C14E); // зөвхөн ялалт
  static const goldLight = Color(0xFFF8DB90);

  // Маягтын төлөв. Алдааг зөвхөн өнгөөр биш, icon + текстээр давхар илэрхийлнэ.
  static const danger = Color(0xFFFF7A85);
  static const dangerSoft = Color(0xFFFFA9B0);
  static const dangerBg = Color(0x1FFF7A85);
  static const warn = Color(0xFFFFB547);
  static const warnBg = Color(0x1FFFB547);
  static const successBg = Color(0x1F63D9A4);

  /// Нууц үгийн бат бөх байдлын шат: сул → дунд → сайн → хүчтэй.
  static const strength = [danger, warn, coralLight, success];

  static const dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A94), Color(0xFFD94452)],
  );

  /// Шүрэн CTA — бараг хавтгай, зөөлөн л өнгө хазайлттай.
  static const ctaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF7556), Color(0xFFFF6140)],
  );

  static const winGradient = LinearGradient(
    colors: [Color(0xFFF2C14E), Color(0xFFF8DB90)],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF231533), Color(0xFF1C1129)],
  );

  static const balGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1B3D), Color(0xFF34224B)],
  );
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

  /// Ambient өнгө зургаас зургийн хооронд уусах хугацаа.
  static const ambient = Duration(milliseconds: 900);

  /// Пүршин мэдрэмж — сонголт, идэвхжилт зэрэг "барьж авах" хөдөлгөөнд.
  static const spring = Curves.easeOutBack;

  /// Жагсаалтын элемент бүрийн хоцролт.
  static const stagger = Duration(milliseconds: 45);
}

abstract class AppRadius {
  static const chip = 14.0;
  static const control = 18.0;
  static const card = 24.0;
  static const art = 28.0;
  static const sheet = 32.0;
}

abstract class AppTheme {
  /// Үнэ, тоо — tabular figures, 800 жин.
  static TextStyle price({double size = 28, Color color = AppColors.ink}) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.1,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.coral,
        secondary: AppColors.coralLight,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: AppColors.ctaInk,
        onSurface: AppColors.ink,
      ),
    );

    final body = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    TextStyle display(double size, FontWeight w) => GoogleFonts.manrope(
          fontSize: size,
          fontWeight: w,
          color: AppColors.ink,
          letterSpacing: -0.3,
        );

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: display(40, FontWeight.w800)
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        displayMedium: display(23, FontWeight.w800),
        displaySmall: display(16, FontWeight.w700),
        titleLarge:
            body.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
        titleMedium: body.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
        bodySmall:
            body.bodySmall?.copyWith(color: AppColors.muted, height: 1.5),
        // Eyebrow хэв маяг хориотой — энгийн, том үсэг, зайгүй.
        labelSmall: body.labelSmall?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.coral,
        selectionColor: AppColors.coral.withValues(alpha: 0.35),
        selectionHandleColor: AppColors.coral,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.7),
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
        // Алдааны текстийг AppField өөрөө зурдаг тул энд орон зай эзлүүлэхгүй.
        errorStyle: const TextStyle(fontSize: 0, height: 0),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHi,
        contentTextStyle:
            GoogleFonts.manrope(color: AppColors.ink, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        // Хөвөгч навын дээгүүр харагдана.
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: const BorderSide(color: AppColors.borderHi),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.border, thickness: 1),
      tabBarTheme: base.tabBarTheme.copyWith(dividerColor: Colors.transparent),
    );
  }
}
