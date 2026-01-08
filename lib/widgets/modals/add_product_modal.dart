import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';

class AddProductModal extends StatefulWidget {
  final Function(Product)? onProductCreated;
  
  const AddProductModal({
    super.key,
    this.onProductCreated,
  });

  @override
  State<AddProductModal> createState() => _AddProductModalState();
}

class _AddProductModalState extends State<AddProductModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _skuController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  String? _selectedCategory;
  String? _selectedSupplier;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  List<ProductCategory> _categories = [];
  List<Supplier> _suppliers = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
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
      
      setState(() {
        _categories = categories;
        _suppliers = suppliers;
        _isLoadingData = false;
        
        if (_categories.isNotEmpty && _selectedCategory == null) {
          _selectedCategory = _categories.first.name;
        }
        if (_suppliers.isNotEmpty && _selectedSupplier == null) {
          _selectedSupplier = _suppliers.first.name;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
      // Find category ID
      int? categoryId;
      if (_selectedCategory != null) {
        final category = _categories.firstWhere(
          (c) => c.name == _selectedCategory,
          orElse: () => _categories.first,
        );
        categoryId = category.id;
      }
      
      // Find supplier ID
      int? supplierId;
      if (_selectedSupplier != null) {
        final supplier = _suppliers.firstWhere(
          (s) => s.name == _selectedSupplier,
          orElse: () => _suppliers.first,
        );
        supplierId = supplier.id;
      }
      
      final productData = {
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
      
      final product = await _apiService.createProduct(productData);
      
      if (mounted) {
        widget.onProductCreated?.call(product);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('productCreated') ?? 'Product created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
                  const Icon(Icons.add_shopping_cart, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations?.translate('addProduct') ?? 'Add Product',
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
                                  child: TextFormField(
                                    controller: _priceController,
                                    decoration: InputDecoration(
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
                                  child: TextFormField(
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
                                  child: TextFormField(
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
                                  child: TextFormField(
                                    controller: _skuController,
                                    decoration: InputDecoration(
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
                            SwitchListTile(
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
      ),
    );
  }
}

