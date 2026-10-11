import 'package:flutter/material.dart';

class Tok {
  static bool isDark = true;

  // ── Surfaces ──────────────────────────────────────────────────────────
  static Color get bg         => isDark ? const Color(0xFF0E0F10) : const Color(0xFFF8FAFC);
  static Color get surface    => isDark ? const Color(0xFF161719) : const Color(0xFFFFFFFF);
  static Color get surfaceAlt => isDark ? const Color(0xFF1D1E21) : const Color(0xFFF1F5F9);
  static Color get border     => isDark ? const Color(0xFF2A2B2F) : const Color(0xFFE2E8F0);
  static Color get borderSoft => isDark ? const Color(0xFF212225) : const Color(0xFFF1F5F9);

  // ── Text ──────────────────────────────────────────────────────────────
  static Color get textHi  => isDark ? const Color(0xFFECECEC) : const Color(0xFF0F172A);
  static Color get textMid => isDark ? const Color(0xFFA6A7AC) : const Color(0xFF475569);
  static Color get textLo  => isDark ? const Color(0xFF6E7075) : const Color(0xFF94A3B8);

  static const brand       = Color(0xFFB3261E);
  static const ok          = Color(0xFF3FB950);
  static const warn        = Color(0xFFD29922);
  static const info        = Color(0xFF4C8DFF);

  static const rSm = 4.0;
  static const rMd = 6.0;
  static const rLg = 8.0;

  static const stack = 'system-ui, -apple-system, "Segoe UI", "Helvetica Neue", Arial, sans-serif';
  static TextStyle get h1     => TextStyle(fontFamily: stack, fontSize: 18, fontWeight: FontWeight.w600, color: textHi, letterSpacing: -0.2);
  static TextStyle get h2     => TextStyle(fontFamily: stack, fontSize: 14, fontWeight: FontWeight.w600, color: textHi, letterSpacing: -0.1);
  static TextStyle get label  => TextStyle(fontFamily: stack, fontSize: 10, fontWeight: FontWeight.w600, color: textLo, letterSpacing: 0.5);
  static TextStyle get bodySm => TextStyle(fontFamily: stack, fontSize: 12, color: textMid, height: 1.35);
  static TextStyle get num    => TextStyle(fontFamily: stack, fontSize: 24, fontWeight: FontWeight.w600, color: textHi, letterSpacing: -0.5, fontFeatures: const [FontFeature.tabularFigures()]);
}
