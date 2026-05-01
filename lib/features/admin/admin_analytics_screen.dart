import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../providers/milk_provider.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(allSalesProvider);

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
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Overview of your dairy business',
                style: GoogleFonts.workSans(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Daily Sales Chart ──
              _buildChartCard(
                title: 'Daily Sales Volume',
                subtitle: 'Last 7 days',
                child: SizedBox(
                  height: 200,
                  child: salesAsync.when(
                    data: (sales) => _buildBarChart(sales),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Revenue Chart ──
              _buildChartCard(
                title: 'Revenue Trend',
                subtitle: 'Monthly overview',
                child: SizedBox(
                  height: 200,
                  child: salesAsync.when(
                    data: (sales) => _buildLineChart(sales),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Milk Type Distribution ──
              _buildChartCard(
                title: 'Milk Type Distribution',
                subtitle: 'All time',
                child: SizedBox(
                  height: 200,
                  child: salesAsync.when(
                    data: (sales) => _buildPieChart(sales),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            title,
            style: GoogleFonts.workSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.workSans(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildBarChart(List sales) {
    // Aggregate last 7 days
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final Map<String, double> dailyVolume = {};
    for (final d in days) {
      dailyVolume[d.toString().split(' ')[0]] = 0;
    }
    for (final sale in sales) {
      final key = sale.saleDate.toString().split(' ')[0];
      if (dailyVolume.containsKey(key)) {
        dailyVolume[key] = dailyVolume[key]! + sale.totalLiters;
      }
    }

    final values = dailyVolume.values.toList();
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(enabled: true),
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
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox();
                return Text(labels[i],
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: List.generate(values.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                color: AppTheme.primary,
                width: 24,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLineChart(List sales) {
    // Simple placeholder with sample data
    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                '₹${v.toInt()}',
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'
                ];
                final i = v.toInt();
                if (i < 0 || i >= months.length) return const SizedBox();
                return Text(months[i],
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 1000),
              FlSpot(1, 2500),
              FlSpot(2, 1800),
              FlSpot(3, 3200),
              FlSpot(4, 2800),
              FlSpot(5, 3500),
            ],
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List sales) {
    // Count milk types
    int cowCount = 0, buffaloCount = 0, mixedCount = 0;
    for (final sale in sales) {
      switch (sale.milkType) {
        case 'buffalo':
          buffaloCount++;
          break;
        case 'mixed':
          mixedCount++;
          break;
        default:
          cowCount++;
      }
    }
    final total = cowCount + buffaloCount + mixedCount;
    if (total == 0) {
      return Center(
        child: Text(
          'No data available',
          style: GoogleFonts.workSans(color: AppTheme.textSecondary),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  value: cowCount.toDouble(),
                  color: AppTheme.primary,
                  title: '${(cowCount / total * 100).toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  radius: 45,
                ),
                PieChartSectionData(
                  value: buffaloCount.toDouble(),
                  color: AppTheme.success,
                  title:
                      '${(buffaloCount / total * 100).toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  radius: 45,
                ),
                PieChartSectionData(
                  value: mixedCount.toDouble(),
                  color: AppTheme.amber,
                  title:
                      '${(mixedCount / total * 100).toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  radius: 45,
                ),
              ],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legendDot('Cow', AppTheme.primary),
            const SizedBox(height: 8),
            _legendDot('Buffalo', AppTheme.success),
            const SizedBox(height: 8),
            _legendDot('Mixed', AppTheme.amber),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
