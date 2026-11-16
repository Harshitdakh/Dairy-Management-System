import 'package:milk_hub/models/delivery_pause.dart';
import 'package:milk_hub/services/pause_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'in_memory_dairy_data_store.dart';

final _dummyClient = SupabaseClient(
  'https://placeholder.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
);

class InMemoryPauseRepository extends PauseRepository {
  final InMemoryDairyDataStore dataStore;

  InMemoryPauseRepository(this.dataStore, [SupabaseClient? client])
      : super(client ?? _dummyClient);

  @override
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

    // Overlap check
    final existingPauses = dataStore.pauses.values.where(
      (p) => p.customerId == customerId && (p.status == 'approved' || p.status == 'pending'),
    );

    for (final p in existingPauses) {
      final pStart = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
      final pEnd = DateTime(p.endDate.year, p.endDate.month, p.endDate.day);

      final overlaps = !(endDay.isBefore(pStart) || startDay.isAfter(pEnd));
      if (overlaps) {
        throw ArgumentError('इस अवधि के लिए पहले से अवकाश अनुरोध मौजूद है (Pause request overlaps with existing)');
      }
    }

    final newId = 'pause-${DateTime.now().microsecondsSinceEpoch}';
    final cust = dataStore.customers[customerId];

    final pause = DeliveryPause(
      id: newId,
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
      status: 'pending',
      reason: reason?.trim(),
      customerName: cust?.fullName ?? 'Unknown Customer',
      customerPhone: cust?.phone ?? '',
      createdAt: DateTime.now(),
    );

    dataStore.pauses[newId] = pause;
    return pause;
  }

  @override
  Future<List<DeliveryPause>> getPendingPausesForSeller(String sellerId) async {
    final list = dataStore.pauses.values.where((p) {
      if (p.status != 'pending') return false;
      final cust = dataStore.customers[p.customerId];
      return cust != null && cust.sellerId == sellerId;
    }).toList();

    list.sort((a, b) => b.createdAt?.compareTo(a.createdAt ?? DateTime.now()) ?? 0);
    return list;
  }

  @override
  Future<List<DeliveryPause>> getAllPendingPauses() async {
    final list = dataStore.pauses.values
        .where((p) => p.status == 'pending')
        .toList();
    list.sort((a, b) => b.createdAt?.compareTo(a.createdAt ?? DateTime.now()) ?? 0);
    return list;
  }

  @override
  Future<List<DeliveryPause>> getPausesForCustomer(String customerId) async {
    final list = dataStore.pauses.values
        .where((p) => p.customerId == customerId)
        .toList();
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  @override
  Future<void> approvePause(String pauseId) async {
    final p = dataStore.pauses[pauseId];
    if (p != null) {
      if (p.status != 'pending') {
        throw StateError(
            'Cannot approve pause with status "${p.status}". Status must be "pending".');
      }
      dataStore.pauses[pauseId] = p.copyWith(
        status: 'approved',
        reviewedBy: 'seller-reviewer',
        reviewedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> rejectPause(String pauseId) async {
    final p = dataStore.pauses[pauseId];
    if (p != null) {
      if (p.status != 'pending') {
        throw StateError(
            'Cannot reject pause with status "${p.status}". Status must be "pending".');
      }
      dataStore.pauses[pauseId] = p.copyWith(
        status: 'rejected',
        reviewedBy: 'seller-reviewer',
        reviewedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> cancelPause(String pauseId) async {
    final p = dataStore.pauses[pauseId];
    if (p != null) {
      if (p.status != 'pending') {
        throw StateError(
            'Cannot cancel pause with status "${p.status}". Status must be "pending".');
      }
      dataStore.pauses[pauseId] = p.copyWith(
        status: 'cancelled',
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<bool> isCustomerPausedOnDate(String customerId, DateTime date) async {
    final queryDate = DateTime(date.year, date.month, date.day);

    for (final p in dataStore.pauses.values) {
      if (p.customerId == customerId && p.status == 'approved') {
        final pStart = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        final pEnd = DateTime(p.endDate.year, p.endDate.month, p.endDate.day);
        if (!queryDate.isBefore(pStart) && !queryDate.isAfter(pEnd)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<Set<String>> getPausedCustomerIdsForDate(DateTime date) async {
    final queryDate = DateTime(date.year, date.month, date.day);
    final Set<String> ids = {};

    for (final p in dataStore.pauses.values) {
      if (p.status == 'approved') {
        final pStart = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        final pEnd = DateTime(p.endDate.year, p.endDate.month, p.endDate.day);
        if (!queryDate.isBefore(pStart) && !queryDate.isAfter(pEnd)) {
          ids.add(p.customerId);
        }
      }
    }
    return ids;
  }
}
