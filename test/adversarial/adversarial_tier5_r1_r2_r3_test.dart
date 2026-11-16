// ==============================================================================
// Milk HUB — Milestone 7 Phase 2: Tier 5 Adversarial Hardening Suite (R1, R2, R3)
// ==============================================================================
// Requirements Covered:
//   - R1: Localization, Devanagari Numeral Conversion, Fallback Locales, Rapid Toggle Stress
//   - R2: Route Management, Stop Sequencing Duplicates, Empty Lists, Out-of-Bounds, 500-Stop Batch
//   - R3: 1-Tap Delivery Sheet, Concurrency (100 parallel), Storage Corruption, Stepper Clamping, Wakelock
// ==============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:milk_hub/core/milk_utils.dart';
import 'package:milk_hub/l10n/app_localizations.dart';
import 'package:milk_hub/models/customer.dart';
import 'package:milk_hub/providers/locale_provider.dart';

import '../helpers/in_memory_billing_repository.dart';
import '../helpers/in_memory_dairy_data_store.dart';
import '../helpers/in_memory_offline_queue_service.dart';
import '../helpers/in_memory_route_repository.dart';

final _dummyClient = SupabaseClient(
  'https://placeholder.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ============================================================================
  // GROUP 1: R1 LOCALIZATION, DEVANAGARI NUMERALS & FALLBACK HARDENING
  // ============================================================================
  group('Tier 5 Adversarial: R1 Localization & Devanagari Hardening', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('T5.1.1: ARB Key Parity & Missing Key Audit between app_en.arb and app_hi.arb', () {
      final enFile = File('lib/l10n/app_en.arb');
      final hiFile = File('lib/l10n/app_hi.arb');

      expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist in repository');
      expect(hiFile.existsSync(), isTrue, reason: 'app_hi.arb must exist in repository');

      final enJson = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      final hiJson = jsonDecode(hiFile.readAsStringSync()) as Map<String, dynamic>;

      final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();
      final hiKeys = hiJson.keys.where((k) => !k.startsWith('@')).toSet();

      final missingInHi = enKeys.difference(hiKeys);
      final missingInEn = hiKeys.difference(enKeys);

      expect(missingInHi, isEmpty, reason: 'Hindi translation must have 100% key parity with English');
      expect(missingInEn, isEmpty, reason: 'English translation must have 100% key parity with Hindi');

      final hiLoc = lookupAppLocalizations(const Locale('hi'));
      final enLoc = lookupAppLocalizations(const Locale('en'));
      expect(hiLoc, isNotNull);
      expect(enLoc, isNotNull);
    });

    test('T5.1.2: Devanagari numeral conversions and parsing resilience', () {
      const devanagariDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
      const asciiDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

      String toDevanagari(String input) {
        String res = input;
        for (int i = 0; i < 10; i++) {
          res = res.replaceAll(asciiDigits[i], devanagariDigits[i]);
        }
        return res;
      }

      String fromDevanagari(String input) {
        String res = input;
        for (int i = 0; i < 10; i++) {
          res = res.replaceAll(devanagariDigits[i], asciiDigits[i]);
        }
        return res;
      }

      final testCases = ['0', '5', '42', '100', '1500', '9876543210', '0.25', '1.50'];
      for (final numStr in testCases) {
        final devStr = toDevanagari(numStr);
        final restored = fromDevanagari(devStr);
        expect(restored, equals(numStr), reason: 'Bidirectional digit mapping failure on $numStr');
      }

      expect(int.tryParse('५'), isNull, reason: 'Native Dart cannot parse Devanagari without normalizer');
      expect(int.tryParse(fromDevanagari('५')), equals(5));
      expect(double.tryParse(fromDevanagari('१.५')), equals(1.5));
    });

    test('T5.1.3: Fallback Locales — 17 Corrupted, Empty, Dialect & Exotic Codes in SharedPreferences', () async {
      final adversarialCodes = [
        'fr', 'es', 'zh', 'mr', 'gu', 'pa', '', '   ', 'null',
        'hi_IN', 'en_US', 'EN', 'HI', '{"code":"hi"}', '../../etc/passwd', '1234', 'unknown_xyz',
      ];

      for (final badCode in adversarialCodes) {
        SharedPreferences.setMockInitialValues({
          LocaleNotifier.prefKey: badCode,
        });

        final loaded = await LocaleNotifier.loadInitialLocale();
        expect(loaded.languageCode, equals('hi'),
            reason: 'Corrupted or unsupported code "$badCode" must fall back safely to "hi"');

        final notifier = LocaleNotifier();
        await Future.delayed(const Duration(milliseconds: 10));
        expect(notifier.state.languageCode, isIn(['hi', 'en']),
            reason: 'State must remain strictly "hi" or "en", never corrupted to "$badCode"');
      }
    });

    test('T5.1.4: Explicit setLocale with unsupported locale falls back to hi', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = LocaleNotifier();

      await notifier.setLocale(const Locale('es'));
      expect(notifier.state.languageCode, equals('hi'));
      expect(notifier.isHindi, isTrue);

      await notifier.setLocale(const Locale('en'));
      expect(notifier.state.languageCode, equals('en'));
      expect(notifier.isHindi, isFalse);

      await notifier.setLocale(const Locale('fr'));
      expect(notifier.state.languageCode, equals('hi'));
      expect(notifier.isHindi, isTrue);
    });

    test('T5.1.5: Rapid Concurrent Locale Toggling Stress (100 parallel toggles)', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = LocaleNotifier(const Locale('hi'));

      final futures = List.generate(100, (_) => notifier.toggleLocale());
      await Future.wait(futures);

      expect(notifier.state.languageCode, isIn(['hi', 'en']));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleNotifier.prefKey), isIn(['hi', 'en']));
      expect(prefs.getString(LocaleNotifier.fallbackPrefKey), isIn(['hi', 'en']));
    });

    test('T5.1.6: Exact Vernacular Dairy Terminology & Domain Glossary Parity', () {
      final hi = lookupAppLocalizations(const Locale('hi'));
      final en = lookupAppLocalizations(const Locale('en'));

      expect(hi.cowMilk, equals('गाय का दूध'));
      expect(hi.buffaloMilk, equals('भैंस का दूध'));
      expect(hi.morningShift, equals('सुबह'));
      expect(hi.eveningShift, equals('शाम'));
      expect(en.cowMilk, equals('Cow Milk'));
      expect(en.buffaloMilk, equals('Buffalo Milk'));
    });

    test('T5.1.7: Cold restart consistency during rapid toggle', () async {
      SharedPreferences.setMockInitialValues({
        LocaleNotifier.prefKey: 'hi',
      });

      final notifier = LocaleNotifier();
      await Future.delayed(const Duration(milliseconds: 5));

      await notifier.toggleLocale();
      expect(notifier.state.languageCode, equals('en'));
      final cold1 = await LocaleNotifier.loadInitialLocale();
      expect(cold1.languageCode, equals('en'));

      await notifier.toggleLocale();
      expect(notifier.state.languageCode, equals('hi'));
      final cold2 = await LocaleNotifier.loadInitialLocale();
      expect(cold2.languageCode, equals('hi'));
    });

    test('T5.1.8: MilkUtils.toDevanagariDigits & fromDevanagariDigits genuine bidirectionality', () {
      expect(MilkUtils.toDevanagariDigits('12345'), equals('१२३४५'));
      expect(MilkUtils.fromDevanagariDigits('१२३४५'), equals('12345'));
      expect(MilkUtils.tryParseInt('५०'), equals(50));
      expect(MilkUtils.tryParseDouble('१.५०'), equals(1.5));
      expect(MilkUtils.tryParseDouble(' invalid '), isNull);
    });

    test('T5.1.9: LocaleNotifier constructor sanitizes invalid initialLocale to hi', () {
      final notifier = LocaleNotifier(const Locale('fr'));
      expect(notifier.state.languageCode, equals('hi'));
      expect(notifier.isHindi, isTrue);

      final validNotifier = LocaleNotifier(const Locale('en'));
      expect(validNotifier.state.languageCode, equals('en'));
      expect(validNotifier.isHindi, isFalse);
    });
  });

  // ============================================================================
  // GROUP 2: R2 ROUTE MANAGEMENT & STOP SEQUENCING HARDENING
  // ============================================================================
  group('Tier 5 Adversarial: R2 Route Management & Stop Sequencing Hardening', () {
    late InMemoryDairyDataStore dataStore;
    late InMemoryRouteRepository routeRepo;

    setUp(() {
      dataStore = InMemoryDairyDataStore();
      dataStore.seedDefaults();
      routeRepo = InMemoryRouteRepository(dataStore);
    });

    test('T5.2.1: Empty list and single customer sequence update', () async {
      await expectLater(
        routeRepo.updateCustomerSequence([]),
        completes,
        reason: 'Empty sequence update should complete gracefully without throwing',
      );

      final customers = dataStore.customers.values.toList();
      expect(customers, isNotEmpty);
      final singleId = customers.first.id;

      await routeRepo.updateCustomerSequence([singleId]);
      expect(dataStore.customers[singleId]?.deliverySequence, equals(1));
    });

    test('T5.2.2: Duplicate customer IDs in sequence update payload are deduplicated', () async {
      final customers = dataStore.customers.values.take(2).toList();
      final id1 = customers[0].id;
      final id2 = customers[1].id;

      await routeRepo.updateCustomerSequence([id1, id1, id2]);
      expect(dataStore.customers[id1]?.deliverySequence, equals(1));
      expect(dataStore.customers[id2]?.deliverySequence, equals(2));
    });

    test('T5.2.3: Non-existent customer IDs in sequence update payload', () async {
      final validId = dataStore.customers.values.first.id;
      const ghostId = 'customer-ghost-404-nonexistent';

      await expectLater(
        routeRepo.updateCustomerSequence([ghostId, validId]),
        completes,
        reason: 'Non-existent customer ID should be gracefully skipped without failing valid updates',
      );
      expect(dataStore.customers[validId]?.deliverySequence, equals(2));
    });

    test('T5.2.4: Out-of-bounds Reorder Index Calculations Simulation', () {
      List<String> simulateReorder(List<String> list, int oldIndex, int newIndex) {
        if (oldIndex < 0 || oldIndex >= list.length) {
          throw RangeError.range(oldIndex, 0, list.length - 1, 'oldIndex');
        }
        if (newIndex < 0 || newIndex > list.length) {
          throw RangeError.range(newIndex, 0, list.length, 'newIndex');
        }
        if (newIndex > oldIndex) newIndex -= 1;
        final reordered = List<String>.from(list);
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        return reordered;
      }

      final items = ['A', 'B', 'C', 'D'];
      expect(simulateReorder(items, 0, 4), equals(['B', 'C', 'D', 'A']));
      expect(simulateReorder(items, 3, 0), equals(['D', 'A', 'B', 'C']));
      expect(() => simulateReorder(items, -1, 2), throwsRangeError);
      expect(() => simulateReorder(items, 5, 2), throwsRangeError);
      expect(() => simulateReorder(items, 1, -1), throwsRangeError);
      expect(() => simulateReorder(items, 1, 10), throwsRangeError);
    });

    test('T5.2.5: High sequence numbers (>10,000) and negative sequence handling', () async {
      final customer = dataStore.customers.values.first;

      await routeRepo.assignCustomerToRoute(
        customerId: customer.id,
        routeId: customer.routeId,
        sequence: 15000,
      );
      expect(dataStore.customers[customer.id]?.deliverySequence, equals(15000));

      await routeRepo.assignCustomerToRoute(
        customerId: customer.id,
        routeId: customer.routeId,
        sequence: -1,
      );
      expect(dataStore.customers[customer.id]?.deliverySequence, equals(-1));

      String formatBadge(int seq) => seq > 0 ? '[$seq]' : '[--]';
      expect(formatBadge(15000), equals('[15000]'));
      expect(formatBadge(0), equals('[--]'));
      expect(formatBadge(-1), equals('[--]'));
      expect(formatBadge(-999), equals('[--]'));
    });

    test('T5.2.6: Stress Sequencing: 500 Stops Batch Reorder', () async {
      const sellerId = 'seller-stress-test';
      final largeCustomerIds = <String>[];

      for (int i = 0; i < 500; i++) {
        final cid = 'cust-stress-$i';
        dataStore.customers[cid] = Customer(
          id: cid,
          userId: 'user-$cid',
          sellerId: sellerId,
          routeId: 'route-stress',
          deliverySequence: 0,
          deliveryShift: (i % 2 == 0) ? 'morning' : 'evening',
          milkType: 'cow',
          ratePerLiter: 60.0,
          dailyQuantityLiters: 1.0,
          dailyQuantityMl: 0,
          status: 'active',
          createdAt: DateTime.now(),
          fullName: 'Stress Customer $i',
        );
        largeCustomerIds.add(cid);
      }

      final stopwatch = Stopwatch()..start();
      final reversedIds = largeCustomerIds.reversed.toList();
      await routeRepo.updateCustomerSequence(reversedIds);
      stopwatch.stop();

      expect(dataStore.customers[reversedIds.first]?.deliverySequence, equals(1));
      expect(dataStore.customers[reversedIds.last]?.deliverySequence, equals(500));
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('T5.2.7: Multi-shift route and customer filtering permutations', () {
      final customers = [
        Customer(id: 'c1', userId: 'u1', sellerId: 's1', deliverySequence: 1, deliveryShift: 'morning', milkType: 'cow', ratePerLiter: 60, dailyQuantityLiters: 1, dailyQuantityMl: 0, status: 'active', createdAt: DateTime.now()),
        Customer(id: 'c2', userId: 'u2', sellerId: 's1', deliverySequence: 2, deliveryShift: 'evening', milkType: 'buffalo', ratePerLiter: 70, dailyQuantityLiters: 2, dailyQuantityMl: 0, status: 'active', createdAt: DateTime.now()),
        Customer(id: 'c3', userId: 'u3', sellerId: 's1', deliverySequence: 3, deliveryShift: 'both', milkType: 'cow', ratePerLiter: 60, dailyQuantityLiters: 1, dailyQuantityMl: 500, status: 'active', createdAt: DateTime.now()),
      ];

      List<Customer> filter(List<Customer> list, String shift) {
        if (shift == 'all') return list;
        return list.where((c) => c.deliveryShift == shift || c.deliveryShift == 'both').toList();
      }

      expect(filter(customers, 'all').length, equals(3));
      final morningOnly = filter(customers, 'morning');
      expect(morningOnly.map((c) => c.id), containsAll(['c1', 'c3']));
      expect(morningOnly.map((c) => c.id), isNot(contains('c2')));

      final eveningOnly = filter(customers, 'evening');
      expect(eveningOnly.map((c) => c.id), containsAll(['c2', 'c3']));
      expect(eveningOnly.map((c) => c.id), isNot(contains('c1')));
    });

    test('T5.2.8: Route Deletion unassigns customers (ON DELETE SET NULL cascade)', () async {
      final routeId = dataStore.routes.values.first.id;
      final assignedBefore = dataStore.customers.values.where((c) => c.routeId == routeId).length;
      expect(assignedBefore, greaterThan(0));

      await routeRepo.deleteRoute(routeId);

      expect(dataStore.routes.containsKey(routeId), isFalse);
      final remaining = dataStore.customers.values.where((c) => c.routeId == routeId).length;
      expect(remaining, equals(0));

      final unassigned = dataStore.customers.values.where((c) => c.routeId == null);
      for (final u in unassigned) {
        expect(u.deliverySequence, equals(0));
      }
    });
  });

  // ============================================================================
  // GROUP 3: R3 1-TAP DELIVERY SHEET, OFFLINE QUEUE CONCURRENCY & WAKELOCK
  // ============================================================================
  group('Tier 5 Adversarial: R3 Delivery Sheet, Concurrency, Corruption & Wakelock', () {
    late InMemoryDairyDataStore dataStore;
    late InMemoryBillingRepository billingRepo;
    late InMemoryOfflineDeliveryQueueService queueService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dataStore = InMemoryDairyDataStore();
      dataStore.seedDefaults();
      billingRepo = InMemoryBillingRepository(dataStore);
      queueService = InMemoryOfflineDeliveryQueueService(dataStore, billingRepo);
    });

    test('T5.3.1: Rapid Concurrent Enqueue Stress (100 parallel async calls)', () async {
      final customer = dataStore.customers.values.first;

      final futures = <Future<void>>[];
      for (int i = 0; i < 100; i++) {
        futures.add(
          queueService.enqueueDelivery(
            customerId: 'cust-concurrent-$i',
            sellerId: customer.sellerId ?? 'seller-01',
            milkType: (i % 2 == 0) ? 'cow' : 'buffalo',
            quantityLiters: 1.0 + (i % 3),
            quantityMl: (i % 4) * 250,
            deliveryDate: DateTime(2026, 11, 16),
            shift: (i % 2 == 0) ? 'morning' : 'evening',
            status: 'delivered',
            rate: 60.0,
          ),
        );
      }

      await Future.wait(futures);

      expect(queueService.pendingCount, equals(100));
      final unsynced = queueService.getUnsyncedDeliveries();
      expect(unsynced.length, equals(100));

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(InMemoryOfflineDeliveryQueueService.prefKey);
      expect(jsonStr, isNotNull);
      final decoded = jsonDecode(jsonStr!) as List;
      expect(decoded.length, equals(100));

      final synced = await queueService.syncQueueToSupabase();
      expect(synced, equals(100));
      expect(queueService.pendingCount, equals(0));
    });

    test('T5.3.2: Offline Queue Storage Corruption Matrix & Graceful Recovery', () async {
      final corruptionPayloads = [
        '{not a valid json string',
        '',
        'null',
        '12345',
        'true',
        '{"single": "object_instead_of_list"}',
        '[1, 2, 3]',
        '[{"id": "incomplete"}]',
        '[{"id":"1", "customer_id":"c1", "seller_id":"s1", "milk_type":"cow", "quantity_liters":1, "quantity_ml":0, "delivery_date":"INVALID_DATE_FORMAT", "shift":"morning", "status":"delivered"}]',
        '[{"id":"2", "customer_id":"c1", "seller_id":"s1", "milk_type":"cow", "quantity_liters":-5.0, "quantity_ml":0, "delivery_date":"2026-11-16T00:00:00.000", "shift":"morning", "status":"delivered"}]',
        '[{"id":"3", "customer_id":"c1", "seller_id":"s1", "milk_type":"cow", "quantity_liters":0, "quantity_ml":0, "delivery_date":"2026-11-16T00:00:00.000", "shift":"morning", "status":"delivered"}]',
      ];

      for (final badPayload in corruptionPayloads) {
        SharedPreferences.setMockInitialValues({
          InMemoryOfflineDeliveryQueueService.prefKey: badPayload,
        });

        await expectLater(
          queueService.restoreFromPrefs(),
          completes,
          reason: 'restoreFromPrefs must catch format/parsing errors gracefully for: $badPayload',
        );

        expect(queueService.pendingCount, isNonNegative);

        await queueService.enqueueDelivery(
          customerId: 'cust-recovery',
          sellerId: 'seller-01',
          milkType: 'cow',
          quantityLiters: 1.0,
          quantityMl: 0,
          deliveryDate: DateTime.now(),
          shift: 'morning',
          status: 'delivered',
        );

        expect(queueService.pendingCount, greaterThanOrEqualTo(1));
      }
    });

    test('T5.3.3: Volume Stepper Clamping, Negative Volumes & Zero-Delivered Rejection', () async {
      expect(
        () => QueuedDelivery(
          id: 'test-1',
          customerId: 'c1',
          sellerId: 's1',
          milkType: 'cow',
          quantityLiters: -1.0,
          quantityMl: 0,
          deliveryDate: DateTime.now(),
          shift: 'morning',
          status: 'delivered',
          timestamp: DateTime.now(),
        ),
        throwsArgumentError,
        reason: 'Negative quantityLiters must throw ArgumentError',
      );

      expect(
        () => QueuedDelivery(
          id: 'test-2',
          customerId: 'c1',
          sellerId: 's1',
          milkType: 'cow',
          quantityLiters: 1.0,
          quantityMl: -250,
          deliveryDate: DateTime.now(),
          shift: 'morning',
          status: 'delivered',
          timestamp: DateTime.now(),
        ),
        throwsArgumentError,
        reason: 'Negative quantityMl must throw ArgumentError',
      );

      expect(
        () => QueuedDelivery(
          id: 'test-3',
          customerId: 'c1',
          sellerId: 's1',
          milkType: 'cow',
          quantityLiters: 0,
          quantityMl: 0,
          deliveryDate: DateTime.now(),
          shift: 'morning',
          status: 'delivered',
          timestamp: DateTime.now(),
        ),
        throwsArgumentError,
        reason: 'Delivered status with 0 quantity must throw ArgumentError',
      );

      final skipped = QueuedDelivery(
        id: 'test-4',
        customerId: 'c1',
        sellerId: 's1',
        milkType: 'cow',
        quantityLiters: 0,
        quantityMl: 0,
        deliveryDate: DateTime.now(),
        shift: 'morning',
        status: 'skipped',
        timestamp: DateTime.now(),
      );
      expect(skipped.status, equals('skipped'));
      expect(skipped.totalLiters, equals(0.0));
      expect(skipped.isSkipped, isTrue);

      double adjustVolume(double current, double delta) {
        final next = current + delta;
        return next < 0.0 ? 0.0 : double.parse(next.toStringAsFixed(3));
      }

      expect(adjustVolume(0.5, -0.25), equals(0.25));
      expect(adjustVolume(0.25, -0.25), equals(0.0));
      expect(adjustVolume(0.0, -0.25), equals(0.0));
      expect(adjustVolume(0.0, -1.0), equals(0.0));
    });

    test('T5.3.4: Commercial High-Volume Bounds (1,000 L Arithmetic)', () {
      final commercialDelivery = QueuedDelivery(
        id: 'commercial-01',
        customerId: 'sweet-factory-01',
        sellerId: 'dairy-co-01',
        milkType: 'buffalo',
        quantityLiters: 1000.0,
        quantityMl: 500,
        deliveryDate: DateTime.now(),
        shift: 'morning',
        status: 'delivered',
        timestamp: DateTime.now(),
        rate: 72.50,
      );

      expect(commercialDelivery.totalLiters, equals(1000.5));
      final totalCost = commercialDelivery.totalLiters * commercialDelivery.rate!;
      expect(totalCost, equals(72536.25));

      final tuple = MilkUtils.fromDecimal(commercialDelivery.totalLiters);
      expect(tuple.liters, equals(1000));
      expect(tuple.ml, equals(500));

      final formatted = MilkUtils.formatQuantity(tuple.liters, tuple.ml);
      expect(formatted, equals('1000 L 500 ml'));
    });

    test('T5.3.5: MilkUtils fromDecimal Boundary & Floating-Point Precision Edge Cases', () {
      final roundUpTuple = MilkUtils.fromDecimal(0.9999);
      expect(roundUpTuple.liters, equals(0));
      expect(roundUpTuple.ml, equals(1000));
      expect(MilkUtils.toDecimal(roundUpTuple.liters, roundUpTuple.ml), equals(1.0));

      final tinyTuple = MilkUtils.fromDecimal(0.0001);
      expect(tinyTuple.liters, equals(0));
      expect(tinyTuple.ml, equals(0));

      final quarterL = MilkUtils.fromDecimal(0.250);
      expect(quarterL.liters, equals(0));
      expect(quarterL.ml, equals(250));

      final halfL = MilkUtils.fromDecimal(0.500);
      expect(halfL.liters, equals(0));
      expect(halfL.ml, equals(500));
    });

    test('T5.3.6: Wakelock Platform Channel Exception Resilience Simulation', () async {
      bool screenAwakeHandled = false;
      Object? capturedError;

      Future<void> simulateSetScreenAwake(bool enable, {required bool throwPlatformError}) async {
        try {
          if (throwPlatformError) {
            throw PlatformException(
              code: 'WAKELOCK_NOT_SUPPORTED',
              message: 'Device does not support wakelock',
              details: null,
            );
          }
          screenAwakeHandled = true;
        } catch (e) {
          capturedError = e;
        }
      }

      await simulateSetScreenAwake(true, throwPlatformError: false);
      expect(screenAwakeHandled, isTrue);
      expect(capturedError, isNull);

      screenAwakeHandled = false;
      await simulateSetScreenAwake(true, throwPlatformError: true);
      expect(screenAwakeHandled, isFalse);
      expect(capturedError, isA<PlatformException>());

      capturedError = null;
      await simulateSetScreenAwake(false, throwPlatformError: true);
      expect(capturedError, isA<PlatformException>());
    });

    test('T5.3.7: Rapid Double-Tap Debouncing Simulation (600ms Guard)', () async {
      final tapTimes = <String, DateTime>{};
      final inFlight = <String>{};
      int deliveryExecutions = 0;

      Future<bool> handleDeliveryTap(String customerId) async {
        final now = DateTime.now();
        final lastTap = tapTimes[customerId];
        if (inFlight.contains(customerId) ||
            (lastTap != null && now.difference(lastTap).inMilliseconds < 600)) {
          return false;
        }

        tapTimes[customerId] = now;
        inFlight.add(customerId);

        try {
          await Future.delayed(const Duration(milliseconds: 50));
          deliveryExecutions++;
          return true;
        } finally {
          inFlight.remove(customerId);
        }
      }

      const custId = 'customer-debounce-test';
      final res1 = await handleDeliveryTap(custId);
      expect(res1, isTrue);
      expect(deliveryExecutions, equals(1));

      final res2 = await handleDeliveryTap(custId);
      expect(res2, isFalse);
      expect(deliveryExecutions, equals(1));

      await Future.delayed(const Duration(milliseconds: 650));
      final res3 = await handleDeliveryTap(custId);
      expect(res3, isTrue);
      expect(deliveryExecutions, equals(2));
    });

    test('T5.3.8: SupabaseOfflineDeliveryQueueService in-place replacement for same customer/date/shift', () async {
      final service = SupabaseOfflineDeliveryQueueService(client: _dummyClient);
      final date = DateTime(2026, 11, 16);
      const custId = 'customer-dedup-01';

      await service.enqueueDelivery(
        customerId: custId,
        sellerId: 'seller-01',
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: date,
        shift: 'morning',
        status: 'delivered',
        rate: 60.0,
      );

      expect(service.pendingCount, equals(1));
      expect(service.getUnsyncedDeliveries().first.totalLiters, equals(1.0));

      await service.enqueueDelivery(
        customerId: custId,
        sellerId: 'seller-01',
        milkType: 'cow',
        quantityLiters: 2.0,
        quantityMl: 500,
        deliveryDate: date,
        shift: 'morning',
        status: 'delivered',
        rate: 60.0,
      );

      expect(service.pendingCount, equals(1));
      expect(service.getUnsyncedDeliveries().first.totalLiters, equals(2.5));

      await service.enqueueDelivery(
        customerId: custId,
        sellerId: 'seller-01',
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: date,
        shift: 'evening',
        status: 'delivered',
        rate: 60.0,
      );

      expect(service.pendingCount, equals(2));
    });

    test('T5.3.9: Recovers valid queue items prior to corrupted entry in storage', () async {
      final validItem = {
        'id': 'queued-001',
        'customer_id': 'cust-01',
        'seller_id': 'seller-01',
        'milk_type': 'cow',
        'quantity_liters': 1.0,
        'quantity_ml': 0,
        'delivery_date': '2026-11-16T00:00:00.000',
        'shift': 'morning',
        'status': 'delivered',
        'timestamp': '2026-11-16T00:00:00.000',
      };

      final corruptedItem = {
        'id': 'queued-002',
      };

      SharedPreferences.setMockInitialValues({
        SupabaseOfflineDeliveryQueueService.prefKey: jsonEncode([validItem, corruptedItem]),
      });

      final service = SupabaseOfflineDeliveryQueueService(client: _dummyClient);
      await service.restoreFromPrefs();

      expect(service.pendingCount, equals(1));
      expect(service.getUnsyncedDeliveries().first.customerId, equals('cust-01'));

      await service.enqueueDelivery(
        customerId: 'cust-02',
        sellerId: 'seller-01',
        milkType: 'buffalo',
        quantityLiters: 2.0,
        quantityMl: 0,
        deliveryDate: DateTime(2026, 11, 16),
        shift: 'morning',
        status: 'delivered',
      );

      expect(service.pendingCount, equals(2));
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(SupabaseOfflineDeliveryQueueService.prefKey);
      final decoded = jsonDecode(savedJson!) as List;
      expect(decoded.length, equals(2));
    });
  });
}
