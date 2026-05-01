import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';

class MonthlyIncomeReportScreen extends ConsumerStatefulWidget {
  const MonthlyIncomeReportScreen({super.key});

  @override
  ConsumerState<MonthlyIncomeReportScreen> createState() =>
      _MonthlyIncomeReportScreenState();
}

class _MonthlyIncomeReportScreenState
    extends ConsumerState<MonthlyIncomeReportScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _selectedStatus = 'all';
  bool _isPaying = false;

  @override
  Widget build(BuildContext context) {
    final query = BillQuery(month: _selectedMonth, status: _selectedStatus);
    final billsAsync = ref.watch(monthlyBillsProvider(query));
    final summaryAsync = ref.watch(collectionSummaryProvider(_selectedMonth));
    final profile = ref.watch(profileProvider).valueOrNull;
    final isCustomer = profile?.role == 'customer';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Monthly Income Report',
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyBillsProvider(query));
          ref.invalidate(collectionSummaryProvider(_selectedMonth));
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildFilters(),
            const SizedBox(height: 16),
            _buildSummaryCards(summaryAsync.valueOrNull),
            const SizedBox(height: 20),
            Text(
              'Day-wise Bills',
              style: GoogleFonts.workSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (billsAsync.isLoading && billsAsync.valueOrNull == null)
              _emptyState('Loading monthly report...')
            else if ((billsAsync.valueOrNull ?? const []).isEmpty)
              _emptyState('No billing data for selected month')
            else
              Column(
                children: (billsAsync.valueOrNull ?? const [])
                    .map(
                      (bill) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    bill.customerName ?? 'Customer',
                                    style: GoogleFonts.workSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                _statusChip(bill.status),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _dataRow(
                              'Month',
                              DateFormat('MMM yyyy').format(bill.billMonth),
                            ),
                            _dataRow('Qty',
                                '${bill.totalQuantityLiters.toStringAsFixed(2)} L'),
                            _dataRow('Amount',
                                'Rs ${bill.totalAmount.toStringAsFixed(2)}'),
                            _dataRow('Paid',
                                'Rs ${bill.paidAmount.toStringAsFixed(2)}'),
                            _dataRow('Pending',
                                'Rs ${bill.pendingAmount.toStringAsFixed(2)}'),
                            if (isCustomer &&
                                bill.status != 'paid' &&
                                bill.pendingAmount > 0) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                    onPressed: _isPaying
                                        ? null
                                        : () async {
                                            setState(() => _isPaying = true);
                                            final result = await context.push<bool>(
                                              '/payment/fake?customerId=${bill.customerId}'
                                              '&billMonth=${DateFormat('yyyy-MM-dd').format(bill.billMonth)}',
                                            );
                                            if (!context.mounted) return;
                                            if (result == true) {
                                              ref.invalidate(monthlyBillsProvider(query));
                                              ref.invalidate(collectionSummaryProvider(_selectedMonth));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Payment recorded successfully'),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                            setState(() => _isPaying = false);
                                          },
                                  icon: const Icon(Icons.payment, size: 18),
                                  label: Text(
                                    'Pay Now  –  Rs ${bill.pendingAmount.toStringAsFixed(2)}',
                                    style: GoogleFonts.workSans(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickMonth,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(DateFormat('MMM yyyy').format(_selectedMonth)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'partial', child: Text('Partial')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedStatus = v ?? 'all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  Widget _buildSummaryCards(Map<String, double>? summary) {
    final resolved = summary ?? const {'total': 0, 'paid': 0, 'pending': 0};
    return Row(
      children: [
        _summaryCard('Total', resolved['total'] ?? 0, AppTheme.primary),
        const SizedBox(width: 10),
        _summaryCard('Collected', resolved['paid'] ?? 0, AppTheme.success),
        const SizedBox(width: 10),
        _summaryCard('Pending', resolved['pending'] ?? 0, AppTheme.amber),
      ],
    );
  }

  Widget _summaryCard(String label, double value, Color color) {
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
            Text(
              label,
              style: GoogleFonts.workSans(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              NumberFormat.compactCurrency(
                symbol: 'Rs ',
                decimalDigits: 1,
              ).format(value),
              style: GoogleFonts.workSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'paid':
        color = AppTheme.success;
        break;
      case 'partial':
        color = AppTheme.amber;
        break;
      default:
        color = AppTheme.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.workSans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.workSans(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.workSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.workSans(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
