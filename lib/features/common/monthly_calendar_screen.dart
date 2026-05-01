import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../providers/billing_provider.dart';

class MonthlyCalendarScreen extends ConsumerStatefulWidget {
  const MonthlyCalendarScreen({super.key});

  @override
  ConsumerState<MonthlyCalendarScreen> createState() =>
      _MonthlyCalendarScreenState();
}

class _MonthlyCalendarScreenState extends ConsumerState<MonthlyCalendarScreen> {
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);

  void _prevMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final billingRepo = ref.read(billingRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Monthly Calendar',
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppTheme.background,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_selectedMonth),
        future: billingRepo.getDeliveries(month: _selectedMonth),
        builder: (context, snapshot) {
          final deliveries = snapshot.data ?? [];

          // Build a map dateString -> list of deliveries
          final Map<String, List<Map<String, dynamic>>> byDate = {};
          for (final d in deliveries) {
            final date = (d['delivery_date'] ?? '').toString();
            byDate.putIfAbsent(date, () => []).add(d);
          }

          final daysInMonth =
              DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

          // Day-of-week offset for the first day of the month (Mon=0)
          final firstWeekday =
              DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;
          final leadingBlanks = (firstWeekday - 1) % 7;

          final totalCells = leadingBlanks + daysInMonth;

          return Column(
            children: [
              // ── Month Navigation Header ──
              Container(
                color: AppTheme.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _prevMonth,
                      icon: const Icon(Icons.chevron_left),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: GoogleFonts.workSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _nextMonth,
                      icon: const Icon(Icons.chevron_right),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Day-of-week labels ──
              Container(
                color: AppTheme.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      .map(
                        (d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: GoogleFonts.workSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Divider(height: 1, color: AppTheme.divider),

              // ── Calendar Grid ──
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.75,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: totalCells,
                    itemBuilder: (context, index) {
                      if (index < leadingBlanks) {
                        return const SizedBox.shrink();
                      }
                      final day = index - leadingBlanks + 1;
                      final date = DateTime(
                          _selectedMonth.year, _selectedMonth.month, day);
                      final dateStr =
                          date.toIso8601String().split('T')[0];
                      final dayDeliveries = byDate[dateStr] ?? [];

                      final isToday = date.year == DateTime.now().year &&
                          date.month == DateTime.now().month &&
                          date.day == DateTime.now().day;
                      final skipped = dayDeliveries
                          .any((e) => (e['status'] ?? '') == 'skipped');
                      final hasDelivery = dayDeliveries.isNotEmpty && !skipped;
                      final amount = dayDeliveries.fold<num>(
                          0, (p, e) => p + (e['amount'] ?? 0));

                      Color bgColor = AppTheme.surface;
                      Color dayNumColor = AppTheme.textPrimary;
                      if (isToday) {
                        bgColor = AppTheme.primary;
                        dayNumColor = Colors.white;
                      } else if (skipped) {
                        bgColor = AppTheme.error.withValues(alpha: 0.08);
                      } else if (hasDelivery) {
                        bgColor = AppTheme.success.withValues(alpha: 0.08);
                      }

                      return Card(
                        elevation: 0,
                        color: bgColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: isToday
                              ? BorderSide.none
                              : BorderSide(
                                  color: AppTheme.divider, width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$day',
                                style: GoogleFonts.workSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: dayNumColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (skipped)
                                Icon(Icons.close,
                                    color: AppTheme.error, size: 12)
                              else if (hasDelivery) ...[
                                Icon(Icons.water_drop,
                                    color: AppTheme.success, size: 10),
                                const SizedBox(height: 1),
                                Text(
                                  '₹${amount.toStringAsFixed(0)}',
                                  style: GoogleFonts.workSans(
                                    fontSize: 9,
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // ── Legend ──
              Container(
                color: AppTheme.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendItem(
                        AppTheme.success.withValues(alpha: 0.15),
                        AppTheme.success,
                        Icons.water_drop,
                        'Delivered'),
                    const SizedBox(width: 20),
                    _legendItem(
                        AppTheme.error.withValues(alpha: 0.1),
                        AppTheme.error,
                        Icons.close,
                        'Skipped'),
                    const SizedBox(width: 20),
                    _legendItem(AppTheme.primary, Colors.white,
                        Icons.circle, 'Today'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _legendItem(
      Color bg, Color iconColor, IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 12, color: iconColor),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
