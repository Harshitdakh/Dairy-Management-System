import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/theme.dart';
import '../../models/customer_bill.dart';
import '../../services/upi_payment_service.dart';

/// Reusable modal dialog for displaying dynamic scannable UPI QR codes
/// and deep-linking to installed UPI payment apps.
class UpiQrDialog extends StatelessWidget {
  final CustomerBill bill;
  final String sellerUpiId;
  final String? sellerName;
  final String? customerName;

  const UpiQrDialog({
    super.key,
    required this.bill,
    required this.sellerUpiId,
    this.sellerName,
    this.customerName,
  });

  /// Helper static method to show the dialog
  static Future<void> show({
    required BuildContext context,
    required CustomerBill bill,
    required String sellerUpiId,
    String? sellerName,
    String? customerName,
  }) {
    return showDialog(
      context: context,
      builder: (context) => UpiQrDialog(
        bill: bill,
        sellerUpiId: sellerUpiId,
        sellerName: sellerName,
        customerName: customerName,
      ),
    );
  }

  /// Build the NPCI UPI URI representation for this dialog if applicable.
  Uri? get upiUri {
    if (sellerUpiId.trim().isEmpty || bill.pendingAmount <= 0) return null;
    final effectiveDairyName =
        sellerName ?? bill.sellerName ?? 'Milk HUB Dairy';
    final effectiveCustomerName =
        customerName ?? bill.customerName ?? 'Customer';
    final monthStr = DateFormat('MMMM yyyy').format(bill.billMonth);
    return UpiPaymentService.buildUpiUri(
      upiId: sellerUpiId.trim(),
      payeeName: effectiveDairyName,
      amount: bill.pendingAmount.toDouble(),
      transactionNote: 'Milk Bill $monthStr - $effectiveCustomerName',
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDairyName =
        sellerName ?? bill.sellerName ?? 'Milk HUB Dairy';
    final effectiveCustomerName =
        customerName ?? bill.customerName ?? 'Customer';
    final monthStr = DateFormat('MMMM yyyy').format(bill.billMonth);
    final pending = bill.pendingAmount.toDouble();
    final isPaid = pending <= 0;
    final hasValidUpi = sellerUpiId.trim().isNotEmpty;

    final uri = upiUri;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dairy Name & Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        effectiveDairyName,
                        style: GoogleFonts.workSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (hasValidUpi)
                        Text(
                          'UPI ID: ${sellerUpiId.trim()}',
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Close',
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: AppTheme.divider),
            const SizedBox(height: 16),

            // Customer & Bill Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  _infoRow('ग्राहक (Customer):', effectiveCustomerName),
                  const SizedBox(height: 6),
                  _infoRow('महीना (Month):', monthStr),
                  const SizedBox(height: 6),
                  _infoRow(
                    'बकाया राशि (Pending):',
                    '₹${UpiPaymentService.formatAmount(pending)}',
                    isHighlight: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Main Body: Paid / Missing UPI / QR Code
            if (isPaid) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paid in Full',
                      style: GoogleFonts.workSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'बिल पूरा चुकता कर दिया गया है',
                      style: GoogleFonts.workSans(
                        fontSize: 14,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!hasValidUpi) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 44,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'UPI ID is not configured',
                      style: GoogleFonts.workSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'विक्रेता का UPI ID सेट नहीं है। कृपया नकद भुगतान करें।',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.workSans(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (uri != null) ...[
              // QR Code Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: uri.toString(),
                  semanticsLabel: uri.toString(),
                  version: QrVersions.auto,
                  size: 220,
                  padding: const EdgeInsets.all(8),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'GPay, PhonePe, Paytm या किसी भी UPI ऐप से स्कैन करें',
                textAlign: TextAlign.center,
                style: GoogleFonts.workSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Open in UPI App button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final launched = await UpiPaymentService.launchUpiPayment(
                      upiId: sellerUpiId.trim(),
                      payeeName: effectiveDairyName,
                      amount: pending,
                      transactionNote:
                          'Milk Bill $monthStr - $effectiveCustomerName',
                    );
                    if (!launched && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'कोई UPI ऐप नहीं मिला (No UPI app installed)',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(
                    'UPI ऐप में खोलें (Open in UPI App)',
                    style: GoogleFonts.workSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'बंद करें (Close)',
                  style: GoogleFonts.workSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.workSans(
            fontSize: isHighlight ? 15 : 13,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            color: isHighlight ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
