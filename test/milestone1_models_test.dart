import 'package:flutter_test/flutter_test.dart';
import 'package:milk_hub/models/customer.dart';
import 'package:milk_hub/models/delivery_pause.dart';
import 'package:milk_hub/models/delivery_route.dart';
import 'package:milk_hub/models/milk_delivery.dart';

void main() {
  group('DeliveryRoute Model', () {
    test('fromJson and toJson serialization', () {
      final json = {
        'id': 'route-123',
        'name': 'Civil Lines Route',
        'seller_id': 'seller-456',
        'created_by': 'user-789',
        'shift': 'morning',
        'status': 'active',
        'description': 'Main morning route',
        'created_at': '2026-11-16T06:00:00.000Z',
        'updated_at': '2026-11-16T06:00:00.000Z',
        'sellers': {
          'profiles': {'full_name': 'Ramesh Kumar'}
        },
        'customers': [{'id': 'c1'}, {'id': 'c2'}]
      };

      final route = DeliveryRoute.fromJson(json);

      expect(route.id, 'route-123');
      expect(route.name, 'Civil Lines Route');
      expect(route.sellerId, 'seller-456');
      expect(route.shift, 'morning');
      expect(route.status, 'active');
      expect(route.sellerName, 'Ramesh Kumar');
      expect(route.customerCount, 2);

      final outJson = route.toJson();
      expect(outJson['name'], 'Civil Lines Route');
      expect(outJson['seller_id'], 'seller-456');
      expect(outJson['shift'], 'morning');
      expect(outJson['status'], 'active');
    });

    test('copyWith updates specified fields', () {
      final route = DeliveryRoute(
        id: 'r1',
        name: 'Old Route',
        shift: 'morning',
      );

      final updated = route.copyWith(
        name: 'New Route',
        shift: 'evening',
        status: 'inactive',
      );

      expect(updated.id, 'r1');
      expect(updated.name, 'New Route');
      expect(updated.shift, 'evening');
      expect(updated.status, 'inactive');
    });
  });

  group('MilkDelivery Model', () {
    test('fromJson, toJson, totalLiters calculation', () {
      final json = {
        'id': 'del-001',
        'seller_id': 'seller-01',
        'customer_id': 'cust-01',
        'sale_id': 'sale-01',
        'delivery_date': '2026-11-16',
        'milk_type': 'cow',
        'quantity_liters': 2,
        'quantity_ml': 500,
        'rate': 60,
        'amount': 150,
        'status': 'delivered',
        'shift': 'evening',
        'notes': 'Delivered early',
      };

      final delivery = MilkDelivery.fromJson(json);

      expect(delivery.id, 'del-001');
      expect(delivery.quantityLiters, 2);
      expect(delivery.quantityMl, 500);
      expect(delivery.totalLiters, 2.5);
      expect(delivery.shift, 'evening');
      expect(delivery.isDelivered, isTrue);
      expect(delivery.isSkipped, isFalse);

      final outJson = delivery.toJson();
      expect(outJson['delivery_date'], '2026-11-16');
      expect(outJson['shift'], 'evening');
      expect(outJson['quantity_liters'], 2);
      expect(outJson['quantity_ml'], 500);
      expect(outJson['amount'], 150);
    });

    test('skipped delivery flags', () {
      final delivery = MilkDelivery(
        id: 'del-002',
        sellerId: 's1',
        customerId: 'c1',
        deliveryDate: DateTime(2026, 11, 16),
        milkType: 'buffalo',
        status: 'skipped',
        shift: 'morning',
      );

      expect(delivery.isSkipped, isTrue);
      expect(delivery.isDelivered, isFalse);
      expect(delivery.totalLiters, 0.0);
    });
  });

  group('DeliveryPause Model', () {
    test('isActiveOn correctly evaluates date boundaries and status', () {
      final pause = DeliveryPause(
        id: 'pause-1',
        customerId: 'cust-1',
        startDate: DateTime(2026, 11, 15),
        endDate: DateTime(2026, 11, 20),
        status: 'approved',
      );

      expect(pause.isApproved, isTrue);
      expect(pause.isPending, isFalse);

      // Boundary tests
      expect(pause.isActiveOn(DateTime(2026, 11, 14)), isFalse);
      expect(pause.isActiveOn(DateTime(2026, 11, 15)), isTrue);
      expect(pause.isActiveOn(DateTime(2026, 11, 18, 14, 30)), isTrue);
      expect(pause.isActiveOn(DateTime(2026, 11, 20)), isTrue);
      expect(pause.isActiveOn(DateTime(2026, 11, 21)), isFalse);
    });

    test('isActiveOn returns false for non-approved pauses', () {
      final pendingPause = DeliveryPause(
        id: 'pause-2',
        customerId: 'cust-1',
        startDate: DateTime(2026, 11, 15),
        endDate: DateTime(2026, 11, 20),
        status: 'pending',
      );

      expect(pendingPause.isPending, isTrue);
      expect(pendingPause.isActiveOn(DateTime(2026, 11, 16)), isFalse);

      final rejectedPause = pendingPause.copyWith(status: 'rejected');
      expect(rejectedPause.isRejected, isTrue);
      expect(rejectedPause.isActiveOn(DateTime(2026, 11, 16)), isFalse);
    });
  });

  group('Customer Model Schema Upgrades', () {
    test('supports routeId, deliverySequence, and deliveryShift', () {
      final json = {
        'id': 'cust-100',
        'user_id': 'usr-100',
        'seller_id': 'seller-100',
        'route_id': 'route-999',
        'delivery_sequence': 5,
        'delivery_shift': 'evening',
        'milk_type': 'cow',
        'rate_per_liter': 55,
        'daily_quantity_liters': 1,
        'daily_quantity_ml': 500,
        'status': 'active',
        'delivery_routes': {'name': 'North Ring Road'},
        'profiles': {'full_name': 'Sunita Sharma', 'phone': '9876543210'}
      };

      final customer = Customer.fromJson(json);

      expect(customer.id, 'cust-100');
      expect(customer.routeId, 'route-999');
      expect(customer.deliverySequence, 5);
      expect(customer.deliveryShift, 'evening');
      expect(customer.routeName, 'North Ring Road');
      expect(customer.fullName, 'Sunita Sharma');
      expect(customer.phone, '9876543210');
      expect(customer.totalDailyLiters, 1.5);

      final outJson = customer.toJson();
      expect(outJson['route_id'], 'route-999');
      expect(outJson['delivery_sequence'], 5);
      expect(outJson['delivery_shift'], 'evening');
    });

    test('copyWith updates delivery sequence and route', () {
      final customer = Customer(
        id: 'cust-1',
        userId: 'usr-1',
        deliverySequence: 1,
        deliveryShift: 'morning',
      );

      final updated = customer.copyWith(
        routeId: 'route-new',
        deliverySequence: 2,
        deliveryShift: 'both',
      );

      expect(updated.routeId, 'route-new');
      expect(updated.deliverySequence, 2);
      expect(updated.deliveryShift, 'both');
    });
  });
}
