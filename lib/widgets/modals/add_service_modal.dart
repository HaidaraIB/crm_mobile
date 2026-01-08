import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';

class AddServiceModal extends StatefulWidget {
  final Function(Service)? onServiceCreated;
  
  const AddServiceModal({
    super.key,
    this.onServiceCreated,
  });

  @override
  State<AddServiceModal> createState() => _AddServiceModalState();
}

class _AddServiceModalState extends State<AddServiceModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  String? _selectedCategory;
  String? _selectedProvider;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  List<Service> _services = [];
  List<ServiceProvider> _providers = [];
  
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
    _durationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    try {
      final services = await _apiService.getServices();
      final providers = await _apiService.getServiceProviders();
      
      if (mounted) {
        setState(() {
          _services = services;
          _providers = providers;
          _isLoadingData = false;
          
          // Extract unique categories from services
          final categories = _services.map((s) => s.category).where((c) => c.isNotEmpty).toSet().toList();
          if (categories.isNotEmpty && _selectedCategory == null) {
            _selectedCategory = categories.first;
          }
          if (_providers.isNotEmpty && _selectedProvider == null) {
            _selectedProvider = _providers.first.name;
          }
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
      // Find provider ID
      int? providerId;
      if (_selectedProvider != null) {
        final provider = _providers.firstWhere(
          (p) => p.name == _selectedProvider,
          orElse: () => _providers.first,
        );
        providerId = provider.id;
      }
      
      final serviceData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        'price': double.parse(_priceController.text.trim()),
        'duration': _durationController.text.trim().isNotEmpty ? _durationController.text.trim() : null,
        'category': _selectedCategory ?? '',
        'provider': providerId,
        'is_active': _isActive,
      };
      
      final service = await _apiService.createService(serviceData);
      
      if (mounted) {
        widget.onServiceCreated?.call(service);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('serviceCreated') ?? 'Service created successfully'),
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
    final categories = _services.map((s) => s.category).where((c) => c.isNotEmpty).toSet().toList();
    
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
                  const Icon(Icons.build, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations?.translate('addService') ?? 'Add Service',
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
                            if (categories.isNotEmpty)
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: InputDecoration(
                                  labelText: '${localizations?.translate('category') ?? 'Category'} *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: categories.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
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
                              )
                            else
                              TextFormField(
                                initialValue: _selectedCategory ?? '',
                                decoration: InputDecoration(
                                  labelText: '${localizations?.translate('category') ?? 'Category'} *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategory = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return localizations?.translate('categoryRequired') ?? 'Category is required';
                                  }
                                  return null;
                                },
                              ),
                            const SizedBox(height: 16),
                            // Provider
                            DropdownButtonFormField<String>(
                              initialValue: _selectedProvider,
                              decoration: InputDecoration(
                                labelText: localizations?.translate('provider') ?? 'Provider',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: _providers.map((provider) {
                                return DropdownMenuItem(
                                  value: provider.name,
                                  child: Text(provider.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedProvider = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            // Price and Duration in a row
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
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return localizations?.translate('priceRequired') ?? 'Price is required';
                                      }
                                      if (double.tryParse(value.trim()) == null) {
                                        return localizations?.translate('invalidPrice') ?? 'Invalid price';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _durationController,
                                    decoration: InputDecoration(
                                      labelText: localizations?.translate('duration') ?? 'Duration',
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
    );
  }
}

