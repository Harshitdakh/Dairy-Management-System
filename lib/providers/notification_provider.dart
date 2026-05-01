import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../services/notification_repository.dart';
import 'auth_provider.dart';

/// Repository provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(Supabase.instance.client);
});

/// Notifications for current user's role
final notificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  final repo = ref.read(notificationRepositoryProvider);
  final role = ref.watch(userRoleProvider);
  if (role == 'admin') {
    return await repo.getAllNotifications();
  }
  if (role == null) return [];
  return await repo.getNotifications(role);
});
