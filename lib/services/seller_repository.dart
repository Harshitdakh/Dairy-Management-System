import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/seller.dart';

class SellerRepository {
  final SupabaseClient _client;

  SellerRepository(this._client);

  /// Get all sellers with their profile info.
  Future<List<Seller>> getAllSellers() async {
    final data = await _client
        .from('sellers')
        .select('*, profiles!sellers_user_id_fkey(full_name, phone)')
        .order('created_at', ascending: false);

    return (data as List).map((e) => Seller.fromJson(e)).toList();
  }

  /// Get seller by user_id (for the logged-in seller).
  Future<Seller?> getSellerByUserId(String userId) async {
    final data = await _client
        .from('sellers')
        .select('*, profiles!sellers_user_id_fkey(full_name, phone)')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Seller.fromJson(data);
  }

  /// Get seller by id.
  Future<Seller?> getSellerById(String id) async {
    final data = await _client
        .from('sellers')
        .select('*, profiles!sellers_user_id_fkey(full_name, phone)')
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return Seller.fromJson(data);
  }

  Future<void> updateSellerProfileAndDetails({
    required String sellerId,
    required String profileId,
    required String fullName,
    required String phone,
    required String routeName,
    String? location,
    required String status,
  }) async {
    await _client.from('profiles').update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', profileId);

    await _client.from('sellers').update({
      'route_name': routeName,
      'location': location,
      'status': status,
    }).eq('id', sellerId);
  }

  /// Create a new seller record (admin).
  Future<Seller> createSeller({
    required String userId,
    required String routeName,
    String? location,
  }) async {
    final data = await _client.from('sellers').insert({
      'user_id': userId,
      'route_name': routeName,
      'location': location,
    }).select('*, profiles!sellers_user_id_fkey(full_name, phone)').single();

    return Seller.fromJson(data);
  }

  /// Update seller details.
  Future<void> updateSeller(String id, Map<String, dynamic> updates) async {
    await _client.from('sellers').update(updates).eq('id', id);
  }

  /// Delete a seller.
  Future<void> deleteSeller(String id) async {
    await _client.from('sellers').delete().eq('id', id);
  }

  /// Get total seller count.
  Future<int> getSellerCount() async {
    final response = await _client
        .from('sellers')
        .select('id')
        .count(CountOption.exact);
    return response.count;
  }
}
