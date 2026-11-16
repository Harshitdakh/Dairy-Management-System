import 'package:milk_hub/models/customer.dart';
import 'package:milk_hub/models/delivery_route.dart';
import 'package:milk_hub/services/route_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'in_memory_dairy_data_store.dart';

final _dummyClient = SupabaseClient(
  'https://placeholder.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
);

class InMemoryRouteRepository extends RouteRepository {
  final InMemoryDairyDataStore dataStore;

  InMemoryRouteRepository(this.dataStore, [SupabaseClient? client])
      : super(client ?? _dummyClient);

  @override
  Future<List<DeliveryRoute>> getAllRoutes() async {
    final list = dataStore.routes.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<List<DeliveryRoute>> getRoutesBySeller(String sellerId) async {
    final list = dataStore.routes.values
        .where((r) => r.sellerId == sellerId)
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<DeliveryRoute?> getRouteById(String routeId) async {
    return dataStore.routes[routeId];
  }

  @override
  Future<DeliveryRoute> createRoute({
    required String name,
    String? sellerId,
    required String shift,
    String? description,
  }) async {
    final newId = 'route-${DateTime.now().microsecondsSinceEpoch}';
    final route = DeliveryRoute(
      id: newId,
      name: name.trim(),
      sellerId: sellerId,
      shift: shift,
      status: 'active',
      description: description?.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      customerCount: 0,
    );
    dataStore.routes[newId] = route;
    return route;
  }

  @override
  Future<void> updateRoute(DeliveryRoute route) async {
    if (dataStore.routes.containsKey(route.id)) {
      dataStore.routes[route.id] = route.copyWith(
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> deleteRoute(String routeId) async {
    // Unassign customers first (ON DELETE SET NULL equivalent)
    for (final entry in dataStore.customers.entries) {
      if (entry.value.routeId == routeId) {
        final old = entry.value;
        dataStore.customers[entry.key] = Customer(
          id: old.id,
          userId: old.userId,
          sellerId: old.sellerId,
          routeId: null,
          deliverySequence: 0,
          deliveryShift: old.deliveryShift,
          routeName: null,
          location: old.location,
          milkType: old.milkType,
          ratePerLiter: old.ratePerLiter,
          dailyQuantityLiters: old.dailyQuantityLiters,
          dailyQuantityMl: old.dailyQuantityMl,
          status: old.status,
          createdAt: old.createdAt,
          fullName: old.fullName,
          phone: old.phone,
          sellerName: old.sellerName,
        );
      }
    }
    dataStore.routes.remove(routeId);
  }

  @override
  Future<void> updateCustomerSequence(List<String> customerIdsInOrder) async {
    final uniqueIds = customerIdsInOrder.toSet().toList();
    for (int i = 0; i < uniqueIds.length; i++) {
      final cid = uniqueIds[i];
      final cust = dataStore.customers[cid];
      if (cust != null) {
        dataStore.customers[cid] = cust.copyWith(
          deliverySequence: i + 1,
        );
      }
    }
  }

  @override
  Future<void> assignCustomerToRoute({
    required String customerId,
    required String? routeId,
    required int sequence,
    String? shift,
  }) async {
    final cust = dataStore.customers[customerId];
    if (cust != null) {
      dataStore.customers[customerId] = Customer(
        id: cust.id,
        userId: cust.userId,
        sellerId: cust.sellerId,
        routeId: routeId,
        deliverySequence: sequence,
        deliveryShift:
            (shift != null && shift.isNotEmpty) ? shift : cust.deliveryShift,
        routeName: routeId == null ? null : cust.routeName,
        location: cust.location,
        milkType: cust.milkType,
        ratePerLiter: cust.ratePerLiter,
        dailyQuantityLiters: cust.dailyQuantityLiters,
        dailyQuantityMl: cust.dailyQuantityMl,
        status: cust.status,
        createdAt: cust.createdAt,
        fullName: cust.fullName,
        phone: cust.phone,
        sellerName: cust.sellerName,
      );
    }
  }
}
