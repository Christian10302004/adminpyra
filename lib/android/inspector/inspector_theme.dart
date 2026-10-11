import 'package:flutter/material.dart';

class Tok {
  /// Set by ThemeProvider on init and on toggle.
  static bool isDark = true;

  static Color get bg         => isDark ? const Color(0xFF0E0F10) : const Color(0xFFF3F4F6);
  static Color get surface    => isDark ? const Color(0xFF161719) : const Color(0xFFFFFFFF);
  static Color get surfaceAlt => isDark ? const Color(0xFF1D1E21) : const Color(0xFFF9FAFB);
  static Color get border     => isDark ? const Color(0xFF2A2B2F) : const Color(0xFFE5E7EB);
  static Color get borderSoft => isDark ? const Color(0xFF212225) : const Color(0xFFEEF0F2);

  static Color get textHi  => isDark ? const Color(0xFFECECEC) : const Color(0xFF111827);
  static Color get textMid => isDark ? const Color(0xFFA6A7AC) : const Color(0xFF4B5563);
  static Color get textLo  => isDark ? const Color(0xFF6E7075) : const Color(0xFF9CA3AF);

  // Brand orange
  static const brand       = Color(0xFFE65100);
  static const brandSoft   = Color(0xFFFF9800);

  // Semantic
  static const ok          = Color(0xFF4CAF50);
  static const warn        = Color(0xFFFF9800);
  static const info        = Color(0xFF4C8DFF);
  static const purple      = Color(0xFF9C27B0);
  static const indigo      = Color(0xFF5C6BC0);
  static const danger      = Color(0xFFF85149);

  static const rSm = 6.0;
  static const rMd = 8.0;

  static const stack = 'system-ui, -apple-system, "Segoe UI", "Helvetica Neue", Arial, sans-serif';

  static TextStyle get h1 => TextStyle(fontFamily: stack, fontSize: 18, fontWeight: FontWeight.w600, color: textHi, letterSpacing: -0.2, height: 1.2);
  static TextStyle get h2 => TextStyle(fontFamily: stack, fontSize: 15, fontWeight: FontWeight.w600, color: textHi, letterSpacing: -0.1);
  static TextStyle get h3 => TextStyle(fontFamily: stack, fontSize: 13, fontWeight: FontWeight.w600, color: textHi);
  static TextStyle get body => TextStyle(fontFamily: stack, fontSize: 14, color: textHi, height: 1.4);
  static TextStyle get bodySm => TextStyle(fontFamily: stack, fontSize: 12, color: textMid, height: 1.4);
  static TextStyle get label => TextStyle(fontFamily: stack, fontSize: 11, fontWeight: FontWeight.w600, color: textLo, letterSpacing: 0.4);
  static TextStyle get caption => TextStyle(fontFamily: stack, fontSize: 11, color: textLo, height: 1.4);
}

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 22, height: 22,
      child: CircularProgressIndicator(strokeWidth: 2, color: Tok.textLo),
    ),
  );
}

class EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const EmptyBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Tok.textLo),
            const SizedBox(height: 12),
            Text(title, style: Tok.h3, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(body, style: Tok.bodySm, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class StatusTag extends StatelessWidget {
  final String label;
  final Color color;
  const StatusTag({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Tok.rSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}