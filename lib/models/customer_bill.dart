class CustomerBill {
  final String id;
  final String customerId;
  final String sellerId;
  final DateTime billMonth;
  final num totalQuantityLiters;
  final num totalAmount;
  final num paidAmount;
  final num pendingAmount;
  final String status;
  final DateTime? updatedAt;

  final String? customerName;
  final String? sellerName;

  CustomerBill({
    required this.id,
    required this.customerId,
    required this.sellerId,
    required this.billMonth,
    this.totalQuantityLiters = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.pendingAmount = 0,
    this.status = 'pending',
    this.updatedAt,
    this.customerName,
    this.sellerName,
  });

  factory CustomerBill.fromJson(Map<String, dynamic> json) {
    final customer = json['customers'] as Map<String, dynamic>?;
    final customerProfile = customer?['profiles'] as Map<String, dynamic>?;

    final seller = json['sellers'] as Map<String, dynamic>?;
    final sellerProfile = seller?['profiles'] as Map<String, dynamic>?;

    return CustomerBill(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      sellerId: json['seller_id'] as String,
      billMonth: DateTime.parse(json['bill_month'] as String),
      totalQuantityLiters: json['total_quantity_liters'] ?? 0,
      totalAmount: json['total_amount'] ?? 0,
      paidAmount: json['paid_amount'] ?? 0,
      pendingAmount: json['pending_amount'] ?? 0,
      status: json['status'] as String? ?? 'pending',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      customerName: customerProfile?['full_name'] as String?,
      sellerName: sellerProfile?['full_name'] as String?,
    );
  }
}
