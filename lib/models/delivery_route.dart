class DeliveryRoute {
  final String id;
  final String name;
  final String? sellerId;
  final String? createdBy;
  final String shift; // 'morning' | 'evening' | 'both'
  final String status; // 'active' | 'inactive' | 'archived'
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields
  final String? sellerName;
  final int? customerCount;

  DeliveryRoute({
    required this.id,
    required this.name,
    this.sellerId,
    this.createdBy,
    this.shift = 'morning',
    this.status = 'active',
    this.description,
    this.createdAt,
    this.updatedAt,
    this.sellerName,
    this.customerCount,
  });

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    String? sellerName;
    final seller = json['sellers'] as Map<String, dynamic>?;
    if (seller != null) {
      if (seller['profiles'] is Map<String, dynamic>) {
        sellerName = (seller['profiles'] as Map<String, dynamic>)['full_name'] as String?;
      } else if (seller['name'] != null) {
        sellerName = seller['name'] as String?;
      }
    }

    int? customerCount;
    if (json['customers'] is List) {
      customerCount = (json['customers'] as List).length;
    } else if (json['customer_count'] is num) {
      customerCount = (json['customer_count'] as num).toInt();
    }

    return DeliveryRoute(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      sellerId: json['seller_id'] as String?,
      createdBy: json['created_by'] as String?,
      shift: json['shift'] as String? ?? 'morning',
      status: json['status'] as String? ?? 'active',
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      sellerName: sellerName,
      customerCount: customerCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (sellerId != null) 'seller_id': sellerId,
        if (createdBy != null) 'created_by': createdBy,
        'shift': shift,
        'status': status,
        'description': description,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  DeliveryRoute copyWith({
    String? id,
    String? name,
    String? sellerId,
    String? createdBy,
    String? shift,
    String? status,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sellerName,
    int? customerCount,
  }) {
    return DeliveryRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      sellerId: sellerId ?? this.sellerId,
      createdBy: createdBy ?? this.createdBy,
      shift: shift ?? this.shift,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sellerName: sellerName ?? this.sellerName,
      customerCount: customerCount ?? this.customerCount,
    );
  }
}
