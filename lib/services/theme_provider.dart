import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../web/admin/admin_theme.dart' as admin_theme;
import '../web/clerk/clerk_theme.dart' as clerk_theme;
import '../web/establishment/establishment_theme.dart' as establishment_theme;
import '../web/fire_marshal/fire_marshal_theme.dart' as fire_marshal_theme;
import '../android/inspector/inspector_theme.dart' as inspector_theme;

/// Manages the app's ThemeMode and mirrors the state onto every token class.
///
/// `main.dart` must load the saved mode from SharedPreferences BEFORE
/// constructing the provider and pass it via `initialMode`. That way every
/// `Tok.isDark` flag is set correctly before the first widget builds, so the
/// app doesn't flash dark and then flip.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';

  /// Public so `main.dart` can read the same key without hardcoding the
  /// string. Prevents drift if `_key` is ever renamed.
  static const storageKey = _key;

  static final List<void Function(bool isDark)> _listeners = [];

  /// Register a listener. Call once per token class at app startup.
  static void registerThemeListener(void Function(bool isDark) listener) {
    _listeners.add(listener);
  }

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Construct with the initial mode already loaded from SharedPreferences.
  ///
  /// The constructor is synchronous on purpose: it applies the mode to every
  /// token class immediately, so the very first frame builds with the correct
  /// colors. No async load happens after construction.
  ThemeProvider({required ThemeMode initialMode}) : _themeMode = initialMode {
    _applyTheme(isDark: _themeMode == ThemeMode.dark);
  }

  Future<void> toggleTheme([bool? isDark]) async {
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    } else {
      _themeMode =
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    }

    // Apply synchronously so any widget that rebuilds in this frame already
    // sees the new Tok.isDark values.
    _applyTheme(isDark: _themeMode == ThemeMode.dark);
    notifyListeners();

    // Persist. Await the write so callers that reload the page afterward
    // (web) are guaranteed the new mode is on disk before navigation.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
      debugPrint(
          'THEME: saved as ${_themeMode == ThemeMode.dark ? "dark" : "light"}');
    } catch (e) {
      debugPrint('THEME: save failed — $e');
    }
  }

  void _applyTheme({required bool isDark}) {
    admin_theme.Tok.isDark = isDark;
    clerk_theme.Tok.isDark = isDark;
    establishment_theme.Tok.isDark = isDark;
    fire_marshal_theme.Tok.isDark = isDark;
    inspector_theme.Tok.isDark = isDark;
    for (final listener in _listeners) {
      listener(isDark);
    }
  }
}