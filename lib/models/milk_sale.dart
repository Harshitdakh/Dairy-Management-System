class MilkSale {
  final String id;
  final String sellerId;
  final String customerId;
  final String milkType;
  final num quantityLiters;
  final num quantityMl;
  final num totalAmount;
  final DateTime saleDate;
  final String? notes;
  final DateTime? createdAt;

  // Joined fields
  final String? customerName;
  final String? sellerName;

  MilkSale({
    required this.id,
    required this.sellerId,
    required this.customerId,
    required this.milkType,
    this.quantityLiters = 0,
    this.quantityMl = 0,
    this.totalAmount = 0,
    required this.saleDate,
    this.notes,
    this.createdAt,
    this.customerName,
    this.sellerName,
  });

  factory MilkSale.fromJson(Map<String, dynamic> json) {
    final customer = json['customers'] as Map<String, dynamic>?;
    String? customerName;
    if (customer != null && customer['profiles'] != null) {
      customerName =
          (customer['profiles'] as Map<String, dynamic>)['full_name'] as String?;
    }
    return MilkSale(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      customerId: json['customer_id'] as String,
      milkType: json['milk_type'] as String,
      quantityLiters: json['quantity_liters'] ?? 0,
      quantityMl: json['quantity_ml'] ?? 0,
      totalAmount: json['total_amount'] ?? 0,
      saleDate: DateTime.parse(json['sale_date'] as String),
        notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      customerName: customerName,
    );
  }

  Map<String, dynamic> toJson() => {
        'seller_id': sellerId,
        'customer_id': customerId,
        'milk_type': milkType,
        'quantity_liters': quantityLiters,
        'quantity_ml': quantityMl,
        'total_amount': totalAmount,
        'sale_date': saleDate.toIso8601String().split('T')[0],
        'notes': notes,
      };

  double get totalLiters =>
      quantityLiters.toDouble() + (quantityMl.toDouble() / 1000);
}
