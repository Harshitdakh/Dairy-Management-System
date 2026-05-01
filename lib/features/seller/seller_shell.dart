import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SellerShell extends StatelessWidget {
  final Widget child;
  const SellerShell({super.key, required this.child});

  int _getIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc == '/seller') return 0;
    if (loc == '/seller/customers') return 1;
    if (loc == '/seller/analytics') return 2;
    if (loc == '/seller/profile') return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getIndex(context),
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/seller');
              break;
            case 1:
              context.go('/seller/customers');
              break;
            case 2:
              context.go('/seller/analytics');
              break;
            case 3:
              context.go('/seller/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
