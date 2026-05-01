import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../providers/customer_provider.dart';
import '../../providers/seller_provider.dart';

class EditCustomerScreen extends ConsumerStatefulWidget {
  final String customerId;

  const EditCustomerScreen({super.key, required this.customerId});

  @override
  ConsumerState<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends ConsumerState<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _rateController = TextEditingController();
  final _dailyLitersController = TextEditingController();
  final _dailyMlController = TextEditingController();
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _selectedSellerId;
  String _milkType = 'cow';
  String _status = 'active';
  String? _selectedRouteName;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _rateController.dispose();
    _dailyLitersController.dispose();
    _dailyMlController.dispose();
    super.dispose();
  }

  Future<void> _save(String profileId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(customerRepositoryProvider).updateCustomerProfileAndDetails(
            customerId: widget.customerId,
            profileId: profileId,
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            sellerId: _selectedSellerId,
            routeName: _selectedRouteName,
            location: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            milkType: _milkType,
            ratePerLiter: double.tryParse(_rateController.text.trim()) ?? 0,
            dailyQuantityLiters:
                double.tryParse(_dailyLitersController.text.trim()) ?? 1,
            dailyQuantityMl: double.tryParse(_dailyMlController.text.trim()) ?? 0,
            status: _status,
          );

      ref.invalidate(allCustomersProvider);
      ref.invalidate(customerByIdProvider(widget.customerId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Customer updated successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update customer: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerByIdProvider(widget.customerId));
    final sellersAsync = ref.watch(allSellersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Edit Customer',
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('Customer not found'));
          }
          if (!_isInitialized) {
            _nameController.text = customer.fullName ?? '';
            _phoneController.text = customer.phone ?? '';
            _locationController.text = customer.location ?? '';
            _rateController.text = customer.ratePerLiter.toString();
            _dailyLitersController.text = customer.dailyQuantityLiters.toString();
            _dailyMlController.text = customer.dailyQuantityMl.toString();
            _selectedSellerId = customer.sellerId;
            _selectedRouteName = customer.routeName;
            _milkType = customer.milkType;
            _status = customer.status;
            _isInitialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Full Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _label('Phone'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _label('Seller'),
                  const SizedBox(height: 8),
                  sellersAsync.when(
                    data: (sellers) => DropdownButtonFormField<String>(
                      initialValue: _selectedSellerId,
                      items: sellers
                          .map(
                            (seller) => DropdownMenuItem(
                              value: seller.id,
                              child: Text('${seller.fullName ?? 'Seller'} (${seller.routeName})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        final selected = sellers.where((seller) => seller.id == v).toList();
                        setState(() {
                          _selectedSellerId = v;
                          _selectedRouteName = selected.isEmpty ? null : selected.first.routeName;
                        });
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 16),
                  _label('Route Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _selectedRouteName,
                    onChanged: (v) => _selectedRouteName = v,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _label('Milk Type'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _milkType,
                    items: const [
                      DropdownMenuItem(value: 'cow', child: Text('Cow')),
                      DropdownMenuItem(value: 'buffalo', child: Text('Buffalo')),
                      DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
                    ],
                    onChanged: (v) => setState(() => _milkType = v ?? 'cow'),
                  ),
                  const SizedBox(height: 16),
                  _label('Rate per Liter'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _rateController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _label('Daily Quantity (Liters)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dailyLitersController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _label('Daily Quantity (ml)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dailyMlController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _label('Location'),
                  const SizedBox(height: 8),
                  TextFormField(controller: _locationController),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'active'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _save(customer.userId),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.workSans(fontWeight: FontWeight.w600),
      );
}
