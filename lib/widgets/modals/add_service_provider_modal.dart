import 'package:flutter/material.dart';
import '../../core/forms/catalog_form_binding.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../widgets/phone_input.dart';
import 'package:crm_mobile/widgets/auto_dir_text_field.dart';

class AddServiceProviderModal extends StatefulWidget {
  final Function(ServiceProvider)? onProviderCreated;
  
  const AddServiceProviderModal({
    super.key,
    this.onProviderCreated,
  });

  @override
  State<AddServiceProviderModal> createState() => _AddServiceProviderModalState();
}

class _AddServiceProviderModalState extends State<AddServiceProviderModal> {
  final _formKey = GlobalKey<FormState>();
  final _catalog = CatalogFormBinding('service_provider.upsert');
  final _nameFocus = FocusNode();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _specializationController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  
  Future<void> _submit() async {
    final catalogOk = await _catalog.validate(context, _catalogValues());
    final formOk = _formKey.currentState!.validate();
    if (!catalogOk || !formOk) {
      if (mounted) setState(() {});
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final providerData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'specialization': _specializationController.text.trim().isNotEmpty ? _specializationController.text.trim() : null,
      };
      
      final provider = await _apiService.createServiceProvider(providerData);
      
      if (mounted) {
        widget.onProviderCreated?.call(provider);
        Navigator.pop(context);
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('providerCreated') ?? 'Provider created successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final applied = e is ApiFieldException && _catalog.applyApiError(l10n, e);
        final fieldError = _catalog.errors.keys.any((key) => key != '_general');
        if (applied && fieldError) {
          setState(() {});
          final general = _catalog.errors['_general'];
          if (general != null && general.isNotEmpty) {
            SnackbarHelper.showError(context, general);
          }
        } else {
          SnackbarHelper.showError(
            context,
            '${l10n?.translate('error') ?? 'Error'}: ${e.toString()}',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Map<String, dynamic> _catalogValues() => {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
      };

  Future<void> _blurCatalog(String key) async {
    await _catalog.validate(context, _catalogValues(), only: key);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _catalog.load();
    _catalog.watch(_nameFocus, 'name', () => _blurCatalog('name'));
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specializationController.dispose();
    super.dispose();
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
                  const Icon(Icons.person_add, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations?.translate('addServiceProvider') ?? 'Add Service Provider',
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
                      AutoDirTextFormField(
                        controller: _nameController,
                          focusNode: _nameFocus,
                          onEditingComplete: () => _blurCatalog('name'),
                        decoration: InputDecoration(
                          errorText: _catalog.errors['name'],
                            labelText: '${localizations?.translate('name') ?? 'Name'} *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Phone
                      PhoneInput(
                        errorText: _catalog.errors['phone'],
                        onEditingComplete: () => _blurCatalog('phone'),
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
                      AutoDirTextFormField(
                        controller: _emailController,
                          onEditingComplete: () => _blurCatalog('email'),
                        decoration: InputDecoration(
                          errorText: _catalog.errors['email'],
                            labelText: localizations?.translate('email') ?? 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      // Specialization
                      AutoDirTextFormField(
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
                                : Text(localizations?.translate('create') ?? 'Create'),
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

