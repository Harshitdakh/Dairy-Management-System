import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/seller_provider.dart';
import '../../providers/milk_provider.dart';

class AssignMilkScreen extends ConsumerStatefulWidget {
  const AssignMilkScreen({super.key});

  @override
  ConsumerState<AssignMilkScreen> createState() => _AssignMilkScreenState();
}

class _AssignMilkScreenState extends ConsumerState<AssignMilkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _litersController = TextEditingController();
  final _mlController = TextEditingController(text: '0');
  final _rateController = TextEditingController();
  String? _selectedSellerId;
  String _milkType = 'cow';
  bool _isLoading = false;

  @override
  void dispose() {
    _litersController.dispose();
    _mlController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _handleAssign() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a seller')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final milkRepo = ref.read(milkRepositoryProvider);
      await milkRepo.createAssignment(
        sellerId: _selectedSellerId!,
        milkType: _milkType,
        quantityLiters: int.tryParse(_litersController.text.trim()) ?? 0,
        quantityMl: int.tryParse(_mlController.text.trim()) ?? 0,
        rate: double.tryParse(_rateController.text.trim()) ?? 0,
        date: DateTime.now(),
      );

      if (mounted) {
        ref.invalidate(allSellersProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Milk assigned successfully'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellersAsync = ref.watch(allSellersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Assign Milk',
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Select seller
              _buildLabel('Select Seller'),
              const SizedBox(height: 8),
              sellersAsync.when(
                data: (sellers) => DropdownButtonFormField<String>(
                  initialValue: _selectedSellerId,
                  decoration: const InputDecoration(
                    hintText: 'Choose a seller',
                    prefixIcon: Icon(Icons.storefront,
                        size: 20, color: AppTheme.textSecondary),
                  ),
                  items: sellers
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              '${s.fullName ?? "Seller"} (${s.routeName})',
                              style: GoogleFonts.workSans(fontSize: 14),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSellerId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 16),

              // Milk type
              _buildLabel('Milk Type'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _milkType,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.water_drop_outlined,
                      size: 20, color: AppTheme.textSecondary),
                ),
                items: const [
                  DropdownMenuItem(value: 'cow', child: Text('Cow')),
                  DropdownMenuItem(value: 'buffalo', child: Text('Buffalo')),
                  DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
                ],
                onChanged: (v) => setState(() => _milkType = v ?? 'cow'),
              ),
              const SizedBox(height: 16),

              // Quantity
              _buildLabel('Quantity'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _litersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Liters',
                        suffixText: 'L',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _mlController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'ml',
                        suffixText: 'ml',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Rate
              _buildLabel('Rate per Liter (₹)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g. 60',
                  prefixIcon: Icon(Icons.currency_rupee,
                      size: 20, color: AppTheme.textSecondary),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAssign,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Assign Milk',
                          style: GoogleFonts.workSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.workSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }
}
