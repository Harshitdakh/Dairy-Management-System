import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milk_hub/models/customer.dart';
import 'package:milk_hub/providers/route_provider.dart';
import 'package:milk_hub/providers/customer_provider.dart';

import '../helpers/in_memory_dairy_data_store.dart';
import '../helpers/in_memory_route_repository.dart';
import '../helpers/in_memory_customer_repository.dart';
import '../helpers/dairy_test_fixtures.dart';

void main() {
  late InMemoryDairyDataStore dataStore;
  late InMemoryRouteRepository routeRepo;
  late InMemoryCustomerRepository customerRepo;

  setUp(() {
    dataStore = InMemoryDairyDataStore();
    dataStore.seedDefaults();
    routeRepo = InMemoryRouteRepository(dataStore);
    customerRepo = InMemoryCustomerRepository(dataStore);
  });

  // ────────────────────────────────────────────────────────────
  // GROUP 1: ROUTE CRUD OPERATIONS
  // ────────────────────────────────────────────────────────────
  group('Group 1: Route CRUD Operations', () {
    test('Create new route with morning, evening, or both shifts', () async {
      final morningRoute = await routeRepo.createRoute(
        name: 'Model Town Morning',
        sellerId: DairyTestFixtures.seller1Id,
        shift: 'morning',
        description: 'Morning route covering Model Town blocks A-D',
      );
      expect(morningRoute.id, startsWith('route-'));
      expect(morningRoute.name, equals('Model Town Morning'));
      expect(morningRoute.shift, equals('morning'));
      expect(morningRoute.status, equals('active'));
      expect(morningRoute.sellerId, equals(DairyTestFixtures.seller1Id));
      expect(morningRoute.description, contains('Model Town'));

      final eveningRoute = await routeRepo.createRoute(
        name: 'Raja Garden Evening',
        sellerId: DairyTestFixtures.seller1Id,
        shift: 'evening',
        description: 'Evening route for market area',
      );
      expect(eveningRoute.shift, equals('evening'));
      expect(eveningRoute.status, equals('active'));

      final bothRoute = await routeRepo.createRoute(
        name: 'Civil Lines Dual Shift',
        sellerId: DairyTestFixtures.seller1Id,
        shift: 'both',
        description: 'Dual shift distribution',
      );
      expect(bothRoute.shift, equals('both'));
      expect(bothRoute.status, equals('active'));
    });

    test('Create unassigned route for owner-seller direct delivery', () async {
      final soloRoute = await routeRepo.createRoute(
        name: 'North Ward Direct Route',
        sellerId: null, // Unassigned seller (solo owner delivery)
        shift: 'both',
        description: 'Direct delivery run managed personally by dairy owner',
      );

      expect(soloRoute.id, isNotEmpty);
      expect(soloRoute.name, equals('North Ward Direct Route'));
      expect(soloRoute.sellerId, isNull);
      expect(soloRoute.shift, equals('both'));
      expect(soloRoute.status, equals('active'));

      final retrieved = await routeRepo.getRouteById(soloRoute.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.sellerId, isNull);
    });

    test('getAllRoutes returns routes sorted alphabetically by name', () async {
      final allRoutes = await routeRepo.getAllRoutes();
      expect(allRoutes.length, greaterThanOrEqualTo(3));

      for (int i = 0; i < allRoutes.length - 1; i++) {
        final current = allRoutes[i].name;
        final next = allRoutes[i + 1].name;
        expect(current.compareTo(next), lessThanOrEqualTo(0),
            reason: 'Routes must be sorted alphabetically by name: "$current" <= "$next"');
      }
    });

    test('getRoutesBySeller isolates routes assigned to specific seller', () async {
      final seller1Routes =
          await routeRepo.getRoutesBySeller(DairyTestFixtures.seller1Id);
      expect(seller1Routes, isNotEmpty);
      for (final route in seller1Routes) {
        expect(route.sellerId, equals(DairyTestFixtures.seller1Id));
      }

      final ownerRoutes =
          await routeRepo.getRoutesBySeller(DairyTestFixtures.adminOwnerId);
      expect(ownerRoutes, isNotEmpty);
      for (final route in ownerRoutes) {
        expect(route.sellerId, equals(DairyTestFixtures.adminOwnerId));
      }

      final nonexistentRoutes =
          await routeRepo.getRoutesBySeller('non-existent-seller');
      expect(nonexistentRoutes, isEmpty);
    });

    test('getRouteById returns correct route or null if nonexistent', () async {
      final route1 = await routeRepo.getRouteById('route-01');
      expect(route1, isNotNull);
      expect(route1!.id, equals('route-01'));
      expect(route1.shift, equals('morning'));

      final nonExistent = await routeRepo.getRouteById('route-missing-xyz');
      expect(nonExistent, isNull);
    });

    test('updateRoute modifies name, shift, status, and description', () async {
      final original = await routeRepo.getRouteById('route-01');
      expect(original, isNotNull);

      final modified = original!.copyWith(
        name: 'वार्ड 3 प्रभात फेरी (Updated Name)',
        shift: 'both',
        status: 'inactive',
        description: 'Updated operating schedule and coverage',
      );
      await routeRepo.updateRoute(modified);

      final retrieved = await routeRepo.getRouteById('route-01');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('वार्ड 3 प्रभात फेरी (Updated Name)'));
      expect(retrieved.shift, equals('both'));
      expect(retrieved.status, equals('inactive'));
      expect(retrieved.description, equals('Updated operating schedule and coverage'));
    });

    test('deleteRoute unassigns customer route_id and deliverySequence without deleting customer', () async {
      // Confirm route-01 has assigned customers
      final initialCustomers =
          await customerRepo.getCustomersByRoute('route-01');
      expect(initialCustomers, isNotEmpty);
      final affectedCustomerIds = initialCustomers.map((c) => c.id).toList();

      // Delete route-01
      await routeRepo.deleteRoute('route-01');

      // Verify route is removed
      final deletedRoute = await routeRepo.getRouteById('route-01');
      expect(deletedRoute, isNull);

      // Verify customers are unassigned (routeId: null, deliverySequence: 0), not deleted
      for (final customerId in affectedCustomerIds) {
        final customer = dataStore.customers[customerId];
        expect(customer, isNotNull,
            reason: 'Customer record must not be deleted when route is removed');
        expect(customer!.routeId, isNull,
            reason: 'Customer routeId must be set to null');
        expect(customer.deliverySequence, equals(0),
            reason: 'Customer deliverySequence must be reset to 0');
      }

      // Querying customers on deleted route returns empty list
      final remainingOnRoute =
          await customerRepo.getCustomersByRoute('route-01');
      expect(remainingOnRoute, isEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────
  // GROUP 2: CUSTOMER STOP SEQUENCING (1..N)
  // ────────────────────────────────────────────────────────────
  group('Group 2: Customer Stop Sequencing (1..N)', () {
    test('Default customer sequence reflects 1..N order along route', () async {
      final customers = await customerRepo.getCustomersByRoute('route-01');
      expect(customers.length, greaterThanOrEqualTo(5));

      for (int i = 0; i < customers.length; i++) {
        expect(customers[i].deliverySequence, equals(i + 1),
            reason: 'Customer stop at index $i must have sequence ${i + 1}');
      }
    });

    test('updateCustomerSequence re-indexes customer sequence strictly from 1 to N', () async {
      final initial = await customerRepo.getCustomersByRoute('route-01');
      final initialIds = initial.map((c) => c.id).toList();

      // Reverse order of customer stops
      final reversedIds = initialIds.reversed.toList();
      await routeRepo.updateCustomerSequence(reversedIds);

      final updated = await customerRepo.getCustomersByRoute('route-01');
      expect(updated.length, equals(reversedIds.length));

      // First customer should now be the former last customer
      expect(updated.first.id, equals(reversedIds.first));
      expect(updated.first.deliverySequence, equals(1));

      // Last customer should now be the former first customer
      expect(updated.last.id, equals(reversedIds.last));
      expect(updated.last.deliverySequence, equals(reversedIds.length));

      // Every customer in order must strictly have deliverySequence = index + 1
      for (int i = 0; i < updated.length; i++) {
        expect(updated[i].id, equals(reversedIds[i]));
        expect(updated[i].deliverySequence, equals(i + 1));
      }
    });

    test('Reordering moves last customer to first position and preserves order', () async {
      final initial = await customerRepo.getCustomersByRoute('route-01');
      final lastCustomer = initial.last;

      // Move last customer to head: [last, 1st, 2nd, ...]
      final reorderedIds = [
        lastCustomer.id,
        ...initial.sublist(0, initial.length - 1).map((c) => c.id),
      ];
      await routeRepo.updateCustomerSequence(reorderedIds);

      final updated = await customerRepo.getCustomersByRoute('route-01');
      expect(updated.first.id, equals(lastCustomer.id));
      expect(updated.first.deliverySequence, equals(1));

      for (int i = 0; i < updated.length; i++) {
        expect(updated[i].deliverySequence, equals(i + 1));
      }
    });

    test('Reordering handles arbitrary customer permutations without gaps or duplicate sequences', () async {
      // Arbitrary custom order permutation
      final permutation = [
        'cust-103',
        'cust-105',
        'cust-101',
        'cust-201',
        'cust-102',
        'cust-104',
      ];
      await routeRepo.updateCustomerSequence(permutation);

      final updated = await customerRepo.getCustomersByRoute('route-01');
      final sequences = updated.map((c) => c.deliverySequence).toList();

      expect(sequences, equals([1, 2, 3, 4, 5, 6]));
      // Verify no duplicate sequence values
      expect(sequences.toSet().length, equals(sequences.length));

      for (int i = 0; i < permutation.length; i++) {
        final cust = updated.firstWhere((c) => c.id == permutation[i]);
        expect(cust.deliverySequence, equals(i + 1));
      }
    });

    test('assignCustomerToRoute updates customer routeId, deliverySequence, and shift', () async {
      // Add unassigned customer
      dataStore.customers['cust-new'] = Customer(
        id: 'cust-new',
        userId: 'u-new',
        sellerId: DairyTestFixtures.seller1Id,
        routeId: null,
        deliverySequence: 0,
        deliveryShift: 'morning',
        fullName: 'New Stop Customer',
        phone: '9876500001',
      );

      // Assign to route-02 at stop #4 with evening shift
      await routeRepo.assignCustomerToRoute(
        customerId: 'cust-new',
        routeId: 'route-02',
        sequence: 4,
        shift: 'evening',
      );

      final assigned = dataStore.customers['cust-new'];
      expect(assigned, isNotNull);
      expect(assigned!.routeId, equals('route-02'));
      expect(assigned.deliverySequence, equals(4));
      expect(assigned.deliveryShift, equals('evening'));

      // Unassign customer
      await routeRepo.assignCustomerToRoute(
        customerId: 'cust-new',
        routeId: null,
        sequence: 0,
      );

      final unassigned = dataStore.customers['cust-new'];
      expect(unassigned!.routeId, isNull);
      expect(unassigned.deliverySequence, equals(0));
    });
  });

  // ────────────────────────────────────────────────────────────
  // GROUP 3: SHIFT SEGREGATION & MULTI-SHIFT ROUTE FILTERING
  // ────────────────────────────────────────────────────────────
  group('Group 3: Shift Segregation & Multi-Shift Route Filtering', () {
    setUp(() {
      // Seed customers with distinct shifts on route-03
      dataStore.customers['c-morn'] = Customer(
        id: 'c-morn',
        userId: 'u-morn',
        sellerId: DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        deliverySequence: 1,
        deliveryShift: 'morning',
        fullName: 'Morning Only Customer',
      );
      dataStore.customers['c-eve'] = Customer(
        id: 'c-eve',
        userId: 'u-eve',
        sellerId: DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        deliverySequence: 2,
        deliveryShift: 'evening',
        fullName: 'Evening Only Customer',
      );
      dataStore.customers['c-both'] = Customer(
        id: 'c-both',
        userId: 'u-both',
        sellerId: DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        deliverySequence: 3,
        deliveryShift: 'both',
        fullName: 'Morning and Evening Customer',
      );
    });

    test('Morning query retrieves morning-only and both-shift customers', () async {
      final morningList = await customerRepo.getCustomersBySeller(
        DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        shift: 'morning',
      );

      final ids = morningList.map((c) => c.id).toList();
      expect(ids, contains('c-morn'));
      expect(ids, contains('c-both'));
      expect(ids, isNot(contains('c-eve')),
          reason: 'Evening-only customer must NOT appear in morning query');

      for (final c in morningList) {
        expect(['morning', 'both'], contains(c.deliveryShift));
      }
    });

    test('Evening query retrieves evening-only and both-shift customers', () async {
      final eveningList = await customerRepo.getCustomersBySeller(
        DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        shift: 'evening',
      );

      final ids = eveningList.map((c) => c.id).toList();
      expect(ids, contains('c-eve'));
      expect(ids, contains('c-both'));
      expect(ids, isNot(contains('c-morn')),
          reason: 'Morning-only customer must NOT appear in evening query');

      for (final c in eveningList) {
        expect(['evening', 'both'], contains(c.deliveryShift));
      }
    });

    test('Customers with shift="both" appear in both morning and evening delivery runs', () async {
      final morningList = await customerRepo.getCustomersBySeller(
        DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        shift: 'morning',
      );
      final eveningList = await customerRepo.getCustomersBySeller(
        DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        shift: 'evening',
      );

      expect(morningList.any((c) => c.id == 'c-both'), isTrue);
      expect(eveningList.any((c) => c.id == 'c-both'), isTrue);
    });

    test('Customer ordering strictly preserves deliverySequence ASC across shift filters', () async {
      final morningList = await customerRepo.getCustomersBySeller(
        DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        shift: 'morning',
      );
      for (int i = 0; i < morningList.length - 1; i++) {
        expect(
          morningList[i].deliverySequence,
          lessThanOrEqualTo(morningList[i + 1].deliverySequence),
        );
      }

      final eveningList = await customerRepo.getCustomersBySeller(
        DairyTestFixtures.seller1Id,
        routeId: 'route-03',
        shift: 'evening',
      );
      for (int i = 0; i < eveningList.length - 1; i++) {
        expect(
          eveningList[i].deliverySequence,
          lessThanOrEqualTo(eveningList[i + 1].deliverySequence),
        );
      }
    });
  });

  // ────────────────────────────────────────────────────────────
  // GROUP 4: UNIFIED OWNER-SELLER MODE
  // ────────────────────────────────────────────────────────────
  group('Group 4: Unified Owner-Seller Mode', () {
    test('Dairy owner can manage and execute assigned delivery routes directly', () async {
      final ownerRoutes =
          await routeRepo.getRoutesBySeller(DairyTestFixtures.adminOwnerId);
      expect(ownerRoutes, isNotEmpty);

      final northRoute = ownerRoutes.firstWhere((r) => r.id == 'route-north');
      expect(northRoute.name, contains('North Ward'));
      expect(northRoute.sellerId, equals(DairyTestFixtures.adminOwnerId));
      expect(northRoute.shift, equals('morning'));
    });

    test('Owner route customer list maintains stop sequencing without seller proxy', () async {
      // Seed customers on owner route
      dataStore.customers['owner-cust-1'] = Customer(
        id: 'owner-cust-1',
        userId: 'u-oc1',
        sellerId: DairyTestFixtures.adminOwnerId,
        routeId: 'route-north',
        deliverySequence: 1,
        deliveryShift: 'morning',
        fullName: 'Owner Customer 1',
      );
      dataStore.customers['owner-cust-2'] = Customer(
        id: 'owner-cust-2',
        userId: 'u-oc2',
        sellerId: DairyTestFixtures.adminOwnerId,
        routeId: 'route-north',
        deliverySequence: 2,
        deliveryShift: 'morning',
        fullName: 'Owner Customer 2',
      );

      final customers = await customerRepo.getCustomersByRoute('route-north');
      expect(customers.length, equals(2));
      expect(customers[0].deliverySequence, equals(1));
      expect(customers[1].deliverySequence, equals(2));

      // Swap sequence
      await routeRepo.updateCustomerSequence(['owner-cust-2', 'owner-cust-1']);

      final reordered = await customerRepo.getCustomersByRoute('route-north');
      expect(reordered[0].id, equals('owner-cust-2'));
      expect(reordered[0].deliverySequence, equals(1));
      expect(reordered[1].id, equals('owner-cust-1'));
      expect(reordered[1].deliverySequence, equals(2));
    });
  });

  // ────────────────────────────────────────────────────────────
  // GROUP 5: RIVERPOD PROVIDER INTEGRATION
  // ────────────────────────────────────────────────────────────
  group('Group 5: Riverpod Provider Integration', () {
    test('allRoutesProvider resolves list from RouteRepository override', () async {
      final container = ProviderContainer(
        overrides: [
          routeRepositoryProvider.overrideWithValue(routeRepo),
        ],
      );
      addTearDown(container.dispose);

      final routes = await container.read(allRoutesProvider.future);
      expect(routes, isNotEmpty);
      expect(routes.length, equals(dataStore.routes.length));
    });

    test('routesBySellerProvider filters by seller ID correctly', () async {
      final container = ProviderContainer(
        overrides: [
          routeRepositoryProvider.overrideWithValue(routeRepo),
        ],
      );
      addTearDown(container.dispose);

      final routes = await container
          .read(routesBySellerProvider(DairyTestFixtures.seller1Id).future);
      expect(routes, isNotEmpty);
      for (final r in routes) {
        expect(r.sellerId, equals(DairyTestFixtures.seller1Id));
      }
    });

    test('customersByRouteProvider queries customer repository by route ID', () async {
      final container = ProviderContainer(
        overrides: [
          customerRepositoryProvider.overrideWithValue(customerRepo),
        ],
      );
      addTearDown(container.dispose);

      final customers =
          await container.read(customersByRouteProvider('route-01').future);
      expect(customers, isNotEmpty);
      for (int i = 0; i < customers.length; i++) {
        expect(customers[i].routeId, equals('route-01'));
        expect(customers[i].deliverySequence, equals(i + 1));
      }
    });

    test('routeByIdProvider returns correct route or null if nonexistent', () async {
      final container = ProviderContainer(
        overrides: [
          routeRepositoryProvider.overrideWithValue(routeRepo),
        ],
      );
      addTearDown(container.dispose);

      final route = await container.read(routeByIdProvider('route-01').future);
      expect(route, isNotNull);
      expect(route!.id, equals('route-01'));

      final nonExistent =
          await container.read(routeByIdProvider('missing-route-id').future);
      expect(nonExistent, isNull);
    });
  });
}
