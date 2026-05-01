import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../providers/seller_provider.dart';

class EditSellerScreen extends ConsumerStatefulWidget {
  final String sellerId;

  const EditSellerScreen({super.key, required this.sellerId});

  @override
  ConsumerState<EditSellerScreen> createState() => _EditSellerScreenState();
}

class _EditSellerScreenState extends ConsumerState<EditSellerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _routeController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isLoading = false;
  String _status = 'active';
  bool _isInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _routeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save(String profileId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(sellerRepositoryProvider).updateSellerProfileAndDetails(
            sellerId: widget.sellerId,
            profileId: profileId,
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            routeName: _routeController.text.trim(),
            location: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            status: _status,
          );

      ref.invalidate(allSellersProvider);
      ref.invalidate(sellerByIdProvider(widget.sellerId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Seller updated successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update seller: $e'),
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
    final sellerAsync = ref.watch(sellerByIdProvider(widget.sellerId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Edit Seller',
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: sellerAsync.when(
        data: (seller) {
          if (seller == null) {
            return const Center(child: Text('Seller not found'));
          }
          if (!_isInitialized) {
            _nameController.text = seller.fullName ?? '';
            _phoneController.text = seller.phone ?? '';
            _routeController.text = seller.routeName;
            _locationController.text = seller.location ?? '';
            _status = seller.status;
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
                  _label('Route Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _routeController,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                      onPressed: _isLoading ? null : () => _save(seller.userId),
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
