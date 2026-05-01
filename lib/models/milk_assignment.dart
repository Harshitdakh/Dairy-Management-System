class MilkAssignment {
  final String id;
  final String sellerId;
  final String milkType;
  final num quantityLiters;
  final num quantityMl;
  final num rate;
  final DateTime date;
  final DateTime? createdAt;

  MilkAssignment({
    required this.id,
    required this.sellerId,
    required this.milkType,
    this.quantityLiters = 0,
    this.quantityMl = 0,
    this.rate = 0,
    required this.date,
    this.createdAt,
  });

  factory MilkAssignment.fromJson(Map<String, dynamic> json) {
    return MilkAssignment(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      milkType: json['milk_type'] as String,
      quantityLiters: json['quantity_liters'] ?? 0,
      quantityMl: json['quantity_ml'] ?? 0,
      rate: json['rate'] ?? 0,
      date: DateTime.parse(json['date'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'seller_id': sellerId,
        'milk_type': milkType,
        'quantity_liters': quantityLiters,
        'quantity_ml': quantityMl,
        'rate': rate,
        'date': date.toIso8601String().split('T')[0],
      };

  double get totalLiters =>
      quantityLiters.toDouble() + (quantityMl.toDouble() / 1000);
}
