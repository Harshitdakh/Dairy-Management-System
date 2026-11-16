// test/unit/indian_payments_test.dart
// Comprehensive Unit & Widget Test Suite for Milestone 5: Indian Payments & Free WhatsApp Invoicing (R4)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:milk_hub/providers/billing_provider.dart';
import 'package:milk_hub/services/upi_payment_service.dart';
import 'package:milk_hub/services/whatsapp_share_service.dart';
import 'package:milk_hub/features/payment/upi_qr_dialog.dart';
import 'package:milk_hub/features/payment/doorstep_cash_dialog.dart';

import '../helpers/dairy_test_fixtures.dart';
import '../helpers/in_memory_dairy_data_store.dart';
import '../helpers/in_memory_billing_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // =========================================================================
  // GROUP 1: NPCI UPI URI Generation & Formatting
  // =========================================================================
  group('Group 1: NPCI UPI URI Generation & Formatting', () {
    test('G1.1: Generates valid upi://pay scheme with standard NPCI query parameters', () {
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
    });

    test('G1.2: Enforces strict two-decimal NPCI precision formatting across values', () {
      expect(UpiPaymentService.formatAmount(50), equals('50.00'));
      expect(UpiPaymentService.formatAmount(50.5), equals('50.50'));
      expect(UpiPaymentService.formatAmount(50.555), equals('50.56'));
      expect(UpiPaymentService.formatAmount(100.994), equals('100.99'));
      expect(UpiPaymentService.formatAmount(0), equals('0.00'));
    });

    test('G1.3: URL-encodes Unicode Devanagari script in payee name and transaction note', () {
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

    test('G1.4: Handles zero amount balance cleanly without crashing', () {
      final uri = UpiPaymentService.buildUpiUri(
        upiId: 'dairy@upi',
        payeeName: 'Dairy',
        amount: 0.00,
        transactionNote: 'Settled',
      );
      expect(uri.queryParameters['am'], equals('0.00'));
    });

    test('G1.5: Validates mock payment launch validation method', () async {
      final launched = await UpiPaymentService.launchUpiPayment(
        upiId: 'dairy@upi',
        payeeName: 'Dairy',
        amount: 100.0,
        transactionNote: 'Test',
      );
      expect(launched, isTrue);
    });
  });

  // =========================================================================
  // GROUP 2: UPI Input Guardrails & Boundary Conditions
  // =========================================================================
  group('Group 2: UPI Input Guardrails & Boundary Conditions', () {
    test('G2.1: Rejects negative payment amounts with ArgumentError', () {
      expect(
        () => UpiPaymentService.buildUpiUri(
          upiId: 'dairy@upi',
          payeeName: 'Dairy',
          amount: -50.0,
          transactionNote: 'Negative test',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('G2.2: Rejects empty or whitespace-only UPI ID with ArgumentError', () {
      expect(
        () => UpiPaymentService.buildUpiUri(
          upiId: '',
          payeeName: 'Dairy',
          amount: 500.0,
          transactionNote: 'Empty UPI ID',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => UpiPaymentService.buildUpiUri(
          upiId: '   ',
          payeeName: 'Dairy',
          amount: 500.0,
          transactionNote: 'Whitespace UPI ID',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // =========================================================================
  // GROUP 3: Indian Phone Number Sanitization (E.164)
  // =========================================================================
  group('Group 3: Indian Phone Number Sanitization (E.164)', () {
    test('G3.1: Normalizes standard 10-digit mobile number to 91-prefixed format', () {
      expect(WhatsappShareService.sanitizeIndianPhone('9876543210'), equals('919876543210'));
    });

    test('G3.2: Strips leading zero from 11-digit mobile numbers', () {
      expect(WhatsappShareService.sanitizeIndianPhone('09876543210'), equals('919876543210'));
    });

    test('G3.3: Strips +91, spaces, and hyphens correctly', () {
      expect(WhatsappShareService.sanitizeIndianPhone('+91 98765 43210'), equals('919876543210'));
      expect(WhatsappShareService.sanitizeIndianPhone('+91-98765-43210'), equals('919876543210'));
      expect(WhatsappShareService.sanitizeIndianPhone('98765-43210'), equals('919876543210'));
      expect(WhatsappShareService.sanitizeIndianPhone(' 98765 43210 '), equals('919876543210'));
    });

    test('G3.4: Preserves already normalized 12-digit 91 numbers', () {
      expect(WhatsappShareService.sanitizeIndianPhone('919876543210'), equals('919876543210'));
    });

    test('G3.5: Throws FormatException on short or invalid phone numbers', () {
      expect(() => WhatsappShareService.sanitizeIndianPhone('12345'), throwsA(isA<FormatException>()));
      expect(() => WhatsappShareService.sanitizeIndianPhone(''), throwsA(isA<FormatException>()));
      expect(() => WhatsappShareService.sanitizeIndianPhone('abcdefghij'), throwsA(isA<FormatException>()));
      expect(() => WhatsappShareService.sanitizeIndianPhone('19876543210'), throwsA(isA<FormatException>()));
      expect(() => WhatsappShareService.sanitizeIndianPhone('91987654321099'), throwsA(isA<FormatException>()));
    });
  });

  // =========================================================================
  // GROUP 4: Free WhatsApp Invoicing Engine
  // =========================================================================
  group('Group 4: Free WhatsApp Invoicing Engine', () {
    test('G4.1: Generates bilingual invoice with Devanagari headers and embedded UPI link', () {
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

    test('G4.2: Fully settled bill displays paid-in-full message and omits UPI payment link', () {
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
      expect(invoice, contains('बिल पूरा चुकता कर दिया गया है (Paid in Full)'));
      expect(invoice, isNot(contains('upi://pay?')));
    });

    test('G4.3: Missing seller UPI ID provides cash payment prompt fallback', () {
      final invoice = WhatsappShareService.formatDairyInvoice(
        dairyName: 'Shree Dairy',
        customerName: 'Anil Kumar',
        monthYear: 'November 2026',
        totalLiters: 20.0,
        milkType: 'COW',
        totalAmount: 1200.00,
        paidAmount: 0.00,
        pendingAmount: 1200.00,
        upiId: '',
      );
      expect(invoice, contains('भुगतान के लिए दूधवाले से संपर्क करें (Pay via cash or contact seller)'));
      expect(invoice, isNot(contains('upi://pay?')));
    });

    test('G4.4: Constructs valid native whatsapp://send and web wa.me URLs', () {
      final nativeUri = WhatsappShareService.buildNativeUri(phone: '9876543210', text: 'Bill');
      final webUri = WhatsappShareService.buildWebUri(phone: '9876543210', text: 'Bill');
      expect(nativeUri.scheme, equals('whatsapp'));
      expect(nativeUri.host, equals('send'));
      expect(nativeUri.queryParameters['phone'], equals('919876543210'));
      expect(webUri.toString(), startsWith('https://wa.me/919876543210?text=Bill'));
    });
  });

  // =========================================================================
  // GROUP 5: Doorstep Cash Collection & BillingRepository Updates
  // =========================================================================
  group('Group 5: Doorstep Cash Collection & BillingRepository Updates', () {
    late InMemoryDairyDataStore dataStore;
    late InMemoryBillingRepository billingRepo;

    setUp(() {
      dataStore = InMemoryDairyDataStore();
      dataStore.seedDefaults();
      billingRepo = InMemoryBillingRepository(dataStore);
    });

    test('G5.1: Records doorstep cash collection, updates paid amount, and sets status to partial', () async {
      final month = DateTime(2026, 11, 1);
      dataStore.upsertBill(
        DairyTestFixtures.createBill(
          customerId: 'cust-101',
          billMonth: month,
          totalAmount: 1500.0,
          paidAmount: 0.0,
          pendingAmount: 1500.0,
          status: 'pending',
        ),
      );

      await billingRepo.recordCollection(
        customerId: 'cust-101',
        sellerId: DairyTestFixtures.seller1Id,
        amountPaid: 600.0,
        billMonth: month,
        paymentMode: 'cash',
        notes: 'Doorstep cash collected (नकद मिला)',
      );

      final collections = await billingRepo.getCollections(customerId: 'cust-101');
      expect(collections.length, equals(1));
      expect(collections.first.amountPaid, equals(600.0));
      expect(collections.first.paymentMode, equals('cash'));

      final bills = await billingRepo.getBills(customerId: 'cust-101', month: month);
      expect(bills.first.paidAmount, equals(600.0));
      expect(bills.first.pendingAmount, equals(900.0));
      expect(bills.first.status, equals('partial'));
    });

    test('G5.2: Full cash settlement transitions bill status to paid with zero pending balance', () async {
      final month = DateTime(2026, 11, 1);
      dataStore.upsertBill(
        DairyTestFixtures.createBill(
          customerId: 'cust-102',
          billMonth: month,
          totalAmount: 1000.0,
          paidAmount: 400.0,
          pendingAmount: 600.0,
          status: 'partial',
        ),
      );

      await billingRepo.recordCollection(
        customerId: 'cust-102',
        sellerId: DairyTestFixtures.seller1Id,
        amountPaid: 600.0,
        billMonth: month,
        paymentMode: 'cash',
      );

      final bills = await billingRepo.getBills(customerId: 'cust-102', month: month);
      expect(bills.first.paidAmount, equals(1000.0));
      expect(bills.first.pendingAmount, equals(0.0));
      expect(bills.first.status, equals('paid'));
    });

    test('G5.3: Cash overpayment capping: payment exceeding total bill caps paidAmount at total', () async {
      final month = DateTime(2026, 11, 1);
      dataStore.upsertBill(
        DairyTestFixtures.createBill(
          customerId: 'cust-103',
          billMonth: month,
          totalAmount: 450.0,
          paidAmount: 0.0,
          pendingAmount: 450.0,
        ),
      );

      await billingRepo.recordCollection(
        customerId: 'cust-103',
        sellerId: DairyTestFixtures.seller1Id,
        amountPaid: 500.0, // ₹50 overpayment
        billMonth: month,
      );

      final bill = (await billingRepo.getBills(customerId: 'cust-103', month: month)).first;
      expect(bill.paidAmount, equals(450.0)); // Capped
      expect(bill.pendingAmount, equals(0.0));
      expect(bill.status, equals('paid'));
    });

    test('G5.4: Rejects negative payment amounts with ArgumentError', () async {
      final month = DateTime(2026, 11, 1);
      expect(
        () => billingRepo.recordCollection(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          amountPaid: -100.0,
          billMonth: month,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('G5.5: Rejects zero payment amounts with ArgumentError', () async {
      final month = DateTime(2026, 11, 1);
      expect(
        () => billingRepo.recordCollection(
          customerId: 'cust-101',
          sellerId: DairyTestFixtures.seller1Id,
          amountPaid: 0.0,
          billMonth: month,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // =========================================================================
  // GROUP 6: Widget Tests for Static UPI QR Dialog (UpiQrDialog)
  // =========================================================================
  group('Group 6: Widget Tests for Static UPI QR Dialog (UpiQrDialog)', () {
    testWidgets('G6.1: Renders scannable QrImageView with correct upi:// payload', (tester) async {
      final bill = DairyTestFixtures.createBill(
        customerId: 'cust-101',
        billMonth: DateTime(2026, 11, 1),
        totalAmount: 1800.0,
        paidAmount: 600.0,
        pendingAmount: 1200.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpiQrDialog(
              bill: bill,
              sellerUpiId: 'shreedairy@oksbi',
              sellerName: 'Shree Krishna Dairy',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      final qrWidget = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qrWidget.semanticsLabel, contains('upi://pay?'));
      expect(qrWidget.semanticsLabel, contains('pa=shreedairy%40oksbi'));
      expect(qrWidget.semanticsLabel, contains('am=1200.00'));
      expect(find.textContaining('1200'), findsWidgets);
    });

    testWidgets('G6.2: Displays fallback notification when seller UPI ID is not configured', (tester) async {
      final bill = DairyTestFixtures.createBill(
        customerId: 'cust-101',
        billMonth: DateTime(2026, 11, 1),
        pendingAmount: 500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpiQrDialog(
              bill: bill,
              sellerUpiId: '',
              sellerName: 'Shree Krishna Dairy',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('UPI ID'), findsWidgets);
    });

    testWidgets('G6.3: Shows paid in full state when pending amount is zero', (tester) async {
      final bill = DairyTestFixtures.createBill(
        customerId: 'cust-101',
        billMonth: DateTime(2026, 11, 1),
        totalAmount: 1000.0,
        paidAmount: 1000.0,
        pendingAmount: 0.0,
        status: 'paid',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpiQrDialog(
              bill: bill,
              sellerUpiId: 'dairy@upi',
              sellerName: 'Dairy',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Paid in Full'), findsWidgets);
    });
  });

  // =========================================================================
  // GROUP 7: Widget Tests for Doorstep Cash Collection Dialog (DoorstepCashDialog)
  // =========================================================================
  group('Group 7: Widget Tests for Doorstep Cash Collection Dialog (DoorstepCashDialog)', () {
    late InMemoryDairyDataStore dataStore;
    late InMemoryBillingRepository billingRepo;

    setUp(() {
      dataStore = InMemoryDairyDataStore();
      dataStore.seedDefaults();
      billingRepo = InMemoryBillingRepository(dataStore);
    });

    testWidgets('G7.1: Pre-fills amount field with current pending balance and records collection on submit', (tester) async {
      final month = DateTime(2026, 11, 1);
      final bill = DairyTestFixtures.createBill(
        customerId: 'cust-101',
        billMonth: month,
        totalAmount: 1500.0,
        paidAmount: 500.0,
        pendingAmount: 1000.0,
        status: 'partial',
      );
      dataStore.upsertBill(bill);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingRepositoryProvider.overrideWithValue(billingRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DoorstepCashDialog(
                bill: bill,
                customer: DairyTestFixtures.createCustomer1(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1000.00'), findsOneWidget);

      final confirmBtn = find.widgetWithText(FilledButton, 'नकद मिला');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      final updatedBill = (await billingRepo.getBills(customerId: 'cust-101', month: month)).first;
      expect(updatedBill.paidAmount, equals(1500.0));
      expect(updatedBill.pendingAmount, equals(0.0));
      expect(updatedBill.status, equals('paid'));
    });
  });

  // =========================================================================
  // GROUP 8: Tier 5 Adversarial & Edge Case Coverage (Challenger 2)
  // =========================================================================
  group('Group 8: Tier 5 Adversarial & Edge Case Coverage (Challenger 2)', () {
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
}
