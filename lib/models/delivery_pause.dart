class DeliveryPause {
  final String id;
  final String customerId;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'pending' | 'approved' | 'rejected' | 'cancelled'
  final String? reason;
  final String? createdBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields
  final String? customerName;
  final String? customerPhone;

  DeliveryPause({
    required this.id,
    required this.customerId,
    required this.startDate,
    required this.endDate,
    this.status = 'pending',
    this.reason,
    this.createdBy,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.customerPhone,
  });

  factory DeliveryPause.fromJson(Map<String, dynamic> json) {
    String? customerName;
    String? customerPhone;
    final customer = json['customers'] as Map<String, dynamic>?;
    if (customer != null) {
      if (customer['profiles'] is Map<String, dynamic>) {
        final profile = customer['profiles'] as Map<String, dynamic>;
        customerName = profile['full_name'] as String?;
        customerPhone = profile['phone'] as String?;
      } else if (customer['name'] != null) {
        customerName = customer['name'] as String?;
      }
    }

    return DeliveryPause(
      id: json['id'] as String,
      customerId: json['customer_id'] as String? ?? '',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      reason: json['reason'] as String?,
      createdBy: json['created_by'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      customerName: customerName,
      customerPhone: customerPhone,
    );
  }

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'start_date': startDate.toLocal().toIso8601String().split('T')[0],
        'end_date': endDate.toLocal().toIso8601String().split('T')[0],
        'status': status,
        if (reason != null) 'reason': reason,
        if (createdBy != null) 'created_by': createdBy,
        if (reviewedBy != null) 'reviewed_by': reviewedBy,
        if (reviewedAt != null) 'reviewed_at': reviewedAt!.toIso8601String(),
      };

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

  /// Returns true if this pause is approved and the given [date] falls
  /// between [startDate] and [endDate] inclusive (date-only comparison).
  bool isActiveOn(DateTime date) {
    if (!isApproved) return false;
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  DeliveryPause copyWith({
    String? id,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? reason,
    String? createdBy,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? customerPhone,
  }) {
    return DeliveryPause(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      createdBy: createdBy ?? this.createdBy,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }
}
