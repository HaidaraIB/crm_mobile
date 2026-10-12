import 'package:flutter/material.dart';
import '../../core/forms/catalog_form_binding.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import 'package:crm_mobile/widgets/auto_dir_text_field.dart';

class AddProductCategoryModal extends StatefulWidget {
  final Function(ProductCategory)? onCategoryCreated;
  
  const AddProductCategoryModal({
    super.key,
    this.onCategoryCreated,
  });

  @override
  State<AddProductCategoryModal> createState() => _AddProductCategoryModalState();
}

class _AddProductCategoryModalState extends State<AddProductCategoryModal> {
  final _formKey = GlobalKey<FormState>();
  final _catalog = CatalogFormBinding('product_category.upsert');
  final _nameFocus = FocusNode();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  int? _selectedParentCategory;
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  List<ProductCategory> _categories = [];
  
  @override
  void initState() {
    super.initState();
    _catalog.load();
    _catalog.watch(_nameFocus, 'name', () => _blurCatalog('name'));

    _loadData();
  }
  
  Map<String, dynamic> _catalogValues() => {
        'name': _nameController.text,
        'description': _descriptionController.text,
      };

  Future<void> _blurCatalog(String key) async {
    await _catalog.validate(context, _catalogValues(), only: key);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    try {
      final categories = await _apiService.getProductCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
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
      final categoryData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        'parent_category': _selectedParentCategory,
      };
      
      final category = await _apiService.createProductCategory(categoryData);
      
      if (mounted) {
        widget.onCategoryCreated?.call(category);
        Navigator.pop(context);
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('categoryCreated') ?? 'Category created successfully',
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
                  const Icon(Icons.category, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations?.translate('addProductCategory') ?? 'Add Product Category',
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
              child: _isLoadingData
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
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
                            // Description
                            AutoDirTextFormField(
                              controller: _descriptionController,
                          onEditingComplete: () => _blurCatalog('description'),
                              decoration: InputDecoration(
                                errorText: _catalog.errors['description'],
                            labelText: localizations?.translate('description') ?? 'Description',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            // Parent Category
                            DropdownButtonFormField<int?>(
                              initialValue: _selectedParentCategory,
                              decoration: InputDecoration(
                                labelText: localizations?.translate('parentCategory') ?? 'Parent Category',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(localizations?.translate('none') ?? 'None'),
                                ),
                                ..._categories.map((category) {
                                  return DropdownMenuItem<int?>(
                                    value: category.id,
                                    child: Text(category.name),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedParentCategory = value;
                                });
                              },
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

