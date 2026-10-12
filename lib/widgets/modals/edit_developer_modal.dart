import 'package:flutter/material.dart';
import '../../core/forms/catalog_form_binding.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../utils/build_update_diff.dart';
import 'package:crm_mobile/widgets/auto_dir_text_field.dart';

class EditDeveloperModal extends StatefulWidget {
  final Developer developer;
  final Function(Developer)? onDeveloperUpdated;
  
  const EditDeveloperModal({
    super.key,
    required this.developer,
    this.onDeveloperUpdated,
  });

  @override
  State<EditDeveloperModal> createState() => _EditDeveloperModalState();
}

class _EditDeveloperModalState extends State<EditDeveloperModal> {
  final _formKey = GlobalKey<FormState>();
  final _catalog = CatalogFormBinding('developer.upsert');
  final _nameFocus = FocusNode();
  late TextEditingController _nameController;
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  Map<String, dynamic>? _initialPayload;
  
  @override
  void initState() {
    super.initState();
    _catalog.load();
    _catalog.watch(_nameFocus, 'name', () => _blurCatalog('name'));

    _nameController = TextEditingController(text: widget.developer.name);
    _initialPayload = _buildPayload();
  }
  
  Map<String, dynamic> _catalogValues() => {
        'name': _nameController.text,
      };

  Future<void> _blurCatalog(String key) async {
    await _catalog.validate(context, _catalogValues(), only: key);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameController.dispose();
    super.dispose();
  }
  
  Map<String, dynamic> _buildPayload() {
    return {
      'name': _nameController.text.trim(),
    };
  }

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
      final diff = buildUpdateDiff(_initialPayload ?? {}, _buildPayload());

      if (diff.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      final developer = await _apiService.updateDeveloper(widget.developer.id, diff);
      
      if (mounted) {
        widget.onDeveloperUpdated?.call(developer);
        Navigator.pop(context);
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('developerUpdated') ?? 'Developer updated successfully',
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
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
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
                      localizations?.translate('editDeveloper') ?? 'Edit Developer',
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
            Padding(
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
          ],
        ),
      ),
    );
  }
}

