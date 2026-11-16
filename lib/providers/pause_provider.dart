import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_pause.dart';
import '../services/pause_repository.dart';

final pauseRepositoryProvider = Provider<PauseRepository>((ref) {
  return PauseRepository(Supabase.instance.client);
});

final allPendingPausesProvider = FutureProvider<List<DeliveryPause>>((ref) async {
  final repo = ref.read(pauseRepositoryProvider);
  return await repo.getAllPendingPauses();
});

final pendingPausesForSellerProvider =
    FutureProvider.family<List<DeliveryPause>, String>((ref, sellerId) async {
  final repo = ref.read(pauseRepositoryProvider);
  return await repo.getPendingPausesForSeller(sellerId);
});

final customerPausesProvider =
    FutureProvider.family<List<DeliveryPause>, String>((ref, customerId) async {
  final repo = ref.read(pauseRepositoryProvider);
  return await repo.getPausesForCustomer(customerId);
});
