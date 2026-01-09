import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../widgets/phone_input.dart';

class EditSupplierModal extends StatefulWidget {
  final Supplier supplier;
  final Function(Supplier)? onSupplierUpdated;
  
  const EditSupplierModal({
    super.key,
    required this.supplier,
    this.onSupplierUpdated,
  });

  @override
  State<EditSupplierModal> createState() => _EditSupplierModalState();
}

class _EditSupplierModalState extends State<EditSupplierModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _contactPersonController;
  late TextEditingController _specializationController;
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier.name);
    _phoneController = TextEditingController(text: widget.supplier.phone);
    _emailController = TextEditingController(text: widget.supplier.email ?? '');
    _addressController = TextEditingController(text: widget.supplier.address ?? '');
    _contactPersonController = TextEditingController(text: widget.supplier.contactPerson ?? '');
    _specializationController = TextEditingController(text: widget.supplier.specialization ?? '');
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _specializationController.dispose();
    super.dispose();
  }
  
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final supplierData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'address': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        'contact_person': _contactPersonController.text.trim().isNotEmpty ? _contactPersonController.text.trim() : null,
        'specialization': _specializationController.text.trim().isNotEmpty ? _specializationController.text.trim() : null,
      };
      
      final supplier = await _apiService.updateSupplier(widget.supplier.id, supplierData);
      
      if (mounted) {
        widget.onSupplierUpdated?.call(supplier);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('supplierUpdated') ?? 'Supplier updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)?.translate('error') ?? 'Error'}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations?.translate('editSupplier') ?? 'Edit Supplier',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: '${localizations?.translate('name') ?? 'Name'} *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return localizations?.translate('nameRequired') ?? 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Phone
                      PhoneInput(
                        value: _phoneController.text,
                        onChanged: (value) {
                          setState(() {
                            _phoneController.text = value;
                          });
                        },
                        hintText: localizations?.translate('phone') ?? 'Phone',
                      ),
                      const SizedBox(height: 16),
                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: localizations?.translate('email') ?? 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      // Address
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: localizations?.translate('address') ?? 'Address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      // Contact Person
                      TextFormField(
                        controller: _contactPersonController,
                        decoration: InputDecoration(
                          labelText: localizations?.translate('contactPerson') ?? 'Contact Person',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Specialization
                      TextFormField(
                        controller: _specializationController,
                        decoration: InputDecoration(
                          labelText: localizations?.translate('specialization') ?? 'Specialization',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(localizations?.translate('cancel') ?? 'Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(localizations?.translate('update') ?? 'Update'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

