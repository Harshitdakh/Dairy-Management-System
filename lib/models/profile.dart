class Profile {
  final String id;
  final String fullName;
  final String role;
  final String? phone;
  final DateTime? createdAt;

  Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'role': role,
        'phone': phone,
      };

  bool get isAdmin => role == 'admin';
  bool get isSeller => role == 'seller';
  bool get isCustomer => role == 'customer';
}
