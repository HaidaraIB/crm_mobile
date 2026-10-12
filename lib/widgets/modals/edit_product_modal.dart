import 'package:flutter/material.dart';
import '../../core/forms/catalog_form_binding.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../utils/build_update_diff.dart';
import '../app_switch.dart';
import 'package:crm_mobile/widgets/auto_dir_text_field.dart';

class EditProductModal extends StatefulWidget {
  final Product product;
  final Function(Product)? onProductUpdated;
  
  const EditProductModal({
    super.key,
    required this.product,
    this.onProductUpdated,
  });

  @override
  State<EditProductModal> createState() => _EditProductModalState();
}

class _EditProductModalState extends State<EditProductModal> {
  final _formKey = GlobalKey<FormState>();
  final _catalog = CatalogFormBinding('product.upsert');
  final _nameFocus = FocusNode();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _stockController;
  late TextEditingController _skuController;
  final ApiService _apiService = ApiService();
  
  String? _selectedCategory;
  String? _selectedSupplier;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  List<ProductCategory> _categories = [];
  List<Supplier> _suppliers = [];
  Map<String, dynamic>? _initialPayload;
  
  @override
  void initState() {
    super.initState();
    _catalog.load();
    _catalog.watch(_nameFocus, 'name', () => _blurCatalog('name'));

    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(text: widget.product.description ?? '');
    _priceController = TextEditingController(text: widget.product.price.toString());
    _costController = TextEditingController(text: widget.product.cost.toString());
    _stockController = TextEditingController(text: widget.product.stock.toString());
    _skuController = TextEditingController(text: widget.product.sku ?? '');
    _selectedCategory = widget.product.category;
    _selectedSupplier = widget.product.supplier;
    _isActive = widget.product.isActive;
    _loadData();
  }
  
  Map<String, dynamic> _catalogValues() => {
        'name': _nameController.text,
        'sku': _skuController.text,
        'price': _priceController.text,
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
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    try {
      final categories = await _apiService.getProductCategories();
      final suppliers = await _apiService.getSuppliers();
      
      if (mounted) {
        setState(() {
          _categories = categories;
          _suppliers = suppliers;
          _isLoadingData = false;
          _initialPayload = _buildPayload();
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
  
  Map<String, dynamic> _buildPayload() {
    int? categoryId;
    if (_selectedCategory != null && _categories.isNotEmpty) {
      final category = _categories.firstWhere(
        (c) => c.name == _selectedCategory,
        orElse: () => _categories.first,
      );
      categoryId = category.id;
    }

    int? supplierId;
    if (_selectedSupplier != null && _suppliers.isNotEmpty) {
      final supplier = _suppliers.firstWhere(
        (s) => s.name == _selectedSupplier,
        orElse: () => _suppliers.first,
      );
      supplierId = supplier.id;
    }

    return {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      'price': double.parse(_priceController.text.trim()),
      'cost': double.parse(_costController.text.trim()),
      'stock': int.parse(_stockController.text.trim()),
      'category': categoryId,
      'supplier': supplierId,
      'sku': _skuController.text.trim().isNotEmpty ? _skuController.text.trim() : null,
      'is_active': _isActive,
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
      final nextPayload = _buildPayload();
      final diff = buildUpdateDiff(_initialPayload ?? {}, nextPayload);

      if (diff.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      final product = await _apiService.updateProduct(widget.product.id, diff);
      
      if (mounted) {
        widget.onProductUpdated?.call(product);
        Navigator.pop(context);
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('productUpdated') ?? 'Product updated successfully',
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
    final isRTL = localizations?.isRTL ?? false;
    
    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
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
                      localizations?.translate('editProduct') ?? 'Edit Product',
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
                            // Category
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: InputDecoration(
                                labelText: '${localizations?.translate('category') ?? 'Category'} *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category.name,
                                  child: Text(category.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return localizations?.translate('categoryRequired') ?? 'Category is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Supplier
                            DropdownButtonFormField<String>(
                              initialValue: _selectedSupplier,
                              decoration: InputDecoration(
                                labelText: localizations?.translate('supplier') ?? 'Supplier',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: _suppliers.map((supplier) {
                                return DropdownMenuItem(
                                  value: supplier.name,
                                  child: Text(supplier.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSupplier = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            // Price and Cost in a row
                            Row(
                              children: [
                                Expanded(
                                  child: AutoDirTextFormField(
                                    controller: _priceController,
                          onEditingComplete: () => _blurCatalog('price'),
                                    decoration: InputDecoration(
                                      errorText: _catalog.errors['price'],
                            labelText: '${localizations?.translate('price') ?? 'Price'} *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    textDirection: TextDirection.ltr,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return localizations?.translate('priceRequired') ?? 'Price is required';
                                      }
                                      final price = double.tryParse(value.trim());
                                      if (price == null) {
                                        return localizations?.translate('invalidPrice') ?? 'Invalid price';
                                      }
                                      if (price < 0) {
                                        return localizations?.translate('invalidPrice') ?? 'Price must be greater than or equal to 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: AutoDirTextFormField(
                                    controller: _costController,
                                    decoration: InputDecoration(
                                      labelText: '${localizations?.translate('cost') ?? 'Cost'} *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    textDirection: TextDirection.ltr,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return localizations?.translate('costRequired') ?? 'Cost is required';
                                      }
                                      final cost = double.tryParse(value.trim());
                                      if (cost == null) {
                                        return localizations?.translate('invalidCost') ?? 'Invalid cost';
                                      }
                                      if (cost < 0) {
                                        return localizations?.translate('invalidCost') ?? 'Cost must be greater than or equal to 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Stock and SKU in a row
                            Row(
                              children: [
                                Expanded(
                                  child: AutoDirTextFormField(
                                    controller: _stockController,
                                    decoration: InputDecoration(
                                      labelText: '${localizations?.translate('stock') ?? 'Stock'} *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    textDirection: TextDirection.ltr,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return localizations?.translate('stockRequired') ?? 'Stock is required';
                                      }
                                      final stock = int.tryParse(value.trim());
                                      if (stock == null) {
                                        return localizations?.translate('invalidStock') ?? 'Invalid stock';
                                      }
                                      if (stock < 0) {
                                        return localizations?.translate('invalidStock') ?? 'Stock must be greater than or equal to 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: AutoDirTextFormField(
                                    controller: _skuController,
                          onEditingComplete: () => _blurCatalog('sku'),
                                    decoration: InputDecoration(
                                      errorText: _catalog.errors['sku'],
                                      labelText: localizations?.translate('sku') ?? 'SKU',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Active toggle
                            AppSwitchListTile(
                              title: Text(localizations?.translate('active') ?? 'Active'),
                              value: _isActive,
                              onChanged: (value) {
                                setState(() {
                                  _isActive = value;
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
      ),
    );
  }
}

