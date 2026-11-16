import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/delivery_pause.dart';
import '../../providers/pause_provider.dart';

class PendingPausesCard extends ConsumerStatefulWidget {
  final String? sellerId; // null = all pending pauses (admin/owner view)
  final bool hideIfEmpty;

  const PendingPausesCard({
    super.key,
    this.sellerId,
    this.hideIfEmpty = true,
  });

  @override
  ConsumerState<PendingPausesCard> createState() => _PendingPausesCardState();
}

class _PendingPausesCardState extends ConsumerState<PendingPausesCard> {
  final Set<String> _inFlightPauseIds = {};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pausesAsync = widget.sellerId != null
        ? ref.watch(pendingPausesForSellerProvider(widget.sellerId!))
        : ref.watch(allPendingPausesProvider);

    return pausesAsync.when(
      data: (pauses) {
        if (pauses.isEmpty) {
          if (widget.hideIfEmpty) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  'कोई लंबित अवकाश अनुरोध नहीं',
                  style: GoogleFonts.workSans(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade300, width: 1.5),
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
              // Header Row: Icon, Title, Pending Count Pill
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.beach_access, color: Colors.amber.shade900, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pendingApprovals,
                          style: GoogleFonts.workSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        Text(
                          'दूध बंद अनुरोध समीक्षा (Review Pause Requests)',
                          style: GoogleFonts.workSans(
                            fontSize: 11,
                            color: Colors.brown.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pauses.length}',
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.amber, height: 1),
              const SizedBox(height: 12),

              // List of Pending Pause Items
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pauses.length,
                separatorBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Colors.amber, height: 1),
                ),
                itemBuilder: (context, index) {
                  final pause = pauses[index];
                  final isProcessing = _inFlightPauseIds.contains(pause.id);
                  final days = pause.endDate.difference(pause.startDate).inDays + 1;
                  final dateRangeStr =
                      '${DateFormat('dd/MM/yyyy').format(pause.startDate)} - ${DateFormat('dd/MM/yyyy').format(pause.endDate)}';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Name & Duration
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pause.customerName ?? 'Customer',
                              style: GoogleFonts.workSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: Text(
                              '$days दिन',
                              style: GoogleFonts.workSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Date Range
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            dateRangeStr,
                            style: GoogleFonts.workSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      // Optional Reason
                      if (pause.reason != null && pause.reason!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes, size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                pause.reason!,
                                style: GoogleFonts.workSans(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),

                      // 1-Tap Action Buttons Row: [स्वीकार करें (Approve)] & [अस्वीकार करें (Reject)]
                      Row(
                        children: [
                          // Approve Button
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: isProcessing ? null : () => _handleAction(pause, isApprove: true),
                              icon: isProcessing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check, size: 16),
                              label: Text(
                                l10n.approvePause,
                                style: GoogleFonts.workSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Reject Button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isProcessing ? null : () => _handleAction(pause, isApprove: false),
                              icon: const Icon(Icons.close, size: 16),
                              label: Text(
                                l10n.rejectPause,
                                style: GoogleFonts.workSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: const BorderSide(color: AppTheme.error),
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _handleAction(DeliveryPause pause, {required bool isApprove}) async {
    setState(() => _inFlightPauseIds.add(pause.id));
    try {
      final repo = ref.read(pauseRepositoryProvider);
      if (isApprove) {
        await repo.approvePause(pause.id);
      } else {
        await repo.rejectPause(pause.id);
      }

      // Reactive cache invalidations for immediate UI refresh across all listeners
      if (widget.sellerId != null) {
        ref.invalidate(pendingPausesForSellerProvider(widget.sellerId!));
      }
      ref.invalidate(allPendingPausesProvider);
      ref.invalidate(customerPausesProvider(pause.customerId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApprove
                  ? 'अवकाश अनुरोध स्वीकृत किया गया (Pause approved)'
                  : 'अवकाश अनुरोध अस्वीकृत किया गया (Pause rejected)',
            ),
            backgroundColor: isApprove ? AppTheme.success : AppTheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _inFlightPauseIds.remove(pause.id));
      }
    }
  }
}
