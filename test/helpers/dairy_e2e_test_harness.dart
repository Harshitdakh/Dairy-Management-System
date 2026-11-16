import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milk_hub/l10n/app_localizations.dart';
import 'package:milk_hub/providers/billing_provider.dart';
import 'package:milk_hub/providers/customer_provider.dart';
import 'package:milk_hub/providers/pause_provider.dart';
import 'package:milk_hub/providers/route_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'in_memory_billing_repository.dart';
import 'in_memory_customer_repository.dart';
import 'in_memory_dairy_data_store.dart';
import 'in_memory_offline_queue_service.dart';
import 'in_memory_pause_repository.dart';
import 'in_memory_route_repository.dart';
import 'locale_notifier_helper.dart';

/// Shared helper for formatting customer stop sequence pill badges
String formatSequenceBadge(int sequence) => sequence > 0 ? '[$sequence]' : '[--]';

/// Fake platform interface implementation for WakelockPlus headless execution.
class FakeWakelockPlusPlatform extends WakelockPlusPlatformInterface {
  bool _enabled = false;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  bool get isMock => true;

  @override
  Future<void> toggle({required bool enable}) async {
    _enabled = enable;
    if (enable) {
      enableCalls++;
    } else {
      disableCalls++;
    }
  }

  @override
  Future<bool> get enabled async => _enabled;
}

class DairyE2ETestHarness {
  late InMemoryDairyDataStore dataStore;
  late InMemoryRouteRepository routeRepo;
  late InMemoryPauseRepository pauseRepo;
  late InMemoryCustomerRepository customerRepo;
  late InMemoryBillingRepository billingRepo;
  late InMemoryOfflineDeliveryQueueService offlineQueue;
  late LocaleNotifier localeNotifier;
  late FakeWakelockPlusPlatform fakeWakelock;

  bool get wakelockEnabled => fakeWakelock._enabled;
  set wakelockEnabled(bool value) => fakeWakelock._enabled = value;
  int get wakelockEnableCalls => fakeWakelock.enableCalls;
  int get wakelockDisableCalls => fakeWakelock.disableCalls;

  Future<void> setUp({Map<String, Object>? initialPrefs}) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(initialPrefs ?? {});
    GoogleFonts.config.allowRuntimeFetching = false;

    // Platform interface mock for wakelock_plus
    fakeWakelock = FakeWakelockPlusPlatform();
    WakelockPlusPlatformInterface.instance = fakeWakelock;
    wakelockPlusPlatformInstance = fakeWakelock;

    // Initialize headless dummy Supabase client to satisfy direct references
    try {
      await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
      );
    } catch (_) {
      // Already initialized or platform channel handled
    }

    dataStore = InMemoryDairyDataStore();
    dataStore.seedDefaults();

    routeRepo = InMemoryRouteRepository(dataStore);
    pauseRepo = InMemoryPauseRepository(dataStore);
    customerRepo = InMemoryCustomerRepository(dataStore);
    billingRepo = InMemoryBillingRepository(dataStore);
    offlineQueue = InMemoryOfflineDeliveryQueueService(dataStore, billingRepo);
    localeNotifier = LocaleNotifier();
  }

  void tearDown() {
    fakeWakelock._enabled = false;
    fakeWakelock.enableCalls = 0;
    fakeWakelock.disableCalls = 0;
    try {
      offlineQueue.dispose();
    } catch (_) {}
    try {
      dataStore.reset();
    } catch (_) {}
  }

  List<Override> get overrides => [
        routeRepositoryProvider.overrideWithValue(routeRepo),
        pauseRepositoryProvider.overrideWithValue(pauseRepo),
        customerRepositoryProvider.overrideWithValue(customerRepo),
        billingRepositoryProvider.overrideWithValue(billingRepo),
        offlineDeliveryQueueServiceProvider.overrideWithValue(offlineQueue),
        localeProvider.overrideWith((ref) => localeNotifier),
      ];

  Widget createTestWidget({required Widget child, Locale? locale}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale ?? const Locale('hi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: child),
      ),
    );
  }
}
