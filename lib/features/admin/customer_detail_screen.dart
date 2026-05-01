import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/customer.dart';
import '../../providers/billing_provider.dart';
import '../../providers/customer_provider.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerByIdProvider(customerId));
    final billsAsync = ref.watch(customerBillsProvider(customerId));
    final collectionsAsync = ref.watch(customerCollectionsProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Info
            customerAsync.when(
              data: (customer) {
                if (customer == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Customer not found'),
                  );
                }
                return _CustomerInfoSection(customer: customer);
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

            // Milk Consumption Info
            customerAsync.when(
              data: (customer) {
                if (customer == null) return const SizedBox.shrink();
                return _MilkConsumptionSection(customer: customer);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const Divider(height: 32),

            // Bills Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Billing Summary',
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
                return _BillingHistory(bills: bills);
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

            // Payment History
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Payment History',
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
                    child: Text('No payments recorded'),
                  );
                }
                return _PaymentHistory(payments: collections);
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

class _CustomerInfoSection extends StatelessWidget {
  final Customer customer;

  const _CustomerInfoSection({required this.customer});

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
                backgroundColor: Colors.green.shade100,
                child: Text(
                  (customer.fullName?.substring(0, 1) ?? 'C').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Customer',
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
            icon: Icons.person,
            label: 'Assigned Seller',
            value: customer.sellerName ?? 'Not assigned',
          ),
          _InfoTile(
            icon: Icons.phone,
            label: 'Phone',
            value: customer.phone ?? 'N/A',
          ),
          if (customer.location != null)
            _InfoTile(
              icon: Icons.location_on,
              label: 'Location',
              value: customer.location!,
            ),
          _InfoTile(
            icon: Icons.check_circle,
            label: 'Status',
            value: customer.status,
            valueColor: customer.status == 'active' ? Colors.green : Colors.orange,
          ),
          if (customer.createdAt != null)
            _InfoTile(
              icon: Icons.calendar_today,
              label: 'Joined',
              value: DateFormat('MMM d, y').format(customer.createdAt!),
            ),
        ],
      ),
    );
  }
}

class _MilkConsumptionSection extends StatelessWidget {
  final Customer customer;

  const _MilkConsumptionSection({required this.customer});

  @override
  Widget build(BuildContext context) {
    final monthlyQuantity = customer.dailyQuantityLiters * 30;
    final monthlyAmount = monthlyQuantity * customer.ratePerLiter;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Milk Consumption',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.local_drink,
            label: 'Milk Type',
            value: customer.milkType,
          ),
          _InfoTile(
            icon: Icons.format_list_numbered,
            label: 'Daily Quantity',
            value: '${customer.dailyQuantityLiters}L',
          ),
          _InfoTile(
            icon: Icons.trending_up,
            label: 'Monthly Quantity',
            value: '${monthlyQuantity.toStringAsFixed(1)}L',
          ),
          _InfoTile(
            icon: Icons.currency_rupee,
            label: 'Rate per Liter',
            value: '₹${customer.ratePerLiter}',
          ),
          _InfoTile(
            icon: Icons.calendar_month,
            label: 'Expected Monthly Bill',
            value: '₹${monthlyAmount.toStringAsFixed(2)}',
            valueColor: Colors.blue,
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

class _BillingHistory extends StatelessWidget {
  final List bills;

  const _BillingHistory({required this.bills});

  @override
  Widget build(BuildContext context) {
    double totalAmount = 0;
    double paidAmount = 0;
    double pendingAmount = 0;

    for (var bill in bills) {
      totalAmount += bill.totalAmount.toDouble();
      paidAmount += bill.paidAmount.toDouble();
      pendingAmount += bill.pendingAmount.toDouble();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _SummaryCard(
            label: 'Total Billed',
            amount: totalAmount,
            color: Colors.blue,
          ),
          _SummaryCard(
            label: 'Amount Paid',
            amount: paidAmount,
            color: Colors.green,
          ),
          _SummaryCard(
            label: 'Amount Pending',
            amount: pendingAmount,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            'Recent Bills',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            bills.length > 5 ? 5 : bills.length,
            (index) {
              final bill = bills[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(bill.status).withValues(alpha: 0.2),
                    child: Icon(
                      _getStatusIcon(bill.status),
                      color: _getStatusColor(bill.status),
                    ),
                  ),
                  title: Text(
                    DateFormat('MMMM y').format(bill.billMonth),
                  ),
                  subtitle: Text(bill.status.toUpperCase()),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${bill.totalAmount}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Pending: ₹${bill.pendingAmount}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'partial':
        return Icons.schedule;
      default:
        return Icons.pending;
    }
  }
}

class _PaymentHistory extends StatelessWidget {
  final List payments;

  const _PaymentHistory({required this.payments});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: List.generate(
          payments.length > 10 ? 10 : payments.length,
          (index) {
            final payment = payments[index];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.check, color: Colors.green),
                ),
                title: Text('₹${payment.amountCollected}'),
                subtitle: Text(
                  DateFormat('MMM d, y').format(payment.collectionDate),
                ),
                trailing: Text(
                  'Bill Month: ${DateFormat('MMM y').format(payment.billMonth)}',
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
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
            '₹${amount.toStringAsFixed(2)}',
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
