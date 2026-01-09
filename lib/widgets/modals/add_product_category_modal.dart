import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';

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
    _loadData();
  }
  
  @override
  void dispose() {
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
    if (!_formKey.currentState!.validate()) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('categoryCreated') ?? 'Category created successfully'),
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
                            // Description
                            TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
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

