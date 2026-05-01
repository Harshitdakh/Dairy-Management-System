import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer.dart';

class CustomerRepository {
  final SupabaseClient _client;

  CustomerRepository(this._client);

  /// Get all customers (admin).
  Future<List<Customer>> getAllCustomers() async {
    final data = await _client
        .from('customers')
        .select('*, profiles!customers_user_id_fkey(full_name, phone), sellers(profiles(full_name))')
        .order('created_at', ascending: false);

    return (data as List).map((e) => Customer.fromJson(e)).toList();
  }

  /// Get customers assigned to a specific seller.
  Future<List<Customer>> getCustomersBySeller(String sellerId) async {
    final data = await _client
        .from('customers')
        .select('*, profiles!customers_user_id_fkey(full_name, phone)')
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => Customer.fromJson(e)).toList();
  }

  /// Get customer by user_id (for the logged-in customer).
  Future<Customer?> getCustomerByUserId(String userId) async {
    final data = await _client
        .from('customers')
        .select('*, profiles!customers_user_id_fkey(full_name, phone), sellers(profiles(full_name))')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Customer.fromJson(data);
  }

  Future<Customer?> getCustomerById(String id) async {
    final data = await _client
        .from('customers')
        .select('*, profiles!customers_user_id_fkey(full_name, phone), sellers(profiles(full_name))')
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
    String? routeName,
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

    await _client.from('customers').update({
      'seller_id': sellerId,
      'route_name': routeName,
      'location': location,
      'milk_type': milkType,
      'rate_per_liter': ratePerLiter,
      'daily_quantity_liters': dailyQuantityLiters,
      'daily_quantity_ml': dailyQuantityMl,
      'status': status,
    }).eq('id', customerId);
  }

  /// Create a new customer (admin or seller).
  Future<Customer> createCustomer({
    required String userId,
    String? sellerId,
    String? routeName,
    String? location,
    String milkType = 'cow',
    num ratePerLiter = 0,
  }) async {
    final data = await _client.from('customers').insert({
      'user_id': userId,
      'seller_id': sellerId,
      'route_name': routeName,
      'location': location,
      'milk_type': milkType,
      'rate_per_liter': ratePerLiter,
    }).select('*, profiles!customers_user_id_fkey(full_name, phone)').single();

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
