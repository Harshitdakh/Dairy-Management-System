import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../core/milk_utils.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/milk_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/seller_provider.dart';
import '../../providers/pause_provider.dart';
import 'pending_pauses_card.dart';
import '../../services/calendar_link_service.dart';
import '../../widgets/stat_card.dart';

class SellerHomeScreen extends ConsumerStatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  ConsumerState<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends ConsumerState<SellerHomeScreen> {
  String? _selectedRouteId;
  String _selectedShift = 'morning';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
            final seller = sellerAsync.valueOrNull;
            if (seller != null) {
              ref.invalidate(pendingPausesForSellerProvider(seller.id));
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
                            l10n.welcomeBack,
                            style: GoogleFonts.workSans(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.valueOrNull?.fullName ?? l10n.seller,
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
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                      label: l10n.deliveryReminder,
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
                      label: l10n.stockRefill,
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
                      label: l10n.openCalendar,
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
                            l10n.sellerNotFound,
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
                    final routesAsync =
                        ref.watch(routesBySellerProvider(seller.id));
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
                          l10n.todaysInventory,
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
                              title: l10n.assigned,
                              value: MilkUtils.formatQuantity(
                                seller.assignedMilkLiters,
                                seller.assignedMilkMl,
                              ),
                              icon: Icons.inventory_2,
                              highlight: true,
                            ),
                            StatCard(
                              title: l10n.soldToday,
                              value: '${todaySold.toStringAsFixed(1)} L',
                              icon: Icons.shopping_cart,
                              iconBgColor:
                                  AppTheme.success.withValues(alpha: 0.1),
                              iconColor: AppTheme.success,
                            ),
                            StatCard(
                              title: l10n.remaining,
                              value: '${remaining.toStringAsFixed(1)} L',
                              icon: Icons.water_drop,
                              iconBgColor:
                                  AppTheme.amber.withValues(alpha: 0.1),
                              iconColor: AppTheme.amber,
                            ),
                            StatCard(
                              title: l10n.route,
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
                          l10n.collectionSnapshot,
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
                                    title: l10n.billed,
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
                                    title: l10n.collected,
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
                                    title: l10n.pending,
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

                        // Pending Vacation Pauses Review Card
                        PendingPausesCard(sellerId: seller.id),
                        const SizedBox(height: 24),

                        // Delivery Route Section
                        Text(
                          l10n.routes,
                          style: GoogleFonts.workSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        routesAsync.when(
                          data: (routes) {
                            // If routes exist in delivery_routes table
                            if (routes.isNotEmpty) {
                              if (_selectedRouteId == null ||
                                  !routes.any((r) => r.id == _selectedRouteId)) {
                                _selectedRouteId = routes.first.id;
                              }
                              final activeRoute = routes
                                  .firstWhere((r) => r.id == _selectedRouteId);

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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Route selection chips
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: routes.map((r) {
                                          final isSelected =
                                              r.id == _selectedRouteId;
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(
                                              label: Text(r.name),
                                              selected: isSelected,
                                              onSelected: (sel) {
                                                if (sel) {
                                                  setState(() {
                                                    _selectedRouteId = r.id;
                                                  });
                                                }
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Shift filter chips
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          ChoiceChip(
                                            avatar: const Icon(
                                                Icons.wb_sunny_outlined,
                                                size: 14),
                                            label: Text(l10n.morningShift),
                                            selected:
                                                _selectedShift == 'morning',
                                            onSelected: (sel) {
                                              if (sel) {
                                                setState(() =>
                                                    _selectedShift = 'morning');
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          ChoiceChip(
                                            avatar: const Icon(
                                                Icons.nights_stay_outlined,
                                                size: 14),
                                            label: Text(l10n.eveningShift),
                                            selected:
                                                _selectedShift == 'evening',
                                            onSelected: (sel) {
                                              if (sel) {
                                                setState(() =>
                                                    _selectedShift = 'evening');
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          ChoiceChip(
                                            avatar: const Icon(Icons.sync,
                                                size: 14),
                                            label: Text(l10n.allShifts),
                                            selected: _selectedShift == 'all',
                                            onSelected: (sel) {
                                              if (sel) {
                                                setState(() =>
                                                    _selectedShift = 'all');
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryLight,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.map,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                activeRoute.name,
                                                style: GoogleFonts.workSans(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                l10n.customerCountBadge(
                                                    activeRoute.customerCount ??
                                                        0),
                                                style: GoogleFonts.workSans(
                                                  fontSize: 13,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            context.push(
                                              '/seller/customers?routeId=${activeRoute.id}&shift=$_selectedShift',
                                            );
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            minimumSize:
                                                const Size(110, 48),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            l10n.startDelivery,
                                            style: GoogleFonts.workSans(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Fallback if seller has no entry in delivery_routes table
                            return Container(
                              padding: const EdgeInsets.all(16),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Shift filter chips
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ChoiceChip(
                                          avatar: const Icon(
                                              Icons.wb_sunny_outlined,
                                              size: 14),
                                          label: Text(l10n.morningShift),
                                          selected: _selectedShift == 'morning',
                                          onSelected: (sel) {
                                            if (sel) {
                                              setState(() =>
                                                  _selectedShift = 'morning');
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          avatar: const Icon(
                                              Icons.nights_stay_outlined,
                                              size: 14),
                                          label: Text(l10n.eveningShift),
                                          selected: _selectedShift == 'evening',
                                          onSelected: (sel) {
                                            if (sel) {
                                              setState(() =>
                                                  _selectedShift = 'evening');
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          avatar:
                                              const Icon(Icons.sync, size: 14),
                                          label: Text(l10n.allShifts),
                                          selected: _selectedShift == 'all',
                                          onSelected: (sel) {
                                            if (sel) {
                                              setState(() =>
                                                  _selectedShift = 'all');
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryLight,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.map,
                                            color: AppTheme.primary),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                  color:
                                                      AppTheme.textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: () => context.push(
                                          '/seller/customers?shift=$_selectedShift',
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          minimumSize: const Size(110, 48),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          l10n.startDelivery,
                                          style: GoogleFonts.workSans(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (e, _) => Text('Error: $e'),
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
        minimumSize: const Size(100, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
