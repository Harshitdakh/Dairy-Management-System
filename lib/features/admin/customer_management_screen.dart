import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../providers/customer_provider.dart';
import '../../providers/seller_provider.dart';

class CustomerManagementScreen extends ConsumerWidget {
  const CustomerManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(allCustomersProvider);
    final sellersAsync = ref.watch(allSellersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allCustomersProvider);
            ref.invalidate(allSellersProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Customer Management',
                        style: GoogleFonts.workSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.push('/admin/add-customer'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                customersAsync.when(
                  data: (customers) {
                    if (customers.isEmpty) {
                      return _emptyState('No customers found');
                    }

                    final sellerMap = {
                      for (final s in sellersAsync.valueOrNull ?? []) s.id: s
                    };

                    return Column(
                      children: customers
                          .map(
                            (customer) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer.fullName ?? 'Customer',
                                              style: GoogleFonts.workSans(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Milk: ${customer.milkType.toUpperCase()}  Rate: Rs ${customer.ratePerLiter}/L',
                                              style: GoogleFonts.workSans(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteCustomer(
                                            context, ref, customer.id),
                                        icon: const Icon(Icons.delete_outline),
                                        color: AppTheme.error,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => context.push(
                                            '/admin/customer-detail?customerId=${customer.id}',
                                          ),
                                          icon: const Icon(Icons.visibility_outlined),
                                          label: const Text('View Details'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        onPressed: () => context.push(
                                          '/admin/edit-customer?customerId=${customer.id}',
                                        ),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Edit'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Text(
                                        customer.status.toUpperCase(),
                                        style: GoogleFonts.workSans(
                                          fontWeight: FontWeight.w700,
                                          color: customer.status == 'active'
                                              ? AppTheme.success
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () => _deleteCustomer(
                                            context, ref, customer.id),
                                        icon: const Icon(Icons.delete_outline),
                                        color: AppTheme.error,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    initialValue: customer.sellerId,
                                    decoration: const InputDecoration(
                                      hintText: 'Assign seller',
                                    ),
                                    items: (sellersAsync.valueOrNull ?? [])
                                        .map(
                                          (seller) => DropdownMenuItem(
                                            value: seller.id,
                                            child: Text(
                                              '${seller.fullName ?? 'Seller'} (${seller.routeName})',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (sellerId) async {
                                      if (sellerId == null) return;
                                      await ref
                                          .read(customerRepositoryProvider)
                                          .updateCustomer(customer.id, {
                                        'seller_id': sellerId,
                                        'route_name':
                                            sellerMap[sellerId]?.routeName,
                                      });
                                      ref.invalidate(allCustomersProvider);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCustomer(
      BuildContext context, WidgetRef ref, String customerId) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete customer?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    await ref.read(customerRepositoryProvider).deleteCustomer(customerId);
    ref.invalidate(allCustomersProvider);
  }

  Widget _emptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.workSans(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
