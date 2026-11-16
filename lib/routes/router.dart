import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/admin/admin_shell.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/seller_management_screen.dart';
import '../features/admin/seller_detail_screen.dart';
import '../features/admin/admin_analytics_screen.dart';
import '../features/admin/admin_profile_screen.dart';
import '../features/admin/add_seller_screen.dart';
import '../features/admin/add_customer_screen.dart';
import '../features/admin/assign_milk_screen.dart';
import '../features/admin/customer_management_screen.dart';
import '../features/admin/customer_detail_screen.dart';
import '../features/admin/edit_seller_screen.dart';
import '../features/admin/edit_customer_screen.dart';
import '../features/admin/route_management_screen.dart';
import '../features/seller/seller_shell.dart';
import '../features/seller/seller_home_screen.dart';
import '../features/seller/route_customers_screen.dart';
import '../features/seller/seller_analytics_screen.dart';
import '../features/seller/seller_profile_screen.dart';
import '../features/seller/record_sale_screen.dart';
import '../features/customer/customer_shell.dart';
import '../features/customer/customer_home_screen.dart';
import '../features/customer/consumption_history_screen.dart';
import '../features/customer/customer_analytics_screen.dart';
import '../features/customer/customer_profile_screen.dart';
import '../features/common/notifications_screen.dart';
import '../features/common/explore_products_screen.dart';
import '../features/common/monthly_income_report_screen.dart';
import '../features/common/collections_screen.dart';
import '../features/common/reports_dashboard_screen.dart';
import '../features/common/settings_screen.dart';
import '../features/common/monthly_calendar_screen.dart';
import '../features/payment/fake_payment_gateway.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _adminShellKey = GlobalKey<NavigatorState>();
final _sellerShellKey = GlobalKey<NavigatorState>();
final _customerShellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // Splash
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      // Auth
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),

      // ── Admin Shell (Bottom Nav) ──
      ShellRoute(
        navigatorKey: _adminShellKey,
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/sellers',
            builder: (context, state) => const SellerManagementScreen(),
          ),
          GoRoute(
            path: '/admin/analytics',
            builder: (context, state) => const AdminAnalyticsScreen(),
          ),
          GoRoute(
            path: '/admin/profile',
            builder: (context, state) => const AdminProfileScreen(),
          ),
        ],
      ),
      // Admin push routes (full screen, no bottom nav)
      GoRoute(
        path: '/admin/add-seller',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddSellerScreen(),
      ),
      GoRoute(
        path: '/admin/edit-seller',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => EditSellerScreen(
          sellerId: state.uri.queryParameters['sellerId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/admin/add-customer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddCustomerScreen(),
      ),
      GoRoute(
        path: '/admin/edit-customer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => EditCustomerScreen(
          customerId: state.uri.queryParameters['customerId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/admin/seller-detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => SellerDetailScreen(
          sellerId: state.uri.queryParameters['sellerId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/admin/customer-detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => CustomerDetailScreen(
          customerId: state.uri.queryParameters['customerId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/admin/assign-milk',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AssignMilkScreen(),
      ),
      GoRoute(
        path: '/admin/customers',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CustomerManagementScreen(),
      ),
      GoRoute(
        path: '/admin/routes',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RouteManagementScreen(),
      ),
      GoRoute(
        path: '/admin/route-delivery',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RouteCustomersScreen(
          routeId: state.uri.queryParameters['routeId'],
          shift: state.uri.queryParameters['shift'],
        ),
      ),

      // ── Seller Shell (Bottom Nav) ──
      ShellRoute(
        navigatorKey: _sellerShellKey,
        builder: (context, state, child) => SellerShell(child: child),
        routes: [
          GoRoute(
            path: '/seller',
            builder: (context, state) => const SellerHomeScreen(),
          ),
          GoRoute(
            path: '/seller/customers',
            builder: (context, state) => RouteCustomersScreen(
              routeId: state.uri.queryParameters['routeId'],
              shift: state.uri.queryParameters['shift'],
            ),
          ),
          GoRoute(
            path: '/seller/analytics',
            builder: (context, state) => const SellerAnalyticsScreen(),
          ),
          GoRoute(
            path: '/seller/profile',
            builder: (context, state) => const SellerProfileScreen(),
          ),
        ],
      ),
      // Seller push routes
      GoRoute(
        path: '/seller/record-sale',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RecordSaleScreen(
          customerId: state.uri.queryParameters['customerId'] ?? '',
          customerName: state.uri.queryParameters['customerName'] ?? '',
          milkType: state.uri.queryParameters['milkType'] ?? 'cow',
          ratePerLiter: double.tryParse(
                  state.uri.queryParameters['rate'] ?? '0') ??
              0,
        ),
      ),

      // ── Customer Shell (Bottom Nav) ──
      ShellRoute(
        navigatorKey: _customerShellKey,
        builder: (context, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(
            path: '/customer',
            builder: (context, state) => const CustomerHomeScreen(),
          ),
          GoRoute(
            path: '/customer/history',
            builder: (context, state) => const ConsumptionHistoryScreen(),
          ),
          GoRoute(
            path: '/customer/analytics',
            builder: (context, state) => const CustomerAnalyticsScreen(),
          ),
          GoRoute(
            path: '/customer/profile',
            builder: (context, state) => const CustomerProfileScreen(),
          ),
        ],
      ),

      // ── Common routes ──
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/explore-products',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ExploreProductsScreen(),
      ),
      GoRoute(
        path: '/reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportsDashboardScreen(),
      ),
      GoRoute(
        path: '/reports/monthly-income',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MonthlyIncomeReportScreen(),
      ),
      GoRoute(
        path: '/reports/collections',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CollectionsScreen(),
      ),
      GoRoute(
        path: '/calendar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MonthlyCalendarScreen(),
      ),
      GoRoute(
        path: '/payment/fake',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => FakePaymentGateway(
          customerId: state.uri.queryParameters['customerId'] ?? '',
          billMonth: DateTime.tryParse(state.uri.queryParameters['billMonth'] ?? '') ?? DateTime(DateTime.now().year, DateTime.now().month),
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
