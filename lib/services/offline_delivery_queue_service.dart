import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/queued_delivery.dart';
import 'pause_repository.dart';
import '../providers/pause_provider.dart';

export '../models/queued_delivery.dart';

abstract class OfflineDeliveryQueueService {
  Future<void> enqueueDelivery({
    required String customerId,
    required String sellerId,
    required String milkType,
    required double quantityLiters,
    required int quantityMl,
    required DateTime deliveryDate,
    required String shift, // 'morning' | 'evening'
    required String status, // 'delivered' | 'skipped'
    String? notes,
    double? rate,
  });

  List<QueuedDelivery> getUnsyncedDeliveries();
  Future<int> syncQueueToSupabase();
  Stream<int> get pendingCountStream;
  int get pendingCount;
  Future<void> restoreFromPrefs();
  Future<void> clearQueue();
  void dispose();
}

class SupabaseOfflineDeliveryQueueService implements OfflineDeliveryQueueService {
  static const String prefKey = 'offline_delivery_queue_v1';
  final SupabaseClient _client;
  final PauseRepository? _pauseRepo;

  final List<QueuedDelivery> _queue = [];
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  SupabaseOfflineDeliveryQueueService({
    required SupabaseClient client,
    PauseRepository? pauseRepo,
  })  : _client = client,
        _pauseRepo = pauseRepo;

  @override
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  @override
  int get pendingCount => _queue.length;

  @override
  List<QueuedDelivery> getUnsyncedDeliveries() {
    return List.unmodifiable(_queue);
  }

  @override
  Future<void> enqueueDelivery({
    required String customerId,
    required String sellerId,
    required String milkType,
    required double quantityLiters,
    required int quantityMl,
    required DateTime deliveryDate,
    required String shift,
    required String status,
    String? notes,
    double? rate,
  }) async {
    if (quantityLiters < 0 || quantityMl < 0) {
      throw ArgumentError('Volume cannot be negative');
    }
    if (status == 'delivered' && quantityLiters == 0 && quantityMl == 0) {
      throw ArgumentError('Quantity must be greater than 0 for delivered status');
    }

    // Vacation Guardrail check
    if (status == 'delivered' && _pauseRepo != null) {
      final isPaused = await _pauseRepo.isCustomerPausedOnDate(customerId, deliveryDate);
      if (isPaused) {
        throw StateError('Customer delivery is paused on this date due to approved vacation');
      }
    }

    final queued = QueuedDelivery(
      id: 'queued-${DateTime.now().microsecondsSinceEpoch}',
      customerId: customerId,
      sellerId: sellerId,
      milkType: milkType,
      quantityLiters: quantityLiters,
      quantityMl: quantityMl,
      deliveryDate: deliveryDate,
      shift: shift,
      status: status,
      notes: notes,
      timestamp: DateTime.now(),
      rate: rate,
    );

    // Debounce / deduplicate in local queue for same customer, date, and shift
    final existingIdx = _queue.indexWhere((item) =>
        item.customerId == customerId &&
        _isSameDay(item.deliveryDate, deliveryDate) &&
        item.shift == shift);

    if (existingIdx >= 0) {
      _queue[existingIdx] = queued;
    } else {
      _queue.add(queued);
    }

    await _persistToPrefs();
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(_queue.length);
    }
  }

  @override
  Future<int> syncQueueToSupabase() async {
    if (_queue.isEmpty) return 0;

    int syncedCount = 0;
    final snapshot = List<QueuedDelivery>.from(_queue);

    for (final item in snapshot) {
      try {
        final dateStr = item.deliveryDate.toIso8601String().split('T')[0];

        // 1. Check for remote deduplication
        final existingDelivery = await _client
            .from('milk_deliveries')
            .select('id')
            .eq('customer_id', item.customerId)
            .eq('delivery_date', dateStr)
            .eq('shift', item.shift)
            .maybeSingle();

        if (existingDelivery == null) {
          if (item.status == 'delivered') {
            // Determine rate
            double rate = item.rate ?? 0.0;
            if (rate <= 0) {
              final custRes = await _client
                  .from('customers')
                  .select('rate_per_liter')
                  .eq('id', item.customerId)
                  .maybeSingle();
              rate = (custRes?['rate_per_liter'] as num?)?.toDouble() ?? 60.0;
            }

            final totalLiters = item.quantityLiters + (item.quantityMl / 1000.0);
            final totalAmount = totalLiters * rate;

            // Inserting into milk_sales triggers apply_sale_to_inventory_and_bill()
            // which creates milk_deliveries record and updates customer_bills atomically
            await _client.from('milk_sales').insert({
              'seller_id': item.sellerId,
              'customer_id': item.customerId,
              'milk_type': item.milkType,
              'quantity_liters': item.quantityLiters,
              'quantity_ml': item.quantityMl,
              'total_amount': totalAmount,
              'sale_date': dateStr,
              'shift': item.shift,
              if (item.notes != null) 'notes': item.notes,
            });
          } else {
            // Skipped delivery: insert directly into milk_deliveries
            await _client.from('milk_deliveries').insert({
              'seller_id': item.sellerId,
              'customer_id': item.customerId,
              'delivery_date': dateStr,
              'milk_type': item.milkType,
              'quantity_liters': 0,
              'quantity_ml': 0,
              'rate': 0,
              'amount': 0,
              'status': 'skipped',
              'shift': item.shift,
              if (item.notes != null) 'notes': item.notes,
            });
          }
        }

        // Successfully processed: remove from queue immediately for partial sync resilience
        _queue.remove(item);
        syncedCount++;
        await _persistToPrefs();
        if (!_pendingCountController.isClosed) {
          _pendingCountController.add(_queue.length);
        }
      } catch (e) {
        // Halt batch on network/server error; keep remaining queue intact for future retry
        break;
      }
    }

    return syncedCount;
  }

  @override
  Future<void> restoreFromPrefs() async {
    final tempList = <QueuedDelivery>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          for (final item in decoded) {
            try {
              if (item is Map<String, dynamic>) {
                tempList.add(QueuedDelivery.fromJson(item));
              } else if (item is Map) {
                tempList.add(
                    QueuedDelivery.fromJson(Map<String, dynamic>.from(item)));
              }
            } catch (_) {
              // Gracefully skip corrupted individual entry
            }
          }
        }
      }
      _queue.clear();
      _queue.addAll(tempList);
    } catch (_) {
      // In-memory fallback if preferences fail
    }
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(_queue.length);
    }
  }

  @override
  Future<void> clearQueue() async {
    _queue.clear();
    await _persistToPrefs();
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(0);
    }
  }

  Future<void> _persistToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _queue.map((e) => e.toJson()).toList();
      await prefs.setString(prefKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _pendingCountController.close();
  }
}

// ── Riverpod Providers ──

final offlineDeliveryQueueServiceProvider =
    Provider<OfflineDeliveryQueueService>((ref) {
  final client = Supabase.instance.client;
  final pauseRepo = ref.watch(pauseRepositoryProvider);
  final service = SupabaseOfflineDeliveryQueueService(
    client: client,
    pauseRepo: pauseRepo,
  );
  service.restoreFromPrefs();
  ref.onDispose(() => service.dispose());
  return service;
});

final pendingDeliveryCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(offlineDeliveryQueueServiceProvider);
  return service.pendingCountStream;
});
