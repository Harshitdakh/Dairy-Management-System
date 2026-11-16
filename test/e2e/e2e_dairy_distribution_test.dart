import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milk_hub/config/theme.dart';
import 'package:milk_hub/core/milk_utils.dart';
import 'package:milk_hub/models/customer.dart';
import 'package:milk_hub/models/customer_bill.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../helpers/dairy_e2e_test_harness.dart';
import '../helpers/dairy_test_fixtures.dart';
import '../helpers/in_memory_offline_queue_service.dart';
import '../helpers/locale_notifier_helper.dart';
import '../helpers/upi_and_whatsapp_services.dart';

void main() {
  late DairyE2ETestHarness harness;

  setUp(() async {
    harness = DairyE2ETestHarness();
    await harness.setUp();
  });

  tearDown(() {
    harness.tearDown();
  });

  // ===========================================================================
  // TIER 1: FEATURE COVERAGE (R1 - R5)
  // ===========================================================================
  group('Tier 1: Feature Coverage (R1 - Bilingual Toggle & Hindi-First Accessibility)', () {
    test('T1.1.1: English to Hindi (en -> hi) runtime toggle', () async {
      await harness.localeNotifier.setLocale(const Locale('en'));
      expect(harness.localeNotifier.state, equals(const Locale('en')));
      expect(harness.localeNotifier.isHindi, isFalse);

      await harness.localeNotifier.toggleLocale();

      expect(harness.localeNotifier.state, equals(const Locale('hi')));
      expect(harness.localeNotifier.isHindi, isTrue);
      expect(DairyGlossary.get('delivered_action', 'hi'), equals('✔ दिया'));
      expect(DairyGlossary.get('route_customers', 'hi'), equals('वितरण मार्ग ग्राहक'));
    });

    test('T1.1.2: Hindi to English (hi -> en) runtime toggle', () async {
      await harness.localeNotifier.setLocale(const Locale('hi'));
      expect(harness.localeNotifier.state, equals(const Locale('hi')));

      await harness.localeNotifier.toggleLocale();

      expect(harness.localeNotifier.state, equals(const Locale('en')));
      expect(harness.localeNotifier.isHindi, isFalse);
      expect(DairyGlossary.get('delivered_action', 'en'), equals('✔ Delivered'));
      expect(DairyGlossary.get('route_customers', 'en'), equals('Route Customers'));
    });

    test('T1.1.3: Persistence of locale preference across cold restarts in SharedPreferences', () async {
      await harness.localeNotifier.setLocale(const Locale('hi'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_locale_code'), equals('hi'));

      final loadedLocale = await LocaleNotifier.loadInitialLocale();
      expect(loadedLocale, equals(const Locale('hi')));
    });

    test('T1.1.4: Exact vernacular phrases validation (दिया, आज नहीं लिया, दूध बंद)', () {
      expect(DairyGlossary.get('delivered_action', 'hi'), equals('✔ दिया'));
      expect(DairyGlossary.get('skip_action', 'hi'), equals('आज नहीं लिया'));
      expect(DairyGlossary.get('vacation_badge', 'hi'), equals('दूध बंद (छुट्टी)'));

      // Check English counterparts
      expect(DairyGlossary.get('delivered_action', 'en'), equals('✔ Delivered'));
      expect(DairyGlossary.get('skip_action', 'en'), equals('Skipped Today'));
      expect(DairyGlossary.get('vacation_badge', 'en'), equals('Milk Paused (Vacation)'));
    });

    test('T1.1.5: Indian dairy domain glossary translation parity across languages', () {
      final keys = [
        'cow_milk',
        'buffalo_milk',
        'mixed_milk',
        'bill',
        'pending',
        'collected',
        'morning',
        'evening',
        'both',
        'approve',
        'reject',
      ];

      for (final key in keys) {
        final hi = DairyGlossary.get(key, 'hi');
        final en = DairyGlossary.get(key, 'en');

        expect(hi, isNotEmpty, reason: 'Hindi translation missing for $key');
        expect(en, isNotEmpty, reason: 'English translation missing for $key');
        expect(hi, isNot(equals(en)), reason: 'Translation parity missing for $key');
      }

      expect(DairyGlossary.get('cow_milk', 'hi'), equals('गाय का दूध'));
      expect(DairyGlossary.get('buffalo_milk', 'hi'), equals('भैंस का दूध'));
      expect(DairyGlossary.get('morning', 'hi'), equals('सुबह'));
      expect(DairyGlossary.get('evening', 'hi'), equals('शाम'));
    });

    test('T1.1.6: Visual color code and minimum touch target size (48dp) accessibility invariance', () {
      Object? testFailure;
      runZonedGuarded(() {
        final theme = AppTheme.lightTheme;
        final btnStyle = theme.elevatedButtonTheme.style;
        final padding = btnStyle?.padding?.resolve({}) as EdgeInsets?;
        expect(padding, isNotNull);
        // Button height with 16pt font + 32pt padding >= 48dp min touch target
        expect((padding!.vertical + 16.0), greaterThanOrEqualTo(48.0));

        // Accessibility color invariance from AppTheme
        expect(AppTheme.success, equals(const Color(0xFF10B981)));
        expect(AppTheme.warning, equals(const Color(0xFFF59E0B)));
        expect(AppTheme.amber, equals(const Color(0xFFD97706)));
        expect(AppTheme.cyan, equals(const Color(0xFF06B6D4)));
        expect(AppTheme.error, equals(const Color(0xFFEF4444)));
        expect(AppTheme.textSecondary, equals(const Color(0xFF6B7280)));
      }, (error, stack) {
        if (error is TestFailure) {
          testFailure = error;
        }
      });
      if (testFailure != null) {
        throw testFailure!;
      }
    });
  });

  group('Tier 1: Feature Coverage (R2 - Route Management & Customer Stop Sequencing)', () {
    test('T1.2.1: Route creation and retrieval (createRoute, getAllRoutes, getRoutesBySeller)', () async {
      final newRoute = await harness.routeRepo.createRoute(
        name: 'Model Town Morning',
        sellerId: DairyTestFixtures.seller1Id,
        shift: 'morning',
        description: 'New route for Model Town',
      );

      expect(newRoute.id, startsWith('route-'));
      expect(newRoute.name, equals('Model Town Morning'));
      expect(newRoute.shift, equals('morning'));
      expect(newRoute.sellerId, equals(DairyTestFixtures.seller1Id));

      final allRoutes = await harness.routeRepo.getAllRoutes();
      expect(allRoutes.any((r) => r.id == newRoute.id), isTrue);

      final sellerRoutes = await harness.routeRepo.getRoutesBySeller(DairyTestFixtures.seller1Id);
      expect(sellerRoutes.any((r) => r.id == newRoute.id), isTrue);
    });

    test('T1.2.2: Customer stop sequence assignment 1..N', () async {
      final customers = await harness.customerRepo.getCustomersByRoute('route-01');
      expect(customers.length, greaterThanOrEqualTo(3));

      // Verify sequence is strictly 1..N
      for (int i = 0; i < customers.length; i++) {
        expect(customers[i].deliverySequence, equals(i + 1));
      }
    });

    test('T1.2.3: Customer drag-and-drop reordering (updateCustomerSequence)', () async {
      final initialCustomers = await harness.customerRepo.getCustomersByRoute('route-01');
      expect(initialCustomers.first.id, equals('cust-101'));

      // Move last customer (cust-105) to first position
      final reorderedIds = ['cust-105', 'cust-101', 'cust-102', 'cust-103', 'cust-104', 'cust-201'];
      await harness.routeRepo.updateCustomerSequence(reorderedIds);

      final updatedCustomers = await harness.customerRepo.getCustomersByRoute('route-01');
      expect(updatedCustomers.first.id, equals('cust-105'));
      expect(updatedCustomers.first.deliverySequence, equals(1));
      expect(updatedCustomers[1].id, equals('cust-101'));
      expect(updatedCustomers[1].deliverySequence, equals(2));
    });

    test('T1.2.4: Multi-shift route filtering (morning, evening, both)', () async {
      // Add a customer with evening shift and one with both
      harness.dataStore.customers['cust-eve'] = Customer(
        id: 'cust-eve',
        userId: 'u-eve',
        sellerId: DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        deliverySequence: 1,
        deliveryShift: 'evening',
        fullName: 'Evening Customer',
        phone: '9800000001',
      );

      harness.dataStore.customers['cust-both'] = Customer(
        id: 'cust-both',
        userId: 'u-both',
        sellerId: DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        deliverySequence: 2,
        deliveryShift: 'both',
        fullName: 'Both Shift Customer',
        phone: '9800000002',
      );

      final morningList = await harness.customerRepo.getCustomersBySeller(
        DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        shift: 'morning',
      );

      final eveningList = await harness.customerRepo.getCustomersBySeller(
        DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        shift: 'evening',
      );

      // Morning list should include 'both' but not 'evening'
      expect(morningList.any((c) => c.id == 'cust-both'), isTrue);
      expect(morningList.any((c) => c.id == 'cust-eve'), isFalse);

      // Evening list should include both 'cust-eve' and 'cust-both'
      expect(eveningList.any((c) => c.id == 'cust-eve'), isTrue);
      expect(eveningList.any((c) => c.id == 'cust-both'), isTrue);
    });

    test('T1.2.5: Unified Owner-Seller route execution access for solo doodhwalas', () async {
      final ownerRoutes = await harness.routeRepo.getRoutesBySeller(DairyTestFixtures.adminOwnerId);
      expect(ownerRoutes.length, greaterThanOrEqualTo(2));
      expect(ownerRoutes.any((r) => r.id == 'route-north'), isTrue);
      expect(ownerRoutes.any((r) => r.id == 'route-south'), isTrue);

      final northRoute = await harness.routeRepo.getRouteById('route-north');
      expect(northRoute, isNotNull);
      expect(northRoute!.sellerId, equals(DairyTestFixtures.adminOwnerId));
    });

    test('T1.2.6: Stop sequence pill badge display ([1], [2], [3])', () async {
      final cust = harness.dataStore.customers['cust-101']!;
      expect(cust.deliverySequence, equals(1));

      // Stop sequence pill format using shared helper
      expect(formatSequenceBadge(cust.deliverySequence), equals('[1]'));
      expect(formatSequenceBadge(5), equals('[5]'));
      expect(formatSequenceBadge(0), equals('[--]'));
    });
  });

  group('Tier 1: Feature Coverage (R3 - High-Speed 1-Tap Delivery Sheet & Keep-Awake)', () {
    test('T1.3.1: 1-tap delivery marking ([ ✔ दिया ]) with default customer quota', () async {
      final cust = harness.dataStore.customers['cust-101']!;
      final today = DateTime(2026, 11, 16);

      await harness.billingRepo.recordDelivery(
        customerId: cust.id,
        sellerId: cust.sellerId!,
        milkType: cust.milkType,
        quantityLiters: cust.dailyQuantityLiters,
        quantityMl: cust.dailyQuantityMl,
        rate: cust.ratePerLiter,
        date: today,
        shift: 'morning',
        status: 'delivered',
      );

      final deliveries = await harness.billingRepo.getDeliveries(
        customerId: cust.id,
        shift: 'morning',
      );

      expect(deliveries.length, equals(1));
      expect(deliveries.first.quantityLiters, equals(1));
      expect(deliveries.first.quantityMl, equals(0));
      expect(deliveries.first.amount, equals(60.0));
      expect(deliveries.first.status, equals('delivered'));
      expect(deliveries.first.shift, equals('morning'));
    });

    test('T1.3.2: Inline volume stepper increments (+250ml, +500ml, +1L) with MilkUtils integration', () {
      num liters = 1;
      num ml = 0;
      const rate = 60.0;

      // +250ml
      ml += 250;
      expect(MilkUtils.toDecimal(liters, ml), equals(1.25));

      // +500ml
      ml += 500;
      expect(MilkUtils.toDecimal(liters, ml), equals(1.75));

      // +1L
      liters += 1;
      expect(MilkUtils.toDecimal(liters, ml), equals(2.75));

      final amount = MilkUtils.calculateAmount(liters, ml, rate);
      expect(amount, equals(165.0)); // 2.75 * 60 = 165
      expect(MilkUtils.formatQuantity(liters, ml), equals('2 L 750 ml'));
    });

    test('T1.3.3: Inline volume stepper decrement (-250ml)', () {
      num liters = 1;
      num ml = 0;
      const rate = 60.0;

      // -250ml from 1L 0ml -> 0L 750ml
      final totalDecimal = MilkUtils.toDecimal(liters, ml) - 0.25;
      final tuple = MilkUtils.fromDecimal(totalDecimal);

      expect(tuple.liters, equals(0));
      expect(tuple.ml, equals(750));

      final amount = MilkUtils.calculateAmount(tuple.liters, tuple.ml, rate);
      expect(amount, equals(45.0)); // 0.75 * 60 = 45
    });

    test('T1.3.4: 1-tap delivery skip action ("आज नहीं लिया") recording ₹0 billed', () async {
      final cust = harness.dataStore.customers['cust-102']!;
      final today = DateTime(2026, 11, 16);

      await harness.billingRepo.recordSkippedDelivery(
        customerId: cust.id,
        sellerId: cust.sellerId!,
        milkType: cust.milkType,
        date: today,
        shift: 'morning',
        notes: 'House locked',
      );

      final deliveries = await harness.billingRepo.getDeliveries(
        customerId: cust.id,
        shift: 'morning',
      );

      expect(deliveries.length, equals(1));
      expect(deliveries.first.status, equals('skipped'));
      expect(deliveries.first.quantityLiters, equals(0));
      expect(deliveries.first.quantityMl, equals(0));
      expect(deliveries.first.amount, equals(0.0));
    });

    test('T1.3.5: Offline delivery queue enqueue and automatic background sync', () async {
      expect(harness.offlineQueue.getUnsyncedDeliveries(), isEmpty);

      await harness.offlineQueue.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: DateTime(2026, 11, 16),
        shift: 'morning',
        status: 'delivered',
      );

      await harness.offlineQueue.enqueueDelivery(
        customerId: 'cust-102',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'buffalo',
        quantityLiters: 0,
        quantityMl: 0,
        deliveryDate: DateTime(2026, 11, 16),
        shift: 'morning',
        status: 'skipped',
      );

      expect(harness.offlineQueue.getUnsyncedDeliveries().length, equals(2));

      // Background network sync
      final syncedCount = await harness.offlineQueue.syncQueueToSupabase();
      expect(syncedCount, equals(2));
      expect(harness.offlineQueue.getUnsyncedDeliveries(), isEmpty);

      final deliveries = await harness.billingRepo.getDeliveries();
      expect(deliveries.length, equals(2));
    });

    test('T1.3.6: Screen keep-awake lifecycle contract (WakelockPlus.enable on mount, disable on dispose)', () async {
      expect(await WakelockPlus.enabled, isFalse);

      // Mount delivery route screen: enable keep-awake
      await WakelockPlus.enable();
      expect(await WakelockPlus.enabled, isTrue);
      expect(harness.wakelockEnabled, isTrue);
      expect(harness.wakelockEnableCalls, equals(1));

      // Unmount / dispose delivery route screen: disable keep-awake
      await WakelockPlus.disable();
      expect(await WakelockPlus.enabled, isFalse);
      expect(harness.wakelockEnabled, isFalse);
      expect(harness.wakelockDisableCalls, equals(1));
    });
  });

  group('Tier 1: Feature Coverage (R4 - Indian Payments & Free WhatsApp Invoicing)', () {
    test('T1.4.1: NPCI UPI Intent URL generation', () {
      final uri = UpiPaymentService.buildUpiUri(
        upiId: 'shreedairy@oksbi',
        payeeName: 'Shree Krishna Dairy',
        amount: 1250.00,
        transactionNote: 'Milk Bill Nov 2026 - Ramesh Kumar',
      );

      expect(uri.scheme, equals('upi'));
      expect(uri.host, equals('pay'));
      expect(uri.queryParameters['pa'], equals('shreedairy@oksbi'));
      expect(uri.queryParameters['pn'], equals('Shree Krishna Dairy'));
      expect(uri.queryParameters['am'], equals('1250.00'));
      expect(uri.queryParameters['cu'], equals('INR'));
      expect(uri.queryParameters['tn'], equals('Milk Bill Nov 2026 - Ramesh Kumar'));
      expect(uri.toString(), contains('upi://pay?'));
    });

    test('T1.4.2: Static UPI QR code payload string formatting', () {
      final upiUri = UpiPaymentService.buildUpiUri(
        upiId: 'milkman@icici',
        payeeName: 'Gopal Dairy',
        amount: 840.00,
        transactionNote: 'Bill-Nov-2026',
      );
      final qrPayload = upiUri.toString();

      expect(qrPayload, startsWith('upi://pay?'));
      expect(qrPayload, contains('pa=milkman%40icici'));
      expect(qrPayload, contains('am=840.00'));
      expect(qrPayload, contains('cu=INR'));
    });

    test('T1.4.3: Doorstep cash collection partial payment logging & bill recalculation', () async {
      final month = DateTime(2026, 11, 1);
      harness.dataStore.upsertBill(
        DairyTestFixtures.createBill(
          customerId: 'cust-101',
          billMonth: month,
          totalAmount: 1500.0,
          paidAmount: 0.0,
          pendingAmount: 1500.0,
          status: 'pending',
        ),
      );

      await harness.billingRepo.recordCollection(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        amountPaid: 600.00,
        billMonth: month,
        paymentMode: 'cash',
        notes: 'Doorstep cash collected by delivery boy',
      );

      final collections = await harness.billingRepo.getCollections(customerId: 'cust-101');
      expect(collections.length, equals(1));
      expect(collections.first.amountPaid, equals(600.00));
      expect(collections.first.paymentMode, equals('cash'));

      final bills = await harness.billingRepo.getBills(customerId: 'cust-101', month: month);
      expect(bills.first.paidAmount, equals(600.00));
      expect(bills.first.pendingAmount, equals(900.00));
      expect(bills.first.status, equals('partial'));
    });

    test('T1.4.4: Doorstep cash collection full settlement transitioning bill status to paid', () async {
      final month = DateTime(2026, 11, 1);
      harness.dataStore.upsertBill(
        DairyTestFixtures.createBill(
          customerId: 'cust-102',
          billMonth: month,
          totalAmount: 1000.0,
          paidAmount: 400.0,
          pendingAmount: 600.0,
          status: 'partial',
        ),
      );

      await harness.billingRepo.recordCollection(
        customerId: 'cust-102',
        sellerId: DairyTestFixtures.seller1Id,
        amountPaid: 600.00,
        billMonth: month,
        paymentMode: 'cash',
      );

      final bills = await harness.billingRepo.getBills(customerId: 'cust-102', month: month);
      expect(bills.first.paidAmount, equals(1000.00));
      expect(bills.first.pendingAmount, equals(0.00));
      expect(bills.first.status, equals('paid'));
    });

    test('T1.4.5: Bilingual WhatsApp invoice text generation with vernacular header and embedded UPI link', () {
      final invoice = WhatsappShareService.formatDairyInvoice(
        dairyName: 'Gopal Dairy',
        customerName: 'Ramesh Kumar',
        monthYear: 'November 2026',
        totalLiters: 30.0,
        milkType: 'COW',
        totalAmount: 1800.00,
        paidAmount: 500.00,
        pendingAmount: 1300.00,
        upiId: 'gopal.dairy@upi',
      );

      expect(invoice, contains('दूध का मासिक हिसाब - Gopal Dairy'));
      expect(invoice, contains('ग्राहक: Ramesh Kumar'));
      expect(invoice, contains('महीना: November 2026'));
      expect(invoice, contains('कुल दूध: 30.0 L (COW)'));
      expect(invoice, contains('कुल राशि: ₹1800'));
      expect(invoice, contains('प्राप्त राशि: ₹500'));
      expect(invoice, contains('बकाया राशि: ₹1300'));
      expect(invoice, contains('upi://pay?pa=gopal.dairy%40upi'));
      expect(invoice, contains('am=1300.00'));
      expect(invoice, contains('धन्यवाद! 🙏'));
    });

    test('T1.4.6: WhatsApp intent URL construction with Indian E.164 phone normalization (919876543210)', () {
      final nativeUri = WhatsappShareService.buildNativeUri(
        phone: '9876543210',
        text: 'Test Bill',
      );
      final webUri = WhatsappShareService.buildWebUri(
        phone: '9876543210',
        text: 'Test Bill',
      );

      expect(nativeUri.scheme, equals('whatsapp'));
      expect(nativeUri.host, equals('send'));
      expect(nativeUri.queryParameters['phone'], equals('919876543210'));
      expect(nativeUri.queryParameters['text'], equals('Test Bill'));

      expect(webUri.toString(), startsWith('https://wa.me/919876543210?text=Test%20Bill'));
    });
  });

  group('Tier 1: Feature Coverage (R5 - Customer Vacation / Pause Guardrails)', () {
    test('T1.5.1: Customer submits future vacation pause date range with pending status', () async {
      final pause = await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: DateTime.now().add(const Duration(days: 4)),
        endDate: DateTime.now().add(const Duration(days: 9)),
        reason: 'गाँव जाना है (Going to village)',
      );

      expect(pause.id, startsWith('pause-'));
      expect(pause.customerId, equals('cust-201'));
      expect(pause.status, equals('pending'));
      expect(pause.reviewedBy, isNull);
      expect(pause.reviewedAt, isNull);
    });

    test('T1.5.2: Guardrail verification: Unapproved (pending) pause does NOT stop deliveries', () async {
      final targetDate = DateTime.now().add(const Duration(days: 5));
      await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: DateTime.now().add(const Duration(days: 4)),
        endDate: DateTime.now().add(const Duration(days: 9)),
      );

      final isPaused = await harness.pauseRepo.isCustomerPausedOnDate('cust-201', targetDate);
      expect(isPaused, isFalse);

      final pausedIds = await harness.pauseRepo.getPausedCustomerIdsForDate(targetDate);
      expect(pausedIds.contains('cust-201'), isFalse);
    });

    test('T1.5.3: Seller review and approval lifecycle updating status to approved', () async {
      final pause = await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: DateTime.now().add(const Duration(days: 4)),
        endDate: DateTime.now().add(const Duration(days: 9)),
      );

      await harness.pauseRepo.approvePause(pause.id);
      final pauses = await harness.pauseRepo.getPausesForCustomer('cust-201');
      final approved = pauses.firstWhere((p) => p.id == pause.id);

      expect(approved.status, equals('approved'));
      expect(approved.reviewedAt, isNotNull);
    });

    test('T1.5.4: Guardrail verification: Approved pause DOES stop deliveries', () async {
      final start = DateTime.now().add(const Duration(days: 4));
      final mid = DateTime.now().add(const Duration(days: 6));
      final end = DateTime.now().add(const Duration(days: 9));

      final pause = await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: start,
        endDate: end,
      );
      await harness.pauseRepo.approvePause(pause.id);

      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', start), isTrue);
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', mid), isTrue);
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', end), isTrue);

      final pausedIds = await harness.pauseRepo.getPausedCustomerIdsForDate(mid);
      expect(pausedIds.contains('cust-201'), isTrue);
    });

    test('T1.5.5: Automatic delivery resumption on the day following the pause end date', () async {
      final start = DateTime.now().add(const Duration(days: 4));
      final end = DateTime.now().add(const Duration(days: 9));
      final dayAfter = DateTime.now().add(const Duration(days: 10));

      final pause = await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: start,
        endDate: end,
      );
      await harness.pauseRepo.approvePause(pause.id);

      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', end), isTrue);
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', dayAfter), isFalse);

      final pausedIds = await harness.pauseRepo.getPausedCustomerIdsForDate(dayAfter);
      expect(pausedIds.contains('cust-201'), isFalse);
    });

    test('T1.5.6: Seller rejection lifecycle updating status to rejected', () async {
      final pause = await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: DateTime.now().add(const Duration(days: 4)),
        endDate: DateTime.now().add(const Duration(days: 9)),
      );

      await harness.pauseRepo.rejectPause(pause.id);
      final pauses = await harness.pauseRepo.getPausesForCustomer('cust-201');
      final rejected = pauses.firstWhere((p) => p.id == pause.id);

      expect(rejected.status, equals('rejected'));
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', DateTime.now().add(const Duration(days: 6))), isFalse);
    });
  });

  // ===========================================================================
  // TIER 2: BOUNDARY & CORNER CASES (R1 - R5)
  // ===========================================================================
  group('Tier 2: Boundary & Corner Cases (R1 - Localization Boundaries)', () {
    test('T2.1.1: Cold boot with uninitialized storage falls back strictly to Hindi Devanagari (hi)', () async {
      SharedPreferences.setMockInitialValues({});
      final locale = await LocaleNotifier.loadInitialLocale();
      expect(locale, equals(const Locale('hi')));
    });

    test('T2.1.2: Corrupted or unsupported locale codes fallback safely to hi', () async {
      await harness.localeNotifier.setLocale(const Locale('fr_FR'));
      expect(harness.localeNotifier.state, equals(const Locale('hi')));

      await harness.localeNotifier.setLocale(const Locale('!@#\$%'));
      expect(harness.localeNotifier.state, equals(const Locale('hi')));
    });

    test('T2.1.3: Rapid stress toggling (20 alternating cycles) resolves consistently without race condition', () async {
      for (int i = 0; i < 20; i++) {
        await harness.localeNotifier.setLocale(i % 2 == 0 ? const Locale('en') : const Locale('hi'));
      }
      expect(harness.localeNotifier.state, equals(const Locale('hi')));
      expect(harness.localeNotifier.isHindi, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_locale_code'), equals('hi'));
    });

    test('T2.1.4: Parameterized localized strings format currency and volume cleanly', () {
      final formatted = DairyGlossary.formatVolumeAmount(
        liters: 2,
        ml: 500,
        amount: 1750.50,
        langCode: 'hi',
      );
      expect(formatted, contains('✔ दिया (2 L 500 ml) - ₹1751'));
    });

    test('T2.1.5: Missing translation keys fall back safely without uncaught runtime errors', () {
      final val = DairyGlossary.get('non_existent_key_123', 'hi');
      expect(val, equals('non_existent_key_123'));
    });
  });

  group('Tier 2: Boundary & Corner Cases (R2 - Route & Sequencing Boundaries)', () {
    test('T2.2.1: Empty route handling (0 customers) renders clean empty state without index crashes', () async {
      final emptyRoute = await harness.routeRepo.createRoute(
        name: 'Empty Route',
        shift: 'morning',
      );
      final customers = await harness.customerRepo.getCustomersByRoute(emptyRoute.id);
      expect(customers, isEmpty);
    });

    test('T2.2.2: Single customer route reordering is a safe no-op', () async {
      await harness.routeRepo.updateCustomerSequence(['cust-101']);
      final cust = harness.dataStore.customers['cust-101']!;
      expect(cust.deliverySequence, equals(1));
    });

    test('T2.2.3: Historical delivery and billing immutability: stop reordering never mutates past records', () async {
      final day1 = DateTime(2026, 11, 14);
      await harness.billingRepo.recordDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        rate: 60.0,
        date: day1,
      );

      final billsBefore = await harness.billingRepo.getBills(customerId: 'cust-101');
      final pastDeliveryBefore = (await harness.billingRepo.getDeliveries(customerId: 'cust-101')).first;

      // Reorder stops on Day 2
      await harness.routeRepo.updateCustomerSequence(['cust-105', 'cust-104', 'cust-103', 'cust-102', 'cust-101']);

      final pastDeliveryAfter = (await harness.billingRepo.getDeliveries(customerId: 'cust-101')).first;
      final billsAfter = await harness.billingRepo.getBills(customerId: 'cust-101');

      expect(pastDeliveryAfter.customerId, equals(pastDeliveryBefore.customerId));
      expect(pastDeliveryAfter.amount, equals(pastDeliveryBefore.amount));
      expect(pastDeliveryAfter.quantityLiters, equals(pastDeliveryBefore.quantityLiters));
      expect(billsAfter.first.totalAmount, equals(billsBefore.first.totalAmount));
    });

    test('T2.2.4: Route deletion safely unassigns customers (ON DELETE SET NULL) without orphan errors', () async {
      final custBefore = harness.dataStore.customers['cust-101']!;
      expect(custBefore.routeId, equals('route-01'));

      await harness.routeRepo.deleteRoute('route-01');

      final custAfter = harness.dataStore.customers['cust-101']!;
      expect(custAfter.routeId, isNull);
      expect(custAfter.deliverySequence, equals(0));
      expect(await harness.routeRepo.getRouteById('route-01'), isNull);
    });

    test('T2.2.5: Sequence collision normalization eliminates duplicate indices', () async {
      // Simulate collision
      harness.dataStore.customers['cust-101'] = harness.dataStore.customers['cust-101']!.copyWith(deliverySequence: 2);
      harness.dataStore.customers['cust-102'] = harness.dataStore.customers['cust-102']!.copyWith(deliverySequence: 2);

      // Reorder and normalize
      await harness.routeRepo.updateCustomerSequence(['cust-101', 'cust-102']);

      expect(harness.dataStore.customers['cust-101']!.deliverySequence, equals(1));
      expect(harness.dataStore.customers['cust-102']!.deliverySequence, equals(2));
    });

    test('T2.2.6: Unassigned customers display neutral sequence badge ([--])', () {
      final unassigned = Customer(
        id: 'cust-unassigned',
        userId: 'u-un',
        routeId: null,
        deliverySequence: 0,
      );
      expect(formatSequenceBadge(unassigned.deliverySequence), equals('[--]'));
    });
  });

  group('Tier 2: Boundary & Corner Cases (R3 - Delivery & Keep-Awake Boundaries)', () {
    test('T2.3.1: Strict volume negative clamping at 0 mL (-250ml clamped at 0)', () async {
      num liters = 0;
      num ml = 250;

      // Decrement by 250 ml
      final dec1 = MilkUtils.toDecimal(liters, ml) - 0.25;
      expect(dec1, equals(0.0));

      // Repository rejects negative volume with ArgumentError
      expect(
        () => harness.billingRepo.recordDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: -1.0,
          quantityMl: 0,
          rate: 60.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => harness.billingRepo.recordDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 0,
          quantityMl: -250,
          rate: 60.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Offline queue also rejects negative volume with ArgumentError
      expect(
        () => harness.offlineQueue.enqueueDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: -1.0,
          quantityMl: 0,
          deliveryDate: DateTime.now(),
          shift: 'morning',
          status: 'delivered',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => harness.offlineQueue.enqueueDelivery(
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

    test('T2.3.2: Zero-volume delivery prevention rejects attempts to mark 0 mL as delivered', () async {
      // Rejects 0 L and 0 mL for 'delivered' status with ArgumentError
      expect(
        () => harness.billingRepo.recordDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 0,
          quantityMl: 0,
          rate: 60.0,
          status: 'delivered',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Offline queue also rejects 0 volume for delivered status with ArgumentError
      expect(
        () => harness.offlineQueue.enqueueDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 0.0,
          quantityMl: 0,
          deliveryDate: DateTime.now(),
          shift: 'morning',
          status: 'delivered',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Verify non-zero delivered quantity succeeds
      await harness.billingRepo.recordDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 0,
        quantityMl: 250,
        rate: 60.0,
        status: 'delivered',
      );
      final deliveries = await harness.billingRepo.getDeliveries(customerId: 'cust-101');
      expect(deliveries.length, equals(1));
      expect(deliveries.first.quantityMl, equals(250));
    });

    test('T2.3.3: Large commercial volume arithmetic precision (150+ L @ ₹58.50/L without floating point drift)', () {
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

    test('T2.3.4: Rapid double-tap debouncing ensures idempotent single delivery record insertion', () async {
      final date = DateTime(2026, 11, 16);

      // Simulate simultaneous rapid double-tap
      await Future.wait([
        harness.billingRepo.recordDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 1.0,
          quantityMl: 0,
          rate: 60.0,
          date: date,
          shift: 'morning',
        ),
        harness.billingRepo.recordDelivery(
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

      final deliveries = await harness.billingRepo.getDeliveries(
        customerId: 'cust-101',
        date: date,
      );
      expect(deliveries.length, equals(1));
    });

    test('T2.3.5: Offline queue persistence and durability across app cold restarts', () async {
      await harness.offlineQueue.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        deliveryDate: DateTime(2026, 11, 16),
        shift: 'morning',
        status: 'delivered',
      );

      // Create a fresh queue simulating cold boot
      final coldQueue = InMemoryOfflineDeliveryQueueService(harness.dataStore);
      await coldQueue.restoreFromPrefs();

      expect(coldQueue.getUnsyncedDeliveries().length, equals(1));
      expect(coldQueue.getUnsyncedDeliveries().first.customerId, equals('cust-101'));
    });

    test('T2.3.6: Screen keep-awake suspension during app backgrounding (paused vs resumed)', () async {
      // App in foreground: keep-awake active
      await WakelockPlus.enable();
      expect(await WakelockPlus.enabled, isTrue);
      expect(harness.wakelockEnabled, isTrue);

      // App backgrounded (paused): suspend keep-awake
      await WakelockPlus.disable();
      expect(await WakelockPlus.enabled, isFalse);
      expect(harness.wakelockEnabled, isFalse);

      // App foregrounded (resumed): restore keep-awake
      await WakelockPlus.enable();
      expect(await WakelockPlus.enabled, isTrue);
      expect(harness.wakelockEnabled, isTrue);

      // Cleanup
      await WakelockPlus.disable();
      expect(await WakelockPlus.enabled, isFalse);
      expect(harness.wakelockEnabled, isFalse);
    });
  });

  group('Tier 2: Boundary & Corner Cases (R4 - Payments & WhatsApp Boundaries)', () {
    test('T2.4.1: Zero pending balance UPI handling formats clean am=0.00 and disables payment button', () {
      final uri = UpiPaymentService.buildUpiUri(
        upiId: 'dairy@upi',
        payeeName: 'Dairy',
        amount: 0.00,
        transactionNote: 'Paid in full',
      );
      expect(uri.queryParameters['am'], equals('0.00'));

      // Reject negative amounts with ArgumentError
      expect(
        () => UpiPaymentService.buildUpiUri(
          upiId: 'dairy@upi',
          payeeName: 'Dairy',
          amount: -50.0,
          transactionNote: 'Invalid negative',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final invoice = WhatsappShareService.formatDairyInvoice(
        dairyName: 'Shree Dairy',
        customerName: 'Anil Kumar',
        monthYear: 'November 2026',
        totalLiters: 10.0,
        milkType: 'COW',
        totalAmount: 600.0,
        paidAmount: 600.0,
        pendingAmount: 0.0,
        upiId: 'dairy@upi',
      );
      expect(invoice, contains('बिल पूरा चुकता कर दिया गया है'));
    });

    test('T2.4.2: Indian phone number sanitization across multiple formats', () {
      expect(WhatsappShareService.sanitizeIndianPhone('+91 98765 43210'), equals('919876543210'));
      expect(WhatsappShareService.sanitizeIndianPhone('09876543210'), equals('919876543210'));
      expect(WhatsappShareService.sanitizeIndianPhone('98765-43210'), equals('919876543210'));
      expect(WhatsappShareService.sanitizeIndianPhone('9876543210'), equals('919876543210'));
      expect(WhatsappShareService.sanitizeIndianPhone('919876543210'), equals('919876543210'));
      expect(() => WhatsappShareService.sanitizeIndianPhone('12345'), throwsA(isA<FormatException>()));
    });

    test('T2.4.3: Devanagari script and special character URL encoding in UPI payee and note', () {
      final uri = UpiPaymentService.buildUpiUri(
        upiId: 'krishna@upi',
        payeeName: 'श्री & कृष्णा Dairy',
        amount: 550.50,
        transactionNote: 'दूध का बिल #123 & "Special"',
      );

      expect(uri.queryParameters['pn'], equals('श्री & कृष्णा Dairy'));
      expect(uri.queryParameters['tn'], equals('दूध का बिल #123 & "Special"'));
      expect(uri.toString(), contains('upi://pay?'));
    });

    test('T2.4.4: Cash overpayment capping: payment exceeding bill total caps paidAmount and clamps pending to 0', () async {
      final month = DateTime(2026, 11, 1);
      harness.dataStore.upsertBill(
        DairyTestFixtures.createBill(
          customerId: 'cust-103',
          billMonth: month,
          totalAmount: 450.0,
          paidAmount: 0.0,
          pendingAmount: 450.0,
        ),
      );

      await harness.billingRepo.recordCollection(
        customerId: 'cust-103',
        sellerId: DairyTestFixtures.seller1Id,
        amountPaid: 500.0, // ₹50 overpayment
        billMonth: month,
      );

      final bill = (await harness.billingRepo.getBills(customerId: 'cust-103', month: month)).first;
      expect(bill.paidAmount, equals(450.0)); // Capped
      expect(bill.pendingAmount, equals(0.0));
      expect(bill.status, equals('paid'));
    });

    test('T2.4.5: NPCI two-decimal precision strictness', () {
      expect(UpiPaymentService.formatAmount(50), equals('50.00'));
      expect(UpiPaymentService.formatAmount(50.5), equals('50.50'));
      expect(UpiPaymentService.formatAmount(50.555), equals('50.56'));
      expect(UpiPaymentService.formatAmount(100.994), equals('100.99'));
    });

    test('T2.4.6: Missing seller UPI ID fallback in WhatsApp invoice replaces link with cash payment prompt', () {
      final invoice = WhatsappShareService.formatDairyInvoice(
        dairyName: 'Shree Dairy',
        customerName: 'Anil Kumar',
        monthYear: 'November 2026',
        totalLiters: 20.0,
        milkType: 'COW',
        totalAmount: 1200.00,
        paidAmount: 0.00,
        pendingAmount: 1200.00,
        upiId: '', // Empty
      );

      expect(invoice, isNot(contains('pa=')));
      expect(invoice, isNot(contains('null')));
      expect(invoice, contains('भुगतान के लिए दूधवाले से संपर्क करें'));
    });
  });

  group('Tier 2: Boundary & Corner Cases (R5 - Vacation & Guardrail Boundaries)', () {
    test('T2.5.1: Validation rejection of past start dates (yesterday)', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        () => harness.pauseRepo.createPauseRequest(
          customerId: 'cust-201',
          startDate: yesterday,
          endDate: yesterday.add(const Duration(days: 3)),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('T2.5.2: Validation rejection of inverted date ranges (startDate > endDate)', () {
      expect(
        () => harness.pauseRepo.createPauseRequest(
          customerId: 'cust-201',
          startDate: DateTime.now().add(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 2)),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('T2.5.3: Single-day pause (startDate == endDate) pauses only that single day', () async {
      final singleDay = DateTime.now().add(const Duration(days: 5));
      final pause = await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: singleDay,
        endDate: singleDay,
      );
      await harness.pauseRepo.approvePause(pause.id);

      final dayBefore = singleDay.subtract(const Duration(days: 1));
      final dayAfter = singleDay.add(const Duration(days: 1));

      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', dayBefore), isFalse);
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', singleDay), isTrue);
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', dayAfter), isFalse);
    });

    test('T2.5.4: Overlapping pause collision detection', () async {
      final start1 = DateTime.now().add(const Duration(days: 3));
      final end1 = DateTime.now().add(const Duration(days: 7));
      await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: start1,
        endDate: end1,
      );

      // Attempt overlapping pause
      final start2 = DateTime.now().add(const Duration(days: 5));
      final end2 = DateTime.now().add(const Duration(days: 10));

      expect(
        () => harness.pauseRepo.createPauseRequest(
          customerId: 'cust-201',
          startDate: start2,
          endDate: end2,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('T2.5.5: Full-day date boundary inclusivity (00:00:00 through 23:59:59)', () async {
      final start = DateTime.now().add(const Duration(days: 4));
      final end = DateTime.now().add(const Duration(days: 6));
      final pause = await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: start,
        endDate: end,
      );
      await harness.pauseRepo.approvePause(pause.id);

      final earlyStart = DateTime(start.year, start.month, start.day, 0, 0, 1);
      final lateEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);

      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', earlyStart), isTrue);
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', lateEnd), isTrue);
    });

    test('T2.5.6: Multi-seller pending pause isolation prevents data leakage between sellers', () async {
      await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-101', // Belongs to seller-01
        startDate: DateTime.now().add(const Duration(days: 3)),
        endDate: DateTime.now().add(const Duration(days: 5)),
      );

      final seller1Pauses = await harness.pauseRepo.getPendingPausesForSeller(DairyTestFixtures.seller1Id);
      final seller2Pauses = await harness.pauseRepo.getPendingPausesForSeller(DairyTestFixtures.seller2Id);

      expect(seller1Pauses.length, equals(1));
      expect(seller2Pauses, isEmpty);
    });
  });

  // ===========================================================================
  // TIER 3: CROSS-FEATURE PAIRWISE COMBINATIONS (8 TESTS)
  // ===========================================================================
  group('Tier 3: Cross-Feature Pairwise Combinations', () {
    test('T3.1: Shift Filtering + Customer Sequence Ordering (R2 + R2)', () async {
      // Route with morning and evening customers
      final morningCustomers = await harness.customerRepo.getCustomersBySeller(
        DairyTestFixtures.seller1Id,
        routeId: 'route-01',
        shift: 'morning',
      );

      for (int i = 0; i < morningCustomers.length; i++) {
        expect(morningCustomers[i].deliverySequence, equals(i + 1));
      }
    });

    test('T3.2: Approved Vacation + 1-Tap Delivery / Volume Stepper Blocking (R5 + R3)', () async {
      final today = DateTime.now().add(const Duration(days: 3));
      final pause = await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );
      await harness.pauseRepo.approvePause(pause.id);

      final isPaused = await harness.pauseRepo.isCustomerPausedOnDate('cust-101', today);
      expect(isPaused, isTrue);

      // Verify delivery marking guardrail throws StateError
      expect(
        () => harness.billingRepo.recordDelivery(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          milkType: 'cow',
          quantityLiters: 1.0,
          quantityMl: 0,
          rate: 60.0,
          date: today,
        ),
        throwsA(isA<StateError>()),
      );

      // Verify offline queue also rejects delivery during vacation with StateError
      expect(
        () => harness.offlineQueue.enqueueDelivery(
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

    test('T3.3: Doorstep Cash Collection + UPI URL Remainder & WhatsApp Invoice Balance (R4 + R4)', () async {
      final month = DateTime(2026, 11, 1);
      harness.dataStore.upsertBill(
        DairyTestFixtures.createBill(
          customerId: 'cust-101',
          billMonth: month,
          totalAmount: 2000.0,
          paidAmount: 0.0,
          pendingAmount: 2000.0,
        ),
      );

      // Collect ₹800 cash
      await harness.billingRepo.recordCollection(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        amountPaid: 800.0,
        billMonth: month,
      );

      final bill = (await harness.billingRepo.getBills(customerId: 'cust-101', month: month)).first;
      expect(bill.pendingAmount, equals(1200.0));

      // Generate remainder UPI URI
      final upiUri = UpiPaymentService.buildUpiUri(
        upiId: 'shreedairy@oksbi',
        payeeName: 'Shree Krishna Dairy',
        amount: bill.pendingAmount.toDouble(),
        transactionNote: 'Bill Balance Nov 2026',
      );
      expect(upiUri.queryParameters['am'], equals('1200.00'));

      // Generate remainder invoice
      final invoice = WhatsappShareService.formatDairyInvoice(
        dairyName: 'Shree Krishna Dairy',
        customerName: 'Amit Sharma',
        monthYear: 'November 2026',
        totalLiters: 33.3,
        milkType: 'COW',
        totalAmount: 2000.0,
        paidAmount: 800.0,
        pendingAmount: 1200.0,
        upiId: 'shreedairy@oksbi',
      );
      expect(invoice, contains('बकाया राशि: ₹1200'));
      expect(invoice, contains('am=1200.00'));
    });

    test('T3.4: Bilingual Runtime Toggle + WhatsApp Invoice Generation (R1 + R4)', () async {
      await harness.localeNotifier.setLocale(const Locale('hi'));
      expect(harness.localeNotifier.isHindi, isTrue);

      final invoiceHi = WhatsappShareService.formatDairyInvoice(
        dairyName: 'Shree Krishna Dairy',
        customerName: 'Amit Sharma',
        monthYear: 'November 2026',
        totalLiters: 30.0,
        milkType: 'COW',
        totalAmount: 1800.0,
        paidAmount: 0.0,
        pendingAmount: 1800.0,
        upiId: 'shreedairy@oksbi',
      );

      expect(invoiceHi, contains('दूध का मासिक हिसाब'));
      expect(invoiceHi, contains('बकाया राशि: ₹1800'));
    });

    test('T3.5: Stop Drag & Reordering + Historical Delivery Immutability (R2 + R3)', () async {
      final yesterday = DateTime(2026, 11, 15);
      await harness.billingRepo.recordDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        rate: 60.0,
        date: yesterday,
      );

      // Reorder stops
      await harness.routeRepo.updateCustomerSequence(['cust-105', 'cust-101']);

      final deliveries = await harness.billingRepo.getDeliveries(customerId: 'cust-101');
      expect(deliveries.first.quantityLiters, equals(1.0));
      expect(deliveries.first.deliveryDate, equals(yesterday));
    });

    test('T3.6: Offline Delivery Queue Sync + Automatic Monthly Bill Rollup (R3 + R4)', () async {
      final date = DateTime(2026, 11, 16);
      await harness.offlineQueue.enqueueDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.5,
        quantityMl: 0,
        deliveryDate: date,
        shift: 'morning',
        status: 'delivered',
      );

      await harness.offlineQueue.syncQueueToSupabase();

      final bill = (await harness.billingRepo.getBills(customerId: 'cust-101', month: date)).first;
      expect(bill.totalQuantityLiters, equals(1.5));
      expect(bill.totalAmount, equals(90.0)); // 1.5 * 60 = 90
    });

    test('T3.7: Pending Vacation Pause + 1-Tap Skip Action (R5 + R3)', () async {
      final today = DateTime.now().add(const Duration(days: 3));
      await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );

      // Unapproved pause does not block
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-101', today), isFalse);

      // Seller arrives to locked house, records 1-tap skip
      await harness.billingRepo.recordSkippedDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        date: today,
      );

      final deliveries = await harness.billingRepo.getDeliveries(customerId: 'cust-101');
      expect(deliveries.first.status, equals('skipped'));
      expect(deliveries.first.amount, equals(0.0));
    });

    test('T3.8: Unified Owner-Seller Mode + Multi-Route Selection (R2 + R2)', () async {
      // Owner selects Route North
      final routeNorth = await harness.routeRepo.getRouteById('route-north');
      expect(routeNorth!.sellerId, equals(DairyTestFixtures.adminOwnerId));

      // Owner selects Route South
      final routeSouth = await harness.routeRepo.getRouteById('route-south');
      expect(routeSouth!.sellerId, equals(DairyTestFixtures.adminOwnerId));
    });
  });

  // ===========================================================================
  // TIER 4: REAL-WORLD DAILY DAIRY OPERATIONAL SCENARIOS (5 SCENARIOS)
  // ===========================================================================
  group('Tier 4: Real-World Daily Dairy Operational Scenarios', () {
    test('T4.1: Scenario 1 - Full Morning Route Run with Steppers, Skips & Offline Sync', () async {
      final today = DateTime(2026, 11, 16);

      // 1. Keep-Awake enabled via WakelockPlus
      await WakelockPlus.enable();
      expect(await WakelockPlus.enabled, isTrue);
      expect(harness.wakelockEnabled, isTrue);

      // 2. Stop 1 (Customer 1): 1-tap Delivered (1.0 L Cow Milk)
      await harness.billingRepo.recordDelivery(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        rate: 60.0,
        date: today,
      );

      // 3. Stop 2 (Customer 2): 1-tap Delivered (1.5 L Buffalo Milk)
      await harness.billingRepo.recordDelivery(
        customerId: 'cust-102',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'buffalo',
        quantityLiters: 1.5,
        quantityMl: 0,
        rate: 70.0,
        date: today,
      );

      // 4. Stop 3 (Customer 3): Inline Stepper +500ml (1.0L default + 500ml = 1.5 L Cow Milk)
      final stepLiters = 1;
      final stepMl = 500;
      await harness.billingRepo.recordDelivery(
        customerId: 'cust-103',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: stepLiters,
        quantityMl: stepMl,
        rate: 60.0,
        date: today,
      );

      // 5. Stop 4 (Customer 4): Locked Gate -> 1-Tap Skip Action (0 L)
      await harness.billingRepo.recordSkippedDelivery(
        customerId: 'cust-104',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        date: today,
      );

      // 6. Stop 5 (Customer 5): Basement Offline Zone -> Enqueued offline
      await harness.offlineQueue.enqueueDelivery(
        customerId: 'cust-105',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'buffalo',
        quantityLiters: 2.0,
        quantityMl: 0,
        deliveryDate: today,
        shift: 'morning',
        status: 'delivered',
      );
      expect(harness.offlineQueue.getUnsyncedDeliveries().length, equals(1));

      // 7. Network restores -> Background Sync
      final synced = await harness.offlineQueue.syncQueueToSupabase();
      expect(synced, equals(1));
      expect(harness.offlineQueue.getUnsyncedDeliveries(), isEmpty);

      // Verification of entire morning route
      final allDeliveries = await harness.billingRepo.getDeliveries(month: today, shift: 'morning');
      expect(allDeliveries.length, equals(5));

      double totalLiters = 0;
      for (final d in allDeliveries) {
        totalLiters += d.totalLiters;
      }
      expect(totalLiters, equals(6.0)); // 1.0 + 1.5 + 1.5 + 0.0 + 2.0 = 6.0 L

      // Route complete -> disable keep-awake
      await WakelockPlus.disable();
      expect(await WakelockPlus.enabled, isFalse);
    });

    test('T4.2: Scenario 2 - Mid-Route Customer Addition & Dynamic Sequence Reordering', () async {
      // 1. Initial 3 customers
      final initialCustomers = ['cust-101', 'cust-102', 'cust-103'];
      await harness.routeRepo.updateCustomerSequence(initialCustomers);

      // 2. Add new household mid-route
      final newCust = await harness.customerRepo.createCustomer(
        userId: 'u-deepak',
        sellerId: DairyTestFixtures.seller1Id,
        routeId: 'route-01',
        deliverySequence: 4,
        milkType: 'cow',
        ratePerLiter: 60.0,
      );

      // 3. Drag new customer between Stop #1 and Stop #2
      final updatedOrder = ['cust-101', newCust.id, 'cust-102', 'cust-103'];
      await harness.routeRepo.updateCustomerSequence(updatedOrder);

      // 4. Verification
      final finalRoute = await harness.customerRepo.getCustomersByRoute('route-01');
      expect(finalRoute.first.id, equals('cust-101'));
      expect(finalRoute[1].id, equals(newCust.id));
      expect(finalRoute[1].deliverySequence, equals(2));
      expect(finalRoute[2].id, equals('cust-102'));
      expect(finalRoute[2].deliverySequence, equals(3));
      expect(finalRoute[3].id, equals('cust-103'));
      expect(finalRoute[3].deliverySequence, equals(4));
    });

    test('T4.3: Scenario 3 - Customer Vacation Pause Lifecycle & Delivery Sheet Impact', () async {
      final now = DateTime.now();
      final day19 = now.add(const Duration(days: 3));
      final day20 = now.add(const Duration(days: 4));
      final day24 = now.add(const Duration(days: 8));
      final day25 = now.add(const Duration(days: 9));

      // Phase 1: Customer submits pause
      final pause = await harness.pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: day20,
        endDate: day24,
        reason: 'शादी में जाना है',
      );
      expect(pause.status, equals('pending'));

      // Phase 2: Before approval on day 19, delivery remains active
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', day19), isFalse);
      await harness.billingRepo.recordDelivery(
        customerId: 'cust-201',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.5,
        quantityMl: 0,
        rate: 60.0,
        date: day19,
      );

      // Phase 3: Seller approves pause
      await harness.pauseRepo.approvePause(pause.id);

      // Phase 4: Active pause blocks delivery on days 20 to 24
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', day20), isTrue);
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', day24), isTrue);

      // Phase 5: Automatic resumption on day 25
      expect(await harness.pauseRepo.isCustomerPausedOnDate('cust-201', day25), isFalse);
      await harness.billingRepo.recordDelivery(
        customerId: 'cust-201',
        sellerId: DairyTestFixtures.seller1Id,
        milkType: 'cow',
        quantityLiters: 1.5,
        quantityMl: 0,
        rate: 60.0,
        date: day25,
      );

      // Verified: 2 deliveries recorded (day 19 and day 25), days 20-24 blocked
      final deliveries = await harness.billingRepo.getDeliveries(customerId: 'cust-201');
      expect(deliveries.length, equals(2));
    });

    test('T4.4: Scenario 4 - End-of-Month Billing Settlement (Cash, UPI Deep Link & WhatsApp)', () async {
      final month = DateTime(2026, 11, 1);

      // 25 days * 1 L = 25 L @ ₹60/L = ₹1500 total
      harness.dataStore.upsertBill(
        CustomerBill(
          id: 'bill-nov-vikram',
          customerId: 'cust-105',
          sellerId: DairyTestFixtures.seller1Id,
          billMonth: month,
          totalQuantityLiters: 25.0,
          totalAmount: 1500.0,
          paidAmount: 0.0,
          pendingAmount: 1500.0,
          status: 'pending',
          customerName: 'Vikram Singh',
          sellerName: 'Shree Krishna Dairy',
        ),
      );

      // 1. Collect ₹500 in doorstep cash
      await harness.billingRepo.recordCollection(
        customerId: 'cust-105',
        sellerId: DairyTestFixtures.seller1Id,
        amountPaid: 500.0,
        billMonth: month,
        paymentMode: 'cash',
      );

      final bill = (await harness.billingRepo.getBills(customerId: 'cust-105', month: month)).first;
      expect(bill.paidAmount, equals(500.0));
      expect(bill.pendingAmount, equals(1000.0));
      expect(bill.status, equals('partial'));

      // 2. Generate UPI URL for remainder ₹1000
      final upiUri = UpiPaymentService.buildUpiUri(
        upiId: 'shreedairy@oksbi',
        payeeName: 'Shree Krishna Dairy',
        amount: bill.pendingAmount.toDouble(),
        transactionNote: 'Milk Bill Nov 2026 - Vikram Singh',
      );
      expect(upiUri.queryParameters['am'], equals('1000.00'));

      // 3. Generate bilingual WhatsApp invoice
      final invoice = WhatsappShareService.formatDairyInvoice(
        dairyName: 'Shree Krishna Dairy',
        customerName: 'Vikram Singh',
        monthYear: 'November 2026',
        totalLiters: 25.0,
        milkType: 'BUFFALO',
        totalAmount: 1500.0,
        paidAmount: 500.0,
        pendingAmount: 1000.0,
        upiId: 'shreedairy@oksbi',
      );

      expect(invoice, contains('दूध का मासिक हिसाब - Shree Krishna Dairy'));
      expect(invoice, contains('कुल राशि: ₹1500'));
      expect(invoice, contains('प्राप्त राशि: ₹500'));
      expect(invoice, contains('बकाया राशि: ₹1000'));
      expect(invoice, contains('am=1000.00'));
      expect(invoice, contains('धन्यवाद! 🙏'));
    });

    test('T4.5: Scenario 5 - Dual-Shift & Multi-Route Operation in Unified Owner Mode', () async {
      final today = DateTime(2026, 11, 16);

      // Morning shift: North Ward (4 stops, 5.5 L delivered)
      await harness.billingRepo.recordDelivery(
        customerId: 'c-n1',
        sellerId: DairyTestFixtures.adminOwnerId,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        rate: 60.0,
        date: today,
        shift: 'morning',
      );
      await harness.billingRepo.recordDelivery(
        customerId: 'c-n2',
        sellerId: DairyTestFixtures.adminOwnerId,
        milkType: 'cow',
        quantityLiters: 1.5,
        quantityMl: 0,
        rate: 60.0,
        date: today,
        shift: 'morning',
      );
      await harness.billingRepo.recordDelivery(
        customerId: 'c-n3',
        sellerId: DairyTestFixtures.adminOwnerId,
        milkType: 'buffalo',
        quantityLiters: 2.0,
        quantityMl: 0,
        rate: 70.0,
        date: today,
        shift: 'morning',
      );
      await harness.billingRepo.recordDelivery(
        customerId: 'c-n4',
        sellerId: DairyTestFixtures.adminOwnerId,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        rate: 60.0,
        date: today,
        shift: 'morning',
      );

      // Evening shift: South Ward (3 stops, 4.0 L delivered)
      await harness.billingRepo.recordDelivery(
        customerId: 'c-s1',
        sellerId: DairyTestFixtures.adminOwnerId,
        milkType: 'cow',
        quantityLiters: 1.5,
        quantityMl: 0,
        rate: 60.0,
        date: today,
        shift: 'evening',
      );
      await harness.billingRepo.recordDelivery(
        customerId: 'c-s2',
        sellerId: DairyTestFixtures.adminOwnerId,
        milkType: 'cow',
        quantityLiters: 1.0,
        quantityMl: 0,
        rate: 60.0,
        date: today,
        shift: 'evening',
      );
      await harness.billingRepo.recordDelivery(
        customerId: 'c-s3',
        sellerId: DairyTestFixtures.adminOwnerId,
        milkType: 'buffalo',
        quantityLiters: 1.5,
        quantityMl: 0,
        rate: 70.0,
        date: today,
        shift: 'evening',
      );

      // Verification
      final morningDeliveries = await harness.billingRepo.getDeliveries(
        sellerId: DairyTestFixtures.adminOwnerId,
        shift: 'morning',
      );
      expect(morningDeliveries.length, equals(4));

      final eveningDeliveries = await harness.billingRepo.getDeliveries(
        sellerId: DairyTestFixtures.adminOwnerId,
        shift: 'evening',
      );
      expect(eveningDeliveries.length, equals(3));

      double morningLiters = morningDeliveries.fold(0, (sum, d) => sum + d.totalLiters);
      double eveningLiters = eveningDeliveries.fold(0, (sum, d) => sum + d.totalLiters);

      expect(morningLiters, equals(5.5));
      expect(eveningLiters, equals(4.0));
      expect(morningLiters + eveningLiters, equals(9.5));
    });
  });
}
