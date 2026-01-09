import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';

class EditServicePackageModal extends StatefulWidget {
  final ServicePackage package;
  final Function(ServicePackage)? onPackageUpdated;
  
  const EditServicePackageModal({
    super.key,
    required this.package,
    this.onPackageUpdated,
  });

  @override
  State<EditServicePackageModal> createState() => _EditServicePackageModalState();
}

class _EditServicePackageModalState extends State<EditServicePackageModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  final ApiService _apiService = ApiService();
  
  List<int> _selectedServiceIds = [];
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  List<Service> _services = [];
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.package.name);
    _descriptionController = TextEditingController(text: widget.package.description ?? '');
    _priceController = TextEditingController(text: widget.package.price.toString());
    _durationController = TextEditingController(text: widget.package.duration ?? '');
    _selectedServiceIds = List.from(widget.package.services);
    _isActive = widget.package.isActive;
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
      if (mounted) {
        setState(() {
          _services = services;
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
      final packageData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        'price': double.parse(_priceController.text.trim()),
        'duration': _durationController.text.trim().isNotEmpty ? _durationController.text.trim() : null,
        'services': _selectedServiceIds,
        'is_active': _isActive,
      };
      
      final package = await _apiService.updateServicePackage(widget.package.id, packageData);
      
      if (mounted) {
        widget.onPackageUpdated?.call(package);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('packageUpdated') ?? 'Package updated successfully'),
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
                      localizations?.translate('editServicePackage') ?? 'Edit Service Package',
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
                            // Services (Multi-select)
                            Text(
                              '${localizations?.translate('services') ?? 'Services'} *',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _services.length,
                                itemBuilder: (context, index) {
                                  final service = _services[index];
                                  final isSelected = _selectedServiceIds.contains(service.id);
                                  return CheckboxListTile(
                                    title: Text(service.name),
                                    subtitle: Text(service.code),
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedServiceIds.add(service.id);
                                        } else {
                                          _selectedServiceIds.remove(service.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
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

