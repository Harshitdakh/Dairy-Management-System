class Customer {
  final String id;
  final String userId;
  final String? sellerId;
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
    return Customer(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sellerId: json['seller_id'] as String?,
      routeName: json['route_name'] as String?,
      location: json['location'] as String?,
      milkType: json['milk_type'] as String? ?? 'cow',
      ratePerLiter: json['rate_per_liter'] ?? 0,
        dailyQuantityLiters: json['daily_quantity_liters'] ?? 1,
        dailyQuantityMl: json['daily_quantity_ml'] ?? 0,
        status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      fullName: profile?['full_name'] as String?,
      phone: profile?['phone'] as String?,
      sellerName: sellerName,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'seller_id': sellerId,
        'route_name': routeName,
        'location': location,
        'milk_type': milkType,
        'rate_per_liter': ratePerLiter,
        'daily_quantity_liters': dailyQuantityLiters,
        'daily_quantity_ml': dailyQuantityMl,
        'status': status,
      };
}
