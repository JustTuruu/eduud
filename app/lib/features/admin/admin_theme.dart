import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Админ хэсгийн тогтмол өнгө. Системийн dark горимоос үл хамаарч үргэлж
/// цагаан — тиймээс апп-ын AppColors (динамик) энд ашиглагдахгүй.
abstract class AdminColors {
  static const bg = Color(0xFFFFFFFF);
  static const panel = Color(0xFFF5F5F7);
  static const border = Color(0xFFE5E5EA);
  static const ink = Color(0xFF1D1D1F);
  static const muted = Color(0xFF6E6E73);
  static const faint = Color(0xFFAEAEB2);

  /// Апп-ын ногоон (товч, график).
  static const accent = Color(0xFF34C759);

  /// Цагаан дээр уншигдах хар ногоон (текст, pill).
  static const accentDark = Color(0xFF1E8E3E);
  static const accentSoft = Color(0xFFE6F6EA);

  static const blue = Color(0xFF0A84FF);
  static const blueSoft = Color(0xFFE5F1FF);
  static const orange = Color(0xFFD97706);
  static const orangeSoft = Color(0xFFFFF1DC);
  static const red = Color(0xFFD92D20);
  static const redSoft = Color(0xFFFDE8E6);
  static const graySoft = Color(0xFFEDEDF0);
}

const _tabular = [FontFeature.tabularFigures()];

/// Тоо харуулах стиль: тэнцүү өргөнтэй цифр.
TextStyle adminNumber({double size = 14, FontWeight? weight, Color? color}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AdminColors.ink,
      fontFeatures: _tabular,
    );

ThemeData adminTheme() {
  const fallback = kIsWeb ? ['system-ui', '-apple-system', 'Roboto'] : null;
  final scheme = const ColorScheme.light().copyWith(
    primary: AdminColors.accentDark,
    onPrimary: Colors.white,
    secondary: AdminColors.accent,
    surface: AdminColors.bg,
    onSurface: AdminColors.ink,
    error: AdminColors.red,
    outline: AdminColors.border,
    outlineVariant: AdminColors.border,
  );
  final base = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AdminColors.bg,
    canvasColor: AdminColors.bg,
    dividerColor: AdminColors.border,
    fontFamilyFallback: fallback,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: AdminColors.panel,
  );
  final text = base.textTheme.apply(
    bodyColor: AdminColors.ink,
    displayColor: AdminColors.ink,
    fontFamilyFallback: fallback,
  );
  OutlineInputBorder border([Color c = AdminColors.border]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c),
      );
  return base.copyWith(
    textTheme: text.copyWith(
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12),
    ),
    dividerTheme: const DividerThemeData(
      color: AdminColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AdminColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      hintStyle: const TextStyle(color: AdminColors.faint, fontSize: 14),
      labelStyle: const TextStyle(color: AdminColors.muted, fontSize: 14),
      border: border(),
      enabledBorder: border(),
      focusedBorder: border(AdminColors.accentDark),
      errorBorder: border(AdminColors.red),
      focusedErrorBorder: border(AdminColors.red),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AdminColors.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AdminColors.border),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AdminColors.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AdminColors.border),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AdminColors.bg,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AdminColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AdminColors.accent
              : AdminColors.border),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AdminColors.accentDark,
      selectionColor: Color(0x3334C759),
    ),
  );
}

// ---------- Формат ----------

final _intFmt = NumberFormat('#,##0');
final _dateFmt = DateFormat('MM/dd HH:mm');

/// 12 345 хэлбэрээр.
String fmtInt(num? n) => n == null ? '—' : _intFmt.format(n.round());

/// 12 345₮
String fmtMnt(num? n) => n == null ? '—' : '${_intFmt.format(n.round())}₮';

/// 12.3k, 1.2M — график тэнхлэгт.
String fmtCompact(num n) {
  final a = n.abs();
  if (a >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(a >= 1e7 ? 0 : 1)}M';
  }
  if (a >= 1000) return '${(n / 1000).toStringAsFixed(a >= 1e4 ? 0 : 1)}k';
  return n.round().toString();
}

/// ISO текстийг "05/12 14:30" болгоно (орон нутгийн цагаар).
String fmtDate(dynamic v) {
  final d = v is DateTime ? v : DateTime.tryParse('$v');
  if (d == null) return '—';
  return _dateFmt.format(d.toLocal());
}
