import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_pause.dart';

class PauseRepository {
  final SupabaseClient _client;

  PauseRepository(this._client);

  /// Create a customer pause request. Always defaults to status 'pending'.
  Future<DeliveryPause> createPauseRequest({
    required String customerId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

    if (startDay.isBefore(today)) {
      throw ArgumentError('प्रारंभ तिथि आज या भविष्य की होनी चाहिए (Start date must be today or future)');
    }

    if (endDay.isBefore(startDay)) {
      throw ArgumentError('समाप्ति तिथि प्रारंभ तिथि से पहले नहीं हो सकती (End date cannot be earlier than start date)');
    }

    final data = await _client
        .from('delivery_pauses')
        .insert({
          'customer_id': customerId,
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
          'status': 'pending',
          'reason': reason?.trim(),
          'created_by': _client.auth.currentUser?.id,
        })
        .select('*, customers!delivery_pauses_customer_id_fkey(profiles!customers_user_id_fkey(full_name, phone))')
        .single();

    return DeliveryPause.fromJson(data);
  }

  /// Fetch all pending pauses for customers belonging to a specific seller.
  Future<List<DeliveryPause>> getPendingPausesForSeller(String sellerId) async {
    final data = await _client
        .from('delivery_pauses')
        .select('*, customers!inner(seller_id, profiles!customers_user_id_fkey(full_name, phone))')
        .eq('status', 'pending')
        .eq('customers.seller_id', sellerId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => DeliveryPause.fromJson(e)).toList();
  }

  /// Fetch all pending pauses across all sellers (admin or owner view).
  Future<List<DeliveryPause>> getAllPendingPauses() async {
    final data = await _client
        .from('delivery_pauses')
        .select('*, customers(seller_id, profiles!customers_user_id_fkey(full_name, phone))')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (data as List).map((e) => DeliveryPause.fromJson(e)).toList();
  }

  /// Fetch pause history and active requests for a specific customer.
  Future<List<DeliveryPause>> getPausesForCustomer(String customerId) async {
    final data = await _client
        .from('delivery_pauses')
        .select('*, customers(profiles!customers_user_id_fkey(full_name, phone))')
        .eq('customer_id', customerId)
        .order('start_date', ascending: false);

    return (data as List).map((e) => DeliveryPause.fromJson(e)).toList();
  }

  /// Approve a pending pause request (seller/admin guardrail).
  /// Strictly requires previous status to be 'pending'.
  Future<void> approvePause(String pauseId) async {
    await _client.from('delivery_pauses').update({
      'status': 'approved',
      'reviewed_by': _client.auth.currentUser?.id,
      'reviewed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', pauseId).eq('status', 'pending');
  }

  /// Reject a pending pause request.
  /// Strictly requires previous status to be 'pending'.
  Future<void> rejectPause(String pauseId) async {
    await _client.from('delivery_pauses').update({
      'status': 'rejected',
      'reviewed_by': _client.auth.currentUser?.id,
      'reviewed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', pauseId).eq('status', 'pending');
  }

  /// Cancel a pending pause request (by customer).
  /// Strictly requires previous status to be 'pending'.
  Future<void> cancelPause(String pauseId) async {
    await _client.from('delivery_pauses').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', pauseId).eq('status', 'pending');
  }

  /// Check if a specific customer has an approved pause on a given date.
  Future<bool> isCustomerPausedOnDate(String customerId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final data = await _client
        .from('delivery_pauses')
        .select('id')
        .eq('customer_id', customerId)
        .eq('status', 'approved')
        .lte('start_date', dateStr)
        .gte('end_date', dateStr)
        .limit(1);

    return (data as List).isNotEmpty;
  }

  /// Get set of all customer IDs with an approved pause on a given date.
  Future<Set<String>> getPausedCustomerIdsForDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final data = await _client
        .from('delivery_pauses')
        .select('customer_id')
        .eq('status', 'approved')
        .lte('start_date', dateStr)
        .gte('end_date', dateStr);

    final Set<String> ids = {};
    for (final row in (data as List)) {
      final cid = row['customer_id'] as String?;
      if (cid != null && cid.isNotEmpty) {
        ids.add(cid);
      }
    }
    return ids;
  }
}
