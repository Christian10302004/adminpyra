import 'package:flutter/material.dart';

/// Non-color tokens — brand, radii, spacing, typography.
/// Same in both themes.
class Tok {
  // Brand — orange
  static const brand     = Color(0xFFE65100);
  static const brandSoft = Color(0xFFFF9800);

  // Semantic
  static const ok     = Color(0xFF4CAF50);
  static const warn   = Color(0xFFFF9800);
  static const info   = Color(0xFF4C8DFF);
  static const purple = Color(0xFF9C27B0);
  static const indigo = Color(0xFF5C6BC0);
  static const danger = Color(0xFFF85149);

  // Radii
  static const rSm = 6.0;
  static const rMd = 8.0;
  static const rLg = 12.0;

  // Spacing
  static const gap2  = 2.0;
  static const gap4  = 4.0;
  static const gap6  = 6.0;
  static const gap8  = 8.0;
  static const gap12 = 12.0;
  static const gap16 = 16.0;
  static const gap20 = 20.0;
  static const gap24 = 24.0;
  static const gap32 = 32.0;

  // Typography — colors applied at call site via copyWith.
  static const stack = 'system-ui, -apple-system, "Segoe UI", "Helvetica Neue", Arial, sans-serif';

  static const h1     = TextStyle(fontFamily: stack, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.2);
  static const h2     = TextStyle(fontFamily: stack, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1);
  static const h3     = TextStyle(fontFamily: stack, fontSize: 13, fontWeight: FontWeight.w600);
  static const body   = TextStyle(fontFamily: stack, fontSize: 14, height: 1.4);
  static const bodySm = TextStyle(fontFamily: stack, fontSize: 12, height: 1.4);
  static const label  = TextStyle(fontFamily: stack, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4);
  static const caption= TextStyle(fontFamily: stack, fontSize: 11, height: 1.4);
  static const metric = TextStyle(
    fontFamily: stack,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.05,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Colors that change between themes.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderSoft;
  final Color textHi;
  final Color textMid;
  final Color textLo;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderSoft,
    required this.textHi,
    required this.textMid,
    required this.textLo,
  });

  static const dark = AppColors(
    bg:         Color(0xFF0E0F10),
    surface:    Color(0xFF161719),
    surfaceAlt: Color(0xFF1D1E21),
    border:     Color(0xFF2A2B2F),
    borderSoft: Color(0xFF212225),
    textHi:     Color(0xFFECECEC),
    textMid:    Color(0xFFA6A7AC),
    textLo:     Color(0xFF6E7075),
  );

  static const light = AppColors(
    bg:         Color(0xFFF3F4F6),
    surface:    Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF9FAFB),
    border:     Color(0xFFE5E7EB),
    borderSoft: Color(0xFFEEF0F2),
    textHi:     Color(0xFF111827),
    textMid:    Color(0xFF4B5563),
    textLo:     Color(0xFF9CA3AF),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? borderSoft,
    Color? textHi,
    Color? textMid,
    Color? textLo,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      borderSoft: borderSoft ?? this.borderSoft,
      textHi: textHi ?? this.textHi,
      textMid: textMid ?? this.textMid,
      textLo: textLo ?? this.textLo,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg:         Color.lerp(bg, other.bg, t)!,
      surface:    Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border:     Color.lerp(border, other.border, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      textHi:     Color.lerp(textHi, other.textHi, t)!,
      textMid:    Color.lerp(textMid, other.textMid, t)!,
      textLo:     Color.lerp(textLo, other.textLo, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppColors.dark : AppColors.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Tok.brand,
      brightness: brightness,
      surface: colors.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.textHi,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: colors.border)),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(side: BorderSide.none),
    ),
    dividerTheme: DividerThemeData(color: colors.borderSoft, thickness: 1, space: 1),
    extensions: [colors],
  );
}

BoxDecoration flatBoxFrom(AppColors colors) => BoxDecoration(
  color: colors.surface,
  borderRadius: BorderRadius.circular(Tok.rMd),
  border: Border.all(color: colors.border),
);

String getInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}