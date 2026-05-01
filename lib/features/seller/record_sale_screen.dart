import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/seller_provider.dart';
import '../../providers/milk_provider.dart';
import '../../providers/billing_provider.dart';
import '../../core/milk_utils.dart';

class RecordSaleScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final String milkType;
  final double ratePerLiter;

  const RecordSaleScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.milkType,
    required this.ratePerLiter,
  });

  @override
  ConsumerState<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends ConsumerState<RecordSaleScreen> {
  final _litersController = TextEditingController();
  final _mlController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String _deliveryStatus = 'delivered';

  double get _totalAmount {
    final liters = int.tryParse(_litersController.text) ?? 0;
    final ml = int.tryParse(_mlController.text) ?? 0;
    return MilkUtils.calculateAmount(liters, ml, widget.ratePerLiter);
  }

  @override
  void initState() {
    super.initState();
    _litersController.addListener(() => setState(() {}));
    _mlController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _litersController.dispose();
    _mlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleRecord() async {
    final liters = int.tryParse(_litersController.text.trim()) ?? 0;
    final ml = int.tryParse(_mlController.text.trim()) ?? 0;

    if (_deliveryStatus == 'delivered' && liters <= 0 && ml <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final seller = ref.read(currentSellerProvider).valueOrNull;
      if (seller == null) throw Exception('Seller not found');

      if (_deliveryStatus == 'delivered') {
        final milkRepo = ref.read(milkRepositoryProvider);
        await milkRepo.recordSale(
          sellerId: seller.id,
          customerId: widget.customerId,
          milkType: widget.milkType,
          quantityLiters: liters,
          quantityMl: ml,
          totalAmount: _totalAmount,
          saleDate: DateTime.now(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      } else {
        final billingRepo = ref.read(billingRepositoryProvider);
        await billingRepo.recordSkippedDelivery(
          customerId: widget.customerId,
          sellerId: seller.id,
          milkType: widget.milkType,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      }

      if (mounted) {
        ref.invalidate(sellerTodaySoldProvider(seller.id));
        ref.invalidate(salesBySellerProvider(seller.id));
        ref.invalidate(collectionSummaryProvider(DateTime.now()));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _deliveryStatus == 'delivered'
                  ? 'Delivery recorded successfully!'
                  : 'Delivery marked as skipped',
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Record Sale',
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      widget.customerName.substring(0, 1).toUpperCase(),
                      style: GoogleFonts.workSans(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customerName,
                        style: GoogleFonts.workSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${widget.milkType.toUpperCase()} • ₹${widget.ratePerLiter.toStringAsFixed(0)}/L',
                        style: GoogleFonts.workSans(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'Delivery Status',
              style: GoogleFonts.workSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'delivered',
                  label: Text('Delivered'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment<String>(
                  value: 'skipped',
                  label: Text('Skipped'),
                  icon: Icon(Icons.event_busy_outlined),
                ),
              ],
              selected: {_deliveryStatus},
              onSelectionChanged: (values) {
                setState(() => _deliveryStatus = values.first);
              },
            ),
            const SizedBox(height: 20),

            // Quantity
            Text(
              'Quantity',
              style: GoogleFonts.workSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _litersController,
                    keyboardType: TextInputType.number,
                    enabled: _deliveryStatus == 'delivered',
                    decoration: const InputDecoration(
                      hintText: 'Liters',
                      suffixText: 'L',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _mlController,
                    keyboardType: TextInputType.number,
                    enabled: _deliveryStatus == 'delivered',
                    decoration: const InputDecoration(
                      hintText: 'ml',
                      suffixText: 'ml',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'Notes',
              style: GoogleFonts.workSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Optional delivery notes',
              ),
            ),
            const SizedBox(height: 20),

            // Total amount preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: GoogleFonts.workSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '₹${_totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.workSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _deliveryStatus == 'delivered'
                          ? AppTheme.primary
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRecord,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _deliveryStatus == 'delivered'
                            ? 'Save Delivery'
                            : 'Save as Skipped',
                        style: GoogleFonts.workSans(
                          fontSize: 16,
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
}
