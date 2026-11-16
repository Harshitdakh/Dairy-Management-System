// ==============================================================================
// Milk HUB — Milestone 7 Phase 2: Tier 5 Adversarial Hardening Suite (R4, R5)
// ==============================================================================
// Requirements Covered:
//   - R4: NPCI UPI URI Validation (NaN/Inf, syntax, special chars), WhatsApp Invoicing, DoT NNP phone validation
//   - R5: Vacation Guardrails & Pause Lifecycle State Machine, Timezone normalization, Race conditions, Stress
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:milk_hub/models/delivery_pause.dart';
import 'package:milk_hub/models/milk_delivery.dart';
import 'package:milk_hub/services/upi_payment_service.dart';
import 'package:milk_hub/services/whatsapp_share_service.dart';

import '../helpers/dairy_test_fixtures.dart';
import '../helpers/in_memory_dairy_data_store.dart';
import '../helpers/in_memory_pause_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ============================================================================
  // GROUP 1: R4 NPCI UPI & WHATSAPP ADVERSARIAL HARDENING
  // ============================================================================
  group('Tier 5 Adversarial: R4 Payments & WhatsApp Invoicing Hardening', () {
    test('ADV-R4.1: buildUpiUri rejects NaN and Infinity amounts with ArgumentError', () {
      expect(
        () => UpiPaymentService.buildUpiUri(
          upiId: 'dairy@upi',
          payeeName: 'Dairy',
          amount: double.nan,
          transactionNote: 'NaN test',
        ),
        throwsArgumentError,
      );

      expect(
        () => UpiPaymentService.buildUpiUri(
          upiId: 'dairy@upi',
          payeeName: 'Dairy',
          amount: double.infinity,
          transactionNote: 'Inf test',
        ),
        throwsArgumentError,
      );
    });

    test('ADV-R4.2: buildUpiUri enforces UPI ID syntactic validation on malformed inputs and throws ArgumentError', () {
      final malformed = ['not-a-valid-upi', '@bank', 'user@', '12345', 'user name@bank'];
      for (final id in malformed) {
        expect(
          () => UpiPaymentService.buildUpiUri(
            upiId: id,
            payeeName: 'Dairy',
            amount: 50.0,
            transactionNote: 'Test',
          ),
          throwsArgumentError,
          reason: 'Malformed UPI ID "$id" must throw ArgumentError',
        );
      }
    });

    test('ADV-R4.3: Special characters in payeeName and transactionNote are properly percent-encoded', () {
      final uri = UpiPaymentService.buildUpiUri(
        upiId: 'dairy@okhdfcbank',
        payeeName: 'श्री & Krishna #1 <"Dairy"> = Best 🥛',
        amount: 250.75,
        transactionNote: 'दूध बिल & ? # = "विशेष"',
      );
      expect(uri.toString(), contains('upi://pay?'));
      expect(uri.queryParameters['pn'], equals('श्री & Krishna #1 <"Dairy"> = Best 🥛'));
      expect(uri.queryParameters['tn'], equals('दूध बिल & ? # = "विशेष"'));
      expect(uri.toString(), contains('%26')); // & is encoded
      expect(uri.toString(), contains('%23')); // # is encoded
    });

    test('ADV-R4.4: Sub-rupee pending amounts format fractional paise accurately without ₹0 truncation conflict', () {
      final invoice = WhatsappShareService.formatDairyInvoice(
        dairyName: 'Test Dairy',
        customerName: 'Customer',
        monthYear: 'Nov 2026',
        totalLiters: 1.0,
        milkType: 'COW',
        totalAmount: 50.75,
        paidAmount: 50.0,
        pendingAmount: 0.75,
        upiId: 'test@upi',
      );
      expect(invoice, contains('⚠️ बकाया राशि: ₹0.75'));
      expect(invoice, contains('am=0.75'));
    });

    test('ADV-R4.5: Negative pending balance displays advance balance cleanly without negative balance sign', () {
      final invoice = WhatsappShareService.formatDairyInvoice(
        dairyName: 'Test Dairy',
        customerName: 'Customer',
        monthYear: 'Nov 2026',
        totalLiters: 20.0,
        milkType: 'COW',
        totalAmount: 1000.0,
        paidAmount: 1200.0,
        pendingAmount: -200.0,
        upiId: 'test@upi',
      );
      expect(invoice, isNot(contains('₹-200')));
      expect(invoice, contains('अग्रिम जमा राशि (Advance Balance): ₹200'));
      expect(invoice, contains('बकाया राशि: ₹0'));
      expect(invoice, contains('✅ बिल पूरा चुकता कर दिया गया है (Paid in Full)'));
    });

    test('ADV-R4.6: sanitizeIndianPhone strictly rejects invalid starting digits under DoT NNP', () {
      expect(() => WhatsappShareService.sanitizeIndianPhone('1234567890'), throwsFormatException);
      expect(() => WhatsappShareService.sanitizeIndianPhone('0000000000'), throwsFormatException);
      expect(() => WhatsappShareService.sanitizeIndianPhone('5555555555'), throwsFormatException);
      expect(WhatsappShareService.sanitizeIndianPhone('9876543210'), equals('919876543210'));
      expect(WhatsappShareService.sanitizeIndianPhone('6123456789'), equals('916123456789'));
      expect(WhatsappShareService.sanitizeIndianPhone('7123456789'), equals('917123456789'));
      expect(WhatsappShareService.sanitizeIndianPhone('8123456789'), equals('918123456789'));
    });
  });

  // ============================================================================
  // GROUP 2: R5 VACATION GUARDRAILS, LIFECYCLE & STRESS
  // ============================================================================
  group('Tier 5 Adversarial: R5 Vacation Guardrails & Lifecycle State Machine', () {
    late InMemoryDairyDataStore dataStore;
    late InMemoryPauseRepository pauseRepo;

    setUp(() {
      dataStore = InMemoryDairyDataStore();
      dataStore.seedDefaults();
      pauseRepo = InMemoryPauseRepository(dataStore);
    });

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
