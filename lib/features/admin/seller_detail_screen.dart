import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/seller.dart';
import '../../providers/billing_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/seller_provider.dart';

class SellerDetailScreen extends ConsumerWidget {
  final String sellerId;

  const SellerDetailScreen({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerAsync = ref.watch(sellerByIdProvider(sellerId));
    final customersAsync = ref.watch(customersBySellerProvider(sellerId));
    final billsAsync = ref.watch(sellerBillsProvider(sellerId));
    final collectionsAsync = ref.watch(sellerCollectionsProvider(sellerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller Info
            sellerAsync.when(
              data: (seller) {
                if (seller == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Seller not found'),
                  );
                }
                return _SellerInfoSection(seller: seller);
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
              error: (error, st) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: $error'),
              ),
            ),
            const Divider(height: 32),

            // Customers assigned to this seller
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Assigned Customers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            customersAsync.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No customers assigned'),
                  );
                }
                return _CustomersList(customers: customers);
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
              error: (error, st) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: $error'),
              ),
            ),
            const Divider(height: 32),

            // Collections Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Collections & Bills Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            billsAsync.when(
              data: (bills) {
                if (bills.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No bills found'),
                  );
                }
                return _BillsSummary(bills: bills);
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
              error: (error, st) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: $error'),
              ),
            ),
            const Divider(height: 32),

            // Recent Collections
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Recent Collections',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            collectionsAsync.when(
              data: (collections) {
                if (collections.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No collections recorded'),
                  );
                }
                return _CollectionsList(collections: collections);
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
              error: (error, st) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: $error'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SellerInfoSection extends StatelessWidget {
  final Seller seller;

  const _SellerInfoSection({required this.seller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and name
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  (seller.fullName?.substring(0, 1) ?? 'S').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.fullName ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Seller',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Info tiles
          _InfoTile(
            icon: Icons.location_on,
            label: 'Route',
            value: seller.routeName,
          ),
          if (seller.location != null)
            _InfoTile(
              icon: Icons.map,
              label: 'Location',
              value: seller.location!,
            ),
          _InfoTile(
            icon: Icons.phone,
            label: 'Phone',
            value: seller.phone ?? 'N/A',
          ),
          _InfoTile(
            icon: Icons.local_drink,
            label: 'Assigned Milk',
            value: '${seller.assignedMilkLiters}L / ${seller.assignedMilkMl}ml',
          ),
          _InfoTile(
            icon: Icons.check_circle,
            label: 'Status',
            value: seller.status,
            valueColor: seller.status == 'active' ? Colors.green : Colors.orange,
          ),
          if (seller.createdAt != null)
            _InfoTile(
              icon: Icons.calendar_today,
              label: 'Joined',
              value: DateFormat('MMM d, y').format(seller.createdAt!),
            ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomersList extends StatelessWidget {
  final List customers;

  const _CustomersList({required this.customers});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: List.generate(customers.length, (index) {
          final customer = customers[index];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Text(
                  (customer.fullName?.substring(0, 1) ?? 'C').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(customer.fullName ?? 'Unknown'),
              subtitle: Text(
                '${customer.milkType ?? 'cow'} - ${customer.dailyQuantityLiters}L/day',
              ),
              trailing: Text(
                '₹${customer.ratePerLiter}/L',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BillsSummary extends StatelessWidget {
  final List bills;

  const _BillsSummary({required this.bills});

  @override
  Widget build(BuildContext context) {
    double totalAmount = 0;
    double paidAmount = 0;
    double pendingAmount = 0;
    int billCount = 0;

    for (var bill in bills) {
      totalAmount += bill.totalAmount.toDouble();
      paidAmount += bill.paidAmount.toDouble();
      pendingAmount += bill.pendingAmount.toDouble();
      billCount++;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _SummaryCard(
            label: 'Total Billable',
            amount: totalAmount,
            color: Colors.blue,
          ),
          _SummaryCard(
            label: 'Amount Collected',
            amount: paidAmount,
            color: Colors.green,
          ),
          _SummaryCard(
            label: 'Pending Amount',
            amount: pendingAmount,
            color: Colors.orange,
          ),
          _SummaryCard(
            label: 'Total Bills',
            amount: billCount.toDouble(),
            color: Colors.purple,
            isCount: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isCount;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    this.isCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            isCount ? amount.toStringAsFixed(0) : '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionsList extends StatelessWidget {
  final List collections;

  const _CollectionsList({required this.collections});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: List.generate(
          collections.length > 10 ? 10 : collections.length,
          (index) {
            final collection = collections[index];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  child: const Icon(Icons.currency_rupee, color: Colors.amber),
                ),
                title: Text('₹${collection.amountCollected}'),
                subtitle: Text(
                  collection.customerName ?? 'Unknown Customer',
                ),
                trailing: Text(
                  DateFormat('MMM d').format(collection.collectionDate),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
