import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the application locale state with Hindi-first default and
/// persistent SharedPreferences storage.
class LocaleNotifier extends StateNotifier<Locale> {
  static const String prefKey = 'selected_locale_code';
  static const String fallbackPrefKey = 'app_locale';

  LocaleNotifier([Locale? initialLocale])
      : super(_sanitizeInitialLocale(initialLocale)) {
    if (initialLocale == null) {
      _loadPersistedLocale();
    }
  }

  static Locale _sanitizeInitialLocale(Locale? locale) {
    if (locale == null) return const Locale('hi');
    final code = locale.languageCode;
    return (code == 'en' || code == 'hi') ? Locale(code) : const Locale('hi');
  }

  /// Whether current active locale is Hindi.
  bool get isHindi => state.languageCode == 'hi';

  /// Asynchronously loads saved locale from SharedPreferences on initialization.
  Future<void> _loadPersistedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(prefKey) ?? prefs.getString(fallbackPrefKey);
      if (code == 'en' || code == 'hi') {
        if (mounted) {
          state = Locale(code!);
        }
      }
    } catch (_) {
      // Retain default locale if SharedPreferences is unavailable
    }
  }

  /// Toggles between Hindi and English at runtime and persists choice.
  Future<void> toggleLocale() async {
    if (state.languageCode == 'hi') {
      await setLocale(const Locale('en'));
    } else {
      await setLocale(const Locale('hi'));
    }
  }

  /// Explicitly sets the active locale and persists it.
  /// Falls back safely to Hindi for unsupported or corrupted locale codes.
  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode;
    final validCode = (code == 'hi' || code == 'en') ? code : 'hi';

    state = Locale(validCode);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, validCode);
      await prefs.setString(fallbackPrefKey, validCode);
    } catch (_) {
      // Ignored in non-persistent testing environments
    }
  }

  /// Helper to synchronously or asynchronously query persisted locale on cold start.
  static Future<Locale> loadInitialLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode =
          prefs.getString(prefKey) ?? prefs.getString(fallbackPrefKey);
      if (savedCode == 'en') {
        return const Locale('en');
      }
    } catch (_) {}
    return const Locale('hi');
  }
}

/// Global provider exposing the active [Locale] and [LocaleNotifier].
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
