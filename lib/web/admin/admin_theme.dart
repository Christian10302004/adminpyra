import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Mode-aware token class for the web/admin shell.
//
// `Tok.isDark` is set by ThemeProvider on init and on every toggle. The
// getters below return light or dark values accordingly. Widgets that read
// `Tok.bg` and friends inside `build()` pick up the new colors on the next
// frame, because `MaterialApp` rebuilds the whole tree when `themeMode`
// changes and the Consumer<ThemeProvider> in main.dart fires.
// ---------------------------------------------------------------------------
class Tok {
  /// Set by ThemeProvider. Never read this directly — read the getters.
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

  // ── Brand (identical in both modes) ───────────────────────────────────
  static const brand    = Color(0xFFB3261E);
  static const brandDim = Color(0xFF7A1A15);

  // ── Semantic (identical in both modes) ────────────────────────────────
  static const ok     = Color(0xFF3FB950);
  static const warn   = Color(0xFFD29922);
  static const info   = Color(0xFF4C8DFF);
  static const danger = Color(0xFFF85149);
  static const purple = Color(0xFF8B5CF6);

  // ── Status colors ─────────────────────────────────────────────────────
  static const stPending   = Color(0xFFD29922);
  static const stApproved  = Color(0xFF4C8DFF);
  static const stAssigned  = Color(0xFF8B5CF6);
  static const stCompleted = Color(0xFF3FB950);

  // ── Radii ─────────────────────────────────────────────────────────────
  static const rSm = 4.0;
  static const rMd = 6.0;
  static const rLg = 8.0;

  // ── Spacing ───────────────────────────────────────────────────────────
  static const gap2  = 2.0;
  static const gap4  = 4.0;
  static const gap6  = 6.0;
  static const gap8  = 8.0;
  static const gap12 = 12.0;
  static const gap16 = 16.0;
  static const gap20 = 20.0;
  static const gap24 = 24.0;
  static const gap32 = 32.0;

  // ── Typography ────────────────────────────────────────────────────────
  static const stack = 'system-ui, -apple-system, "Segoe UI", "Helvetica Neue", Arial, sans-serif';

  static TextStyle get h1 => TextStyle(
    fontFamily: stack,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textHi,
    letterSpacing: -0.2,
    height: 1.2,
  );
  static TextStyle get h2 => TextStyle(
    fontFamily: stack,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textHi,
    letterSpacing: -0.1,
    height: 1.25,
  );
  static TextStyle get body => TextStyle(
    fontFamily: stack,
    fontSize: 13,
    color: textHi,
    height: 1.4,
  );
  static TextStyle get bodySm => TextStyle(
    fontFamily: stack,
    fontSize: 12,
    color: textMid,
    height: 1.35,
  );
  static TextStyle get label => TextStyle(
    fontFamily: stack,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textLo,
    letterSpacing: 0.4,
  );
  static TextStyle get caption => TextStyle(
    fontFamily: stack,
    fontSize: 11,
    color: textLo,
    height: 1.4,
  );
  static TextStyle get num => TextStyle(
    fontFamily: stack,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textHi,
    letterSpacing: -0.5,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static TextStyle get numSm => TextStyle(
    fontFamily: stack,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textHi,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

// ---------------------------------------------------------------------------
// Shared decoration used across admin views.
// ---------------------------------------------------------------------------
BoxDecoration get flatBox => BoxDecoration(
  color: Tok.surface,
  borderRadius: BorderRadius.circular(Tok.rMd),
  border: Border.all(color: Tok.border),
);

// ---------------------------------------------------------------------------
// Empty state — used by admin views.
// ---------------------------------------------------------------------------
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const EmptyState({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: Tok.textLo),
          const SizedBox(height: 8),
          Text(label, style: Tok.bodySm.copyWith(color: Tok.textLo)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel — the one container primitive used by the admin shell.
// ---------------------------------------------------------------------------
class Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool padded;

  const Panel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rLg),
        border: Border.all(color: Tok.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Tok.h2),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Tok.bodySm.copyWith(
                            color: Tok.textLo,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, color: Tok.borderSoft),
          Padding(
            padding: padded ? const EdgeInsets.all(20) : EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );
  }
}