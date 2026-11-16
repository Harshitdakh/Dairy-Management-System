import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer.dart';
import '../services/customer_repository.dart';

/// Repository provider
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(Supabase.instance.client);
});

/// All customers (admin view)
final allCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final repo = ref.read(customerRepositoryProvider);
  return await repo.getAllCustomers();
});

final customerByIdProvider = FutureProvider.family<Customer?, String>((ref, customerId) async {
  final repo = ref.read(customerRepositoryProvider);
  return await repo.getCustomerById(customerId);
});

/// Customers by seller
final customersBySellerProvider =
    FutureProvider.family<List<Customer>, String>((ref, sellerId) async {
  final repo = ref.read(customerRepositoryProvider);
  return await repo.getCustomersBySeller(sellerId);
});

/// Customers by route (ordered by delivery sequence)
final customersByRouteProvider =
    FutureProvider.family<List<Customer>, String>((ref, routeId) async {
  final repo = ref.read(customerRepositoryProvider);
  return await repo.getCustomersByRoute(routeId);
});

/// Current customer (for logged-in customer user)
final currentCustomerProvider = FutureProvider<Customer?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  final repo = ref.read(customerRepositoryProvider);
  return await repo.getCustomerByUserId(userId);
});

/// Customer count
final customerCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(customerRepositoryProvider);
  return await repo.getCustomerCount();
});
