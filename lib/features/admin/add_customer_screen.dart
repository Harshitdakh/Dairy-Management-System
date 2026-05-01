import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../providers/seller_provider.dart';
import '../../providers/customer_provider.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _locationController = TextEditingController();
  final _rateController = TextEditingController();
  String _milkType = 'cow';
  String? _selectedSellerId;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _locationController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;

      await client.functions.invoke(
        'admin-provision-user',
        body: {
          'role': 'customer',
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'seller_id': _selectedSellerId,
          'location': _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          'milk_type': _milkType,
          'rate_per_liter': double.tryParse(_rateController.text.trim()) ?? 0,
          'daily_quantity_liters': 1,
          'daily_quantity_ml': 0,
        },
      );

      if (mounted) {
        ref.invalidate(allCustomersProvider);
        ref.invalidate(customerCountProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Customer added successfully'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        context.pop();
      }
    } on FunctionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.details?.toString() ?? e.reasonPhrase ?? 'Provisioning failed'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add customer: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          'Add Customer',
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
              _buildLabel('Full Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter customer name',
                  prefixIcon: Icon(Icons.person_outline,
                      size: 20, color: AppTheme.textSecondary),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Email'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'customer@milkhub.com',
                  prefixIcon: Icon(Icons.email_outlined,
                      size: 20, color: AppTheme.textSecondary),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Phone'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '+91 98765 43210',
                  prefixIcon: Icon(Icons.phone_outlined,
                      size: 20, color: AppTheme.textSecondary),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Minimum 6 characters',
                  prefixIcon: Icon(Icons.lock_outlined,
                      size: 20, color: AppTheme.textSecondary),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Assign to seller
              _buildLabel('Assign to Seller'),
              const SizedBox(height: 8),
              sellersAsync.when(
                data: (sellers) => DropdownButtonFormField<String>(
                  initialValue: _selectedSellerId,
                  decoration: const InputDecoration(
                    hintText: 'Select a seller',
                    prefixIcon: Icon(Icons.storefront,
                        size: 20, color: AppTheme.textSecondary),
                  ),
                  items: sellers
                      .map((s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(
                              '${s.fullName ?? "Seller"} (${s.routeName})',
                              style: GoogleFonts.workSans(fontSize: 14),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSellerId = v),
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
              const SizedBox(height: 16),

              // Location
              _buildLabel('Location (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Street, Area',
                  prefixIcon: Icon(Icons.location_on_outlined,
                      size: 20, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAdd,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Add Customer',
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
