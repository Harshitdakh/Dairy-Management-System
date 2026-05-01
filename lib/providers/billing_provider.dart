import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/collection_entry.dart';
import '../models/customer_bill.dart';
import '../services/billing_repository.dart';
import 'auth_provider.dart';
import 'customer_provider.dart';
import 'seller_provider.dart';

class BillQuery {
  final DateTime month;
  final String status;

  const BillQuery({required this.month, this.status = 'all'});
}

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(Supabase.instance.client);
});

final monthlyBillsProvider =
    FutureProvider.family<List<CustomerBill>, BillQuery>((ref, query) async {
  final repo = ref.read(billingRepositoryProvider);
  final profile = ref.watch(profileProvider).valueOrNull;

  if (profile == null) return [];

  if (profile.isAdmin) {
    return repo.getBills(month: query.month, status: query.status);
  }

  if (profile.isSeller) {
    final seller = ref.watch(currentSellerProvider).valueOrNull;
    if (seller == null) return [];
    return repo.getBills(
      sellerId: seller.id,
      month: query.month,
      status: query.status,
    );
  }

  final customer = ref.watch(currentCustomerProvider).valueOrNull;
  if (customer == null) return [];
  return repo.getBills(
    customerId: customer.id,
    month: query.month,
    status: query.status,
  );
});

final collectionSummaryProvider =
    FutureProvider.family<Map<String, double>, DateTime>((ref, month) async {
  final repo = ref.read(billingRepositoryProvider);
  final profile = ref.watch(profileProvider).valueOrNull;

  if (profile == null) {
    return {'total': 0, 'paid': 0, 'pending': 0};
  }

  if (profile.isAdmin) {
    return repo.getCollectionSummary(month: month);
  }

  if (profile.isSeller) {
    final seller = ref.watch(currentSellerProvider).valueOrNull;
    if (seller == null) return {'total': 0, 'paid': 0, 'pending': 0};
    return repo.getCollectionSummary(sellerId: seller.id, month: month);
  }

  final customer = ref.watch(currentCustomerProvider).valueOrNull;
  if (customer == null) return {'total': 0, 'paid': 0, 'pending': 0};
  return repo.getCollectionSummary(customerId: customer.id, month: month);
});

final collectionsProvider =
    FutureProvider.family<List<CollectionEntry>, DateTime>((ref, month) async {
  final repo = ref.read(billingRepositoryProvider);
  final profile = ref.watch(profileProvider).valueOrNull;

  if (profile == null) return [];

  if (profile.isAdmin) {
    return repo.getCollections(month: month);
  }

  if (profile.isSeller) {
    final seller = ref.watch(currentSellerProvider).valueOrNull;
    if (seller == null) return [];
    return repo.getCollections(sellerId: seller.id, month: month);
  }

  final customer = ref.watch(currentCustomerProvider).valueOrNull;
  if (customer == null) return [];
  return repo.getCollections(customerId: customer.id, month: month);
});

// Bills for a specific seller's customers
final sellerBillsProvider = FutureProvider.family.autoDispose<List<CustomerBill>, String>((ref, sellerId) async {
  final repo = ref.read(billingRepositoryProvider);
  return repo.getBills(sellerId: sellerId);
});

// Collections for a specific seller
final sellerCollectionsProvider = FutureProvider.family.autoDispose<List<CollectionEntry>, String>((ref, sellerId) async {
  final repo = ref.read(billingRepositoryProvider);
  return repo.getCollections(sellerId: sellerId);
});

// Bills for a specific customer
final customerBillsProvider = FutureProvider.family.autoDispose<List<CustomerBill>, String>((ref, customerId) async {
  final repo = ref.read(billingRepositoryProvider);
  return repo.getBills(customerId: customerId);
});

// Collections for a specific customer
final customerCollectionsProvider = FutureProvider.family.autoDispose<List<CollectionEntry>, String>((ref, customerId) async {
  final repo = ref.read(billingRepositoryProvider);
  return repo.getCollections(customerId: customerId);
});
