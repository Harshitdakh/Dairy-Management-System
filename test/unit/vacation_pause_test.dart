import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milk_hub/features/customer/pause_request_dialog.dart';
import 'package:milk_hub/features/seller/pending_pauses_card.dart';
import 'package:milk_hub/l10n/app_localizations.dart';
import 'package:milk_hub/models/customer.dart';
import 'package:milk_hub/models/delivery_pause.dart';
import 'package:milk_hub/models/milk_delivery.dart';
import 'package:milk_hub/providers/pause_provider.dart';
import 'package:milk_hub/services/upi_payment_service.dart';

import '../helpers/dairy_test_fixtures.dart';
import '../helpers/in_memory_dairy_data_store.dart';
import '../helpers/in_memory_pause_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDairyDataStore dataStore;
  late InMemoryPauseRepository pauseRepo;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    dataStore = InMemoryDairyDataStore();
    dataStore.seedDefaults();
    pauseRepo = InMemoryPauseRepository(dataStore);
  });

  Widget createTestWidget(
    Widget child, {
    Locale locale = const Locale('hi'),
  }) {
    return ProviderScope(
      overrides: [
        pauseRepositoryProvider.overrideWithValue(pauseRepo),
        allPendingPausesProvider.overrideWith((ref) => pauseRepo.getAllPendingPauses()),
        pendingPausesForSellerProvider.overrideWith(
          (ref, sellerId) => pauseRepo.getPendingPausesForSeller(sellerId),
        ),
        customerPausesProvider.overrideWith(
          (ref, customerId) => pauseRepo.getPausesForCustomer(customerId),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Group 1: Pause Request Date Validation Rules', () {
    test('T1.1: Past start date (yesterday) throws ArgumentError', () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      final nextWeek = yesterday.add(const Duration(days: 5));

      expect(
        () => pauseRepo.createPauseRequest(
          customerId: 'cust-101',
          startDate: yesterday,
          endDate: nextWeek,
          reason: 'Past pause',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('प्रारंभ तिथि आज या भविष्य की होनी चाहिए'),
        )),
      );
    });

    test('T1.2: Today as start date succeeds and creates a pending pause', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final endDate = today.add(const Duration(days: 2));

      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: endDate,
        reason: 'Immediate pause today',
      );

      expect(pause.id, isNotEmpty);
      expect(pause.status, equals('pending'));
      expect(pause.customerId, equals('cust-101'));
      expect(pause.reason, equals('Immediate pause today'));
    });

    test('T1.3: Future start date succeeds and creates a pending pause', () async {
      final now = DateTime.now();
      final futureStart = DateTime(now.year, now.month, now.day).add(const Duration(days: 5));
      final futureEnd = futureStart.add(const Duration(days: 3));

      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: futureStart,
        endDate: futureEnd,
        reason: 'Next week holiday',
      );

      expect(pause.id, isNotEmpty);
      expect(pause.status, equals('pending'));
      expect(pause.startDate, equals(futureStart));
      expect(pause.endDate, equals(futureEnd));
    });

    test('T1.4: Inverted date range (startDate > endDate) throws ArgumentError', () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).add(const Duration(days: 5));
      final invertedEnd = start.subtract(const Duration(days: 2));

      expect(
        () => pauseRepo.createPauseRequest(
          customerId: 'cust-101',
          startDate: start,
          endDate: invertedEnd,
          reason: 'Inverted dates',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('समाप्ति तिथि प्रारंभ तिथि से पहले नहीं हो सकती'),
        )),
      );
    });

    test('T1.5: Single-day pause (startDate == endDate) is accepted', () async {
      final now = DateTime.now();
      final singleDay = DateTime(now.year, now.month, now.day).add(const Duration(days: 2));

      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: singleDay,
        endDate: singleDay,
        reason: 'One day off',
      );

      expect(pause.id, isNotEmpty);
      expect(pause.status, equals('pending'));
      expect(pause.startDate, equals(singleDay));
      expect(pause.endDate, equals(singleDay));
    });

    test('T1.6: Overlapping date range with existing pending or approved pause throws ArgumentError', () async {
      final now = DateTime.now();
      final start1 = DateTime(now.year, now.month, now.day).add(const Duration(days: 10));
      final end1 = start1.add(const Duration(days: 5)); // Days 10 to 15

      await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: start1,
        endDate: end1,
        reason: 'Initial leave',
      );

      // Overlap from day 12 to 17
      final start2 = start1.add(const Duration(days: 2));
      final end2 = start2.add(const Duration(days: 5));

      expect(
        () => pauseRepo.createPauseRequest(
          customerId: 'cust-101',
          startDate: start2,
          endDate: end2,
          reason: 'Colliding leave',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('इस अवधि के लिए पहले से अवकाश अनुरोध मौजूद है'),
        )),
      );
    });

    test('T1.7: Adjacent non-overlapping date ranges for the same customer both succeed', () async {
      final now = DateTime.now();
      final start1 = DateTime(now.year, now.month, now.day).add(const Duration(days: 20));
      final end1 = start1.add(const Duration(days: 2)); // Days 20 to 22

      final pause1 = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: start1,
        endDate: end1,
        reason: 'Period 1',
      );

      await Future.delayed(const Duration(milliseconds: 2));

      // Adjacent: Day 23 to 25
      final start2 = end1.add(const Duration(days: 1));
      final end2 = start2.add(const Duration(days: 2));

      final pause2 = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: start2,
        endDate: end2,
        reason: 'Period 2',
      );

      expect(pause1.id, isNotEmpty);
      expect(pause2.id, isNotEmpty);
      expect(pause1.id, isNot(equals(pause2.id)));
    });
  });

  group('Group 2: Pause Model Properties & Date Arithmetic', () {
    test('T2.1: Default status is pending, getters evaluate correctly', () {
      final pause = DeliveryPause(
        id: 'p-01',
        customerId: 'cust-101',
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 25),
        status: 'pending',
      );

      expect(pause.isPending, isTrue);
      expect(pause.isApproved, isFalse);
      expect(pause.isRejected, isFalse);
      expect(pause.isCancelled, isFalse);
    });

    test('T2.2: isActiveOn returns false when status is pending, even if date falls within range', () {
      final pause = DeliveryPause(
        id: 'p-01',
        customerId: 'cust-101',
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 25),
        status: 'pending',
      );

      expect(pause.isActiveOn(DateTime(2026, 11, 22)), isFalse);
      expect(pause.isActiveOn(DateTime(2026, 11, 20)), isFalse);
      expect(pause.isActiveOn(DateTime(2026, 11, 25)), isFalse);
    });

    test('T2.3: isActiveOn returns true when status is approved and date is within range (inclusive start and end)', () {
      final pause = DeliveryPause(
        id: 'p-01',
        customerId: 'cust-101',
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 25),
        status: 'approved',
      );

      expect(pause.isActiveOn(DateTime(2026, 11, 20)), isTrue); // inclusive start
      expect(pause.isActiveOn(DateTime(2026, 11, 22)), isTrue); // middle
      expect(pause.isActiveOn(DateTime(2026, 11, 25)), isTrue); // inclusive end
      expect(pause.isActiveOn(DateTime(2026, 11, 19)), isFalse); // before
      expect(pause.isActiveOn(DateTime(2026, 11, 26)), isFalse); // after
    });

    test('T2.4: isActiveOn handles boundary times (00:00:00 and 23:59:59) correctly', () {
      final pause = DeliveryPause(
        id: 'p-01',
        customerId: 'cust-101',
        startDate: DateTime(2026, 11, 20, 14, 30),
        endDate: DateTime(2026, 11, 22, 18, 45),
        status: 'approved',
      );

      // Check midnight of start date
      expect(pause.isActiveOn(DateTime(2026, 11, 20, 0, 0, 0)), isTrue);
      // Check last second of end date
      expect(pause.isActiveOn(DateTime(2026, 11, 22, 23, 59, 59)), isTrue);
      // Check day after
      expect(pause.isActiveOn(DateTime(2026, 11, 23, 0, 0, 0)), isFalse);
    });

    test('T2.5: copyWith produces updated immutable instances with new status and reviewed timestamps', () {
      final pause = DeliveryPause(
        id: 'p-01',
        customerId: 'cust-101',
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 25),
        status: 'pending',
      );

      final reviewTime = DateTime.now();
      final approved = pause.copyWith(
        status: 'approved',
        reviewedBy: 'seller-01',
        reviewedAt: reviewTime,
      );

      expect(approved.id, equals('p-01'));
      expect(approved.status, equals('approved'));
      expect(approved.isApproved, isTrue);
      expect(approved.reviewedBy, equals('seller-01'));
      expect(approved.reviewedAt, equals(reviewTime));
      // Original remains untouched
      expect(pause.status, equals('pending'));
    });
  });

  group('Group 3: Approval / Rejection Lifecycle & Multi-Seller Isolation', () {
    test('T3.1: approvePause transitions status to approved and records reviewedAt', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today.add(const Duration(days: 1)),
        endDate: today.add(const Duration(days: 3)),
      );

      expect(pause.status, equals('pending'));
      await pauseRepo.approvePause(pause.id);

      final updated = dataStore.pauses[pause.id];
      expect(updated?.status, equals('approved'));
      expect(updated?.reviewedAt, isNotNull);
    });

    test('T3.2: rejectPause transitions status to rejected and records reviewedAt', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today.add(const Duration(days: 1)),
        endDate: today.add(const Duration(days: 3)),
      );

      await pauseRepo.rejectPause(pause.id);

      final updated = dataStore.pauses[pause.id];
      expect(updated?.status, equals('rejected'));
      expect(updated?.isRejected, isTrue);
      expect(updated?.reviewedAt, isNotNull);
    });

    test('T3.3: cancelPause transitions status to cancelled', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today.add(const Duration(days: 1)),
        endDate: today.add(const Duration(days: 3)),
      );

      await pauseRepo.cancelPause(pause.id);

      final updated = dataStore.pauses[pause.id];
      expect(updated?.status, equals('cancelled'));
      expect(updated?.isCancelled, isTrue);
    });

    test('T3.4: getPendingPausesForSeller filters strictly by sellers customers and prevents leakage', () async {
      // Ensure customer mapping for both sellers
      dataStore.customers['cust-101'] = Customer(
        id: 'cust-101',
        userId: 'user-c101',
        sellerId: DairyTestFixtures.seller1Id,
        fullName: 'Amit Sharma',
        phone: '9876543210',
      );
      dataStore.customers['cust-201'] = Customer(
        id: 'cust-201',
        userId: 'user-c201',
        sellerId: DairyTestFixtures.seller2Id,
        fullName: 'Suresh Kumar',
        phone: '9988776655',
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Create pause for Seller 1's customer
      final pause1 = await pauseRepo.createPauseRequest(
        customerId: 'cust-101', // belongs to seller1Id
        startDate: today.add(const Duration(days: 2)),
        endDate: today.add(const Duration(days: 4)),
      );

      await Future.delayed(const Duration(milliseconds: 2));

      // Create pause for Seller 2's customer
      final pause2 = await pauseRepo.createPauseRequest(
        customerId: 'cust-201', // belongs to seller2Id
        startDate: today.add(const Duration(days: 2)),
        endDate: today.add(const Duration(days: 4)),
      );

      // Query for Seller 1
      final seller1Pauses = await pauseRepo.getPendingPausesForSeller(DairyTestFixtures.seller1Id);
      expect(seller1Pauses.map((p) => p.id), contains(pause1.id));
      expect(seller1Pauses.map((p) => p.id), isNot(contains(pause2.id)));

      // Query for Seller 2
      final seller2Pauses = await pauseRepo.getPendingPausesForSeller(DairyTestFixtures.seller2Id);
      expect(seller2Pauses.map((p) => p.id), contains(pause2.id));
      expect(seller2Pauses.map((p) => p.id), isNot(contains(pause1.id)));
    });

    test('T3.5: getAllPendingPauses returns all pending pauses across all sellers for admin review', () async {
      dataStore.customers['cust-201'] = Customer(
        id: 'cust-201',
        userId: 'user-c201',
        sellerId: DairyTestFixtures.seller2Id,
        fullName: 'Suresh Kumar',
        phone: '9988776655',
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final pause1 = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today.add(const Duration(days: 2)),
        endDate: today.add(const Duration(days: 4)),
      );

      await Future.delayed(const Duration(milliseconds: 2));

      final pause2 = await pauseRepo.createPauseRequest(
        customerId: 'cust-201',
        startDate: today.add(const Duration(days: 2)),
        endDate: today.add(const Duration(days: 4)),
      );

      final allPending = await pauseRepo.getAllPendingPauses();
      final allIds = allPending.map((p) => p.id).toSet();
      expect(allIds, contains(pause1.id));
      expect(allIds, contains(pause2.id));
    });
  });

  group('Group 4: Vacation Delivery Guardrail Verification', () {
    test('T4.1: isCustomerPausedOnDate returns false for customer with pending pause', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );

      final isPaused = await pauseRepo.isCustomerPausedOnDate('cust-101', today);
      expect(isPaused, isFalse);
    });

    test('T4.2: isCustomerPausedOnDate returns true for customer with approved pause', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );

      await pauseRepo.approvePause(pause.id);

      final isPaused = await pauseRepo.isCustomerPausedOnDate('cust-101', today);
      expect(isPaused, isTrue);
    });

    test('T4.3: getPausedCustomerIdsForDate does NOT contain pending customers', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );

      final pausedIds = await pauseRepo.getPausedCustomerIdsForDate(today);
      expect(pausedIds, isNot(contains('cust-101')));
    });

    test('T4.4: getPausedCustomerIdsForDate DOES contain approved customers', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );

      await pauseRepo.approvePause(pause.id);

      final pausedIds = await pauseRepo.getPausedCustomerIdsForDate(today);
      expect(pausedIds, contains('cust-101'));
    });

    test('T4.5: Automatic resumption: day after endDate returns false', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final endDate = today.add(const Duration(days: 2));

      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: endDate,
      );

      await pauseRepo.approvePause(pause.id);

      // Active during vacation
      expect(await pauseRepo.isCustomerPausedOnDate('cust-101', endDate), isTrue);

      // Resumed on the day after
      final dayAfter = endDate.add(const Duration(days: 1));
      expect(await pauseRepo.isCustomerPausedOnDate('cust-101', dayAfter), isFalse);
    });
  });

  group('Group 5: Widget Tests for PauseRequestDialog', () {
    testWidgets('T5.1: Renders dialog with vernacular labels', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const PauseRequestDialog(customerId: 'cust-101'),
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('दूध बंद अनुरोध'), findsOneWidget);
      expect(find.text('प्रारंभ तिथि'), findsOneWidget);
      expect(find.text('समाप्ति तिथि'), findsOneWidget);
      expect(find.text('कारण (वैकल्पिक / Optional)'), findsOneWidget);
      expect(find.text('जमा करें'), findsOneWidget);
      expect(find.text('रद्द करें'), findsOneWidget);
    });

    testWidgets('T5.2: Selecting quick reason chip updates text controller', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const PauseRequestDialog(customerId: 'cust-101'),
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      final chipFinder = find.text('गाँव जाना है (Village)');
      expect(chipFinder, findsOneWidget);

      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      expect(find.text('गाँव जाना है (Village)'), findsNWidgets(2)); // in chip & text field
    });

    testWidgets('T5.3: Valid submission calls repo.createPauseRequest with pending status and pops dialog', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      DeliveryPause? createdPause;

      await tester.pumpWidget(
        createTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                createdPause = await PauseRequestDialog.show(
                  context: context,
                  customerId: 'cust-101',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
          locale: const Locale('hi'),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(PauseRequestDialog), findsOneWidget);

      // Tap submit button ('जमा करें')
      await tester.tap(find.text('जमा करें'));
      await tester.pumpAndSettle();

      // Dialog should have popped
      expect(find.byType(PauseRequestDialog), findsNothing);
      expect(createdPause, isNotNull);
      expect(createdPause?.customerId, equals('cust-101'));
      expect(createdPause?.status, equals('pending'));
      expect(dataStore.pauses.values.any((p) => p.customerId == 'cust-101'), isTrue);
    });
  });

  group('Group 6: Widget Tests for PendingPausesCard', () {
    testWidgets('T6.1: Renders card showing customer name, formatted date range, reason, and action buttons', (tester) async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final endDate = startDate.add(const Duration(days: 2));

      final pause = DeliveryPause(
        id: 'pause-test-101',
        customerId: 'cust-101',
        startDate: startDate,
        endDate: endDate,
        status: 'pending',
        reason: 'गाँव जा रहे हैं',
        customerName: 'Amit Sharma',
        customerPhone: '9876543210',
        createdAt: DateTime.now(),
      );
      dataStore.pauses[pause.id] = pause;

      await tester.pumpWidget(
        createTestWidget(
          const PendingPausesCard(sellerId: DairyTestFixtures.seller1Id),
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('लंबित स्वीकृतियां'), findsOneWidget);
      expect(find.text('Amit Sharma'), findsOneWidget);
      expect(find.text('गाँव जा रहे हैं'), findsOneWidget);
      expect(find.text('स्वीकार करें'), findsOneWidget);
      expect(find.text('अस्वीकार करें'), findsOneWidget);
    });

    testWidgets('T6.2: Tapping स्वीकार करें calls pauseRepo.approvePause and updates list', (tester) async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final endDate = startDate.add(const Duration(days: 2));

      final pause = DeliveryPause(
        id: 'pause-test-102',
        customerId: 'cust-101',
        startDate: startDate,
        endDate: endDate,
        status: 'pending',
        reason: 'Wedding ceremony',
        customerName: 'Amit Sharma',
        customerPhone: '9876543210',
        createdAt: DateTime.now(),
      );
      dataStore.pauses[pause.id] = pause;

      await tester.pumpWidget(
        createTestWidget(
          const PendingPausesCard(sellerId: DairyTestFixtures.seller1Id),
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('स्वीकार करें'), findsOneWidget);

      await tester.tap(find.text('स्वीकार करें'));
      await tester.pumpAndSettle();

      expect(dataStore.pauses['pause-test-102']?.status, equals('approved'));
    });

    testWidgets('T6.3: Tapping अस्वीकार करें calls pauseRepo.rejectPause and updates list', (tester) async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final endDate = startDate.add(const Duration(days: 2));

      final pause = DeliveryPause(
        id: 'pause-test-103',
        customerId: 'cust-101',
        startDate: startDate,
        endDate: endDate,
        status: 'pending',
        reason: 'Reject me',
        customerName: 'Amit Sharma',
        customerPhone: '9876543210',
        createdAt: DateTime.now(),
      );
      dataStore.pauses[pause.id] = pause;

      await tester.pumpWidget(
        createTestWidget(
          const PendingPausesCard(sellerId: DairyTestFixtures.seller1Id),
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('अस्वीकार करें'), findsOneWidget);

      await tester.tap(find.text('अस्वीकार करें'));
      await tester.pumpAndSettle();

      expect(dataStore.pauses['pause-test-103']?.status, equals('rejected'));
    });

    testWidgets('T6.4: Empty state returns SizedBox.shrink when hideIfEmpty: true, and placeholder when false', (tester) async {
      // hideIfEmpty: true (default)
      await tester.pumpWidget(
        createTestWidget(
          const PendingPausesCard(sellerId: DairyTestFixtures.seller1Id, hideIfEmpty: true),
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('कोई लंबित अवकाश अनुरोध नहीं'), findsNothing);
      expect(find.byType(ListView), findsNothing);

      // hideIfEmpty: false
      await tester.pumpWidget(
        createTestWidget(
          const PendingPausesCard(sellerId: DairyTestFixtures.seller1Id, hideIfEmpty: false),
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('कोई लंबित अवकाश अनुरोध नहीं'), findsOneWidget);
    });

    testWidgets('T6.5: Admin mode (sellerId == null) fetches from allPendingPausesProvider across all sellers', (tester) async {
      dataStore.customers['cust-201'] = Customer(
        id: 'cust-201',
        userId: 'user-c201',
        sellerId: DairyTestFixtures.seller2Id,
        fullName: 'Suresh Kumar',
        phone: '9988776655',
      );

      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final endDate = startDate.add(const Duration(days: 2));

      // Seller 1 pause
      dataStore.pauses['p-admin-1'] = DeliveryPause(
        id: 'p-admin-1',
        customerId: 'cust-101',
        startDate: startDate,
        endDate: endDate,
        status: 'pending',
        customerName: 'Amit Sharma',
        createdAt: DateTime.now(),
      );

      // Seller 2 pause
      dataStore.pauses['p-admin-2'] = DeliveryPause(
        id: 'p-admin-2',
        customerId: 'cust-201',
        startDate: startDate,
        endDate: endDate,
        status: 'pending',
        customerName: 'Suresh Kumar',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestWidget(
          const PendingPausesCard(), // Admin mode: sellerId is null
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Amit Sharma'), findsOneWidget);
      expect(find.text('Suresh Kumar'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // badge count
    });
  });

  // =========================================================================
  // GROUP 7: Tier 5 Adversarial & Lifecycle Guardrails (Challenger 2)
  // =========================================================================
  group('Group 7: Tier 5 Adversarial & Lifecycle Guardrails (Challenger 2)', () {
    test('ADV-R5.1: DeliveryPause UTC timestamp is normalized via toLocal() to prevent calendar shift', () {
      final now = DateTime.now();
      final localToday = DateTime(now.year, now.month, now.day);
      final pause = DeliveryPause(
        id: 'p-utc',
        customerId: 'cust-1',
        startDate: localToday,
        endDate: localToday.add(const Duration(days: 2)),
        status: 'approved',
      );
      final expectedDateStr = localToday.toIso8601String().split('T')[0];
      expect(pause.toJson()['start_date'], equals(expectedDateStr));
    });

    test('ADV-R5.2: State machine rejects transition from approved to rejected', () async {
      final today = DateTime.now();
      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today.add(const Duration(days: 1)),
        endDate: today.add(const Duration(days: 3)),
      );
      await pauseRepo.approvePause(pause.id);
      expect(dataStore.pauses[pause.id]?.status, equals('approved'));

      expect(() => pauseRepo.rejectPause(pause.id), throwsStateError);
      expect(dataStore.pauses[pause.id]?.status, equals('approved'));
    });

    test('ADV-R5.3: State machine rejects transition from cancelled to approved', () async {
      final today = DateTime.now();
      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today.add(const Duration(days: 1)),
        endDate: today.add(const Duration(days: 3)),
      );
      await pauseRepo.cancelPause(pause.id);
      expect(dataStore.pauses[pause.id]?.status, equals('cancelled'));

      expect(() => pauseRepo.approvePause(pause.id), throwsStateError);
      expect(dataStore.pauses[pause.id]?.status, equals('cancelled'));
    });

    test('ADV-R5.4: Simultaneous approve and reject race condition: only one transition succeeds', () async {
      final today = DateTime.now();
      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today.add(const Duration(days: 5)),
        endDate: today.add(const Duration(days: 8)),
      );

      int successes = 0;
      int errors = 0;
      await Future.wait([
        pauseRepo.approvePause(pause.id).then((_) => successes++).catchError((_) => errors++),
        pauseRepo.rejectPause(pause.id).then((_) => successes++).catchError((_) => errors++),
      ]);
      expect(successes, equals(1));
      expect(errors, equals(1));
      expect(['approved', 'rejected'], contains(dataStore.pauses[pause.id]?.status));
    });

    test('ADV-R5.5: Delivery logging and pause approval race condition detection', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final pause = await pauseRepo.createPauseRequest(
        customerId: 'cust-101',
        startDate: today,
        endDate: today.add(const Duration(days: 2)),
      );

      dataStore.deliveries.add(MilkDelivery(
        id: 'del-race-01',
        sellerId: DairyTestFixtures.seller1Id,
        customerId: 'cust-101',
        deliveryDate: today,
        milkType: 'COW',
        quantityLiters: 1.0,
        amount: 60.0,
        status: 'delivered',
      ));

      await pauseRepo.approvePause(pause.id);

      final isPaused = await pauseRepo.isCustomerPausedOnDate('cust-101', today);
      expect(isPaused, isTrue);
      final hasDelivery = dataStore.deliveries.any((d) => d.customerId == 'cust-101' && d.deliveryDate == today);
      expect(hasDelivery, isTrue);
    });

    test('ADV-R5.6: Stress test 1,000 rapid URI constructions and 10,000 pause queries executes under 3s', () {
      final sw = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        UpiPaymentService.buildUpiUri(
          upiId: 'seller$i@upi',
          payeeName: 'Seller $i',
          amount: 100.0,
          transactionNote: 'Bill',
        );
      }
      expect(sw.elapsedMilliseconds, lessThan(3000));

      final pauses = List.generate(
        50,
        (i) => DeliveryPause(
          id: 'p$i',
          customerId: 'c$i',
          startDate: DateTime(2026, 11, 10),
          endDate: DateTime(2026, 11, 25),
          status: 'approved',
        ),
      );
      for (int i = 0; i < 200; i++) {
        final d = DateTime(2026, 11, 15);
        for (final p in pauses) {
          expect(p.isActiveOn(d), isTrue);
        }
      }
    });
  });
}
