import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/calendar_link_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/milk_provider.dart';
import '../../providers/billing_provider.dart';
import '../../models/customer.dart';
import '../../models/customer_bill.dart';
import '../../providers/pause_provider.dart';
import 'pause_request_dialog.dart';
import '../payment/upi_qr_dialog.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final profile = ref.watch(profileProvider);
    final customerAsync = ref.watch(currentCustomerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentCustomerProvider);
            ref.invalidate(collectionSummaryProvider(currentMonth));
            final customer = customerAsync.valueOrNull;
            if (customer != null) {
              ref.invalidate(customerPausesProvider(customer.id));
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good ${_getGreeting()}',
                            style: GoogleFonts.workSans(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.valueOrNull?.fullName ?? 'Customer',
                            style: GoogleFonts.workSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push('/notifications'),
                      icon: const Icon(Icons.notifications_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CalendarActionButton(
                      icon: Icons.payments_outlined,
                      label: 'Payment Reminder',
                      onPressed: () async {
                        final ok = await CalendarLinkService.openGoogleCalendar(
                          title: 'Payment Reminder',
                          description:
                              'Review current month payable and complete pending payment.',
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Unable to open calendar link'),
                            ),
                          );
                        }
                      },
                    ),
                    _CalendarActionButton(
                      icon: Icons.calendar_month,
                      label: 'Monthly Calendar',
                      onPressed: () => context.push('/calendar'),
                    ),
                    _CalendarActionButton(
                      icon: Icons.receipt_long,
                      label: 'Billing Report',
                      onPressed: () => context.push('/reports/monthly-income'),
                    ),
                    _CalendarActionButton(
                      icon: Icons.pause_circle_outline,
                      label: 'Pause Milk (दूध बंद)',
                      onPressed: () {
                        final customer = customerAsync.valueOrNull;
                        if (customer == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Customer details loading, please wait...'),
                            ),
                          );
                          return;
                        }
                        PauseRequestDialog.show(
                          context: context,
                          customerId: customer.id,
                          customerName: customer.fullName,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                customerAsync.when(
                  data: (customer) {
                    if (customer == null) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Customer record not found.\nPlease contact admin.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.workSans(
                                color: AppTheme.textSecondary),
                          ),
                        ),
                      );
                    }

                    final salesAsync =
                        ref.watch(salesByCustomerProvider(customer.id));
                    final collectionSummary =
                        ref.watch(collectionSummaryProvider(currentMonth));
                    final currentSales = salesAsync.valueOrNull ?? const [];
                    double monthlyQuantity = 0;
                    double monthlyTotal = 0;
                    final now = DateTime.now();
                    for (final sale in currentSales) {
                      if (sale.saleDate.year == now.year &&
                          sale.saleDate.month == now.month) {
                        monthlyQuantity += sale.totalLiters;
                        monthlyTotal += sale.totalAmount.toDouble();
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Milk info card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.water_drop,
                                        color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    customer.milkType.toUpperCase(),
                                    style: GoogleFonts.workSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _cardStat('Rate', '₹${customer.ratePerLiter}/L'),
                                  _cardStat('Seller',
                                      customer.sellerName ?? 'N/A'),
                                  _cardStat('Route',
                                      customer.routeName ?? 'N/A'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildVacationStatusCard(context, ref, customer),
                        const SizedBox(height: 24),

                        // Bill summary
                        Text(
                          'Monthly Summary',
                          style: GoogleFonts.workSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _summaryRow(
                                'Monthly Qty',
                                '${monthlyQuantity.toStringAsFixed(1)} L',
                                Icons.water_drop_outlined,
                              ),
                              const Divider(color: AppTheme.divider),
                              _summaryRow(
                                'Current Month Payable',
                                '₹${monthlyTotal.toStringAsFixed(0)}',
                                Icons.receipt,
                              ),
                              const Divider(color: AppTheme.divider),
                              _summaryRow(
                                'Amount Paid',
                                '₹${(collectionSummary.valueOrNull?['paid'] ?? 0).toStringAsFixed(0)}',
                                Icons.payments,
                              ),
                              const Divider(color: AppTheme.divider),
                              _summaryRow(
                                'Amount Needed To Pay',
                                '₹${(collectionSummary.valueOrNull?['pending'] ?? 0).toStringAsFixed(0)}',
                                Icons.pending_actions,
                              ),
                              if (((collectionSummary.valueOrNull?['pending'] as num?)?.toDouble() ?? 0.0) > 0) ...[
                                const Divider(color: AppTheme.divider),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      final pendingAmount = ((collectionSummary.valueOrNull?['pending'] as num?)?.toDouble() ?? 0.0);
                                      final bill = CustomerBill(
                                        id: 'bill-${customer.id}',
                                        customerId: customer.id,
                                        sellerId: customer.sellerId ?? '',
                                        billMonth: currentMonth,
                                        totalQuantityLiters: monthlyQuantity,
                                        totalAmount: monthlyTotal,
                                        paidAmount: (collectionSummary.valueOrNull?['paid'] as num?)?.toDouble() ?? 0.0,
                                        pendingAmount: pendingAmount,
                                        status: 'pending',
                                        customerName: customer.fullName,
                                        sellerName: customer.sellerName,
                                      );
                                      UpiQrDialog.show(
                                        context: context,
                                        bill: bill,
                                        sellerUpiId: (customer.sellerName != null && customer.sellerName!.isNotEmpty)
                                            ? '${customer.sellerName!.toLowerCase().replaceAll(' ', '')}@upi'
                                            : 'milkhub@upi',
                                        sellerName: customer.sellerName ?? 'Milk HUB Dairy',
                                        customerName: customer.fullName,
                                      );
                                    },
                                    icon: const Icon(Icons.qr_code_2, size: 20),
                                    label: Text(
                                      'Pay via UPI / QR Code (UPI से भुगतान करें)',
                                      style: GoogleFonts.workSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      minimumSize: const Size.fromHeight(44),
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
                        const SizedBox(height: 24),

                        // Recent activity
                        Text(
                          'Recent Activity',
                          style: GoogleFonts.workSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        salesAsync.when(
                          data: (sales) {
                            if (sales.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    'No deliveries yet',
                                    style: GoogleFonts.workSans(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount:
                                    sales.length > 5 ? 5 : sales.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(
                                        height: 1,
                                        color: AppTheme.divider),
                                itemBuilder: (context, index) {
                                  final sale = sales[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryLight,
                                      radius: 20,
                                      child: const Icon(
                                          Icons.water_drop,
                                          color: AppTheme.primary,
                                          size: 18),
                                    ),
                                    title: Text(
                                      '${sale.totalLiters.toStringAsFixed(1)} L • ${sale.milkType}',
                                      style: GoogleFonts.workSans(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      DateFormat('MMM dd, yyyy')
                                          .format(sale.saleDate),
                                      style: GoogleFonts.workSans(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    trailing: Text(
                                      '₹${sale.totalAmount}',
                                      style: GoogleFonts.workSans(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (e, _) => Text('$e'),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.workSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.workSans(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.workSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacationStatusCard(
      BuildContext context, WidgetRef ref, Customer customer) {
    final pausesAsync = ref.watch(customerPausesProvider(customer.id));
    final pauses = pausesAsync.valueOrNull ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check for active approved pause today
    final activeApproved =
        pauses.where((p) => p.isApproved && p.isActiveOn(today)).firstOrNull;

    // Check for upcoming pending pause request
    final pendingPause = pauses
        .where((p) =>
            p.isPending &&
            !DateTime(p.endDate.year, p.endDate.month, p.endDate.day)
                .isBefore(today))
        .firstOrNull;

    if (activeApproved != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.skippedBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.paused.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.beach_access, color: AppTheme.paused, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⛔ आज दूध बंद (छुट्टी) / Vacation Active',
                    style: GoogleFonts.workSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.paused,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.paused,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Approved',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'अवधि (Period): ${DateFormat('dd MMM').format(activeApproved.startDate)} - ${DateFormat('dd MMM yyyy').format(activeApproved.endDate)}',
              style: GoogleFonts.workSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (activeApproved.reason != null &&
                activeApproved.reason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'कारण: ${activeApproved.reason}',
                style: GoogleFonts.workSans(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      );
    }

    if (pendingPause != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hourglass_top,
                    color: Color(0xFFD97706), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⏳ दूध बंद अनुरोध लंबित / Pause Pending',
                    style: GoogleFonts.workSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pending',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'अवधि (Period): ${DateFormat('dd MMM').format(pendingPause.startDate)} - ${DateFormat('dd MMM yyyy').format(pendingPause.endDate)}',
              style: GoogleFonts.workSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'विक्रेता की स्वीकृति की प्रतीक्षा है (Deliveries continue until approved)',
              style: GoogleFonts.workSans(
                  fontSize: 12, color: const Color(0xFF92400E)),
            ),
          ],
        ),
      );
    }

    // Default: Clean Vacation Pause Request Banner
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.beach_access, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Vacation / दूध बंद',
                  style: GoogleFonts.workSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Going on leave? Request delivery pause',
                  style: GoogleFonts.workSans(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () {
              PauseRequestDialog.show(
                context: context,
                customerId: customer.id,
                customerName: customer.fullName,
              );
            },
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'अनुरोध करें',
              style: GoogleFonts.workSans(
                  fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _CalendarActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CalendarActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: AppTheme.divider),
        backgroundColor: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
