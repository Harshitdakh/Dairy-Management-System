import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../providers/seller_provider.dart';
import '../../providers/milk_provider.dart';

class SellerAnalyticsScreen extends ConsumerWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerAsync = ref.watch(currentSellerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics',
                style: GoogleFonts.workSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your sales performance',
                style: GoogleFonts.workSans(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              sellerAsync.when(
                data: (seller) {
                  if (seller == null) return const SizedBox();
                  final salesAsync =
                      ref.watch(salesBySellerProvider(seller.id));

                  return salesAsync.when(
                    data: (sales) {
                      // Calculate summary
                      double totalVolume = 0;
                      double totalRevenue = 0;
                      for (final sale in sales) {
                        totalVolume += sale.totalLiters;
                        totalRevenue += sale.totalAmount.toDouble();
                      }

                      return Column(
                        children: [
                          // Summary row
                          Row(
                            children: [
                              _summaryCard(
                                'Total Volume',
                                '${totalVolume.toStringAsFixed(1)} L',
                                Icons.water_drop,
                                AppTheme.primary,
                              ),
                              const SizedBox(width: 12),
                              _summaryCard(
                                'Total Revenue',
                                '₹${totalRevenue.toStringAsFixed(0)}',
                                Icons.account_balance_wallet,
                                AppTheme.success,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Sales chart
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sales Trend',
                                  style: GoogleFonts.workSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 200,
                                  child: _buildChart(sales),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => Text('$e'),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.workSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.workSans(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List sales) {
    if (sales.isEmpty) {
      return Center(
        child: Text(
          'No sales data yet',
          style: GoogleFonts.workSans(color: AppTheme.textSecondary),
        ),
      );
    }

    // Group sales by date for last 7 days
    final now = DateTime.now();
    final spots = <FlSpot>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      double dayTotal = 0;
      for (final sale in sales) {
        if (sale.saleDate.year == date.year &&
            sale.saleDate.month == date.month &&
            sale.saleDate.day == date.day) {
          dayTotal += sale.totalLiters;
        }
      }
      spots.add(FlSpot((6 - i).toDouble(), dayTotal));
    }

    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}L',
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
