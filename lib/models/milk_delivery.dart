class MilkDelivery {
  final String id;
  final String sellerId;
  final String customerId;
  final String? saleId;
  final DateTime deliveryDate;
  final String milkType;
  final num quantityLiters;
  final num quantityMl;
  final num rate;
  final num amount;
  final String status; // 'delivered' | 'skipped'
  final String shift; // 'morning' | 'evening'
  final String? notes;
  final DateTime? createdAt;

  // Joined fields
  final String? customerName;
  final String? customerPhone;
  final String? sellerName;

  MilkDelivery({
    required this.id,
    required this.sellerId,
    required this.customerId,
    this.saleId,
    required this.deliveryDate,
    required this.milkType,
    this.quantityLiters = 0,
    this.quantityMl = 0,
    this.rate = 0,
    this.amount = 0,
    this.status = 'delivered',
    this.shift = 'morning',
    this.notes,
    this.createdAt,
    this.customerName,
    this.customerPhone,
    this.sellerName,
  });

  factory MilkDelivery.fromJson(Map<String, dynamic> json) {
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

    String? sellerName;
    final seller = json['sellers'] as Map<String, dynamic>?;
    if (seller != null && seller['profiles'] is Map<String, dynamic>) {
      sellerName = (seller['profiles'] as Map<String, dynamic>)['full_name'] as String?;
    }

    return MilkDelivery(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      saleId: json['sale_id'] as String?,
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'] as String)
          : DateTime.now(),
      milkType: json['milk_type'] as String? ?? 'cow',
      quantityLiters: json['quantity_liters'] ?? 0,
      quantityMl: json['quantity_ml'] ?? 0,
      rate: json['rate'] ?? 0,
      amount: json['amount'] ?? 0,
      status: json['status'] as String? ?? 'delivered',
      shift: json['shift'] as String? ?? 'morning',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      customerName: customerName,
      customerPhone: customerPhone,
      sellerName: sellerName,
    );
  }

  Map<String, dynamic> toJson() => {
        'seller_id': sellerId,
        'customer_id': customerId,
        if (saleId != null) 'sale_id': saleId,
        'delivery_date': deliveryDate.toIso8601String().split('T')[0],
        'milk_type': milkType,
        'quantity_liters': quantityLiters,
        'quantity_ml': quantityMl,
        'rate': rate,
        'amount': amount,
        'status': status,
        'shift': shift,
        if (notes != null) 'notes': notes,
      };

  double get totalLiters =>
      quantityLiters.toDouble() + (quantityMl.toDouble() / 1000);

  bool get isSkipped => status == 'skipped';
  bool get isDelivered => status == 'delivered';

  MilkDelivery copyWith({
    String? id,
    String? sellerId,
    String? customerId,
    String? saleId,
    DateTime? deliveryDate,
    String? milkType,
    num? quantityLiters,
    num? quantityMl,
    num? rate,
    num? amount,
    String? status,
    String? shift,
    String? notes,
    DateTime? createdAt,
    String? customerName,
    String? customerPhone,
    String? sellerName,
  }) {
    return MilkDelivery(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      customerId: customerId ?? this.customerId,
      saleId: saleId ?? this.saleId,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      milkType: milkType ?? this.milkType,
      quantityLiters: quantityLiters ?? this.quantityLiters,
      quantityMl: quantityMl ?? this.quantityMl,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      shift: shift ?? this.shift,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      sellerName: sellerName ?? this.sellerName,
    );
  }
}
