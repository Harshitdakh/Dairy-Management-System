class Customer {
  final String id;
  final String userId;
  final String? sellerId;
  final String? routeId;
  final int deliverySequence;
  final String deliveryShift; // 'morning' | 'evening' | 'both'
  final String? routeName;
  final String? location;
  final String milkType;
  final num ratePerLiter;
  final num dailyQuantityLiters;
  final num dailyQuantityMl;
  final String status;
  final DateTime? createdAt;

  // Joined fields
  final String? fullName;
  final String? phone;
  final String? sellerName;

  Customer({
    required this.id,
    required this.userId,
    this.sellerId,
    this.routeId,
    this.deliverySequence = 0,
    this.deliveryShift = 'morning',
    this.routeName,
    this.location,
    this.milkType = 'cow',
    this.ratePerLiter = 0,
    this.dailyQuantityLiters = 1,
    this.dailyQuantityMl = 0,
    this.status = 'active',
    this.createdAt,
    this.fullName,
    this.phone,
    this.sellerName,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final seller = json['sellers'] as Map<String, dynamic>?;
    String? sellerName;
    if (seller != null && seller['profiles'] != null) {
      sellerName = (seller['profiles'] as Map<String, dynamic>)['full_name'] as String?;
    }

    String? routeName = json['route_name'] as String?;
    final route = json['delivery_routes'] as Map<String, dynamic>?;
    if (route != null && route['name'] != null) {
      routeName = route['name'] as String?;
    }

    return Customer(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sellerId: json['seller_id'] as String?,
      routeId: json['route_id'] as String?,
      deliverySequence: (json['delivery_sequence'] as num?)?.toInt() ?? 0,
      deliveryShift: json['delivery_shift'] as String? ?? 'morning',
      routeName: routeName,
      location: json['location'] as String?,
      milkType: json['milk_type'] as String? ?? 'cow',
      ratePerLiter: json['rate_per_liter'] ?? 0,
      dailyQuantityLiters: json['daily_quantity_liters'] ?? 1,
      dailyQuantityMl: json['daily_quantity_ml'] ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      fullName: profile?['full_name'] as String?,
      phone: profile?['phone'] as String?,
      sellerName: sellerName,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'seller_id': sellerId,
        'route_id': routeId,
        'delivery_sequence': deliverySequence,
        'delivery_shift': deliveryShift,
        'route_name': routeName,
        'location': location,
        'milk_type': milkType,
        'rate_per_liter': ratePerLiter,
        'daily_quantity_liters': dailyQuantityLiters,
        'daily_quantity_ml': dailyQuantityMl,
        'status': status,
      };

  double get totalDailyLiters =>
      dailyQuantityLiters.toDouble() + (dailyQuantityMl.toDouble() / 1000);

  Customer copyWith({
    String? id,
    String? userId,
    String? sellerId,
    String? routeId,
    int? deliverySequence,
    String? deliveryShift,
    String? routeName,
    String? location,
    String? milkType,
    num? ratePerLiter,
    num? dailyQuantityLiters,
    num? dailyQuantityMl,
    String? status,
    DateTime? createdAt,
    String? fullName,
    String? phone,
    String? sellerName,
  }) {
    return Customer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sellerId: sellerId ?? this.sellerId,
      routeId: routeId ?? this.routeId,
      deliverySequence: deliverySequence ?? this.deliverySequence,
      deliveryShift: deliveryShift ?? this.deliveryShift,
      routeName: routeName ?? this.routeName,
      location: location ?? this.location,
      milkType: milkType ?? this.milkType,
      ratePerLiter: ratePerLiter ?? this.ratePerLiter,
      dailyQuantityLiters: dailyQuantityLiters ?? this.dailyQuantityLiters,
      dailyQuantityMl: dailyQuantityMl ?? this.dailyQuantityMl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      sellerName: sellerName ?? this.sellerName,
    );
  }
}
