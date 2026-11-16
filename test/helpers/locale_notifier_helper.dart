import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  static const String prefKey = 'selected_locale_code';

  LocaleNotifier([Locale? initialLocale])
      : super(initialLocale ?? const Locale('hi'));

  bool get isHindi => state.languageCode == 'hi';

  Future<void> toggleLocale() async {
    if (state.languageCode == 'hi') {
      await setLocale(const Locale('en'));
    } else {
      await setLocale(const Locale('hi'));
    }
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode;
    // Fall back safely to Hindi if unsupported or corrupted
    if (code != 'hi' && code != 'en') {
      state = const Locale('hi');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, 'hi');
      return;
    }

    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, code);
  }

  static Future<Locale> loadInitialLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(prefKey);

    if (savedCode == 'en') {
      return const Locale('en');
    }
    // Hindi-first default
    return const Locale('hi');
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

/// Indian Dairy Vernacular Glossary & Localization Verification Helper
class DairyGlossary {
  static const Map<String, Map<String, String>> translations = {
    'delivered_action': {
      'hi': '✔ दिया',
      'en': '✔ Delivered',
    },
    'skip_action': {
      'hi': 'आज नहीं लिया',
      'en': 'Skipped Today',
    },
    'vacation_badge': {
      'hi': 'दूध बंद (छुट्टी)',
      'en': 'Milk Paused (Vacation)',
    },
    'cow_milk': {
      'hi': 'गाय का दूध',
      'en': 'Cow Milk',
    },
    'buffalo_milk': {
      'hi': 'भैंस का दूध',
      'en': 'Buffalo Milk',
    },
    'mixed_milk': {
      'hi': 'मिश्रित दूध',
      'en': 'Mixed Milk',
    },
    'bill': {
      'hi': 'हिसाब',
      'en': 'Bill',
    },
    'pending': {
      'hi': 'बकाया',
      'en': 'Pending Due',
    },
    'collected': {
      'hi': 'नकद मिला',
      'en': 'Cash Collected',
    },
    'morning': {
      'hi': 'सुबह',
      'en': 'Morning',
    },
    'evening': {
      'hi': 'शाम',
      'en': 'Evening',
    },
    'both': {
      'hi': 'दोनों समय',
      'en': 'Both Shifts',
    },
    'approve': {
      'hi': 'मंजूर करें',
      'en': 'Approve',
    },
    'reject': {
      'hi': 'अस्वीकार करें',
      'en': 'Reject',
    },
    'route_customers': {
      'hi': 'वितरण मार्ग ग्राहक',
      'en': 'Route Customers',
    },
  };

  static String get(String key, String langCode) {
    final dict = translations[key];
    if (dict == null) return key;
    return dict[langCode] ?? dict['en'] ?? key;
  }

  static String formatVolumeAmount({
    required num liters,
    required num ml,
    required num amount,
    required String langCode,
  }) {
    if (langCode == 'hi') {
      return '✔ दिया ($liters L $ml ml) - ₹${amount.toStringAsFixed(0)}';
    } else {
      return '✔ Delivered ($liters L $ml ml) - ₹${amount.toStringAsFixed(0)}';
    }
  }
}
