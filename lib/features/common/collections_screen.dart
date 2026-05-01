import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/customer_provider.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedCustomerId;
  String _paymentMode = 'cash';
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final summaryAsync = ref.watch(collectionSummaryProvider(_selectedMonth));
    final collectionsAsync = ref.watch(collectionsProvider(_selectedMonth));
    final query = BillQuery(month: _selectedMonth, status: 'all');
    final billsAsync = ref.watch(monthlyBillsProvider(query));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Collections',
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(collectionSummaryProvider(_selectedMonth));
          ref.invalidate(collectionsProvider(_selectedMonth));
          ref.invalidate(monthlyBillsProvider(query));
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            summaryAsync.when(
              data: (summary) => _summary(summary),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load summary: $e'),
            ),
            const SizedBox(height: 16),
            if (profile != null && (profile.isAdmin || profile.isSeller))
              _collectionForm(),
            if (profile != null && (profile.isAdmin || profile.isSeller))
              const SizedBox(height: 20),
            Text(
              'Pending / Monthly Bills',
              style: GoogleFonts.workSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            billsAsync.when(
              data: (bills) {
                if (bills.isEmpty) {
                  return _empty('No monthly bills found');
                }
                return Column(
                  children: bills
                      .map(
                        (bill) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bill.customerName ?? 'Customer',
                                      style: GoogleFonts.workSans(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Bill: Rs ${bill.totalAmount.toStringAsFixed(2)}  Paid: Rs ${bill.paidAmount.toStringAsFixed(2)}',
                                      style: GoogleFonts.workSans(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Rs ${bill.pendingAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.workSans(
                                  fontWeight: FontWeight.w700,
                                  color: bill.pendingAmount.toDouble() <= 0
                                      ? AppTheme.success
                                      : AppTheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load bills: $e'),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment History',
              style: GoogleFonts.workSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            collectionsAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return _empty('No collections recorded this month');
                }
                return Column(
                  children: rows
                      .map(
                        (row) => ListTile(
                          tileColor: AppTheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          title: Text(
                            row.customerName ?? 'Customer',
                            style: GoogleFonts.workSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${DateFormat('dd MMM yyyy').format(row.paidOn)} • ${row.paymentMode.toUpperCase()}',
                            style: GoogleFonts.workSans(fontSize: 12),
                          ),
                          trailing: Text(
                            'Rs ${row.amountPaid.toStringAsFixed(2)}',
                            style: GoogleFonts.workSans(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load history: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(Map<String, double> summary) {
    return Row(
      children: [
        _metric('Total', summary['total'] ?? 0, AppTheme.primary),
        const SizedBox(width: 10),
        _metric('Collected', summary['paid'] ?? 0, AppTheme.success),
        const SizedBox(width: 10),
        _metric('Pending', summary['pending'] ?? 0, AppTheme.error),
      ],
    );
  }

  Widget _metric(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.workSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                )),
            const SizedBox(height: 4),
            Text(
              NumberFormat.compactCurrency(symbol: 'Rs ', decimalDigits: 1)
                  .format(value),
              style: GoogleFonts.workSans(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectionForm() {
    final List<Customer> customers =
      ref.watch(allCustomersProvider).valueOrNull ?? const <Customer>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record Collection',
            style: GoogleFonts.workSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedCustomerId,
            decoration: const InputDecoration(
              hintText: 'Select customer',
            ),
            items: customers
                .map(
                  (customer) => DropdownMenuItem<String>(
                    value: customer.id,
                    child: Text(customer.fullName ?? 'Customer'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedCustomerId = v),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Amount paid',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _paymentMode,
            decoration: const InputDecoration(hintText: 'Payment mode'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'upi', child: Text('UPI')),
              DropdownMenuItem(
                value: 'bank_transfer',
                child: Text('Bank Transfer'),
              ),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _paymentMode = v ?? 'cash'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _notesController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Notes (optional)',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _recordCollection,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Collection'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordCollection() async {
    final customerId = _selectedCustomerId;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (customerId == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select customer and enter valid amount')),
      );
      return;
    }

    final List<Customer> customers =
        ref.read(allCustomersProvider).valueOrNull ?? const <Customer>[];
    Customer? customer;
    for (final c in customers) {
      if (c.id == customerId) {
        customer = c;
        break;
      }
    }

    if (customer == null || customer.sellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer is not mapped to a seller')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(billingRepositoryProvider).recordCollection(
            customerId: customerId,
            sellerId: customer.sellerId!,
            amountPaid: amount,
            billMonth: _selectedMonth,
            paymentMode: _paymentMode,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

      ref.invalidate(collectionSummaryProvider(_selectedMonth));
      ref.invalidate(collectionsProvider(_selectedMonth));
      ref.invalidate(
        monthlyBillsProvider(BillQuery(month: _selectedMonth, status: 'all')),
      );

      if (!mounted) return;
      _amountController.clear();
      _notesController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Collection recorded successfully'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record collection: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _empty(String text) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.workSans(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
