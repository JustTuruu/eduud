import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ice Night — "Мөсөн шөнө" дизайн систем.
///
/// Гүн хөх шөнийн дэвсгэр дээр мөсөн цэнхэр (#8EB9FD) гол туяа, түүнийг
/// дагасан аврорагийн солонгорол: мөсөн цэнхэр → гаа ногоон → цайвар ягаан.
/// Гарын үсэг нь эргэдэг аврора цагираг — дуудлага худалдааны цаг хугацааны
/// мэдрэмжийг нэг дүрсэнд шингээнэ. Алт (gold) зөвхөн ЯЛАЛТ-ын семантикт.
abstract class AppColors {
  // Дэвсгэр давхаргууд — хөх туяатай шөнийн гүн
  static const bg = Color(0xFF060A13);
  static const surface = Color(0xFF0B1220);
  static const surfaceHi = Color(0xFF141F38);

  // Хүрээ
  static const border = Color(0xFF1C2A47);
  static const borderHi = Color(0xFF2E4470);

  // Гол accent — мөсөн цэнхэр (брэндийн #8EB9FD)
  static const sapphire = Color(0xFF8EB9FD);
  static const sapphireLight = Color(0xFFADCBFF);
  static const sapphireSoft = Color(0xFFCBDEFF);

  /// Аврорагийн хоёр дахь туяа — цайвар ягаан. Зөвхөн аврора градиент
  /// болон онцлох glow-д хэрэглэнэ; өөрөө CTA болохгүй.
  static const lavender = Color(0xFFA18FFF);

  /// Аврорагийн гурав дахь туяа — гаа ногоон. "Хугацаа/нарийвчлал" утгатай.
  static const cyan = Color(0xFF7BE8CF);

  // Текст
  static const ink = Color(0xFFEAF1FF);
  static const inkSoft = Color(0xFFC9D6EF);
  static const muted = Color(0xFF7186AC);

  /// Мөсөн цэнхэр CTA дээрх бараан бэх — цайвар товчинд цагаан биш
  /// харанхуй текст тод уншигдана.
  static const ctaInk = Color(0xFF0A1830);

  // Семантик
  static const live = Color(0xFFFF5470);
  static const liveSoft = Color(0xFFFF8CA0);
  static const success = Color(0xFF3ECF8E);
  static const gold = Color(0xFFE8B34B); // зөвхөн ялалт
  static const goldLight = Color(0xFFF5D488);

  // Маягтын төлөв. Алдааг зөвхөн өнгөөр биш, icon + текстээр давхар илэрхийлнэ.
  static const danger = Color(0xFFFF6B6B);
  static const dangerSoft = Color(0xFFFFA0A0);
  static const dangerBg = Color(0x1FFF6B6B);
  static const warn = Color(0xFFF5A524);
  static const warnBg = Color(0x1FF5A524);
  static const successBg = Color(0x1F3ECF8E);

  /// Нууц үгийн бат бөх байдлын шат: сул → дунд → сайн → хүчтэй.
  static const strength = [danger, warn, sapphireLight, success];

  static const dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7B7B), Color(0xFFD93A3A)],
  );

  /// Мөсөн цэнхэр CTA — цайвараас гүн рүү. Дээр нь [ctaInk] бараан текст.
  static const ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB7D3FF), Color(0xFF8EB9FD)],
  );

  /// Гарын үсэг — аврорагийн солонгорол. Wordmark, эргэдэг цагираг, онцлох
  /// элементэд л хэрэглэнэ; хаа сайгүй цацвал үнэ цэнээ алдана.
  static const opalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8EB9FD), Color(0xFF7BE8CF), Color(0xFFA18FFF)],
  );

  /// Аврора цагирагийн эргэдэг sweep — эхлэл төгсгөл нь ижил өнгөөр
  /// залгагдаж тасархайгүй эргэнэ.
  static const opalSweep = SweepGradient(
    colors: [
      Color(0xFF8EB9FD),
      Color(0xFF7BE8CF),
      Color(0xFFA18FFF),
      Color(0xFF8EB9FD),
    ],
  );

  static const priceGradient = LinearGradient(
    colors: [Color(0xFFADCBFF), Color(0xFFEAF3FF)],
  );

  static const winGradient = LinearGradient(
    colors: [Color(0xFFE8B34B), Color(0xFFF5D488)],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0E1628), Color(0xFF0A101D)],
  );

  static const balGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16264A), Color(0xFF1E335F)],
  );

  /// Картын gradient hairline хүрээ — дээрээсээ мөсөн туяарч доошоо уусна.
  static const hairlineGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x808EB9FD), Color(0x337BE8CF), Color(0x0D1C2A47)],
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

  /// Пүршин мэдрэмж — сонголт, идэвхжилт зэрэг "барьж авах" хөдөлгөөнд.
  static const spring = Curves.easeOutBack;

  /// Жагсаалтын элемент бүрийн хоцролт.
  static const stagger = Duration(milliseconds: 45);

  /// Аврора цагираг бүтэн нэг эргэлт хийх хугацаа — тайван, яарахгүй.
  static const opalSpin = Duration(seconds: 6);
}

abstract class AppRadius {
  static const chip = 14.0;
  static const control = 18.0;
  static const card = 24.0;
  static const sheet = 32.0;
}

abstract class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.sapphire,
        secondary: AppColors.sapphireLight,
        surface: AppColors.surface,
        error: AppColors.live,
        // Гол өнгө цайвар тул дээрх текст нь бараан байж тод уншигдана.
        onPrimary: AppColors.ctaInk,
        onSurface: AppColors.ink,
      ),
    );

    final body = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: AppColors.sapphireSoft,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        displaySmall: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
        titleMedium: body.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
        bodySmall: body.bodySmall?.copyWith(color: AppColors.muted, height: 1.5),
        labelSmall: body.labelSmall?.copyWith(
          color: AppColors.muted,
          letterSpacing: 2.4,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
          borderSide: const BorderSide(color: AppColors.sapphire, width: 1.6),
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
        contentTextStyle: GoogleFonts.manrope(color: AppColors.ink, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      tabBarTheme: base.tabBarTheme.copyWith(dividerColor: Colors.transparent),
    );
  }
}
