class QueuedDelivery {
  final String id;
  final String customerId;
  final String sellerId;
  final String milkType;
  final double quantityLiters;
  final int quantityMl;
  final DateTime deliveryDate;
  final String shift; // 'morning' | 'evening'
  final String status; // 'delivered' | 'skipped'
  final String? notes;
  final DateTime timestamp;
  final double? rate;

  QueuedDelivery({
    required this.id,
    required this.customerId,
    required this.sellerId,
    required this.milkType,
    required this.quantityLiters,
    required this.quantityMl,
    required this.deliveryDate,
    required this.shift,
    required this.status,
    this.notes,
    required this.timestamp,
    this.rate,
  }) {
    if (quantityLiters < 0 || quantityMl < 0) {
      throw ArgumentError('Volume cannot be negative');
    }
    if (status == 'delivered' && quantityLiters == 0 && quantityMl == 0) {
      throw ArgumentError('Quantity must be greater than 0 for delivered status');
    }
  }

  double get totalLiters => quantityLiters + (quantityMl / 1000.0);
  bool get isSkipped => status == 'skipped';
  bool get isDelivered => status == 'delivered';

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'seller_id': sellerId,
        'milk_type': milkType,
        'quantity_liters': quantityLiters,
        'quantity_ml': quantityMl,
        'delivery_date': deliveryDate.toIso8601String(),
        'shift': shift,
        'status': status,
        if (notes != null) 'notes': notes,
        'timestamp': timestamp.toIso8601String(),
        if (rate != null) 'rate': rate,
      };

  factory QueuedDelivery.fromJson(Map<String, dynamic> json) => QueuedDelivery(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        sellerId: json['seller_id'] as String,
        milkType: json['milk_type'] as String? ?? 'cow',
        quantityLiters: (json['quantity_liters'] as num).toDouble(),
        quantityMl: (json['quantity_ml'] as num).toInt(),
        deliveryDate: DateTime.parse(json['delivery_date'] as String),
        shift: json['shift'] as String? ?? 'morning',
        status: json['status'] as String? ?? 'delivered',
        notes: json['notes'] as String?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        rate: (json['rate'] as num?)?.toDouble(),
      );

  QueuedDelivery copyWith({
    String? id,
    String? customerId,
    String? sellerId,
    String? milkType,
    double? quantityLiters,
    int? quantityMl,
    DateTime? deliveryDate,
    String? shift,
    String? status,
    String? notes,
    DateTime? timestamp,
    double? rate,
  }) {
    return QueuedDelivery(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      sellerId: sellerId ?? this.sellerId,
      milkType: milkType ?? this.milkType,
      quantityLiters: quantityLiters ?? this.quantityLiters,
      quantityMl: quantityMl ?? this.quantityMl,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      shift: shift ?? this.shift,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
      rate: rate ?? this.rate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueuedDelivery &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
