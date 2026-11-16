import 'package:milk_hub/models/collection_entry.dart';
import 'package:milk_hub/models/customer.dart';
import 'package:milk_hub/models/customer_bill.dart';
import 'package:milk_hub/models/delivery_pause.dart';
import 'package:milk_hub/models/delivery_route.dart';
import 'package:milk_hub/models/milk_delivery.dart';

import 'dairy_test_fixtures.dart';

/// Central in-memory state engine for opaque-box testing.
/// Provides zero-network deterministic storage matching PostgreSQL tables.
class InMemoryDairyDataStore {
  final Map<String, DeliveryRoute> routes = {};
  final Map<String, Customer> customers = {};
  final Map<String, DeliveryPause> pauses = {};
  final List<MilkDelivery> deliveries = [];
  final Map<String, CustomerBill> bills = {};
  final List<CollectionEntry> collections = [];

  void reset() {
    routes.clear();
    customers.clear();
    pauses.clear();
    deliveries.clear();
    bills.clear();
    collections.clear();
  }

  void seedDefaults() {
    reset();

    // Seed Routes
    final r1 = DairyTestFixtures.createRoute1();
    final r2 = DairyTestFixtures.createRoute2();
    final r3 = DairyTestFixtures.createRoute3();
    final rNorth = DairyTestFixtures.createNorthRoute();
    final rSouth = DairyTestFixtures.createSouthRoute();
    routes[r1.id] = r1;
    routes[r2.id] = r2;
    routes[r3.id] = r3;
    routes[rNorth.id] = rNorth;
    routes[rSouth.id] = rSouth;

    // Seed Customers for Route 1
    final c1 = DairyTestFixtures.createCustomer1();
    final c2 = DairyTestFixtures.createCustomer2();
    final c3 = DairyTestFixtures.createCustomer3();
    final c4 = DairyTestFixtures.createCustomer4();
    final c5 = DairyTestFixtures.createCustomer5();
    final cSunita = DairyTestFixtures.createSunitaCustomer();

    customers[c1.id] = c1;
    customers[c2.id] = c2;
    customers[c3.id] = c3;
    customers[c4.id] = c4;
    customers[c5.id] = c5;
    customers[cSunita.id] = cSunita;
  }

  String billKey(String customerId, DateTime month) {
    return '${customerId}_${month.year}_${month.month}';
  }

  void upsertBill(CustomerBill bill) {
    bills[billKey(bill.customerId, bill.billMonth)] = bill;
  }

  CustomerBill? getBill(String customerId, DateTime month) {
    return bills[billKey(customerId, month)];
  }
}
