import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/seller_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/billing_provider.dart';

class RouteCustomersScreen extends ConsumerWidget {
  const RouteCustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final sellerAsync = ref.watch(currentSellerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: sellerAsync.when(
          data: (seller) {
            if (seller == null) {
              return const Center(child: Text('Seller not found'));
            }
            final customersAsync =
                ref.watch(customersBySellerProvider(seller.id));
            final billsAsync = ref.watch(
              monthlyBillsProvider(BillQuery(month: currentMonth, status: 'all')),
            );

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(customersBySellerProvider(seller.id));
                ref.invalidate(
                  monthlyBillsProvider(
                    BillQuery(month: currentMonth, status: 'all'),
                  ),
                );
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route Customers',
                      style: GoogleFonts.workSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      seller.routeName,
                      style: GoogleFonts.workSans(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    customersAsync.when(
                      data: (customers) {
                        final bills = billsAsync.valueOrNull ?? const [];
                        final billMap = {
                          for (final bill in bills) bill.customerId: bill,
                        };
                        if (customers.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline,
                                      size: 48, color: AppTheme.textMuted),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No customers assigned yet',
                                    style: GoogleFonts.workSans(
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: customers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final customer = customers[index];
                            final bill = billMap[customer.id];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: AppTheme.primaryLight,
                                        child: Text(
                                          (customer.fullName ?? 'C')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: GoogleFonts.workSans(
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer.fullName ?? 'Customer',
                                              style: GoogleFonts.workSans(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${customer.milkType.toUpperCase()} • ₹${customer.ratePerLiter}/L',
                                              style: GoogleFonts.workSans(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            if (customer.location != null)
                                              Text(
                                                customer.location!,
                                                style: GoogleFonts.workSans(
                                                  fontSize: 12,
                                                  color:
                                                      AppTheme.textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          context.push(
                                            '/seller/record-sale'
                                            '?customerId=${customer.id}'
                                            '&customerName=${Uri.encodeComponent(customer.fullName ?? 'Customer')}'
                                            '&milkType=${customer.milkType}'
                                            '&rate=${customer.ratePerLiter}',
                                          );
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          'Delivery Entry',
                                          style: GoogleFonts.workSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.background,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.divider),
                                    ),
                                    child: Column(
                                      children: [
                                        _detailRow(
                                          'Current Month Total',
                                          '₹${(bill?.totalAmount ?? 0).toStringAsFixed(0)}',
                                        ),
                                        const SizedBox(height: 6),
                                        _detailRow(
                                          'Collected',
                                          '₹${(bill?.paidAmount ?? 0).toStringAsFixed(0)}',
                                        ),
                                        const SizedBox(height: 6),
                                        _detailRow(
                                          'Pending',
                                          '₹${(bill?.pendingAmount ?? 0).toStringAsFixed(0)}',
                                        ),
                                        const SizedBox(height: 6),
                                        _detailRow(
                                          'Qty',
                                          '${(bill?.totalQuantityLiters ?? 0).toStringAsFixed(1)} L',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            );
                          },
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
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.workSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
