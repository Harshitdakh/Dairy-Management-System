import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/delivery_pause.dart';
import '../../providers/pause_provider.dart';

/// Modal dialog for customer vacation / delivery pause requests ("दूध बंद").
/// Enforces future date validation (`startDate >= today`, `endDate >= startDate`),
/// creates a pause record with `status: 'pending'`, and informs customer of guardrail approval.
class PauseRequestDialog extends ConsumerStatefulWidget {
  final String customerId;
  final String? customerName;
  final VoidCallback? onPauseCreated;

  const PauseRequestDialog({
    super.key,
    required this.customerId,
    this.customerName,
    this.onPauseCreated,
  });

  /// Static helper to display the dialog
  static Future<DeliveryPause?> show({
    required BuildContext context,
    required String customerId,
    String? customerName,
    VoidCallback? onPauseCreated,
  }) {
    return showDialog<DeliveryPause?>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PauseRequestDialog(
        customerId: customerId,
        customerName: customerName,
        onPauseCreated: onPauseCreated,
      ),
    );
  }

  @override
  ConsumerState<PauseRequestDialog> createState() => _PauseRequestDialogState();
}

class _PauseRequestDialogState extends ConsumerState<PauseRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _startDate;
  late DateTime _endDate;
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default start date to tomorrow (or today)
    _startDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _endDate = _startDate.add(const Duration(days: 3));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  DateTime _stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final today = _stripTime(now);
    final initial = _startDate.isBefore(today) ? today : _startDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'प्रारंभ तिथि चुनें (Select Start Date)',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
        _errorMessage = null;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final today = _stripTime(now);
    final minDate = _startDate.isBefore(today) ? today : _startDate;
    final initial = _endDate.isBefore(minDate) ? minDate : _endDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'समाप्ति तिथि चुनें (Select End Date)',
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _errorMessage = null;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final today = _stripTime(now);

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'दूध बंद अवधि चुनें (Select Pause Period)',
      saveText: 'चुनें (Select)',
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleSubmit() async {
    final now = DateTime.now();
    final today = _stripTime(now);
    final start = _stripTime(_startDate);
    final end = _stripTime(_endDate);

    // Validation Guardrails
    if (start.isBefore(today)) {
      setState(() {
        _errorMessage = 'प्रारंभ तिथि आज या भविष्य की होनी चाहिए (Start date cannot be in the past)';
      });
      return;
    }

    if (end.isBefore(start)) {
      setState(() {
        _errorMessage = 'समाप्ति तिथि प्रारंभ तिथि से पहले नहीं हो सकती (End date cannot be earlier than start date)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(pauseRepositoryProvider);
      final pause = await repo.createPauseRequest(
        customerId: widget.customerId,
        startDate: start,
        endDate: end,
        reason: _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : null,
      );

      // Invalidate relevant providers to refresh UI state
      ref.invalidate(customerPausesProvider(widget.customerId));
      ref.invalidate(allPendingPausesProvider);

      widget.onPauseCreated?.call();

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop(pause);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primary,
            content: Text(
              'दूध बंद अनुरोध भेजा गया (Pause request submitted for approval)',
              style: GoogleFonts.workSans(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is ArgumentError ? e.message.toString() : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pauseDays = _endDate.difference(_startDate).inDays + 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pause_circle_filled,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pauseRequest,
                          style: GoogleFonts.workSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select vacation dates / छुट्टी की तिथियां चुनें',
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Duration Chip + Range Picker Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'कुल अवधि: $pauseDays दिन ($pauseDays ${pauseDays == 1 ? 'day' : 'days'})',
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range, size: 16),
                    label: const Text('एक साथ चुनें (Range)'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date Pickers Row
              Row(
                children: [
                  // Start Date Picker Card
                  Expanded(
                    child: InkWell(
                      onTap: _selectStartDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.startDate,
                                  style: GoogleFonts.workSans(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('dd MMM yyyy').format(_startDate),
                              style: GoogleFonts.workSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE').format(_startDate),
                              style: GoogleFonts.workSans(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // End Date Picker Card
                  Expanded(
                    child: InkWell(
                      onTap: _selectEndDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.event, size: 14, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.endDate,
                                  style: GoogleFonts.workSans(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('dd MMM yyyy').format(_endDate),
                              style: GoogleFonts.workSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE').format(_endDate),
                              style: GoogleFonts.workSans(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reason Input
              Text(
                '${l10n.reason} (वैकल्पिक / Optional)',
                style: GoogleFonts.workSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'उदा. गाँव जा रहे हैं / Out of station',
                  hintStyle: GoogleFonts.workSans(fontSize: 13, color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),

              // Quick reason suggestion chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _quickReasonChip('गाँव जाना है (Village)'),
                  _quickReasonChip('घर पर कोई नहीं (Out of town)'),
                  _quickReasonChip('शादी / त्यौहार (Function)'),
                ],
              ),
              const SizedBox(height: 16),

              // Guardrail notice callout
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7), // Light amber
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'नोट: अनुरोध भेजने के बाद विक्रेता द्वारा स्वीकृति आवश्यक है। स्वीकृति होने तक दूध वितरण जारी रहेगा।\n(Pause requires seller approval. Deliveries continue until approved.)',
                        style: GoogleFonts.workSans(
                          fontSize: 11,
                          color: const Color(0xFF92400E),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Error display
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.skippedBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.skipped.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: AppTheme.skipped),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            color: AppTheme.skipped,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppTheme.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        l10n.cancel,
                        style: GoogleFonts.workSans(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n.submit,
                              style: GoogleFonts.workSans(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickReasonChip(String label) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.workSans(fontSize: 11)),
      onPressed: () {
        setState(() {
          _reasonController.text = label;
        });
      },
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: AppTheme.divider),
    );
  }
}
