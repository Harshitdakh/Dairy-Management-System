import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milk_hub/config/theme.dart';
import 'package:milk_hub/features/common/settings_screen.dart';
import 'package:milk_hub/l10n/l10n.dart';
import 'package:milk_hub/models/profile.dart';
import 'package:milk_hub/providers/auth_provider.dart';
import 'package:milk_hub/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocaleNotifier Unit Tests', () {
    test('Initial state defaults to Hindi (hi) and isHindi is true', () {
      final notifier = LocaleNotifier();
      expect(notifier.state, equals(const Locale('hi')));
      expect(notifier.isHindi, isTrue);
      expect(notifier.state.languageCode, equals('hi'));
    });

    test('Initial state respects explicit initialLocale constructor argument', () {
      final notifier = LocaleNotifier(const Locale('en'));
      expect(notifier.state, equals(const Locale('en')));
      expect(notifier.isHindi, isFalse);
    });

    test('toggleLocale() alternates cleanly between hi and en with persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = LocaleNotifier();
      expect(notifier.state, equals(const Locale('hi')));

      // First toggle: hi -> en
      await notifier.toggleLocale();
      expect(notifier.state, equals(const Locale('en')));
      expect(notifier.isHindi, isFalse);

      final prefs1 = await SharedPreferences.getInstance();
      expect(prefs1.getString(LocaleNotifier.prefKey), equals('en'));
      expect(prefs1.getString(LocaleNotifier.fallbackPrefKey), equals('en'));

      // Second toggle: en -> hi
      await notifier.toggleLocale();
      expect(notifier.state, equals(const Locale('hi')));
      expect(notifier.isHindi, isTrue);

      final prefs2 = await SharedPreferences.getInstance();
      expect(prefs2.getString(LocaleNotifier.prefKey), equals('hi'));
      expect(prefs2.getString(LocaleNotifier.fallbackPrefKey), equals('hi'));
    });

    test('setLocale() updates state and persists valid codes to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = LocaleNotifier();

      await notifier.setLocale(const Locale('en'));
      expect(notifier.state, equals(const Locale('en')));
      expect(notifier.isHindi, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_locale_code'), equals('en'));
      expect(prefs.getString('app_locale'), equals('en'));

      await notifier.setLocale(const Locale('hi'));
      expect(notifier.state, equals(const Locale('hi')));
      expect(notifier.isHindi, isTrue);
      expect(prefs.getString('selected_locale_code'), equals('hi'));
    });

    test('setLocale() safely falls back to Hindi on invalid or corrupted codes', () async {
      SharedPreferences.setMockInitialValues({'selected_locale_code': 'en'});
      final notifier = LocaleNotifier(const Locale('en'));
      expect(notifier.state, equals(const Locale('en')));

      // Unsupported foreign language
      await notifier.setLocale(const Locale('fr_FR'));
      expect(notifier.state, equals(const Locale('hi')));
      expect(notifier.isHindi, isTrue);

      // Corrupted characters
      await notifier.setLocale(const Locale('!@#\$%'));
      expect(notifier.state, equals(const Locale('hi')));
      expect(notifier.isHindi, isTrue);

      // Random string
      await notifier.setLocale(const Locale('unknown'));
      expect(notifier.state, equals(const Locale('hi')));
      expect(notifier.isHindi, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_locale_code'), equals('hi'));
    });

    test('loadInitialLocale() returns Hindi on empty storage (cold start)', () async {
      SharedPreferences.setMockInitialValues({});
      final locale = await LocaleNotifier.loadInitialLocale();
      expect(locale, equals(const Locale('hi')));
    });

    test('loadInitialLocale() loads English when selected_locale_code is en', () async {
      SharedPreferences.setMockInitialValues({'selected_locale_code': 'en'});
      final locale = await LocaleNotifier.loadInitialLocale();
      expect(locale, equals(const Locale('en')));
    });

    test('loadInitialLocale() loads English when fallback app_locale is en', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});
      final locale = await LocaleNotifier.loadInitialLocale();
      expect(locale, equals(const Locale('en')));
    });

    test('loadInitialLocale() falls back to Hindi on unsupported or corrupted codes', () async {
      SharedPreferences.setMockInitialValues({'selected_locale_code': 'de_DE'});
      final locale = await LocaleNotifier.loadInitialLocale();
      expect(locale, equals(const Locale('hi')));
    });

    test('Riverpod container correctly binds localeProvider and reacts to state changes', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial read
      expect(container.read(localeProvider), equals(const Locale('hi')));

      // Mutate via notifier
      await container.read(localeProvider.notifier).setLocale(const Locale('en'));
      expect(container.read(localeProvider), equals(const Locale('en')));

      // Toggle back
      await container.read(localeProvider.notifier).toggleLocale();
      expect(container.read(localeProvider), equals(const Locale('hi')));
    });
  });

  group('AppTheme Dairy Semantic Colors Tests', () {
    test('Semantic color constants and background tints match specifications', () {
      expect(AppTheme.delivered, equals(const Color(0xFF10B981)));
      expect(AppTheme.deliveredBg, equals(const Color(0xFFECFDF5)));
      expect(AppTheme.cowMilk, equals(const Color(0xFFD97706)));
      expect(AppTheme.cowMilkBg, equals(const Color(0xFFFEF3C7)));
      expect(AppTheme.buffaloMilk, equals(const Color(0xFF06B6D4)));
      expect(AppTheme.buffaloMilkBg, equals(const Color(0xFFCFFAFE)));
      expect(AppTheme.skipped, equals(const Color(0xFFEF4444)));
      expect(AppTheme.skippedBg, equals(const Color(0xFFFEE2E2)));
      expect(AppTheme.paused, equals(const Color(0xFFEF4444)));
    });

    test('getMilkColor and getMilkBgColor return appropriate colors by milk type', () {
      expect(AppTheme.getMilkColor('cow'), equals(AppTheme.cowMilk));
      expect(AppTheme.getMilkColor('Cow'), equals(AppTheme.cowMilk));
      expect(AppTheme.getMilkColor('buffalo'), equals(AppTheme.buffaloMilk));
      expect(AppTheme.getMilkColor('BUFFALO'), equals(AppTheme.buffaloMilk));
      expect(AppTheme.getMilkColor('other'), equals(AppTheme.cowMilk));

      expect(AppTheme.getMilkBgColor('cow'), equals(AppTheme.cowMilkBg));
      expect(AppTheme.getMilkBgColor('buffalo'), equals(AppTheme.buffaloMilkBg));
    });
  });

  group('AppLocalizations & context.l10n Dairy Glossary Tests', () {
    testWidgets('AppLocalizations provides complete Devanagari dairy glossary in Hindi', (tester) async {
      late AppLocalizations localizations;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('hi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              localizations = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );

      // Dairy delivery & status actions
      expect(localizations.delivered, equals('✔ दिया'));
      expect(localizations.notDeliveredToday, equals('✕ आज नहीं लिया'));
      expect(localizations.skipped, equals('नहीं लिया'));
      expect(localizations.pausedVacation, equals('⛔ आज दूध बंद (छुट्टी)'));
      expect(localizations.vacation, equals('छुट्टी (अवकाश)'));

      // Milk varieties
      expect(localizations.cowMilk, equals('गाय का दूध'));
      expect(localizations.buffaloMilk, equals('भैंस का दूध'));
      expect(localizations.mixedMilk, equals('मिश्रित दूध'));

      // Delivery shifts
      expect(localizations.morningShift, equals('सुबह'));
      expect(localizations.eveningShift, equals('शाम'));
      expect(localizations.bothShifts, equals('दोनों समय'));

      // Billing & collection
      expect(localizations.cashCollected, equals('नकद मिला'));
      expect(localizations.doorstepCashCollected, equals('नकद मिला'));
      expect(localizations.payViaUpi, equals('UPI द्वारा भुगतान करें'));
      expect(localizations.shareInvoiceWhatsapp, equals('WhatsApp पर बिल भेजें'));
      expect(localizations.monthlyBill, equals('मासिक बिल'));
      expect(localizations.pendingAmount, equals('बाकी राशि'));
      expect(localizations.paidAmount, equals('जमा राशि'));
      expect(localizations.totalAmount, equals('कुल राशि'));

      // Route management
      expect(localizations.route, equals('मार्ग'));
      expect(localizations.routes, equals('वितरण मार्ग'));
      expect(localizations.stopSequence, equals('स्टॉप क्रम'));
      expect(localizations.customerSequence, equals('ग्राहक क्रम'));
      expect(localizations.routeCustomers, equals('मार्ग के ग्राहक'));

      // Parameterized formatting
      expect(localizations.welcomeUser('रामेश'), equals('स्वागत है, रामेश'));
      expect(localizations.stopSequenceBadge(3), equals('स्टॉप #3'));
      expect(localizations.formatRupees('550'), equals('₹550'));
      expect(localizations.formatLiters('2.5'), equals('2.5 लीटर'));
    });

    testWidgets('AppLocalizations provides complete English dairy glossary in English', (tester) async {
      late AppLocalizations localizations;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              localizations = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );

      // Dairy delivery & status actions
      expect(localizations.delivered, equals('✔ Delivered'));
      expect(localizations.notDeliveredToday, equals('✕ Skipped Today'));
      expect(localizations.skipped, equals('Skipped'));
      expect(localizations.pausedVacation, equals('⛔ Milk Paused (Vacation)'));
      expect(localizations.vacation, equals('Vacation'));

      // Milk varieties
      expect(localizations.cowMilk, equals('Cow Milk'));
      expect(localizations.buffaloMilk, equals('Buffalo Milk'));
      expect(localizations.mixedMilk, equals('Mixed Milk'));

      // Delivery shifts
      expect(localizations.morningShift, equals('Morning'));
      expect(localizations.eveningShift, equals('Evening'));
      expect(localizations.bothShifts, equals('Both Shifts'));

      // Billing & collection
      expect(localizations.cashCollected, equals('Cash Collected'));
      expect(localizations.doorstepCashCollected, equals('Doorstep Cash Collected'));
      expect(localizations.payViaUpi, equals('Pay via UPI'));
      expect(localizations.shareInvoiceWhatsapp, equals('Share Invoice on WhatsApp'));
      expect(localizations.monthlyBill, equals('Monthly Bill'));
      expect(localizations.pendingAmount, equals('Pending Amount'));
      expect(localizations.paidAmount, equals('Paid Amount'));
      expect(localizations.totalAmount, equals('Total Amount'));

      // Route management
      expect(localizations.route, equals('Route'));
      expect(localizations.routes, equals('Routes'));
      expect(localizations.stopSequence, equals('Stop Sequence'));
      expect(localizations.customerSequence, equals('Customer Sequence'));
      expect(localizations.routeCustomers, equals('Route Customers'));

      // Parameterized formatting
      expect(localizations.welcomeUser('Ramesh'), equals('Welcome, Ramesh'));
      expect(localizations.stopSequenceBadge(3), equals('Stop #3'));
      expect(localizations.formatRupees('550'), equals('₹550'));
      expect(localizations.formatLiters('2.5'), equals('2.5 L'));
    });
  });

  group('SettingsScreen Widget Tests', () {
    testWidgets('Renders bilingual options and toggles language dynamically', (tester) async {
      final mockProfile = Profile(
        id: 'test-admin',
        role: 'admin',
        fullName: 'Rajesh Sharma',
        phone: '+919876543210',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => Future.value(mockProfile)),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final locale = ref.watch(localeProvider);
              return MaterialApp(
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: const SettingsScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Hindi default
      expect(find.text('सेटिंग्स'), findsOneWidget);
      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('हिंदी (Hindi)'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('लॉगआउट'), findsOneWidget);

      // Tap English option
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // UI updates to English
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
      expect(find.text('Ends session and clears Remember Me'), findsOneWidget);

      // Tap Hindi option back
      await tester.tap(find.text('हिंदी (Hindi)'));
      await tester.pumpAndSettle();

      // UI updates back to Hindi
      expect(find.text('सेटिंग्स'), findsOneWidget);
      expect(find.text('लॉगआउट'), findsOneWidget);
    });
  });
}
