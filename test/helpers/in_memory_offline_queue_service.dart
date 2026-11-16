import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milk_hub/services/offline_delivery_queue_service.dart';

import 'in_memory_billing_repository.dart';
import 'in_memory_dairy_data_store.dart';

export 'package:milk_hub/services/offline_delivery_queue_service.dart';

class InMemoryOfflineDeliveryQueueService implements OfflineDeliveryQueueService {
  static const String prefKey = 'offline_delivery_queue_v1';
  final InMemoryDairyDataStore dataStore;
  final InMemoryBillingRepository? billingRepo;

  final List<QueuedDelivery> _queue = [];
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  InMemoryOfflineDeliveryQueueService(this.dataStore, [this.billingRepo]);

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

    if (status == 'delivered') {
      final queryDate = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
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

    final existingIndex = _queue.indexWhere((item) =>
        item.customerId == customerId &&
        item.deliveryDate.year == deliveryDate.year &&
        item.deliveryDate.month == deliveryDate.month &&
        item.deliveryDate.day == deliveryDate.day &&
        item.shift == shift);

    if (existingIndex >= 0) {
      _queue[existingIndex] = queued;
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
    final count = _queue.length;
    if (count == 0) return 0;

    for (final item in _queue) {
      final cust = dataStore.customers[item.customerId];
      final rate = item.rate ?? cust?.ratePerLiter ?? 60.0;

      if (billingRepo != null) {
        await billingRepo!.recordDelivery(
          customerId: item.customerId,
          sellerId: item.sellerId,
          milkType: item.milkType,
          quantityLiters: item.quantityLiters,
          quantityMl: item.quantityMl,
          rate: rate,
          date: item.deliveryDate,
          shift: item.shift,
          status: item.status,
          notes: item.notes,
        );
      }
    }

    _queue.clear();
    await _persistToPrefs();
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(0);
    }
    return count;
  }

  Future<void> _persistToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _queue.map((e) => e.toJson()).toList();
    await prefs.setString(prefKey, jsonEncode(jsonList));
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
      // In-memory fallback if preferences fail or json corrupted
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

  @override
  void dispose() {
    _pendingCountController.close();
  }
}
