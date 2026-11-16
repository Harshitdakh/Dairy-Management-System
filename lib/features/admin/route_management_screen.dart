import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/customer.dart';
import '../../models/delivery_route.dart';
import '../../models/seller.dart';
import '../../providers/customer_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/seller_provider.dart';

class RouteManagementScreen extends ConsumerStatefulWidget {
  const RouteManagementScreen({super.key});

  @override
  ConsumerState<RouteManagementScreen> createState() =>
      _RouteManagementScreenState();
}

class _RouteManagementScreenState extends ConsumerState<RouteManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          l10n.manageRoutes,
          style: GoogleFonts.workSans(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.workSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.alt_route, size: 20),
              text: l10n.routes,
            ),
            Tab(
              icon: const Icon(Icons.format_list_numbered, size: 20),
              text: l10n.stopSequence,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RoutesTab(
            onNavigateToSequence: (routeId) {
              setState(() {
                _selectedRouteId = routeId;
              });
              _tabController.animateTo(1);
            },
          ),
          _StopSequenceTab(
            initialRouteId: _selectedRouteId,
            onRouteChange: (routeId) {
              setState(() {
                _selectedRouteId = routeId;
              });
            },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// TAB 1: ROUTES LIST & CRUD
// ────────────────────────────────────────────────────────────
class _RoutesTab extends ConsumerWidget {
  final ValueChanged<String> onNavigateToSequence;

  const _RoutesTab({required this.onNavigateToSequence});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final routesAsync = ref.watch(allRoutesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditRouteDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(
          l10n.addRoute,
          style: GoogleFonts.workSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(allRoutesProvider),
        child: routesAsync.when(
          data: (routes) {
            if (routes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.alt_route,
                          size: 48,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.noRoutesFound,
                        style: GoogleFonts.workSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.createFirstRoute,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.workSans(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: routes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final route = routes[index];
                return _RouteCard(
                  route: route,
                  onSequence: () => onNavigateToSequence(route.id),
                  onEdit: () => _showAddEditRouteDialog(context, ref, route: route),
                  onDelete: () => _showDeleteDialog(context, ref, route),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error: $err',
                style: GoogleFonts.workSans(color: AppTheme.error),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddEditRouteDialog(
    BuildContext context,
    WidgetRef ref, {
    DeliveryRoute? route,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddEditRouteDialog(route: route),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    DeliveryRoute route,
  ) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.deleteRouteConfirmTitle,
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          l10n.deleteRouteConfirmMessage,
          style: GoogleFonts.workSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l10n.cancel,
              style: GoogleFonts.workSans(color: AppTheme.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(routeRepositoryProvider).deleteRoute(route.id);
                ref.invalidate(allRoutesProvider);
                ref.invalidate(allCustomersProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.routeDeleted)),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete route: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(
              l10n.delete,
              style: GoogleFonts.workSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final DeliveryRoute route;
  final VoidCallback onSequence;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RouteCard({
    required this.route,
    required this.onSequence,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Color shiftBg;
    Color shiftColor;
    String shiftLabel;
    IconData shiftIcon;

    switch (route.shift) {
      case 'evening':
        shiftBg = Colors.indigo.withValues(alpha: 0.1);
        shiftColor = Colors.indigo;
        shiftLabel = l10n.eveningShift;
        shiftIcon = Icons.nights_stay;
        break;
      case 'both':
        shiftBg = Colors.teal.withValues(alpha: 0.1);
        shiftColor = Colors.teal;
        shiftLabel = l10n.bothShifts;
        shiftIcon = Icons.sync;
        break;
      case 'morning':
      default:
        shiftBg = Colors.amber.withValues(alpha: 0.15);
        shiftColor = Colors.amber.shade900;
        shiftLabel = l10n.morningShift;
        shiftIcon = Icons.wb_sunny;
        break;
    }

    final sellerDisplayName = (route.sellerName != null && route.sellerName!.isNotEmpty)
        ? route.sellerName!
        : l10n.noSellerAssigned;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: GoogleFonts.workSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: shiftBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(shiftIcon, size: 13, color: shiftColor),
                              const SizedBox(width: 4),
                              Text(
                                shiftLabel,
                                style: GoogleFonts.workSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: shiftColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.customerCountBadge(route.customerCount ?? 0),
                            style: GoogleFonts.workSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppTheme.textSecondary,
                tooltip: l10n.editRoute,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppTheme.error,
                tooltip: l10n.deleteRoute,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sellerDisplayName,
                  style: GoogleFonts.workSans(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (route.description != null && route.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              route.description!,
              style: GoogleFonts.workSans(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onSequence,
              icon: const Icon(Icons.format_list_numbered, size: 18),
              label: Text(l10n.reorderStops),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// ADD / EDIT ROUTE DIALOG
// ────────────────────────────────────────────────────────────
class _AddEditRouteDialog extends ConsumerStatefulWidget {
  final DeliveryRoute? route;

  const _AddEditRouteDialog({this.route});

  @override
  ConsumerState<_AddEditRouteDialog> createState() =>
      _AddEditRouteDialogState();
}

class _AddEditRouteDialogState extends ConsumerState<_AddEditRouteDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late String _shift;
  String? _sellerId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.route?.name ?? '');
    _descController =
        TextEditingController(text: widget.route?.description ?? '');
    _shift = widget.route?.shift ?? 'morning';
    _sellerId = widget.route?.sellerId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sellersAsync = ref.watch(allSellersProvider);

    return AlertDialog(
      title: Text(
        widget.route == null ? l10n.addRoute : l10n.editRoute,
        style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.routeName,
                    hintText: 'e.g. Ward 3 Morning',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Route name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _shift,
                  decoration: InputDecoration(
                    labelText: l10n.shift,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'morning',
                      child: Text(l10n.morningShift),
                    ),
                    DropdownMenuItem(
                      value: 'evening',
                      child: Text(l10n.eveningShift),
                    ),
                    DropdownMenuItem(
                      value: 'both',
                      child: Text(l10n.bothShifts),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _shift = val);
                  },
                ),
                const SizedBox(height: 16),
                sellersAsync.when(
                  data: (sellers) {
                    final items = <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.noSellerAssigned),
                      ),
                      ...sellers.map((Seller s) {
                        final label = s.fullName != null && s.fullName!.isNotEmpty
                            ? '${s.fullName} (${s.routeName})'
                            : s.routeName;
                        return DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(label),
                        );
                      }),
                    ];

                    return DropdownButtonFormField<String?>(
                      initialValue: _sellerId,
                      decoration: InputDecoration(
                        labelText: l10n.assignedSeller,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: items,
                      onChanged: (val) {
                        setState(() => _sellerId = val);
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.routeDescription,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            l10n.cancel,
            style: GoogleFonts.workSans(color: AppTheme.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size(100, 48),
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
                  l10n.save,
                  style: GoogleFonts.workSans(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repo = ref.read(routeRepositoryProvider);
    final l10n = context.l10n;

    try {
      if (widget.route == null) {
        await repo.createRoute(
          name: _nameController.text.trim(),
          sellerId: _sellerId,
          shift: _shift,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
        );
      } else {
        final updated = widget.route!.copyWith(
          name: _nameController.text.trim(),
          sellerId: _sellerId,
          shift: _shift,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
        );
        await repo.updateRoute(updated);
      }

      ref.invalidate(allRoutesProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.routeSaved)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save route: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

// ────────────────────────────────────────────────────────────
// TAB 2: STOP SEQUENCING (1..N Drag & Drop)
// ────────────────────────────────────────────────────────────
class _StopSequenceTab extends ConsumerStatefulWidget {
  final String? initialRouteId;
  final ValueChanged<String> onRouteChange;

  const _StopSequenceTab({
    this.initialRouteId,
    required this.onRouteChange,
  });

  @override
  ConsumerState<_StopSequenceTab> createState() => _StopSequenceTabState();
}

class _StopSequenceTabState extends ConsumerState<_StopSequenceTab> {
  String? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    _selectedRouteId = widget.initialRouteId;
  }

  @override
  void didUpdateWidget(covariant _StopSequenceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRouteId != null &&
        widget.initialRouteId != _selectedRouteId) {
      setState(() {
        _selectedRouteId = widget.initialRouteId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final routesAsync = ref.watch(allRoutesProvider);

    return routesAsync.when(
      data: (routes) {
        if (routes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l10n.noRoutesFound,
                style: GoogleFonts.workSans(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }

        // Auto-select first route if not set or invalid
        if (_selectedRouteId == null ||
            !routes.any((r) => r.id == _selectedRouteId)) {
          _selectedRouteId = routes.first.id;
        }

        final selectedRoute =
            routes.firstWhere((r) => r.id == _selectedRouteId);
        final customersAsync =
            ref.watch(customersByRouteProvider(_selectedRouteId!));

        return Column(
          children: [
            // Route Selector & Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppTheme.surface,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(_selectedRouteId),
                          initialValue: _selectedRouteId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.selectRoute,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: routes.map((r) {
                            return DropdownMenuItem<String>(
                              value: r.id,
                              child: Text(
                                '${r.name} (${r.shift})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedRouteId = val);
                              widget.onRouteChange(val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => _showAssignCustomerDialog(
                          context,
                          selectedRoute,
                        ),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: Text(l10n.add),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size(90, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.drag_indicator,
                        size: 16,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          l10n.dragToReorder,
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.divider),

            // Stop list
            Expanded(
              child: customersAsync.when(
                data: (customers) {
                  if (customers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.format_list_numbered,
                              size: 48,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noCustomersOnRoute,
                              style: GoogleFonts.workSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showAssignCustomerDialog(
                                context,
                                selectedRoute,
                              ),
                              icon: const Icon(Icons.person_add, size: 18),
                              label: Text(l10n.add),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                minimumSize: const Size(120, 48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: customers.length,
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) => _handleReorder(
                      customers,
                      oldIndex,
                      newIndex,
                    ),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return _StopSequenceItem(
                        key: ValueKey(customer.id),
                        customer: customer,
                        index: index,
                        onUnassign: () => _unassignCustomer(customer),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text(
                    'Error: $err',
                    style: GoogleFonts.workSans(color: AppTheme.error),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Future<void> _handleReorder(
    List<Customer> currentList,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final reorderedList = List<Customer>.from(currentList);
    final moved = reorderedList.removeAt(oldIndex);
    reorderedList.insert(newIndex, moved);

    // Call repository with 1..N order
    final customerIds = reorderedList.map((c) => c.id).toList();
    try {
      await ref
          .read(routeRepositoryProvider)
          .updateCustomerSequence(customerIds);
      ref.invalidate(customersByRouteProvider(_selectedRouteId!));
      ref.invalidate(allRoutesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.sequenceUpdated),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update sequence: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _unassignCustomer(Customer customer) async {
    try {
      await ref.read(routeRepositoryProvider).assignCustomerToRoute(
            customerId: customer.id,
            routeId: null,
            sequence: 0,
          );
      ref.invalidate(customersByRouteProvider(_selectedRouteId!));
      ref.invalidate(allRoutesProvider);
      ref.invalidate(allCustomersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unassign customer: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showAssignCustomerDialog(
    BuildContext context,
    DeliveryRoute route,
  ) {
    showDialog(
      context: context,
      builder: (_) => _AssignCustomerToRouteDialog(
        route: route,
        onCustomerAssigned: () {
          ref.invalidate(customersByRouteProvider(route.id));
          ref.invalidate(allRoutesProvider);
          ref.invalidate(allCustomersProvider);
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// STOP SEQUENCE ITEM WIDGET
// ────────────────────────────────────────────────────────────
class _StopSequenceItem extends StatelessWidget {
  final Customer customer;
  final int index;
  final VoidCallback onUnassign;

  const _StopSequenceItem({
    super.key,
    required this.customer,
    required this.index,
    required this.onUnassign,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            '#${index + 1}',
            style: GoogleFonts.workSans(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppTheme.primary,
            ),
          ),
        ),
        title: Text(
          customer.fullName ?? 'Customer',
          style: GoogleFonts.workSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${customer.totalDailyLiters.toStringAsFixed(1)} L • ${customer.milkType.toUpperCase()}',
              style: GoogleFonts.workSans(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            if (customer.location != null && customer.location!.isNotEmpty)
              Text(
                customer.location!,
                style: GoogleFonts.workSans(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.person_remove_outlined, size: 20),
              color: AppTheme.textSecondary,
              tooltip: l10n.unassigned,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: onUnassign,
            ),
            ReorderableDragStartListener(
              index: index,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.drag_handle,
                  color: AppTheme.textSecondary,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// ASSIGN CUSTOMER MODAL
// ────────────────────────────────────────────────────────────
class _AssignCustomerToRouteDialog extends ConsumerWidget {
  final DeliveryRoute route;
  final VoidCallback onCustomerAssigned;

  const _AssignCustomerToRouteDialog({
    required this.route,
    required this.onCustomerAssigned,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final allCustomersAsync = ref.watch(allCustomersProvider);

    return AlertDialog(
      title: Text(
        l10n.add,
        style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 400,
        height: 380,
        child: allCustomersAsync.when(
          data: (allCustomers) {
            // Find customers not assigned to this route
            final available = allCustomers
                .where((c) => c.routeId == null || c.routeId!.isEmpty)
                .toList();

            if (available.isEmpty) {
              return Center(
                child: Text(
                  'No unassigned customers available.',
                  style: GoogleFonts.workSans(color: AppTheme.textSecondary),
                ),
              );
            }

            return ListView.separated(
              itemCount: available.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final cust = available[idx];
                return ListTile(
                  title: Text(
                    cust.fullName ?? 'Customer',
                    style: GoogleFonts.workSans(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${cust.totalDailyLiters.toStringAsFixed(1)} L • ${cust.location ?? 'No address'}',
                    style: GoogleFonts.workSans(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.add_circle_outline,
                      color: AppTheme.primary),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      // Sequence is assigned at end of list
                      final existingRouteCustomers = await ref
                          .read(customerRepositoryProvider)
                          .getCustomersByRoute(route.id);
                      final nextSeq = existingRouteCustomers.length + 1;

                      await ref
                          .read(routeRepositoryProvider)
                          .assignCustomerToRoute(
                            customerId: cust.id,
                            routeId: route.id,
                            sequence: nextSeq,
                            shift: route.shift,
                          );

                      onCustomerAssigned();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to assign customer: $e'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    }
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.cancel,
            style: GoogleFonts.workSans(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
