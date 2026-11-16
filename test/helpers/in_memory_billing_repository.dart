import 'package:milk_hub/models/collection_entry.dart';
import 'package:milk_hub/models/customer_bill.dart';
import 'package:milk_hub/models/milk_delivery.dart';
import 'package:milk_hub/services/billing_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'in_memory_dairy_data_store.dart';

final _dummyClient = SupabaseClient(
  'https://placeholder.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
);

class InMemoryBillingRepository extends BillingRepository {
  final InMemoryDairyDataStore dataStore;

  InMemoryBillingRepository(this.dataStore, [SupabaseClient? client])
      : super(client ?? _dummyClient);

  @override
  Future<List<CustomerBill>> getBills({
    String? sellerId,
    String? customerId,
    DateTime? month,
    String? status,
  }) async {
    final list = dataStore.bills.values.where((b) {
      if (sellerId != null && b.sellerId != sellerId) return false;
      if (customerId != null && b.customerId != customerId) return false;
      if (month != null) {
        if (b.billMonth.year != month.year || b.billMonth.month != month.month) {
          return false;
        }
      }
      if (status != null && status.isNotEmpty && status != 'all' && b.status != status) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) => b.billMonth.compareTo(a.billMonth));
    return list;
  }

  @override
  Future<Map<String, double>> getCollectionSummary({
    String? sellerId,
    String? customerId,
    DateTime? month,
  }) async {
    final bills = await getBills(
      sellerId: sellerId,
      customerId: customerId,
      month: month,
    );

    double total = 0;
    double paid = 0;
    double pending = 0;

    for (final bill in bills) {
      total += bill.totalAmount.toDouble();
      paid += bill.paidAmount.toDouble();
      pending += bill.pendingAmount.toDouble();
    }

    return {
      'total': total,
      'paid': paid,
      'pending': pending,
    };
  }

  @override
  Future<List<CollectionEntry>> getCollections({
    String? sellerId,
    String? customerId,
    DateTime? month,
  }) async {
    final list = dataStore.collections.where((c) {
      if (sellerId != null && c.sellerId != sellerId) return false;
      if (customerId != null && c.customerId != customerId) return false;
      if (month != null) {
        if (c.billMonth.year != month.year || c.billMonth.month != month.month) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) => b.paidOn.compareTo(a.paidOn));
    return list;
  }

  @override
  Future<void> recordCollection({
    required String customerId,
    required String sellerId,
    required num amountPaid,
    required DateTime billMonth,
    String paymentMode = 'cash',
    String? notes,
  }) async {
    if (amountPaid < 0 || amountPaid.isNegative) {
      throw ArgumentError('Payment amount cannot be negative');
    }
    if (amountPaid == 0) {
      throw ArgumentError('Payment amount must be greater than zero');
    }

    final normalizedMonth = DateTime(billMonth.year, billMonth.month, 1);
    final cust = dataStore.customers[customerId];

    final collection = CollectionEntry(
      id: 'coll-${DateTime.now().microsecondsSinceEpoch}',
      customerId: customerId,
      sellerId: sellerId,
      billMonth: normalizedMonth,
      amountPaid: amountPaid,
      paidOn: DateTime.now(),
      paymentMode: paymentMode,
      notes: notes,
      createdAt: DateTime.now(),
      customerName: cust?.fullName ?? 'Customer',
    );
    dataStore.collections.add(collection);

    // Update customer bill
    final bill = dataStore.getBill(customerId, normalizedMonth);
    if (bill != null) {
      final totalAmount = bill.totalAmount;
      final currentPaid = bill.paidAmount;
      final updatedPaid = currentPaid + amountPaid;
      final cappedPaid = updatedPaid > totalAmount ? totalAmount : updatedPaid;
      final pendingAmount = totalAmount - cappedPaid;
      final status = pendingAmount <= 0
          ? 'paid'
          : cappedPaid > 0
              ? 'partial'
              : 'pending';

      final updatedBill = CustomerBill(
        id: bill.id,
        customerId: bill.customerId,
        sellerId: bill.sellerId,
        billMonth: bill.billMonth,
        totalQuantityLiters: bill.totalQuantityLiters,
        totalAmount: totalAmount,
        paidAmount: cappedPaid,
        pendingAmount: pendingAmount < 0 ? 0 : pendingAmount,
        status: status,
        updatedAt: DateTime.now(),
        customerName: bill.customerName,
        sellerName: bill.sellerName,
      );

      dataStore.upsertBill(updatedBill);
    }
  }

  @override
  Future<void> recordSkippedDelivery({
    required String customerId,
    required String sellerId,
    required String milkType,
    DateTime? date,
    String shift = 'morning',
    String? notes,
  }) async {
    final cust = dataStore.customers[customerId];
    final delivery = MilkDelivery(
      id: 'del-${DateTime.now().microsecondsSinceEpoch}',
      sellerId: sellerId,
      customerId: customerId,
      deliveryDate: date ?? DateTime.now(),
      milkType: milkType,
      quantityLiters: 0,
      quantityMl: 0,
      rate: 0,
      amount: 0,
      status: 'skipped',
      shift: shift,
      notes: notes,
      createdAt: DateTime.now(),
      customerName: cust?.fullName,
      customerPhone: cust?.phone,
    );
    dataStore.deliveries.add(delivery);
  }

  /// Helper to record delivery and recalculate monthly bill
  Future<void> recordDelivery({
    required String customerId,
    required String sellerId,
    required String milkType,
    required num quantityLiters,
    required num quantityMl,
    required num rate,
    DateTime? date,
    String shift = 'morning',
    String status = 'delivered',
    String? notes,
  }) async {
    if (quantityLiters < 0 || quantityMl < 0) {
      throw ArgumentError('Volume cannot be negative');
    }
    if (status == 'delivered' && quantityLiters == 0 && quantityMl == 0) {
      throw ArgumentError('Quantity must be greater than 0 for delivered status');
    }

    final dDate = date ?? DateTime.now();
    final queryDate = DateTime(dDate.year, dDate.month, dDate.day);

    if (status == 'delivered') {
      for (final p in dataStore.pauses.values) {
        if (p.customerId == customerId && p.status == 'approved') {
          final pStart = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
          final pEnd = DateTime(p.endDate.year, p.endDate.month, p.endDate.day);
          if (!queryDate.isBefore(pStart) && !queryDate.isAfter(pEnd)) {
            throw StateError('Customer delivery is paused on this date due to approved vacation');
          }
        }
      }
    }

    // Debouncing / Idempotency guard: prevent duplicate rapid delivery for same customer, date, and shift
    final isDuplicate = dataStore.deliveries.any((d) =>
        d.customerId == customerId &&
        d.shift == shift &&
        d.deliveryDate.year == dDate.year &&
        d.deliveryDate.month == dDate.month &&
        d.deliveryDate.day == dDate.day);
    if (isDuplicate) {
      return;
    }

    final cust = dataStore.customers[customerId];
    final totalLiters = quantityLiters.toDouble() + (quantityMl.toDouble() / 1000);
    final amount = status == 'skipped' ? 0.0 : totalLiters * rate.toDouble();

    final delivery = MilkDelivery(
      id: 'del-${DateTime.now().microsecondsSinceEpoch}',
      sellerId: sellerId,
      customerId: customerId,
      deliveryDate: dDate,
      milkType: milkType,
      quantityLiters: status == 'skipped' ? 0 : quantityLiters,
      quantityMl: status == 'skipped' ? 0 : quantityMl,
      rate: status == 'skipped' ? 0 : rate,
      amount: amount,
      status: status,
      shift: shift,
      notes: notes,
      createdAt: DateTime.now(),
      customerName: cust?.fullName,
      customerPhone: cust?.phone,
    );
    dataStore.deliveries.add(delivery);

    // Rollup into customer bill
    final normalizedMonth = DateTime(dDate.year, dDate.month, 1);
    final existingBill = dataStore.getBill(customerId, normalizedMonth);

    if (existingBill != null) {
      final newTotalLiters = existingBill.totalQuantityLiters + (status == 'skipped' ? 0 : totalLiters);
      final newTotalAmount = existingBill.totalAmount + amount;
      final pending = newTotalAmount - existingBill.paidAmount;
      final newStatus = pending <= 0
          ? 'paid'
          : existingBill.paidAmount > 0
              ? 'partial'
              : 'pending';

      final updatedBill = CustomerBill(
        id: existingBill.id,
        customerId: customerId,
        sellerId: sellerId,
        billMonth: normalizedMonth,
        totalQuantityLiters: newTotalLiters,
        totalAmount: newTotalAmount,
        paidAmount: existingBill.paidAmount,
        pendingAmount: pending < 0 ? 0 : pending,
        status: newStatus,
        updatedAt: DateTime.now(),
        customerName: cust?.fullName ?? existingBill.customerName,
        sellerName: existingBill.sellerName,
      );
      dataStore.upsertBill(updatedBill);
    } else {
      final newBill = CustomerBill(
        id: 'bill-${DateTime.now().microsecondsSinceEpoch}',
        customerId: customerId,
        sellerId: sellerId,
        billMonth: normalizedMonth,
        totalQuantityLiters: status == 'skipped' ? 0 : totalLiters,
        totalAmount: amount,
        paidAmount: 0,
        pendingAmount: amount,
        status: 'pending',
        updatedAt: DateTime.now(),
        customerName: cust?.fullName,
      );
      dataStore.upsertBill(newBill);
    }
  }

  @override
  Future<List<MilkDelivery>> getDeliveries({
    String? sellerId,
    String? customerId,
    DateTime? month,
    String? shift,
    DateTime? date,
  }) async {
    final list = dataStore.deliveries.where((d) {
      if (sellerId != null && d.sellerId != sellerId) return false;
      if (customerId != null && d.customerId != customerId) return false;
      if (shift != null && shift.isNotEmpty && d.shift != shift) return false;
      if (month != null) {
        if (d.deliveryDate.year != month.year || d.deliveryDate.month != month.month) {
          return false;
        }
      }
      if (date != null) {
        if (d.deliveryDate.year != date.year ||
            d.deliveryDate.month != date.month ||
            d.deliveryDate.day != date.day) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));
    return list;
  }
}
