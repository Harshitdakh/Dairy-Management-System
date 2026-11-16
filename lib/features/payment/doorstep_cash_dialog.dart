import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/customer.dart';
import '../../models/customer_bill.dart';
import '../../providers/billing_provider.dart';
import '../../services/upi_payment_service.dart';

/// Modal dialog for recording doorstep cash payment ("नकद मिला") directly from
/// route delivery sheets and customer billing cards.
class DoorstepCashDialog extends ConsumerStatefulWidget {
  final CustomerBill bill;
  final Customer customer;
  final VoidCallback? onCollectionRecorded;

  const DoorstepCashDialog({
    super.key,
    required this.bill,
    required this.customer,
    this.onCollectionRecorded,
  });

  /// Helper static method to show the dialog
  static Future<bool?> show({
    required BuildContext context,
    required CustomerBill bill,
    required Customer customer,
    VoidCallback? onCollectionRecorded,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DoorstepCashDialog(
        bill: bill,
        customer: customer,
        onCollectionRecorded: onCollectionRecorded,
      ),
    );
  }

  @override
  ConsumerState<DoorstepCashDialog> createState() => _DoorstepCashDialogState();
}

class _DoorstepCashDialogState extends ConsumerState<DoorstepCashDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with pending balance formatted to 2 decimals
    final pending = widget.bill.pendingAmount.toDouble();
    _amountController = TextEditingController(
      text: pending > 0 ? pending.toStringAsFixed(2) : '0.00',
    );
    _notesController = TextEditingController(
      text: 'Doorstep cash collected (नकद मिला)',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(_amountController.text.trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() {
        _errorMessage = 'कृपया वैध राशि दर्ज करें (Enter valid positive amount)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(billingRepositoryProvider);
      final sellerId = widget.bill.sellerId.isNotEmpty
          ? widget.bill.sellerId
          : (widget.customer.sellerId ?? '');

      await repo.recordCollection(
        customerId: widget.customer.id,
        sellerId: sellerId,
        amountPaid: parsedAmount,
        billMonth: widget.bill.billMonth,
        paymentMode: 'cash',
        notes: _notesController.text.trim().isEmpty
            ? 'Doorstep cash collected (नकद मिला)'
            : _notesController.text.trim(),
      );

      // Invalidate relevant providers to refresh UI state
      ref.invalidate(monthlyBillsProvider);

      widget.onCollectionRecorded?.call();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primary,
            content: Text(
              '₹${UpiPaymentService.formatAmount(parsedAmount)} नकद दर्ज किया गया (Cash recorded)',
              style: GoogleFonts.workSans(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName =
        widget.customer.fullName ?? widget.bill.customerName ?? 'Customer';
    final monthStr = DateFormat('MMMM yyyy').format(widget.bill.billMonth);
    final pending = widget.bill.pendingAmount.toDouble();
    final total = widget.bill.totalAmount.toDouble();
    final paid = widget.bill.paidAmount.toDouble();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.payments,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'नकद संग्रह (Cash Collection)',
                          style: GoogleFonts.workSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          customerName,
                          style: GoogleFonts.workSans(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: AppTheme.divider),
              const SizedBox(height: 12),

              // Summary card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  children: [
                    _billRow('महीना (Bill Month):', monthStr),
                    const SizedBox(height: 4),
                    _billRow('कुल बिल (Total):', '₹${total.toStringAsFixed(0)}'),
                    const SizedBox(height: 4),
                    _billRow('प्राप्त (Paid):', '₹${paid.toStringAsFixed(0)}'),
                    const SizedBox(height: 4),
                    _billRow(
                      'बकाया (Pending):',
                      '₹${pending.toStringAsFixed(2)}',
                      isHighlight: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quick preset chips if pending > 0
              if (pending > 0) ...[
                Text(
                  'त्वरित राशि (Quick Amount):',
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: Text('पूरा (Full) ₹${pending.toStringAsFixed(0)}'),
                      backgroundColor: AppTheme.primaryLight,
                      labelStyle: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _amountController.text = pending.toStringAsFixed(2);
                        });
                      },
                    ),
                    if (pending > 100)
                      ActionChip(
                        label: Text('आधा (Half) ₹${(pending / 2).toStringAsFixed(0)}'),
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: GoogleFonts.workSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        onPressed: () {
                          setState(() {
                            _amountController.text = (pending / 2).toStringAsFixed(2);
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Amount Input Field
              Text(
                'प्राप्त नकद राशि (Amount Received ₹):',
                style: GoogleFonts.workSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.workSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                  hintText: '0.00',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'राशि दर्ज करें (Enter amount)';
                  }
                  final n = double.tryParse(val.trim());
                  if (n == null) {
                    return 'संख्या दर्ज करें (Enter valid number)';
                  }
                  if (n <= 0) {
                    return 'राशि 0 से अधिक होनी चाहिए (Amount must be > 0)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Notes Input Field
              Text(
                'विवरण / नोट (Notes):',
                style: GoogleFonts.workSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                style: GoogleFonts.workSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'टिप्पणी दर्ज करें...',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'रद्द करें (Cancel)',
                        style: GoogleFonts.workSans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _handleConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'नकद मिला',
                              style: GoogleFonts.workSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _billRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.workSans(
            fontSize: isHighlight ? 14 : 12,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            color: isHighlight ? Colors.red.shade700 : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
