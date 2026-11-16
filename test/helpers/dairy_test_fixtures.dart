import 'package:milk_hub/models/customer.dart';
import 'package:milk_hub/models/customer_bill.dart';
import 'package:milk_hub/models/delivery_pause.dart';
import 'package:milk_hub/models/delivery_route.dart';

class DairyTestFixtures {
  // Sellers
  static const String seller1Id = 'seller-01';
  static const String seller1Name = 'Ramesh Doodhwala';
  static const String seller1Dairy = 'Shree Krishna Dairy';
  static const String seller1Upi = 'shreedairy@oksbi';
  static const String seller1Phone = '9876543210';

  static const String seller2Id = 'seller-02';
  static const String seller2Name = 'Gopal Yadav';
  static const String seller2Dairy = 'Gopal Dairy';
  static const String seller2Upi = 'gopal.dairy@upi';
  static const String seller2Phone = '9811122233';

  static const String adminOwnerId = 'admin-owner-01';
  static const String adminOwnerName = 'Suresh Dairy Owner';
  static const String adminOwnerDairy = 'Suresh Dairy';
  static const String adminOwnerUpi = 'suresh.dairy@okaxis';

  // Routes
  static DeliveryRoute createRoute1({String? sellerId}) => DeliveryRoute(
        id: 'route-01',
        name: 'वार्ड 3 प्रभात फेरी (Morning Ward 3)',
        sellerId: sellerId ?? seller1Id,
        shift: 'morning',
        status: 'active',
        description: 'Main bazaar morning delivery route',
        sellerName: seller1Dairy,
      );

  static DeliveryRoute createRoute2({String? sellerId}) => DeliveryRoute(
        id: 'route-02',
        name: 'सिविल लाइंस शाम (Civil Lines Evening)',
        sellerId: sellerId ?? seller1Id,
        shift: 'evening',
        status: 'active',
        description: 'Evening route for Civil lines',
        sellerName: seller1Dairy,
      );

  static DeliveryRoute createRoute3({String? sellerId}) => DeliveryRoute(
        id: 'route-03',
        name: 'आदर्श नगर (Both Shifts)',
        sellerId: sellerId ?? seller1Id,
        shift: 'both',
        status: 'active',
        description: 'Covers morning and evening deliveries',
        sellerName: seller1Dairy,
      );

  static DeliveryRoute createNorthRoute() => DeliveryRoute(
        id: 'route-north',
        name: 'North Ward (उत्तर वार्ड)',
        sellerId: adminOwnerId,
        shift: 'morning',
        status: 'active',
        description: 'North morning deliveries',
        sellerName: adminOwnerDairy,
      );

  static DeliveryRoute createSouthRoute() => DeliveryRoute(
        id: 'route-south',
        name: 'South Ward (दक्षिण वार्ड)',
        sellerId: adminOwnerId,
        shift: 'evening',
        status: 'active',
        description: 'South evening deliveries',
        sellerName: adminOwnerDairy,
      );

  // Customers
  static Customer createCustomer1({int sequence = 1, String? routeId, String shift = 'morning'}) =>
      Customer(
        id: 'cust-101',
        userId: 'user-c101',
        sellerId: seller1Id,
        routeId: routeId ?? 'route-01',
        deliverySequence: sequence,
        deliveryShift: shift,
        routeName: 'वार्ड 3 प्रभात फेरी (Morning Ward 3)',
        location: 'House 12, Lane A',
        milkType: 'cow',
        ratePerLiter: 60.0,
        dailyQuantityLiters: 1,
        dailyQuantityMl: 0,
        fullName: 'Amit Sharma',
        phone: '9876543210',
        sellerName: seller1Dairy,
      );

  static Customer createCustomer2({int sequence = 2, String? routeId, String shift = 'morning'}) =>
      Customer(
        id: 'cust-102',
        userId: 'user-c102',
        sellerId: seller1Id,
        routeId: routeId ?? 'route-01',
        deliverySequence: sequence,
        deliveryShift: shift,
        routeName: 'वार्ड 3 प्रभात फेरी (Morning Ward 3)',
        location: 'Plot 18, Main Road',
        milkType: 'buffalo',
        ratePerLiter: 70.0,
        dailyQuantityLiters: 1,
        dailyQuantityMl: 500,
        fullName: 'Balraj Singh',
        phone: '9812345678',
        sellerName: seller1Dairy,
      );

  static Customer createCustomer3({int sequence = 3, String? routeId, String shift = 'morning'}) =>
      Customer(
        id: 'cust-103',
        userId: 'user-c103',
        sellerId: seller1Id,
        routeId: routeId ?? 'route-01',
        deliverySequence: sequence,
        deliveryShift: shift,
        routeName: 'वार्ड 3 प्रभात फेरी (Morning Ward 3)',
        location: 'Flat 204, Surya Apts',
        milkType: 'cow',
        ratePerLiter: 60.0,
        dailyQuantityLiters: 1,
        dailyQuantityMl: 0,
        fullName: 'Chetan Verma',
        phone: '9898765432',
        sellerName: seller1Dairy,
      );

  static Customer createCustomer4({int sequence = 4, String? routeId, String shift = 'morning'}) =>
      Customer(
        id: 'cust-104',
        userId: 'user-c104',
        sellerId: seller1Id,
        routeId: routeId ?? 'route-01',
        deliverySequence: sequence,
        deliveryShift: shift,
        routeName: 'वार्ड 3 प्रभात फेरी (Morning Ward 3)',
        location: 'House 31, Sector 4',
        milkType: 'cow',
        ratePerLiter: 60.0,
        dailyQuantityLiters: 1,
        dailyQuantityMl: 0,
        fullName: 'Deepak Gupta',
        phone: '9823456789',
        sellerName: seller1Dairy,
      );

  static Customer createCustomer5({int sequence = 5, String? routeId, String shift = 'morning'}) =>
      Customer(
        id: 'cust-105',
        userId: 'user-c105',
        sellerId: seller1Id,
        routeId: routeId ?? 'route-01',
        deliverySequence: sequence,
        deliveryShift: shift,
        routeName: 'वार्ड 3 प्रभात फेरी (Morning Ward 3)',
        location: 'Plot 45, Market Gate',
        milkType: 'buffalo',
        ratePerLiter: 70.0,
        dailyQuantityLiters: 2,
        dailyQuantityMl: 0,
        fullName: 'Vikram Singh',
        phone: '9834567890',
        sellerName: seller1Dairy,
      );

  static Customer createSunitaCustomer({int sequence = 6, String? routeId}) =>
      Customer(
        id: 'cust-201',
        userId: 'user-c201',
        sellerId: seller1Id,
        routeId: routeId ?? 'route-01',
        deliverySequence: sequence,
        deliveryShift: 'morning',
        routeName: 'वार्ड 3 प्रभात फेरी (Morning Ward 3)',
        location: 'Villa 7, Green Enclave',
        milkType: 'cow',
        ratePerLiter: 60.0,
        dailyQuantityLiters: 1,
        dailyQuantityMl: 500,
        fullName: 'Sunita Sharma',
        phone: '9845678901',
        sellerName: seller1Dairy,
      );

  // Default Pauses
  static DeliveryPause createPause({
    String id = 'pause-01',
    String customerId = 'cust-201',
    required DateTime startDate,
    required DateTime endDate,
    String status = 'pending',
    String? reason = 'गाँव जाना है (Going to village)',
  }) =>
      DeliveryPause(
        id: id,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        status: status,
        reason: reason,
        customerName: 'Sunita Sharma',
        customerPhone: '9845678901',
      );

  // Default Bill
  static CustomerBill createBill({
    String id = 'bill-01',
    String customerId = 'cust-101',
    String sellerId = seller1Id,
    required DateTime billMonth,
    num totalQuantityLiters = 30.0,
    num totalAmount = 1800.0,
    num paidAmount = 0.0,
    num pendingAmount = 1800.0,
    String status = 'pending',
  }) =>
      CustomerBill(
        id: id,
        customerId: customerId,
        sellerId: sellerId,
        billMonth: DateTime(billMonth.year, billMonth.month, 1),
        totalQuantityLiters: totalQuantityLiters,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        pendingAmount: pendingAmount,
        status: status,
        customerName: 'Amit Sharma',
        sellerName: seller1Dairy,
      );
}
