import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../widgets/phone_input.dart';

class EditOwnerModal extends StatefulWidget {
  final Owner owner;
  final Function(Owner)? onOwnerUpdated;
  
  const EditOwnerModal({
    super.key,
    required this.owner,
    this.onOwnerUpdated,
  });

  @override
  State<EditOwnerModal> createState() => _EditOwnerModalState();
}

class _EditOwnerModalState extends State<EditOwnerModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _districtController;
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.owner.name);
    _phoneController = TextEditingController(text: widget.owner.phone);
    _cityController = TextEditingController(text: widget.owner.city ?? '');
    _districtController = TextEditingController(text: widget.owner.district ?? '');
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _districtController.dispose();
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
      final ownerData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        'district': _districtController.text.trim().isNotEmpty ? _districtController.text.trim() : null,
      };
      
      final owner = await _apiService.updateOwner(widget.owner.id, ownerData);
      
      if (mounted) {
        widget.onOwnerUpdated?.call(owner);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('ownerUpdated') ?? 'Owner updated successfully'),
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
                      localizations?.translate('editOwner') ?? 'Edit Owner',
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
                      // City and District in a row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                labelText: localizations?.translate('city') ?? 'City',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _districtController,
                              decoration: InputDecoration(
                                labelText: localizations?.translate('district') ?? 'District',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
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

