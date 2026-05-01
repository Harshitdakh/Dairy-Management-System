class CollectionEntry {
  final String id;
  final String customerId;
  final String sellerId;
  final DateTime billMonth;
  final num amountPaid;
  final DateTime paidOn;
  final String paymentMode;
  final String? notes;
  final DateTime? createdAt;

  final String? customerName;

  CollectionEntry({
    required this.id,
    required this.customerId,
    required this.sellerId,
    required this.billMonth,
    this.amountPaid = 0,
    required this.paidOn,
    this.paymentMode = 'cash',
    this.notes,
    this.createdAt,
    this.customerName,
  });

  factory CollectionEntry.fromJson(Map<String, dynamic> json) {
    final customer = json['customers'] as Map<String, dynamic>?;
    final customerProfile = customer?['profiles'] as Map<String, dynamic>?;

    return CollectionEntry(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      sellerId: json['seller_id'] as String,
      billMonth: DateTime.parse(json['bill_month'] as String),
      amountPaid: json['amount_paid'] ?? 0,
      paidOn: DateTime.parse(json['paid_on'] as String),
      paymentMode: json['payment_mode'] as String? ?? 'cash',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      customerName: customerProfile?['full_name'] as String?,
    );
  }
}
