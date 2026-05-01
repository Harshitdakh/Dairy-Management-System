import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../providers/customer_provider.dart';
import '../../providers/milk_provider.dart';

class CustomerAnalyticsScreen extends ConsumerWidget {
  const CustomerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(currentCustomerProvider);

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
                'Your consumption insights',
                style: GoogleFonts.workSans(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              customerAsync.when(
                data: (customer) {
                  if (customer == null) return const SizedBox();
                  final salesAsync =
                      ref.watch(salesByCustomerProvider(customer.id));

                  return salesAsync.when(
                    data: (sales) {
                      double totalLiters = 0;
                      double totalSpent = 0;
                      for (final s in sales) {
                        totalLiters += s.totalLiters;
                        totalSpent += s.totalAmount.toDouble();
                      }

                      return Column(
                        children: [
                          // Summary
                          Row(
                            children: [
                              _summaryCard(
                                'Total Consumed',
                                '${totalLiters.toStringAsFixed(1)} L',
                                Icons.water_drop,
                                AppTheme.primary,
                              ),
                              const SizedBox(width: 12),
                              _summaryCard(
                                'Total Spent',
                                '₹${totalSpent.toStringAsFixed(0)}',
                                Icons.account_balance_wallet,
                                AppTheme.success,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Consumption chart
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
                                  'Daily Consumption',
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
                          const SizedBox(height: 16),

                          // Avg per day
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.amber
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.speed,
                                      color: AppTheme.amber, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Average Daily',
                                      style: GoogleFonts.workSans(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      sales.isEmpty
                                          ? '0 L'
                                          : '${(totalLiters / sales.length).toStringAsFixed(1)} L',
                                      style: GoogleFonts.workSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
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
        child: Text('No data yet',
            style: GoogleFonts.workSans(color: AppTheme.textSecondary)),
      );
    }

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

    return BarChart(
      BarChartData(
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
        barGroups: spots.map((spot) {
          return BarChartGroupData(
            x: spot.x.toInt(),
            barRods: [
              BarChartRodData(
                toY: spot.y,
                color: AppTheme.primary,
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
