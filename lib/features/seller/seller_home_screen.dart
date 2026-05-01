import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../services/calendar_link_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/seller_provider.dart';
import '../../providers/milk_provider.dart';
import '../../providers/billing_provider.dart';
import '../../core/milk_utils.dart';
import '../../widgets/stat_card.dart';

class SellerHomeScreen extends ConsumerWidget {
  const SellerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final profile = ref.watch(profileProvider);
    final sellerAsync = ref.watch(currentSellerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentSellerProvider);
            ref.invalidate(collectionSummaryProvider(currentMonth));
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
                            'Welcome Back',
                            style: GoogleFonts.workSans(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.valueOrNull?.fullName ?? 'Seller',
                            style: GoogleFonts.workSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
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
                      icon: Icons.event_available,
                      label: 'Delivery Reminder',
                      onPressed: () async {
                        final ok = await CalendarLinkService.openGoogleCalendar(
                          title: 'Delivery Reminder',
                          description:
                              'Confirm today\'s route customers and delivery schedule.',
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
                      icon: Icons.inventory_2_outlined,
                      label: 'Stock Refill',
                      onPressed: () async {
                        final ok = await CalendarLinkService.openGoogleCalendar(
                          title: 'Stock Refill Reminder',
                          description:
                              'Review assigned stock and arrange refill before dispatch.',
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
                      label: 'Open Calendar',
                      onPressed: () => context.push('/calendar'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                sellerAsync.when(
                  data: (seller) {
                    if (seller == null) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Seller record not found.\nPlease contact admin.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.workSans(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }

                    final todaySoldAsync =
                        ref.watch(sellerTodaySoldProvider(seller.id));
                    final todaySold = todaySoldAsync.valueOrNull ?? 0;
                    final collectionSummary =
                      ref.watch(collectionSummaryProvider(currentMonth));
                    final assigned = MilkUtils.toDecimal(
                      seller.assignedMilkLiters,
                      seller.assignedMilkMl,
                    );
                    final remaining = assigned - todaySold;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Inventory Cards
                        Text(
                          'Today\'s Inventory',
                          style: GoogleFonts.workSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.0,
                          children: [
                            StatCard(
                              title: 'Assigned',
                              value: MilkUtils.formatQuantity(
                                seller.assignedMilkLiters,
                                seller.assignedMilkMl,
                              ),
                              icon: Icons.inventory_2,
                              highlight: true,
                            ),
                            StatCard(
                              title: 'Sold Today',
                              value: '${todaySold.toStringAsFixed(1)} L',
                              icon: Icons.shopping_cart,
                              iconBgColor:
                                  AppTheme.success.withValues(alpha: 0.1),
                              iconColor: AppTheme.success,
                            ),
                            StatCard(
                              title: 'Remaining',
                              value: '${remaining.toStringAsFixed(1)} L',
                              icon: Icons.water_drop,
                              iconBgColor:
                                  AppTheme.amber.withValues(alpha: 0.1),
                              iconColor: AppTheme.amber,
                            ),
                            StatCard(
                              title: 'Route',
                              value: seller.routeName,
                              icon: Icons.route,
                              iconBgColor:
                                  AppTheme.cyan.withValues(alpha: 0.1),
                              iconColor: AppTheme.cyan,
                              valueColor: AppTheme.textPrimary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Collection Snapshot',
                          style: GoogleFonts.workSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth - 24) / 3;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: StatCard(
                                    title: 'Billed',
                                    value:
                                        '₹${(collectionSummary.valueOrNull?['total'] ?? 0).toStringAsFixed(0)}',
                                    icon: Icons.receipt_long,
                                    iconBgColor:
                                        AppTheme.primary.withValues(alpha: 0.1),
                                    iconColor: AppTheme.primary,
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: StatCard(
                                    title: 'Collected',
                                    value:
                                        '₹${(collectionSummary.valueOrNull?['paid'] ?? 0).toStringAsFixed(0)}',
                                    icon: Icons.payments,
                                    iconBgColor:
                                        AppTheme.success.withValues(alpha: 0.1),
                                    iconColor: AppTheme.success,
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: StatCard(
                                    title: 'Pending',
                                    value:
                                        '₹${(collectionSummary.valueOrNull?['pending'] ?? 0).toStringAsFixed(0)}',
                                    icon: Icons.warning_amber_rounded,
                                    iconBgColor:
                                        AppTheme.amber.withValues(alpha: 0.1),
                                    iconColor: AppTheme.amber,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Delivery Route section
                        Text(
                          'Delivery Route',
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
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.map,
                                    color: AppTheme.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      seller.routeName,
                                      style: GoogleFonts.workSans(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (seller.location != null)
                                      Text(
                                        seller.location!,
                                        style: GoogleFonts.workSans(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    context.go('/seller/customers'),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      AppTheme.primary.withValues(alpha: 0.1),
                                  foregroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('View'),
                              ),
                            ],
                          ),
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
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
