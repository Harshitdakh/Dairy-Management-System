import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/milk_assignment.dart';
import '../models/milk_sale.dart';

class MilkRepository {
  final SupabaseClient _client;

  MilkRepository(this._client);

  // ── Assignments ──

  /// Get all assignments (admin).
  Future<List<MilkAssignment>> getAllAssignments({DateTime? date}) async {
    var query = _client.from('milk_assignments').select();
    if (date != null) {
      query = query.eq('date', date.toIso8601String().split('T')[0]);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => MilkAssignment.fromJson(e)).toList();
  }

  /// Get assignments for a seller.
  Future<List<MilkAssignment>> getAssignmentsBySeller(String sellerId,
      {DateTime? date}) async {
    var query =
        _client.from('milk_assignments').select().eq('seller_id', sellerId);
    if (date != null) {
      query = query.eq('date', date.toIso8601String().split('T')[0]);
    }
    final data = await query.order('date', ascending: false);
    return (data as List).map((e) => MilkAssignment.fromJson(e)).toList();
  }

  /// Create a milk assignment (admin).
  Future<MilkAssignment> createAssignment({
    required String sellerId,
    required String milkType,
    required num quantityLiters,
    required num quantityMl,
    required num rate,
    required DateTime date,
  }) async {
    final data = await _client.from('milk_assignments').insert({
      'seller_id': sellerId,
      'milk_type': milkType,
      'quantity_liters': quantityLiters,
      'quantity_ml': quantityMl,
      'rate': rate,
      'date': date.toIso8601String().split('T')[0],
    }).select().single();

    return MilkAssignment.fromJson(data);
  }

  // ── Sales ──

  /// Get all sales (admin).
  Future<List<MilkSale>> getAllSales({DateTime? date}) async {
    var query = _client
        .from('milk_sales')
        .select('*, customers(profiles(full_name))');
    if (date != null) {
      query = query.eq('sale_date', date.toIso8601String().split('T')[0]);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => MilkSale.fromJson(e)).toList();
  }

  /// Get sales by seller.
  Future<List<MilkSale>> getSalesBySeller(String sellerId,
      {DateTime? date}) async {
    var query = _client
        .from('milk_sales')
        .select('*, customers(profiles(full_name))')
        .eq('seller_id', sellerId);
    if (date != null) {
      query = query.eq('sale_date', date.toIso8601String().split('T')[0]);
    }
    final data = await query.order('sale_date', ascending: false);
    return (data as List).map((e) => MilkSale.fromJson(e)).toList();
  }

  /// Get sales for a customer.
  Future<List<MilkSale>> getSalesByCustomer(String customerId,
      {DateTime? date}) async {
    var query = _client
        .from('milk_sales')
        .select()
        .eq('customer_id', customerId);
    if (date != null) {
      query = query.eq('sale_date', date.toIso8601String().split('T')[0]);
    }
    final data = await query.order('sale_date', ascending: false);
    return (data as List).map((e) => MilkSale.fromJson(e)).toList();
  }

  /// Record a new sale (seller).
  Future<MilkSale> recordSale({
    required String sellerId,
    required String customerId,
    required String milkType,
    required num quantityLiters,
    required num quantityMl,
    required num totalAmount,
    required DateTime saleDate,
    String? notes,
  }) async {
    final data = await _client.from('milk_sales').insert({
      'seller_id': sellerId,
      'customer_id': customerId,
      'milk_type': milkType,
      'quantity_liters': quantityLiters,
      'quantity_ml': quantityMl,
      'total_amount': totalAmount,
      'sale_date': saleDate.toIso8601String().split('T')[0],
      'notes': notes,
    }).select().single();

    return MilkSale.fromJson(data);
  }

  // ── Aggregated Stats ──

  /// Get today's total volume sold (all sellers).
  Future<double> getTodayTotalVolume() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await _client
        .from('milk_sales')
        .select('quantity_liters, quantity_ml')
        .eq('sale_date', today);

    double total = 0;
    for (final row in data as List) {
      total += (row['quantity_liters'] as num).toDouble() +
          ((row['quantity_ml'] as num).toDouble() / 1000);
    }
    return total;
  }

  /// Get today's total revenue.
  Future<double> getTodayRevenue() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await _client
        .from('milk_sales')
        .select('total_amount')
        .eq('sale_date', today);

    double total = 0;
    for (final row in data as List) {
      total += (row['total_amount'] as num).toDouble();
    }
    return total;
  }

  /// Get total sold by a seller today.
  Future<double> getSellerTodaySold(String sellerId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await _client
        .from('milk_sales')
        .select('quantity_liters, quantity_ml')
        .eq('seller_id', sellerId)
        .eq('sale_date', today);

    double total = 0;
    for (final row in data as List) {
      total += (row['quantity_liters'] as num).toDouble() +
          ((row['quantity_ml'] as num).toDouble() / 1000);
    }
    return total;
  }
}
