class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String? createdBy;
  final String targetRole;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.createdBy,
    required this.targetRole,
    this.type = 'info',
    this.isRead = false,
    this.createdAt,
  });

  /// Alias for message, used in the UI
  String get body => message;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      createdBy: json['created_by'] as String?,
      targetRole: json['target_role'] as String,
      type: (json['type'] as String?) ?? 'info',
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'message': message,
        'created_by': createdBy,
        'target_role': targetRole,
        'type': type,
        'is_read': isRead,
      };
}
