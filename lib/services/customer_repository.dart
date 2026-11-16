import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer.dart';

class CustomerRepository {
  final SupabaseClient _client;

  CustomerRepository(this._client);

  /// Get all customers (admin), joining route info and ordering by delivery sequence.
  Future<List<Customer>> getAllCustomers() async {
    final data = await _client
        .from('customers')
        .select('*, profiles!customers_user_id_fkey(full_name, phone), sellers(profiles(full_name)), delivery_routes(name)')
        .order('delivery_sequence', ascending: true);

    return (data as List).map((e) => Customer.fromJson(e)).toList();
  }

  /// Get customers assigned to a specific seller, optionally filtered by routeId or shift,
  /// ordered by physical delivery sequence (1, 2, 3...).
  Future<List<Customer>> getCustomersBySeller(
    String sellerId, {
    String? routeId,
    String? shift,
  }) async {
    var query = _client
        .from('customers')
        .select('*, profiles!customers_user_id_fkey(full_name, phone), delivery_routes(name)')
        .eq('seller_id', sellerId);

    if (routeId != null && routeId.isNotEmpty) {
      query = query.eq('route_id', routeId);
    }

    if (shift != null && shift.isNotEmpty && shift != 'both') {
      // Return customers matching this shift OR 'both'
      query = query.inFilter('delivery_shift', [shift, 'both']);
    }

    final data = await query.order('delivery_sequence', ascending: true);
    return (data as List).map((e) => Customer.fromJson(e)).toList();
  }

  /// Get customers assigned to a specific route, ordered by delivery_sequence ASC.
  Future<List<Customer>> getCustomersByRoute(String routeId) async {
    final data = await _client
        .from('customers')
        .select('*, profiles!customers_user_id_fkey(full_name, phone), delivery_routes(name)')
        .eq('route_id', routeId)
        .order('delivery_sequence', ascending: true);

    return (data as List).map((e) => Customer.fromJson(e)).toList();
  }

  /// Get customer by user_id (for the logged-in customer).
  Future<Customer?> getCustomerByUserId(String userId) async {
    final data = await _client
        .from('customers')
        .select('*, profiles!customers_user_id_fkey(full_name, phone), sellers(profiles(full_name)), delivery_routes(name)')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Customer.fromJson(data);
  }

  /// Get customer by customer ID.
  Future<Customer?> getCustomerById(String id) async {
    final data = await _client
        .from('customers')
        .select('*, profiles!customers_user_id_fkey(full_name, phone), sellers(profiles(full_name)), delivery_routes(name)')
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return Customer.fromJson(data);
  }

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
    await _client.from('profiles').update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', profileId);

    final Map<String, dynamic> customerUpdates = {
      'seller_id': sellerId,
      'route_name': routeName,
      'location': location,
      'milk_type': milkType,
      'rate_per_liter': ratePerLiter,
      'daily_quantity_liters': dailyQuantityLiters,
      'daily_quantity_ml': dailyQuantityMl,
      'status': status,
    };
    if (routeId != null) {
      customerUpdates['route_id'] = routeId;
    }
    if (deliverySequence != null) {
      customerUpdates['delivery_sequence'] = deliverySequence;
    }
    if (deliveryShift != null) {
      customerUpdates['delivery_shift'] = deliveryShift;
    }

    await _client.from('customers').update(customerUpdates).eq('id', customerId);
  }

  /// Create a new customer (admin or seller).
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
    final data = await _client.from('customers').insert({
      'user_id': userId,
      'seller_id': sellerId,
      'route_id': routeId,
      'route_name': routeName,
      'delivery_sequence': deliverySequence,
      'delivery_shift': deliveryShift,
      'location': location,
      'milk_type': milkType,
      'rate_per_liter': ratePerLiter,
      'daily_quantity_liters': dailyQuantityLiters,
      'daily_quantity_ml': dailyQuantityMl,
    }).select('*, profiles!customers_user_id_fkey(full_name, phone), delivery_routes(name)').single();

    return Customer.fromJson(data);
  }

  /// Update a customer.
  Future<void> updateCustomer(String id, Map<String, dynamic> updates) async {
    await _client.from('customers').update(updates).eq('id', id);
  }

  /// Delete a customer.
  Future<void> deleteCustomer(String id) async {
    await _client.from('customers').delete().eq('id', id);
  }

  /// Get total customer count.
  Future<int> getCustomerCount() async {
    final response = await _client
        .from('customers')
        .select('id')
        .count(CountOption.exact);
    return response.count;
  }
}
