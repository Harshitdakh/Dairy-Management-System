import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../config/theme.dart';
import '../../core/milk_utils.dart';
import '../../l10n/l10n.dart';
import '../../models/customer.dart';
import '../../models/delivery_route.dart';
import '../../providers/seller_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/pause_provider.dart';
import '../../services/offline_delivery_queue_service.dart';
import '../../services/whatsapp_share_service.dart';
import '../../models/customer_bill.dart';
import '../payment/upi_qr_dialog.dart';
import '../payment/doorstep_cash_dialog.dart';
import 'package:intl/intl.dart';

class RouteCustomersScreen extends ConsumerStatefulWidget {
  final String? routeId;
  final String? shift;

  const RouteCustomersScreen({
    super.key,
    this.routeId,
    this.shift,
  });

  @override
  ConsumerState<RouteCustomersScreen> createState() =>
      _RouteCustomersScreenState();
}

class _RouteCustomersScreenState extends ConsumerState<RouteCustomersScreen>
    with WidgetsBindingObserver {
  late String _selectedShift;
  String? _selectedRouteId;
  bool _isSyncing = false;

  // Local adjusted volumes per customer (in decimal Liters)
  final Map<String, double> _adjustedVolumes = {};

  // Debouncing & double-tap guard
  final Set<String> _inFlightCustomerIds = {};
  final Map<String, DateTime> _lastTapTimes = {};

  // Session delivery recording overrides for instant UI update
  final Map<String, ({String status, double volume, double amount})>
      _sessionOverrides = {};

  // Server-recorded deliveries for today
  Map<String, ({String status, double volume, double amount})>
      _recordedDeliveries = {};

  // Set of customer IDs with approved vacation pauses today
  Set<String> _pausedCustomerIds = {};

  @override
  void initState() {
    super.initState();
    _selectedShift = widget.shift ?? 'all';
    _selectedRouteId = widget.routeId;
    WidgetsBinding.instance.addObserver(this);
    _setScreenAwake(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTodayDeliveriesAndPauses();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setScreenAwake(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setScreenAwake(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _setScreenAwake(false);
    }
  }

  Future<void> _setScreenAwake(bool enable) async {
    try {
      if (enable) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('WakelockPlus error: $e');
    }
  }

  Future<void> _loadTodayDeliveriesAndPauses() async {
    try {
      final pauseRepo = ref.read(pauseRepositoryProvider);
      final paused = await pauseRepo.getPausedCustomerIdsForDate(DateTime.now());
      if (mounted) {
        setState(() {
          _pausedCustomerIds = paused;
        });
      }
    } catch (_) {}

    try {
      final billingRepo = ref.read(billingRepositoryProvider);
      final today = DateTime.now();
      final deliveries = await billingRepo.getDeliveries(month: today);
      if (mounted) {
        final map = <String, ({String status, double volume, double amount})>{};
        for (final d in deliveries) {
          if (_isSameDay(d.deliveryDate, today)) {
            map[d.customerId] = (
              status: d.status,
              volume: d.totalLiters,
              amount: d.amount.toDouble(),
            );
          }
        }
        setState(() {
          _recordedDeliveries = map;
        });
      }
    } catch (_) {}

    try {
      final queueService = ref.read(offlineDeliveryQueueServiceProvider);
      for (final q in queueService.getUnsyncedDeliveries()) {
        if (_isSameDay(q.deliveryDate, DateTime.now())) {
          _sessionOverrides[q.customerId] = (
            status: q.status,
            volume: q.totalLiters,
            amount: q.totalLiters * (q.rate ?? 60.0),
          );
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final sellerAsync = ref.watch(currentSellerProvider);
    final queueService = ref.watch(offlineDeliveryQueueServiceProvider);

    // If routeId is provided directly (from Admin Solo Delivery or deep link)
    if (_selectedRouteId != null && _selectedRouteId!.isNotEmpty) {
      final routeAsync = ref.watch(routeByIdProvider(_selectedRouteId!));
      final customersAsync =
          ref.watch(customersByRouteProvider(_selectedRouteId!));
      final billsAsync = ref.watch(
        monthlyBillsProvider(BillQuery(month: currentMonth, status: 'all')),
      );

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildAppBar(routeAsync.valueOrNull?.name ?? l10n.routeCustomers),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(routeByIdProvider(_selectedRouteId!));
              ref.invalidate(customersByRouteProvider(_selectedRouteId!));
              ref.invalidate(
                monthlyBillsProvider(
                  BillQuery(month: currentMonth, status: 'all'),
                ),
              );
              await _loadTodayDeliveriesAndPauses();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOfflineSyncPill(queueService),
                  _buildShiftFilterBar(l10n),
                  const SizedBox(height: 16),
                  customersAsync.when(
                    data: (customers) {
                      final filtered = _filterCustomersByShift(customers);
                      return _buildCustomerList(
                        filtered,
                        billsAsync.valueOrNull ?? const [],
                        l10n,
                        routeAsync.valueOrNull,
                        null,
                        queueService,
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Error: $e',
                        style: GoogleFonts.workSans(color: AppTheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Default: Seller view based on current seller
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(l10n.routeCustomers),
      body: SafeArea(
        child: sellerAsync.when(
          data: (seller) {
            if (seller == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.sellerNotFound,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.workSans(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }

            final routesAsync = ref.watch(routesBySellerProvider(seller.id));
            final customersAsync =
                ref.watch(customersBySellerProvider(seller.id));
            final billsAsync = ref.watch(
              monthlyBillsProvider(
                BillQuery(month: currentMonth, status: 'all'),
              ),
            );

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(routesBySellerProvider(seller.id));
                ref.invalidate(customersBySellerProvider(seller.id));
                ref.invalidate(
                  monthlyBillsProvider(
                    BillQuery(month: currentMonth, status: 'all'),
                  ),
                );
                await _loadTodayDeliveriesAndPauses();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOfflineSyncPill(queueService),

                    // Route selection chips if seller has assigned routes
                    routesAsync.when(
                      data: (routes) {
                        if (routes.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              seller.routeName,
                              style: GoogleFonts.workSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: Text(l10n.allRoutes),
                                  selected: _selectedRouteId == null,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedRouteId = null);
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                ...routes.map((r) {
                                  final isSelected = _selectedRouteId == r.id;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(r.name),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedRouteId =
                                              selected ? r.id : null;
                                        });
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    _buildShiftFilterBar(l10n),
                    const SizedBox(height: 16),

                    customersAsync.when(
                      data: (customers) {
                        var filtered = customers;
                        if (_selectedRouteId != null) {
                          filtered = filtered
                              .where((c) => c.routeId == _selectedRouteId)
                              .toList();
                        }
                        filtered = _filterCustomersByShift(filtered);

                        return _buildCustomerList(
                          filtered,
                          billsAsync.valueOrNull ?? const [],
                          l10n,
                          null,
                          seller.id,
                          queueService,
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

  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      title: Text(
        title,
        style: GoogleFonts.workSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      backgroundColor: AppTheme.surface,
      elevation: 0,
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              color: AppTheme.textPrimary,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wb_incandescent, size: 14, color: AppTheme.primary),
              const SizedBox(width: 4),
              Text(
                'स्क्रीन चालू',
                style: GoogleFonts.workSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineSyncPill(OfflineDeliveryQueueService queueService) {
    return StreamBuilder<int>(
      stream: queueService.pendingCountStream,
      initialData: queueService.pendingCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? queueService.pendingCount;
        if (count == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_done, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'सभी रिकॉर्ड सिंक हैं',
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined,
                  color: Colors.amber.shade900, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$count ऑफ़लाइन रिकॉर्ड बाकी',
                  style: GoogleFonts.workSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _isSyncing ? null : () => _handleSync(queueService),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: Text(
                  _isSyncing ? 'सिंक हो रहा है...' : 'सिंक करें',
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(80, 36),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSync(OfflineDeliveryQueueService queueService) async {
    setState(() => _isSyncing = true);
    try {
      final synced = await queueService.syncQueueToSupabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$synced रिकॉर्ड सिंक हो गए (Synced $synced records)'),
          ),
        );
        await _loadTodayDeliveriesAndPauses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Widget _buildShiftFilterBar(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            avatar: const Icon(Icons.sync, size: 16),
            label: Text(l10n.allShifts),
            selected: _selectedShift == 'all',
            onSelected: (selected) {
              if (selected) setState(() => _selectedShift = 'all');
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
            label: Text(l10n.morningShift),
            selected: _selectedShift == 'morning',
            onSelected: (selected) {
              if (selected) setState(() => _selectedShift = 'morning');
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.nights_stay_outlined, size: 16),
            label: Text(l10n.eveningShift),
            selected: _selectedShift == 'evening',
            onSelected: (selected) {
              if (selected) setState(() => _selectedShift = 'evening');
            },
          ),
        ],
      ),
    );
  }

  List<Customer> _filterCustomersByShift(List<Customer> customers) {
    if (_selectedShift == 'all') return customers;
    return customers.where((c) {
      return c.deliveryShift == _selectedShift || c.deliveryShift == 'both';
    }).toList();
  }

  Widget _buildCustomerList(
    List<Customer> customers,
    List<dynamic> bills,
    AppLocalizations l10n,
    DeliveryRoute? route,
    String? fallbackSellerId,
    OfflineDeliveryQueueService queueService,
  ) {
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
              Icon(Icons.people_outline, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text(
                l10n.noCustomersOnRoute,
                style: GoogleFonts.workSans(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final billMap = {for (final b in bills) b.customerId: b};

    // Sort customers by delivery sequence (1..N first, then unassigned 0)
    final sortedCustomers = List<Customer>.from(customers);
    sortedCustomers.sort((a, b) {
      if (a.deliverySequence > 0 && b.deliverySequence > 0) {
        return a.deliverySequence.compareTo(b.deliverySequence);
      }
      if (a.deliverySequence > 0) return -1;
      if (b.deliverySequence > 0) return 1;
      return (a.fullName ?? '').compareTo(b.fullName ?? '');
    });

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedCustomers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final customer = sortedCustomers[index];
        final bill = billMap[customer.id];
        final sellerId = route?.sellerId ?? customer.sellerId ?? fallbackSellerId ?? '';

        final isVacation = _pausedCustomerIds.contains(customer.id);
        final recorded = _sessionOverrides[customer.id] ?? _recordedDeliveries[customer.id];

        final defaultVolume = MilkUtils.toDecimal(
          customer.dailyQuantityLiters,
          customer.dailyQuantityMl,
        );
        final currentVolume = _adjustedVolumes[customer.id] ??
            (defaultVolume > 0 ? defaultVolume : 1.0);

        final tuple = MilkUtils.fromDecimal(currentVolume);
        final formattedVolume = MilkUtils.formatQuantity(tuple.liters, tuple.ml);
        final currentAmount = MilkUtils.calculateAmount(
          tuple.liters,
          tuple.ml,
          customer.ratePerLiter,
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isVacation ? Colors.grey.shade100 : AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: isVacation
                ? Border.all(color: Colors.amber.shade200, width: 1.5)
                : null,
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
              // Header Row: Sequence Badge, Customer Info, Record-Sale Link
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSequenceBadge(customer.deliverySequence),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.fullName ?? 'Customer',
                          style: GoogleFonts.workSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: isVacation
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
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
                              color: AppTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    tooltip: l10n.deliveryEntry,
                    onPressed: isVacation
                        ? null
                        : () {
                            final uri = Uri(
                              path: '/seller/record-sale',
                              queryParameters: {
                                'customerId': customer.id,
                                'customerName': customer.fullName ?? 'Customer',
                                'milkType': customer.milkType,
                                'rate': customer.ratePerLiter.toString(),
                                if (sellerId.isNotEmpty) 'sellerId': sellerId,
                              },
                            );
                            try {
                              context.push(uri.toString());
                            } catch (_) {}
                          },
                  ),
                ],
              ),

              // Vacation Banner if approved pause today
              if (isVacation) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.beach_access,
                          size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.pausedVacation,
                          style: GoogleFonts.workSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Recorded Status Banner (if already delivered/skipped today and not on vacation)
              if (recorded != null && !isVacation) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: recorded.status == 'delivered'
                        ? AppTheme.primaryLight
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: recorded.status == 'delivered'
                          ? AppTheme.primary.withValues(alpha: 0.3)
                          : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        recorded.status == 'delivered'
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: recorded.status == 'delivered'
                            ? AppTheme.primary
                            : Colors.grey.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recorded.status == 'delivered'
                              ? '✔ आज दिया गया: ${recorded.volume} L • ₹${recorded.amount.toStringAsFixed(0)}'
                              : '✕ आज नहीं लिया (₹0)',
                          style: GoogleFonts.workSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: recorded.status == 'delivered'
                                ? AppTheme.primary
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _sessionOverrides.remove(customer.id);
                            _recordedDeliveries.remove(customer.id);
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(48, 36),
                        ),
                        child: Text(
                          'बदलें',
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Active Delivery Controls (if unrecorded and not on vacation)
              if (recorded == null && !isVacation) ...[
                const SizedBox(height: 12),
                // Current Selected Volume & Price Display
                Row(
                  children: [
                    Text(
                      '$formattedVolume • ₹${currentAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.workSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_adjustedVolumes.containsKey(customer.id) &&
                        _adjustedVolumes[customer.id] != defaultVolume)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _adjustedVolumes.remove(customer.id);
                          });
                          HapticFeedback.selectionClick();
                        },
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('रीसेट'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(48, 32),
                          textStyle: GoogleFonts.workSans(fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Inline Volume Steppers: [-250ml], [+250ml], [+500ml], [+1L]
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStepperButton(
                        label: '-250ml',
                        onTap: () => _adjustVolume(customer.id, currentVolume, -0.25),
                      ),
                      const SizedBox(width: 8),
                      _buildStepperButton(
                        label: '+250ml',
                        onTap: () => _adjustVolume(customer.id, currentVolume, 0.25),
                      ),
                      const SizedBox(width: 8),
                      _buildStepperButton(
                        label: '+500ml',
                        onTap: () => _adjustVolume(customer.id, currentVolume, 0.50),
                      ),
                      const SizedBox(width: 8),
                      _buildStepperButton(
                        label: '+1L',
                        onTap: () => _adjustVolume(customer.id, currentVolume, 1.00),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 1-Tap Action Buttons Row: [ ✔ दिया ] and [ ✕ आज नहीं लिया ]
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        onPressed: currentVolume <= 0.0 || _inFlightCustomerIds.contains(customer.id)
                            ? null
                            : () => _handleDelivered(
                                  customer: customer,
                                  sellerId: sellerId,
                                  volume: currentVolume,
                                  queueService: queueService,
                                ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size(120, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          '✔ दिया',
                          style: GoogleFonts.workSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: _inFlightCustomerIds.contains(customer.id)
                            ? null
                            : () => _handleSkip(
                                  customer: customer,
                                  sellerId: sellerId,
                                  queueService: queueService,
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          minimumSize: const Size(100, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          '✕ आज नहीं लिया',
                          style: GoogleFonts.workSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Monthly Bill Summary
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
                      l10n.monthlyBill,
                      '₹${(bill?.totalAmount ?? 0).toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 6),
                    _detailRow(
                      l10n.collected,
                      '₹${(bill?.paidAmount ?? 0).toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 6),
                    _detailRow(
                      l10n.pending,
                      '₹${(bill?.pendingAmount ?? 0).toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 6),
                    _detailRow(
                      l10n.quantity,
                      '${(bill?.totalQuantityLiters ?? 0).toStringAsFixed(1)} L',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Quick Action Buttons: [💵 नकद मिला], [📲 QR कोड], [💬 व्हाट्सएप]
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final effectiveBill = bill ??
                            CustomerBill(
                              id: 'bill-${customer.id}',
                              customerId: customer.id,
                              sellerId: sellerId,
                              billMonth: DateTime.now(),
                              totalQuantityLiters: 0,
                              totalAmount: 0,
                              paidAmount: 0,
                              pendingAmount: 0,
                              status: 'pending',
                              customerName: customer.fullName,
                            );
                        DoorstepCashDialog.show(
                          context: context,
                          bill: effectiveBill,
                          customer: customer,
                          onCollectionRecorded: () {
                            ref.invalidate(monthlyBillsProvider);
                          },
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        minimumSize: const Size(0, 38),
                        side: BorderSide(color: Colors.green.shade600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '💵 नकद मिला',
                        style: GoogleFonts.workSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final effectiveBill = bill ??
                            CustomerBill(
                              id: 'bill-${customer.id}',
                              customerId: customer.id,
                              sellerId: sellerId,
                              billMonth: DateTime.now(),
                              totalQuantityLiters: 0,
                              totalAmount: 0,
                              paidAmount: 0,
                              pendingAmount: 0,
                              status: 'pending',
                              customerName: customer.fullName,
                            );
                        UpiQrDialog.show(
                          context: context,
                          bill: effectiveBill,
                          sellerUpiId: (customer.phone != null && customer.phone!.isNotEmpty)
                              ? '${customer.phone}@upi'
                              : 'milkhub@upi',
                          sellerName: customer.sellerName ?? 'Milk HUB Dairy',
                          customerName: customer.fullName,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        minimumSize: const Size(0, 38),
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '📲 QR कोड',
                        style: GoogleFonts.workSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final effectiveBill = bill ??
                            CustomerBill(
                              id: 'bill-${customer.id}',
                              customerId: customer.id,
                              sellerId: sellerId,
                              billMonth: DateTime.now(),
                              totalQuantityLiters: 0,
                              totalAmount: 0,
                              paidAmount: 0,
                              pendingAmount: 0,
                              status: 'pending',
                              customerName: customer.fullName,
                            );

                        final invoice = WhatsappShareService.formatDairyInvoice(
                          dairyName: customer.sellerName ?? 'Milk HUB Dairy',
                          customerName: customer.fullName ?? 'Customer',
                          monthYear: DateFormat('MMMM yyyy').format(effectiveBill.billMonth),
                          totalLiters: effectiveBill.totalQuantityLiters.toDouble(),
                          milkType: customer.milkType.toUpperCase(),
                          totalAmount: effectiveBill.totalAmount.toDouble(),
                          paidAmount: effectiveBill.paidAmount.toDouble(),
                          pendingAmount: effectiveBill.pendingAmount.toDouble(),
                          upiId: (customer.phone != null && customer.phone!.isNotEmpty)
                              ? '${customer.phone}@upi'
                              : 'milkhub@upi',
                        );

                        try {
                          await WhatsappShareService.shareInvoiceOnWhatsapp(
                            phone: customer.phone ?? '',
                            invoiceText: invoice,
                          );
                        } on FormatException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        minimumSize: const Size(0, 38),
                        side: BorderSide(color: Colors.teal.shade600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '💬 व्हाट्सएप',
                        style: GoogleFonts.workSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSequenceBadge(int sequence) {
    final badgeText = sequence > 0 ? '[$sequence]' : '[--]';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        badgeText,
        style: GoogleFonts.workSans(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildStepperButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  void _adjustVolume(String customerId, double currentVolume, double delta) {
    final newVolume = max(0.0, currentVolume + delta);
    final clamped = double.parse(newVolume.toStringAsFixed(3));
    setState(() {
      _adjustedVolumes[customerId] = clamped;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _handleDelivered({
    required Customer customer,
    required String sellerId,
    required double volume,
    required OfflineDeliveryQueueService queueService,
  }) async {
    final now = DateTime.now();
    final lastTap = _lastTapTimes[customer.id];
    if (_inFlightCustomerIds.contains(customer.id) ||
        (lastTap != null && now.difference(lastTap).inMilliseconds < 600)) {
      return;
    }

    if (volume <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('मात्रा 0 से अधिक होनी चाहिए (Quantity must be > 0 mL)'),
        ),
      );
      return;
    }

    _lastTapTimes[customer.id] = now;
    _inFlightCustomerIds.add(customer.id);
    setState(() {});

    try {
      final tuple = MilkUtils.fromDecimal(volume);
      final shift = _selectedShift == 'all'
          ? (customer.deliveryShift == 'evening' ? 'evening' : 'morning')
          : _selectedShift;

      await queueService.enqueueDelivery(
        customerId: customer.id,
        sellerId: sellerId,
        milkType: customer.milkType,
        quantityLiters: tuple.liters.toDouble(),
        quantityMl: tuple.ml,
        deliveryDate: DateTime.now(),
        shift: shift,
        status: 'delivered',
        rate: customer.ratePerLiter.toDouble(),
      );

      final amount = MilkUtils.calculateAmount(
        tuple.liters,
        tuple.ml,
        customer.ratePerLiter,
      );

      _sessionOverrides[customer.id] = (
        status: 'delivered',
        volume: volume,
        amount: amount,
      );

      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      _inFlightCustomerIds.remove(customer.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleSkip({
    required Customer customer,
    required String sellerId,
    required OfflineDeliveryQueueService queueService,
  }) async {
    final now = DateTime.now();
    final lastTap = _lastTapTimes[customer.id];
    if (_inFlightCustomerIds.contains(customer.id) ||
        (lastTap != null && now.difference(lastTap).inMilliseconds < 600)) {
      return;
    }

    _lastTapTimes[customer.id] = now;
    _inFlightCustomerIds.add(customer.id);
    setState(() {});

    try {
      final shift = _selectedShift == 'all'
          ? (customer.deliveryShift == 'evening' ? 'evening' : 'morning')
          : _selectedShift;

      await queueService.enqueueDelivery(
        customerId: customer.id,
        sellerId: sellerId,
        milkType: customer.milkType,
        quantityLiters: 0,
        quantityMl: 0,
        deliveryDate: DateTime.now(),
        shift: shift,
        status: 'skipped',
        notes: 'आज नहीं लिया',
      );

      _sessionOverrides[customer.id] = (
        status: 'skipped',
        volume: 0.0,
        amount: 0.0,
      );

      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      _inFlightCustomerIds.remove(customer.id);
      if (mounted) setState(() {});
    }
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
