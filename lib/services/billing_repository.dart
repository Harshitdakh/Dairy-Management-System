import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/collection_entry.dart';
import '../models/customer_bill.dart';
import '../models/milk_delivery.dart';

class BillingRepository {
  final SupabaseClient _client;

  BillingRepository(this._client);

  Future<List<CustomerBill>> getBills({
    String? sellerId,
    String? customerId,
    DateTime? month,
    String? status,
  }) async {
    var query = _client.from('customer_bills').select(
          '*, customers!customer_bills_customer_id_fkey(profiles(full_name)), sellers!customer_bills_seller_id_fkey(profiles(full_name))',
        );

    if (sellerId != null) {
      query = query.eq('seller_id', sellerId);
    }
    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }
    if (month != null) {
      final monthStart = DateTime(month.year, month.month, 1)
          .toIso8601String()
          .split('T')[0];
      query = query.eq('bill_month', monthStart);
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      query = query.eq('status', status);
    }

    final data = await query.order('bill_month', ascending: false);
    return (data as List).map((e) => CustomerBill.fromJson(e)).toList();
  }

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

  Future<List<CollectionEntry>> getCollections({
    String? sellerId,
    String? customerId,
    DateTime? month,
  }) async {
    var query = _client.from('collections').select(
          '*, customers!collections_customer_id_fkey(profiles(full_name))',
        );

    if (sellerId != null) {
      query = query.eq('seller_id', sellerId);
    }
    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }
    if (month != null) {
      final monthStart = DateTime(month.year, month.month, 1)
          .toIso8601String()
          .split('T')[0];
      query = query.eq('bill_month', monthStart);
    }

    final data = await query.order('paid_on', ascending: false);
    return (data as List).map((e) => CollectionEntry.fromJson(e)).toList();
  }

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

    final normalizedMonth = DateTime(billMonth.year, billMonth.month, 1)
        .toIso8601String()
        .split('T')[0];

    await _client.from('collections').insert({
      'customer_id': customerId,
      'seller_id': sellerId,
      'amount_paid': amountPaid,
      'bill_month': normalizedMonth,
      'paid_on': DateTime.now().toIso8601String().split('T')[0],
      'payment_mode': paymentMode,
      'notes': notes,
      'created_by': _client.auth.currentUser?.id,
    });

    final bill = await _client
        .from('customer_bills')
        .select('id,total_amount,paid_amount,pending_amount,status')
        .eq('customer_id', customerId)
        .eq('seller_id', sellerId)
        .eq('bill_month', normalizedMonth)
        .maybeSingle();

    if (bill == null) return;

    final totalAmount = (bill['total_amount'] ?? 0) as num;
    final currentPaid = (bill['paid_amount'] ?? 0) as num;
    final updatedPaid = currentPaid + amountPaid;
    final cappedPaid = updatedPaid > totalAmount ? totalAmount : updatedPaid;
    final pendingAmount = totalAmount - cappedPaid;
    final status = pendingAmount <= 0
        ? 'paid'
        : cappedPaid > 0
            ? 'partial'
            : 'pending';

    await _client.from('customer_bills').update({
      'paid_amount': cappedPaid,
      'pending_amount': pendingAmount < 0 ? 0 : pendingAmount,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bill['id']);
  }

  Future<void> recordSkippedDelivery({
    required String customerId,
    required String sellerId,
    required String milkType,
    DateTime? date,
    String shift = 'morning',
    String? notes,
  }) async {
    await _client.from('milk_deliveries').insert({
      'customer_id': customerId,
      'seller_id': sellerId,
      'delivery_date': (date ?? DateTime.now()).toIso8601String().split('T')[0],
      'milk_type': milkType,
      'quantity_liters': 0,
      'quantity_ml': 0,
      'rate': 0,
      'amount': 0,
      'status': 'skipped',
      'shift': shift,
      'notes': notes,
    });
  }

  Future<List<MilkDelivery>> getDeliveries({
    String? sellerId,
    String? customerId,
    DateTime? month,
    String? shift,
  }) async {
    var query = _client.from('milk_deliveries').select(
          '*, customers!milk_deliveries_customer_id_fkey(profiles!customers_user_id_fkey(full_name, phone)), sellers(profiles(full_name))',
        );

    if (sellerId != null) {
      query = query.eq('seller_id', sellerId);
    }
    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }
    if (shift != null && shift.isNotEmpty) {
      query = query.eq('shift', shift);
    }
    if (month != null) {
      final monthStart = DateTime(month.year, month.month, 1)
          .toIso8601String()
          .split('T')[0];
      final nextMonth = DateTime(month.year, month.month + 1, 1)
          .toIso8601String()
          .split('T')[0];
      query = query.gte('delivery_date', monthStart).lt('delivery_date', nextMonth);
    }

    final data = await query.order('delivery_date', ascending: false);
    return (data as List).map((e) => MilkDelivery.fromJson(e)).toList();
  }
}
