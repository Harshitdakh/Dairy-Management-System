import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

class ExploreProductsScreen extends StatelessWidget {
  const ExploreProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = [
      _Product('Fresh Cow Milk', 'Pure cow milk, delivered daily', '₹60/L',
          Icons.water_drop, AppTheme.primary),
      _Product('Buffalo Milk', 'Rich & creamy buffalo milk', '₹70/L',
          Icons.water_drop, AppTheme.success),
      _Product('Mixed Milk', 'Blend of cow & buffalo', '₹65/L',
          Icons.water_drop, AppTheme.amber),
      _Product('Paneer', 'Fresh cottage cheese', '₹320/kg',
          Icons.restaurant, AppTheme.error),
      _Product('Curd', 'Thick homemade curd', '₹50/kg',
          Icons.soup_kitchen, AppTheme.cyan),
      _Product('Ghee', 'Pure desi ghee', '₹600/L',
          Icons.local_fire_department, AppTheme.amber),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Explore Products',
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.85,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final p = products[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(p.icon, color: p.color, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  p.name,
                  style: GoogleFonts.workSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  p.description,
                  style: GoogleFonts.workSans(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  p.price,
                  style: GoogleFonts.workSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Product {
  final String name;
  final String description;
  final String price;
  final IconData icon;
  final Color color;

  const _Product(
      this.name, this.description, this.price, this.icon, this.color);
}
