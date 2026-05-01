import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/customer_bill.dart';
import '../../providers/billing_provider.dart';
import '../../providers/customer_provider.dart';

class FakePaymentGateway extends ConsumerStatefulWidget {
  final String customerId;
  final DateTime billMonth;

  const FakePaymentGateway({
    super.key,
    required this.customerId,
    required this.billMonth,
  });

  @override
  ConsumerState<FakePaymentGateway> createState() => _FakePaymentGatewayState();
}

class _FakePaymentGatewayState extends ConsumerState<FakePaymentGateway> {
  final _formKey = GlobalKey<FormState>();
  final _cardController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  bool _busy = false;
  late final Future<CustomerBill?> _billFuture;

  @override
  void initState() {
    super.initState();
    _billFuture = _loadBill();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<CustomerBill?> _loadBill() async {
    final repo = ref.read(billingRepositoryProvider);
    final bills = await repo.getBills(
      customerId: widget.customerId,
      month: widget.billMonth,
    );
    if (bills.isEmpty) return null;

    final bill = bills.first;
    _amountController.text = bill.pendingAmount.toStringAsFixed(2);
    return bill;
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final repo = ref.read(billingRepositoryProvider);

      final customer = await ref.read(currentCustomerProvider.future);
      final sellerId = customer?.sellerId ?? '';
      if (sellerId.isEmpty) {
        throw Exception('Seller mapping not found for this customer');
      }

      await repo.recordCollection(
        customerId: widget.customerId,
        sellerId: sellerId,
        amountPaid: amount,
        billMonth: widget.billMonth,
        paymentMode: 'card',
        notes: 'Fake gateway payment',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful and bill updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMM yyyy').format(widget.billMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppTheme.background,
      body: FutureBuilder<CustomerBill?>(
        future: _billFuture,
        builder: (context, snapshot) {
          final bill = snapshot.data;
          final payableAmount = bill?.pendingAmount ??
              (double.tryParse(_amountController.text) ?? 0);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill?.customerName ?? 'Customer payment',
                      style: GoogleFonts.workSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      monthLabel,
                      style: GoogleFonts.workSans(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This demo gateway records the collection and updates the bill status.',
                      style: GoogleFonts.workSans(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(labelText: 'Cardholder name'),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cardController,
                      decoration:
                          const InputDecoration(labelText: 'Card number'),
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter card'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Amount (₹)'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter amount'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _pay,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Pay ₹${payableAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.workSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
