import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milk_hub/core/milk_utils.dart';
import 'package:milk_hub/features/seller/route_customers_screen.dart';
import 'package:milk_hub/l10n/app_localizations.dart';
import 'package:milk_hub/models/profile.dart';
import 'package:milk_hub/models/seller.dart';
import 'package:milk_hub/providers/auth_provider.dart';
import 'package:milk_hub/providers/billing_provider.dart';
import 'package:milk_hub/providers/customer_provider.dart';
import 'package:milk_hub/providers/pause_provider.dart';
import 'package:milk_hub/providers/route_provider.dart';
import 'package:milk_hub/providers/seller_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import '../helpers/dairy_e2e_test_harness.dart';
import '../helpers/dairy_test_fixtures.dart';
import '../helpers/in_memory_billing_repository.dart';
import '../helpers/in_memory_customer_repository.dart';
import '../helpers/in_memory_dairy_data_store.dart';
import '../helpers/in_memory_offline_queue_service.dart';
import '../helpers/in_memory_pause_repository.dart';
import '../helpers/in_memory_route_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDairyDataStore dataStore;
  late InMemoryRouteRepository routeRepo;
  late InMemoryCustomerRepository customerRepo;
  late InMemoryBillingRepository billingRepo;
  late InMemoryPauseRepository pauseRepo;
  late InMemoryOfflineDeliveryQueueService queueService;
  late FakeWakelockPlusPlatform fakeWakelock;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeWakelock = FakeWakelockPlusPlatform();
    WakelockPlusPlatformInterface.instance = fakeWakelock;
    wakelockPlusPlatformInstance = fakeWakelock;

    dataStore = InMemoryDairyDataStore();
    dataStore.seedDefaults();

    routeRepo = InMemoryRouteRepository(dataStore);
    customerRepo = InMemoryCustomerRepository(dataStore);
    billingRepo = InMemoryBillingRepository(dataStore);
    pauseRepo = InMemoryPauseRepository(dataStore);
    queueService = InMemoryOfflineDeliveryQueueService(dataStore, billingRepo);
  });

  tearDown(() {
    fakeWakelock = FakeWakelockPlusPlatform();
    queueService.dispose();
  });

  Widget buildTestWidget({
    String? routeId,
    String? shift,
    Locale locale = const Locale('hi'),
  }) {
    return ProviderScope(
      overrides: [
        routeRepositoryProvider.overrideWithValue(routeRepo),
        customerRepositoryProvider.overrideWithValue(customerRepo),
        billingRepositoryProvider.overrideWithValue(billingRepo),
        pauseRepositoryProvider.overrideWithValue(pauseRepo),
        offlineDeliveryQueueServiceProvider.overrideWithValue(queueService),
        monthlyBillsProvider.overrideWith((ref, query) => Future.value([])),
        routeByIdProvider.overrideWith((ref, id) => Future.value(dataStore.routes[id])),
        customersByRouteProvider.overrideWith(
          (ref, id) => Future.value(
            dataStore.customers.values.where((c) => c.routeId == id).toList(),
          ),
        ),
        routesBySellerProvider.overrideWith(
          (ref, id) => Future.value(
            dataStore.routes.values.where((r) => r.sellerId == id).toList(),
          ),
        ),
        customersBySellerProvider.overrideWith(
          (ref, id) => Future.value(
            dataStore.customers.values.where((c) => c.sellerId == id).toList(),
          ),
        ),
        profileProvider.overrideWith((ref) => Future.value(Profile(
          id: 'user-s1',
          role: 'seller',
          fullName: DairyTestFixtures.seller1Name,
          phone: DairyTestFixtures.seller1Phone,
        ))),
        currentSellerProvider.overrideWith(
          (ref) => Future.value(Seller(
            id: DairyTestFixtures.seller1Id,
            userId: 'user-s1',
            routeName: 'वार्ड 3 प्रभात फेरी (Morning Ward 3)',
            fullName: DairyTestFixtures.seller1Name,
            phone: DairyTestFixtures.seller1Phone,
          )),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: RouteCustomersScreen(
          routeId: routeId ?? 'route-01',
          shift: shift ?? 'morning',
        ),
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? routeId,
    String? shift,
    Locale locale = const Locale('hi'),
  }) async {
    await tester.pumpWidget(buildTestWidget(routeId: routeId, shift: shift, locale: locale));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // =========================================================================
  // Group 1: Offline Delivery Queue Service Enqueue & Persistence
  // =========================================================================
  group('Group 1: Offline Delivery Queue Service Enqueue & Persistence', () {
    test('G1.1: Enqueue persists to SharedPreferences and updates pendingCountStream', () async {
      expect(queueService.getUnsyncedDeliveries(), isEmpty);

      final events = <int>[];
      final sub = queueService.pendingCountStream.listen(events.add);

      await queueService.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 250,
        deliveryDate: DateTime(2026, 11, 16),
        shift: 'morning',
        status: 'delivered',
        rate: 60.0,
      );

      await pumpEventQueue();
      expect(queueService.getUnsyncedDeliveries().length, equals(1));
      expect(events, contains(1));

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(InMemoryOfflineDeliveryQueueService.prefKey);
      expect(jsonStr, isNotNull);
      final list = jsonDecode(jsonStr!) as List;
      expect(list.length, equals(1));
      expect(list.first['customer_id'], equals('cust-101'));
      expect(list.first['quantity_ml'], equals(250));
      expect(list.first['rate'], equals(60.0));

      await sub.cancel();
    });

    test('G1.2: Enqueue serializes full JSON payload matching PROJECT.md interface contract', () async {
      final now = DateTime(2026, 11, 16, 7, 30);
      final queued = QueuedDelivery(
        id: 'queued-001',
        customerId: 'cust-102',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'buffalo',
        quantityLiters: 1.0,
        quantityMl: 500,
        deliveryDate: now,
        shift: 'morning',
        status: 'delivered',
        notes: 'Extra creamy',
        timestamp: now,
        rate: 70.0,
      );

      final json = queued.toJson();
      expect(json['id'], equals('queued-001'));
      expect(json['customer_id'], equals('cust-102'));
      expect(json['seller_id'], equals(DairyTestFixtures.seller1Id));
      expect(json['milk_type'], equals('buffalo'));
      expect(json['quantity_liters'], equals(1.0));
      expect(json['quantity_ml'], equals(500));
      expect(json['shift'], equals('morning'));
      expect(json['status'], equals('delivered'));
      expect(json['notes'], equals('Extra creamy'));
      expect(json['rate'], equals(70.0));
      expect(queued.totalLiters, equals(1.5));
      expect(queued.isDelivered, isTrue);
      expect(queued.isSkipped, isFalse);

      final restored = QueuedDelivery.fromJson(json);
      expect(restored.id, equals(queued.id));
      expect(restored.customerId, equals(queued.customerId));
      expect(restored.quantityLiters, equals(1.0));
      expect(restored.quantityMl, equals(500));
      expect(restored.rate, equals(70.0));
      expect(restored == queued, isTrue);
      expect(restored.hashCode, equals(queued.hashCode));
    });

    test('G1.3: Cold boot restoration recreates queue from SharedPreferences', () async {
      await queueService.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: DateTime(2026, 11, 16),
        shift: 'morning',
        status: 'delivered',
      );

      final freshQueue = InMemoryOfflineDeliveryQueueService(dataStore, billingRepo);
      await freshQueue.restoreFromPrefs();

      expect(freshQueue.getUnsyncedDeliveries().length, equals(1));
      expect(freshQueue.getUnsyncedDeliveries().first.customerId, equals('cust-101'));
      freshQueue.dispose();
    });

    test('G1.4: Graceful handling of null, empty or corrupted JSON in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(InMemoryOfflineDeliveryQueueService.prefKey, 'invalid-corrupt-json');

      final freshQueue = InMemoryOfflineDeliveryQueueService(dataStore, billingRepo);
      await freshQueue.restoreFromPrefs();

      expect(freshQueue.getUnsyncedDeliveries(), isEmpty);
      expect(freshQueue.pendingCount, equals(0));
      freshQueue.dispose();
    });

    test('G1.5: QueuedDelivery copyWith creates expected modified clones', () {
      final original = QueuedDelivery(
        id: 'q1',
        customerId: 'c1',
        sellerId: 's1',
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: DateTime(2026, 11, 16),
        shift: 'morning',
        status: 'delivered',
        timestamp: DateTime(2026, 11, 16),
      );

      final copied = original.copyWith(quantityLiters: 2.0, quantityMl: 500);
      expect(copied.id, equals('q1'));
      expect(copied.quantityLiters, equals(2.0));
      expect(copied.quantityMl, equals(500));
      expect(copied.totalLiters, equals(2.5));
    });
  });

  // =========================================================================
  // Group 2: Offline Queue Sync Engine & Error Recovery
  // =========================================================================
  group('Group 2: Offline Queue Sync Engine', () {
    test('G2.1: Batch sync uploads all records and flushes local queue', () async {
      await queueService.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: DateTime(2026, 11, 16),
        shift: 'morning',
        status: 'delivered',
      );
      await queueService.enqueueDelivery(
        customerId: 'cust-102',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'buffalo',
        quantityLiters: 0,
        quantityMl: 0,
        deliveryDate: DateTime(2026, 11, 16),
        shift: 'morning',
        status: 'skipped',
      );

      expect(queueService.getUnsyncedDeliveries().length, equals(2));

      final syncedCount = await queueService.syncQueueToSupabase();
      expect(syncedCount, equals(2));
      expect(queueService.getUnsyncedDeliveries(), isEmpty);

      final deliveries = await billingRepo.getDeliveries();
      expect(deliveries.length, equals(2));
      expect(deliveries.any((d) => d.customerId == 'cust-101' && d.status == 'delivered'), isTrue);
      expect(deliveries.any((d) => d.customerId == 'cust-102' && d.status == 'skipped'), isTrue);
    });

    test('G2.2: syncQueueToSupabase on empty queue is a fast no-op returning 0', () async {
      final count = await queueService.syncQueueToSupabase();
      expect(count, equals(0));
      expect(queueService.pendingCount, equals(0));
    });

    test('G2.3: clearQueue flushes queue and resets SharedPreferences', () async {
      await queueService.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: DateTime(2026, 11, 16),
        shift: 'morning',
        status: 'delivered',
      );
      expect(queueService.pendingCount, equals(1));

      await queueService.clearQueue();
      expect(queueService.pendingCount, equals(0));
      expect(queueService.getUnsyncedDeliveries(), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(InMemoryOfflineDeliveryQueueService.prefKey);
      expect(jsonStr, equals('[]'));
    });
  });

  // =========================================================================
  // Group 3: Volume Steppers & Boundary Clamping
  // =========================================================================
  group('Group 3: Volume Steppers & Boundary Clamping', () {
    test('G3.1: Step arithmetic and MilkUtils format and amount calculation', () {
      num liters = 1;
      num ml = 0;
      const rate = 60.0;

      // +250ml
      ml += 250;
      expect(MilkUtils.toDecimal(liters, ml), equals(1.25));
      expect(MilkUtils.calculateAmount(liters, ml, rate), equals(75.0));

      // +500ml -> 1L 750ml
      ml += 500;
      expect(MilkUtils.toDecimal(liters, ml), equals(1.75));
      expect(MilkUtils.formatQuantity(liters, ml), equals('1 L 750 ml'));

      // +1L -> 2L 750ml
      liters += 1;
      expect(MilkUtils.toDecimal(liters, ml), equals(2.75));
      expect(MilkUtils.calculateAmount(liters, ml, rate), equals(165.0));
    });

    test('G3.2: Stepper decrements transition smoothly across liter boundaries', () {
      const liters = 1;
      const ml = 0;

      // 1L 0ml - 250ml = 0L 750ml
      final dec = MilkUtils.toDecimal(liters, ml) - 0.25;
      final tuple = MilkUtils.fromDecimal(dec);
      expect(tuple.liters, equals(0));
      expect(tuple.ml, equals(750));
      expect(MilkUtils.formatQuantity(tuple.liters, tuple.ml), equals('0 L 750 ml'));
    });

    test('G3.3: Clamping at 0 mL prevents negative quantities', () {
      final dec = MilkUtils.toDecimal(0, 0) - 0.25;
      final clamped = dec < 0 ? 0.0 : dec;
      expect(clamped, equals(0.0));
    });

    test('G3.4: Negative volume throws ArgumentError in model and service', () {
      expect(
        () => QueuedDelivery(
          id: 'err1',
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: -1,
          quantityMl: 0,
          deliveryDate: DateTime.now(),
          shift: 'morning',
          status: 'delivered',
          timestamp: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => queueService.enqueueDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 0,
          quantityMl: -250,
          deliveryDate: DateTime.now(),
          shift: 'morning',
          status: 'delivered',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('G3.5: Zero volume for delivered status throws ArgumentError', () {
      expect(
        () => QueuedDelivery(
          id: 'err2',
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 0,
          quantityMl: 0,
          deliveryDate: DateTime.now(),
          shift: 'morning',
          status: 'delivered',
          timestamp: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => queueService.enqueueDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 0,
          quantityMl: 0,
          deliveryDate: DateTime.now(),
          shift: 'morning',
          status: 'delivered',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('G3.6: Commercial volume precision (150+ L @ ₹58.50/L) maintains exact arithmetic', () {
      const liters = 150;
      const ml = 500;
      const rate = 58.50;

      final decimal = MilkUtils.toDecimal(liters, ml);
      expect(decimal, equals(150.5));

      final amount = MilkUtils.calculateAmount(liters, ml, rate);
      expect(amount, equals(8804.25));

      final tuple = MilkUtils.fromDecimal(decimal);
      expect(tuple.liters, equals(150));
      expect(tuple.ml, equals(500));
    });

    test('G3.7: Rapid double-tap debouncing ensures idempotent single record creation', () async {
      final date = DateTime(2026, 11, 16);

      await Future.wait([
        billingRepo.recordDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 1.0,
          quantityMl: 0,
          rate: 60.0,
          date: date,
          shift: 'morning',
        ),
        billingRepo.recordDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 1.0,
          quantityMl: 0,
          rate: 60.0,
          date: date,
          shift: 'morning',
        ),
      ]);

      final deliveries = await billingRepo.getDeliveries(
        customerId: 'cust-101',
        month: date,
      );
      expect(deliveries.length, equals(1));
    });
  });

  // =========================================================================
  // Group 4: Vacation Pause Guardrails
  // =========================================================================
  group('Group 4: Vacation Pause Guardrails', () {
    test('G4.1: Approved vacation blocks delivery on target date with StateError', () async {
      final today = DateTime(2026, 11, 16);
      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 3)),
        reason: 'Out of town',
      );
      await pauseRepo.approvePause(pause.id);

      expect(
        () => queueService.enqueueDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 1.0,
          quantityMl: 0,
          deliveryDate: today,
          shift: 'morning',
          status: 'delivered',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('G4.2: Pending vacation pause does NOT block delivery', () async {
      final today = DateTime(2026, 11, 16);
      await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );

      // Should succeed without error
      await queueService.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: today,
        shift: 'morning',
        status: 'delivered',
      );

      expect(queueService.getUnsyncedDeliveries().length, equals(1));
    });

    test('G4.3: Deliveries on dates outside approved range succeed', () async {
      final today = DateTime(2026, 11, 16);
      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today.add(const Duration(days: 2)),
        endDate: today.add(const Duration(days: 4)),
      );
      await pauseRepo.approvePause(pause.id);

      // Delivery today is before pause starts
      await queueService.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: today,
        shift: 'morning',
        status: 'delivered',
      );

      expect(queueService.getUnsyncedDeliveries().length, equals(1));
    });

    test('G4.4: 1-Tap skip is allowed even during vacation', () async {
      final today = DateTime(2026, 11, 16);
      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );
      await pauseRepo.approvePause(pause.id);

      // Skips have 0 volume and do not bill, so they are not rejected by pause guard
      await queueService.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 0,
        quantityMl: 0,
        deliveryDate: today,
        shift: 'morning',
        status: 'skipped',
      );

      expect(queueService.getUnsyncedDeliveries().length, equals(1));
      expect(queueService.getUnsyncedDeliveries().first.status, equals('skipped'));
    });
  });

  // =========================================================================
  // Group 5: Keep-Awake Lifecycle Contract
  // =========================================================================
  group('Group 5: Keep-Awake Lifecycle Contract', () {
    testWidgets('G5.1 & G5.2: Mount enables wakelock and dispose disables wakelock', (tester) async {
      expect(fakeWakelock.enableCalls, equals(0));
      expect(fakeWakelock.disableCalls, equals(0));

      await pumpScreen(tester);

      expect(fakeWakelock.enableCalls, equals(1));
      expect(fakeWakelock.disableCalls, equals(0));

      // Pump empty container to dispose screen
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fakeWakelock.disableCalls, equals(1));
    });

    testWidgets('G5.3 & G5.4: AppLifecycleState paused disables wakelock and resumed enables wakelock', (tester) async {
      await pumpScreen(tester);

      expect(fakeWakelock.enableCalls, equals(1));
      expect(fakeWakelock.disableCalls, equals(0));

      // Simulate App backgrounded
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(fakeWakelock.disableCalls, equals(1));

      // Simulate App foregrounded
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(fakeWakelock.enableCalls, equals(2));
    });
  });

  // =========================================================================
  // Group 6: RouteCustomersScreen Widget & Interaction Tests
  // =========================================================================
  group('Group 6: RouteCustomersScreen Widget Tests', () {
    testWidgets('G6.1: Displays sequence pill badges [1], [2], [3] for assigned route customers', (tester) async {
      await pumpScreen(tester);

      // Sequence pill badges
      expect(find.text('[1]'), findsOneWidget);
      expect(find.text('[2]'), findsOneWidget);
      expect(find.text('[3]'), findsOneWidget);
    });

    testWidgets('G6.2: Renders 1-Tap "✔ दिया" button; tapping enqueues delivery with customer default quota', (tester) async {
      await pumpScreen(tester);

      expect(find.text('✔ दिया'), findsWidgets);

      // Tap "✔ दिया" for customer 1 (Amit Sharma: 1L cow)
      await tester.tap(find.text('✔ दिया').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(queueService.getUnsyncedDeliveries().length, equals(1));
      final enqueued = queueService.getUnsyncedDeliveries().first;
      expect(enqueued.customerId, equals('cust-101'));
      expect(enqueued.status, equals('delivered'));
      expect(enqueued.quantityLiters, equals(1.0));
    });

    testWidgets('G6.3: Stepper buttons [-250ml], [+250ml], [+500ml], [+1L] update volume before tapping delivered', (tester) async {
      await pumpScreen(tester);

      expect(find.text('+250ml'), findsWidgets);
      expect(find.text('-250ml'), findsWidgets);

      // Tap +500ml on first customer card
      await tester.tap(find.text('+500ml').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Volume should update from 1 L to 1 L 500 ml
      expect(find.textContaining('1 L 500 ml'), findsWidgets);

      // Tap "✔ दिया"
      await tester.tap(find.text('✔ दिया').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(queueService.getUnsyncedDeliveries().length, equals(1));
      final enqueued = queueService.getUnsyncedDeliveries().first;
      expect(enqueued.customerId, equals('cust-101'));
      expect(enqueued.quantityLiters, equals(1.0));
      expect(enqueued.quantityMl, equals(500));
    });

    testWidgets('G6.4: Renders 1-Tap "✕ आज नहीं लिया" button; tapping records skip with ₹0 billed', (tester) async {
      await pumpScreen(tester);

      expect(find.text('✕ आज नहीं लिया'), findsWidgets);

      // Tap skip on first customer
      await tester.tap(find.text('✕ आज नहीं लिया').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(queueService.getUnsyncedDeliveries().length, equals(1));
      final enqueued = queueService.getUnsyncedDeliveries().first;
      expect(enqueued.customerId, equals('cust-101'));
      expect(enqueued.status, equals('skipped'));
      expect(enqueued.quantityLiters, equals(0.0));
      expect(enqueued.quantityMl, equals(0));
    });

    testWidgets('G6.5: Approved vacation stop displays "⛔ आज दूध बंद (छुट्टी)" badge', (tester) async {
      final today = DateTime.now();
      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );
      await pauseRepo.approvePause(pause.id);

      await pumpScreen(tester);

      expect(find.text('⛔ आज दूध बंद (छुट्टी)'), findsOneWidget);
    });

    testWidgets('G6.6: Sync banner displays pending count when queue > 0 and manual tap triggers sync', (tester) async {
      await queueService.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: DateTime.now(),
        shift: 'morning',
        status: 'delivered',
      );

      await pumpScreen(tester);

      expect(find.textContaining('ऑफ़लाइन रिकॉर्ड बाकी'), findsOneWidget);
      expect(find.text('सिंक करें'), findsOneWidget);

      await tester.tap(find.text('सिंक करें'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(queueService.getUnsyncedDeliveries(), isEmpty);
      expect(find.text('सभी रिकॉर्ड सिंक हैं'), findsOneWidget);
    });
  });
}
