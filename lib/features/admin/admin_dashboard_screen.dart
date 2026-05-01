import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/calendar_link_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/seller_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/milk_provider.dart';
import '../../providers/billing_provider.dart';
import '../../widgets/stat_card.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final profile = ref.watch(profileProvider);
    final sellerCount = ref.watch(sellerCountProvider);
    final customerCount = ref.watch(customerCountProvider);
    final todayVolume = ref.watch(todayVolumeProvider);
    final todayRevenue = ref.watch(todayRevenueProvider);
    final collectionSummary = ref.watch(collectionSummaryProvider(currentMonth));

    final userName = profile.valueOrNull?.fullName ?? 'Admin';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sellerCountProvider);
            ref.invalidate(customerCountProvider);
            ref.invalidate(todayVolumeProvider);
            ref.invalidate(todayRevenueProvider);
            ref.invalidate(collectionSummaryProvider(currentMonth));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: GoogleFonts.workSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Welcome, $userName 👋',
                            style: GoogleFonts.workSans(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
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
                      label: 'Monthly Calendar',
                      onPressed: () => context.push('/calendar'),
                    ),
                    _CalendarActionButton(
                      icon: Icons.notifications_active_outlined,
                      label: 'Collection Reminder',
                      onPressed: () async {
                        final ok = await CalendarLinkService.openGoogleCalendar(
                          title: 'Monthly Collection Reminder',
                          description:
                              'Review pending collections and follow up with sellers.',
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
                              'Check stock balance and schedule a refill before the route starts.',
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
                  ],
                ),
                const SizedBox(height: 24),

                // ── Stat Cards ──
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.95,
                  children: [
                    StatCard(
                      title: 'Total Sellers',
                      value: sellerCount.valueOrNull?.toString() ?? '0',
                      icon: Icons.storefront,
                      iconBgColor: const Color(0xFFEEF2FF),
                      iconColor: AppTheme.primary,
                      subtitle: 'Active',
                      onTap: () => context.push('/admin/sellers'),
                    ),
                    StatCard(
                      title: 'Total Customers',
                      value: customerCount.valueOrNull?.toString() ?? '0',
                      icon: Icons.people,
                      iconBgColor: const Color(0xFFF0FDF4),
                      iconColor: AppTheme.success,
                      onTap: () => context.push('/admin/customers'),
                    ),
                    StatCard(
                      title: 'Monthly Income',
                      value: '₹${NumberFormat('#,##0').format(collectionSummary.valueOrNull?['total'] ?? 0)}',
                      icon: Icons.currency_rupee,
                      iconBgColor: const Color(0xFFEFF6FF),
                      iconColor: AppTheme.primary,
                      onTap: () => context.push('/reports/monthly-income'),
                    ),
                    StatCard(
                      title: 'Pending Collections',
                      value: '₹${NumberFormat('#,##0').format(collectionSummary.valueOrNull?['pending'] ?? 0)}',
                      icon: Icons.payments_outlined,
                      iconBgColor: const Color(0xFFFFF1F2),
                      iconColor: AppTheme.error,
                      onTap: () => context.push('/reports/collections'),
                    ),
                    StatCard(
                      title: 'Milk Assigned',
                      value:
                          '${todayVolume.valueOrNull?.toStringAsFixed(1) ?? '0'} L',
                      icon: Icons.water_drop,
                      highlight: true,
                      onTap: () => context.push('/admin/assign-milk'),
                    ),
                    StatCard(
                      title: 'Reports',
                      value:
                          '₹${NumberFormat('#,##0').format(todayRevenue.valueOrNull ?? 0)}',
                      icon: Icons.analytics_outlined,
                      iconBgColor: const Color(0xFFFEF3C7),
                      iconColor: AppTheme.amber,
                      onTap: () => context.push('/reports'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Quick Actions ──
                Text(
                  'Quick Actions',
                  style: GoogleFonts.workSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _QuickActionBtn(
                      icon: Icons.person_add,
                      label: 'Add Seller',
                      color: AppTheme.primary,
                      onTap: () => context.push('/admin/add-seller'),
                    ),
                    const SizedBox(width: 12),
                    _QuickActionBtn(
                      icon: Icons.group_add,
                      label: 'Add Customer',
                      color: AppTheme.success,
                      onTap: () => context.push('/admin/add-customer'),
                    ),
                    const SizedBox(width: 12),
                    _QuickActionBtn(
                      icon: Icons.water_drop,
                      label: 'Assign Milk',
                      color: AppTheme.amber,
                      onTap: () => context.push('/admin/assign-milk'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Recent Activity ──
                Text(
                  'Recent Activity',
                  style: GoogleFonts.workSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildRecentSales(ref),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSales(WidgetRef ref) {
    final salesAsync = ref.watch(allSalesProvider);

    return salesAsync.when(
      data: (sales) {
        if (sales.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 48, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No sales recorded yet',
                    style: GoogleFonts.workSans(color: AppTheme.textSecondary),
                  ),
                ],
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
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sales.length > 5 ? 5 : sales.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppTheme.divider),
            itemBuilder: (context, index) {
              final sale = sales[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryLight,
                  child: const Icon(Icons.water_drop,
                      color: AppTheme.primary, size: 20),
                ),
                title: Text(
                  sale.customerName ?? 'Customer',
                  style: GoogleFonts.workSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${sale.totalLiters.toStringAsFixed(1)} L • ${sale.milkType}',
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
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.workSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
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
