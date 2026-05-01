import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _client;

  NotificationRepository(this._client);

  /// Get notifications for a given role (also includes 'all' target).
  Future<List<NotificationModel>> getNotifications(String role) async {
    final data = await _client
        .from('notifications')
        .select()
        .or('target_role.eq.all,target_role.eq.$role')
        .order('created_at', ascending: false)
        .limit(50);

    return (data as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  /// Get all notifications (admin).
  Future<List<NotificationModel>> getAllNotifications() async {
    final data = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);

    return (data as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  /// Create a notification (admin only).
  Future<NotificationModel> createNotification({
    required String title,
    required String message,
    required String targetRole,
    required String createdBy,
  }) async {
    final data = await _client.from('notifications').insert({
      'title': title,
      'message': message,
      'target_role': targetRole,
      'created_by': createdBy,
    }).select().single();

    return NotificationModel.fromJson(data);
  }
}
