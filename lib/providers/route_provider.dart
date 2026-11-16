import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_route.dart';
import '../services/route_repository.dart';

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepository(Supabase.instance.client);
});

final allRoutesProvider = FutureProvider<List<DeliveryRoute>>((ref) async {
  final repo = ref.read(routeRepositoryProvider);
  return await repo.getAllRoutes();
});

final routesBySellerProvider =
    FutureProvider.family<List<DeliveryRoute>, String>((ref, sellerId) async {
  final repo = ref.read(routeRepositoryProvider);
  return await repo.getRoutesBySeller(sellerId);
});

final routeByIdProvider =
    FutureProvider.family<DeliveryRoute?, String>((ref, routeId) async {
  final repo = ref.read(routeRepositoryProvider);
  return await repo.getRouteById(routeId);
});

final selectedSellerRouteIdProvider = StateProvider<String?>((ref) => null);

final selectedDeliveryShiftProvider = StateProvider<String>((ref) => 'morning');
