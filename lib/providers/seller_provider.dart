import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/seller.dart';
import '../services/seller_repository.dart';

/// Repository provider
final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  return SellerRepository(Supabase.instance.client);
});

/// All sellers (admin view)
final allSellersProvider = FutureProvider<List<Seller>>((ref) async {
  final repo = ref.read(sellerRepositoryProvider);
  return await repo.getAllSellers();
});

final sellerByIdProvider = FutureProvider.family<Seller?, String>((ref, sellerId) async {
  final repo = ref.read(sellerRepositoryProvider);
  return await repo.getSellerById(sellerId);
});

/// Current seller (for logged-in seller user)
final currentSellerProvider = FutureProvider<Seller?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  final repo = ref.read(sellerRepositoryProvider);
  return await repo.getSellerByUserId(userId);
});

/// Seller count
final sellerCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(sellerRepositoryProvider);
  return await repo.getSellerCount();
});
