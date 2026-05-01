import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/milk_assignment.dart';
import '../models/milk_sale.dart';
import '../services/milk_repository.dart';

/// Repository provider
final milkRepositoryProvider = Provider<MilkRepository>((ref) {
  return MilkRepository(Supabase.instance.client);
});

/// Today's total volume (admin)
final todayVolumeProvider = FutureProvider<double>((ref) async {
  final repo = ref.read(milkRepositoryProvider);
  return await repo.getTodayTotalVolume();
});

/// Today's total revenue (admin)
final todayRevenueProvider = FutureProvider<double>((ref) async {
  final repo = ref.read(milkRepositoryProvider);
  return await repo.getTodayRevenue();
});

/// All sales (admin)
final allSalesProvider = FutureProvider<List<MilkSale>>((ref) async {
  final repo = ref.read(milkRepositoryProvider);
  return await repo.getAllSales();
});

/// Sales by seller
final salesBySellerProvider =
    FutureProvider.family<List<MilkSale>, String>((ref, sellerId) async {
  final repo = ref.read(milkRepositoryProvider);
  return await repo.getSalesBySeller(sellerId);
});

/// Sales by customer
final salesByCustomerProvider =
    FutureProvider.family<List<MilkSale>, String>((ref, customerId) async {
  final repo = ref.read(milkRepositoryProvider);
  return await repo.getSalesByCustomer(customerId);
});

/// Assignments by seller
final assignmentsBySellerProvider =
    FutureProvider.family<List<MilkAssignment>, String>((ref, sellerId) async {
  final repo = ref.read(milkRepositoryProvider);
  return await repo.getAssignmentsBySeller(sellerId);
});

/// Seller today sold volume
final sellerTodaySoldProvider =
    FutureProvider.family<double, String>((ref, sellerId) async {
  final repo = ref.read(milkRepositoryProvider);
  return await repo.getSellerTodaySold(sellerId);
});
