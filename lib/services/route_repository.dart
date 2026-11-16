import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_route.dart';

class RouteRepository {
  final SupabaseClient _client;

  RouteRepository(this._client);

  /// Fetch all delivery routes (for admin or owner overview).
  Future<List<DeliveryRoute>> getAllRoutes() async {
    final data = await _client
        .from('delivery_routes')
        .select('*, sellers(profiles(full_name)), customers(id)')
        .order('name', ascending: true);

    return (data as List).map((e) => DeliveryRoute.fromJson(e)).toList();
  }

  /// Fetch delivery routes assigned to a specific seller.
  Future<List<DeliveryRoute>> getRoutesBySeller(String sellerId) async {
    final data = await _client
        .from('delivery_routes')
        .select('*, sellers(profiles(full_name)), customers(id)')
        .eq('seller_id', sellerId)
        .order('name', ascending: true);

    return (data as List).map((e) => DeliveryRoute.fromJson(e)).toList();
  }

  /// Get a single route by ID.
  Future<DeliveryRoute?> getRouteById(String routeId) async {
    final data = await _client
        .from('delivery_routes')
        .select('*, sellers(profiles(full_name)), customers(id)')
        .eq('id', routeId)
        .maybeSingle();

    if (data == null) return null;
    return DeliveryRoute.fromJson(data);
  }

  /// Create a new delivery route.
  Future<DeliveryRoute> createRoute({
    required String name,
    String? sellerId,
    required String shift, // 'morning' | 'evening' | 'both'
    String? description,
  }) async {
    final data = await _client
        .from('delivery_routes')
        .insert({
          'name': name.trim(),
          if (sellerId != null && sellerId.isNotEmpty) 'seller_id': sellerId,
          'created_by': _client.auth.currentUser?.id,
          'shift': shift,
          'status': 'active',
          'description': description?.trim(),
        })
        .select('*, sellers(profiles(full_name))')
        .single();

    return DeliveryRoute.fromJson(data);
  }

  /// Update an existing delivery route.
  Future<void> updateRoute(DeliveryRoute route) async {
    await _client.from('delivery_routes').update({
      'name': route.name.trim(),
      'seller_id': route.sellerId,
      'shift': route.shift,
      'status': route.status,
      'description': route.description?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', route.id);
  }

  /// Delete a delivery route (unassigns customers first).
  Future<void> deleteRoute(String routeId) async {
    await _client.from('customers').update({
      'route_id': null,
      'delivery_sequence': 0,
    }).eq('route_id', routeId);

    await _client.from('delivery_routes').delete().eq('id', routeId);
  }

  /// Reorder customers along a route sequence without breaking historical delivery records.
  Future<void> updateCustomerSequence(List<String> customerIdsInOrder) async {
    final uniqueIds = customerIdsInOrder.toSet().toList();
    for (int i = 0; i < uniqueIds.length; i++) {
      await _client.from('customers').update({
        'delivery_sequence': i + 1,
      }).eq('id', uniqueIds[i]);
    }
  }

  /// Assign a customer to a route with sequence number and delivery shift.
  Future<void> assignCustomerToRoute({
    required String customerId,
    required String? routeId,
    required int sequence,
    String? shift,
  }) async {
    final Map<String, dynamic> updates = {
      'route_id': routeId,
      'delivery_sequence': sequence,
    };
    if (shift != null && shift.isNotEmpty) {
      updates['delivery_shift'] = shift;
    }

    await _client.from('customers').update(updates).eq('id', customerId);
  }
}
