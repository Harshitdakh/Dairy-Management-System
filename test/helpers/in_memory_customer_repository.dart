import 'package:milk_hub/models/customer.dart';
import 'package:milk_hub/services/customer_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'in_memory_dairy_data_store.dart';

final _dummyClient = SupabaseClient(
  'https://placeholder.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
);

class InMemoryCustomerRepository extends CustomerRepository {
  final InMemoryDairyDataStore dataStore;

  InMemoryCustomerRepository(this.dataStore, [SupabaseClient? client])
      : super(client ?? _dummyClient);

  @override
  Future<List<Customer>> getAllCustomers() async {
    final list = dataStore.customers.values.toList();
    list.sort((a, b) => a.deliverySequence.compareTo(b.deliverySequence));
    return list;
  }

  @override
  Future<List<Customer>> getCustomersBySeller(
    String sellerId, {
    String? routeId,
    String? shift,
  }) async {
    final list = dataStore.customers.values.where((c) {
      if (c.sellerId != sellerId) return false;
      if (routeId != null && routeId.isNotEmpty && c.routeId != routeId) {
        return false;
      }
      if (shift != null && shift.isNotEmpty && shift != 'both') {
        if (c.deliveryShift != shift && c.deliveryShift != 'both') {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) => a.deliverySequence.compareTo(b.deliverySequence));
    return list;
  }

  @override
  Future<List<Customer>> getCustomersByRoute(String routeId) async {
    final list = dataStore.customers.values
        .where((c) => c.routeId == routeId)
        .toList();
    list.sort((a, b) => a.deliverySequence.compareTo(b.deliverySequence));
    return list;
  }

  @override
  Future<Customer?> getCustomerByUserId(String userId) async {
    for (final c in dataStore.customers.values) {
      if (c.userId == userId) return c;
    }
    return null;
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    return dataStore.customers[id];
  }

  @override
  Future<Customer> createCustomer({
    required String userId,
    String? sellerId,
    String? routeId,
    String? routeName,
    int deliverySequence = 0,
    String deliveryShift = 'morning',
    String? location,
    String milkType = 'cow',
    num ratePerLiter = 0,
    num dailyQuantityLiters = 1,
    num dailyQuantityMl = 0,
  }) async {
    final newId = 'cust-${DateTime.now().microsecondsSinceEpoch}';
    final cust = Customer(
      id: newId,
      userId: userId,
      sellerId: sellerId,
      routeId: routeId,
      routeName: routeName,
      deliverySequence: deliverySequence,
      deliveryShift: deliveryShift,
      location: location,
      milkType: milkType,
      ratePerLiter: ratePerLiter,
      dailyQuantityLiters: dailyQuantityLiters,
      dailyQuantityMl: dailyQuantityMl,
      status: 'active',
      createdAt: DateTime.now(),
    );
    dataStore.customers[newId] = cust;
    return cust;
  }

  @override
  Future<void> updateCustomer(String id, Map<String, dynamic> updates) async {
    final cust = dataStore.customers[id];
    if (cust != null) {
      dataStore.customers[id] = cust.copyWith(
        routeId: updates.containsKey('route_id') ? updates['route_id'] as String? : cust.routeId,
        deliverySequence: updates.containsKey('delivery_sequence')
            ? (updates['delivery_sequence'] as num).toInt()
            : cust.deliverySequence,
        deliveryShift: updates.containsKey('delivery_shift')
            ? updates['delivery_shift'] as String
            : cust.deliveryShift,
        status: updates.containsKey('status') ? updates['status'] as String : cust.status,
      );
    }
  }

  @override
  Future<void> updateCustomerProfileAndDetails({
    required String customerId,
    required String profileId,
    required String fullName,
    required String phone,
    String? sellerId,
    String? routeId,
    String? routeName,
    int? deliverySequence,
    String? deliveryShift,
    String? location,
    required String milkType,
    required num ratePerLiter,
    required num dailyQuantityLiters,
    required num dailyQuantityMl,
    required String status,
  }) async {
    final cust = dataStore.customers[customerId];
    if (cust != null) {
      dataStore.customers[customerId] = cust.copyWith(
        fullName: fullName,
        phone: phone,
        sellerId: sellerId,
        routeId: routeId,
        routeName: routeName,
        deliverySequence: deliverySequence ?? cust.deliverySequence,
        deliveryShift: deliveryShift ?? cust.deliveryShift,
        location: location,
        milkType: milkType,
        ratePerLiter: ratePerLiter,
        dailyQuantityLiters: dailyQuantityLiters,
        dailyQuantityMl: dailyQuantityMl,
        status: status,
      );
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    dataStore.customers.remove(id);
  }

  @override
  Future<int> getCustomerCount() async {
    return dataStore.customers.length;
  }
}
