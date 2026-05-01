class Seller {
  final String id;
  final String userId;
  final String routeName;
  final String? location;
  final num assignedMilkLiters;
  final num assignedMilkMl;
  final String status;
  final DateTime? createdAt;

  // Joined fields
  final String? fullName;
  final String? phone;

  Seller({
    required this.id,
    required this.userId,
    required this.routeName,
    this.location,
    this.assignedMilkLiters = 0,
    this.assignedMilkMl = 0,
    this.status = 'active',
    this.createdAt,
    this.fullName,
    this.phone,
  });

  factory Seller.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return Seller(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      routeName: json['route_name'] as String,
      location: json['location'] as String?,
      assignedMilkLiters: json['assigned_milk_liters'] ?? 0,
      assignedMilkMl: json['assigned_milk_ml'] ?? 0,
        status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      fullName: profile?['full_name'] as String?,
      phone: profile?['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'route_name': routeName,
        'location': location,
        'assigned_milk_liters': assignedMilkLiters,
        'assigned_milk_ml': assignedMilkMl,
        'status': status,
      };
}
