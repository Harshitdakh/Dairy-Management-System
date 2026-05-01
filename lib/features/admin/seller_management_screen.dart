import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/seller_provider.dart';
import '../../core/milk_utils.dart';

class SellerManagementScreen extends ConsumerWidget {
  const SellerManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellersAsync = ref.watch(allSellersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(allSellersProvider),
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
                      child: Text(
                        'Seller Management',
                        style: GoogleFonts.workSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.push('/admin/add-seller'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                sellersAsync.when(
                  data: (sellers) {
                    if (sellers.isEmpty) {
                      return _emptyState();
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sellers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final seller = sellers[index];
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
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppTheme.primaryLight,
                                    child: Text(
                                      (seller.fullName ?? 'S')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: GoogleFonts.workSans(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                        fontSize: 18,
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
                                          seller.fullName ?? 'Seller',
                                          style: GoogleFonts.workSans(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.route,
                                              size: 14,
                                              color: AppTheme.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              seller.routeName,
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (seller.status == 'active'
                                              ? AppTheme.success
                                              : AppTheme.textMuted)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      seller.status == 'active'
                                          ? 'Active'
                                          : 'Inactive',
                                      style: GoogleFonts.workSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: seller.status == 'active'
                                            ? AppTheme.success
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(
                                  height: 1, color: AppTheme.divider),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _milkStat(
                                    'Assigned',
                                    MilkUtils.formatQuantity(
                                      seller.assignedMilkLiters,
                                      seller.assignedMilkMl,
                                    ),
                                    AppTheme.primary,
                                  ),
                                  _milkStat(
                                    'Sold',
                                    '0 L',
                                    AppTheme.success,
                                  ),
                                  _milkStat(
                                    'Remaining',
                                    MilkUtils.formatQuantity(
                                      seller.assignedMilkLiters,
                                      seller.assignedMilkMl,
                                    ),
                                    AppTheme.amber,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => context.push(
                                        '/admin/seller-detail?sellerId=${seller.id}',
                                      ),
                                      icon: const Icon(Icons.visibility_outlined),
                                      label: const Text('View Details'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: () => context.push(
                                      '/admin/edit-seller?sellerId=${seller.id}',
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await ref
                                          .read(sellerRepositoryProvider)
                                          .updateSeller(seller.id, {
                                        'status': seller.status == 'active'
                                            ? 'inactive'
                                            : 'active',
                                      });
                                      ref.invalidate(allSellersProvider);
                                    },
                                    icon: Icon(
                                      seller.status == 'active'
                                          ? Icons.pause_circle_outline
                                          : Icons.play_circle_outline,
                                      size: 18,
                                    ),
                                    label: Text(
                                      seller.status == 'active'
                                          ? 'Deactivate'
                                          : 'Activate',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete seller?'),
                                              content: const Text(
                                                'This action cannot be undone.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          ) ??
                                          false;
                                      if (!confirm) return;
                                      await ref
                                          .read(sellerRepositoryProvider)
                                          .deleteSeller(seller.id);
                                      ref.invalidate(allSellersProvider);
                                      ref.invalidate(sellerCountProvider);
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppTheme.error,
                                    ),
                                    label: const Text(
                                      'Delete',
                                      style: TextStyle(color: AppTheme.error),
                                    ),
                                  ),
                                ],
                              ),
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
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _milkStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.workSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.workSans(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.storefront, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'No sellers yet',
              style: GoogleFonts.workSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add your first seller to get started',
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
}
