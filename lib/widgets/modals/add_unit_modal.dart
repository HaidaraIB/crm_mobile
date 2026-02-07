import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';

class AddUnitModal extends StatefulWidget {
  final Function(Unit)? onUnitCreated;
  
  const AddUnitModal({
    super.key,
    this.onUnitCreated,
  });

  @override
  State<AddUnitModal> createState() => _AddUnitModalState();
}

class _AddUnitModalState extends State<AddUnitModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _priceController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _zoneController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  String? _selectedProject;
  String? _selectedType;
  String? _selectedFinishing;
  bool _isSold = false;
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  List<Project> _projects = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _priceController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _zoneController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    try {
      final projects = await _apiService.getProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          _isLoadingData = false;
          if (_projects.isNotEmpty && _selectedProject == null) {
            _selectedProject = _projects.first.name;
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
      // Find project ID
      int? projectId;
      if (_selectedProject != null) {
        final project = _projects.firstWhere(
          (p) => p.name == _selectedProject,
          orElse: () => _projects.first,
        );
        projectId = project.id;
      }
      
      final unitData = {
        'name': _nameController.text.trim(),
        'project': projectId,
        'bedrooms': int.parse(_bedroomsController.text.trim()),
        'bathrooms': int.parse(_bathroomsController.text.trim()),
        'price': double.parse(_priceController.text.trim()),
        'type': _selectedType,
        'finishing': _selectedFinishing,
        'city': _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        'district': _districtController.text.trim().isNotEmpty ? _districtController.text.trim() : null,
        'zone': _zoneController.text.trim().isNotEmpty ? _zoneController.text.trim() : null,
        'is_sold': _isSold,
      };
      
      final unit = await _apiService.createUnit(unitData);
      
      if (mounted) {
        widget.onUnitCreated?.call(unit);
        Navigator.pop(context);
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('unitCreated') ?? 'Unit created successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          '${AppLocalizations.of(context)?.translate('error') ?? 'Error'}: ${e.toString()}',
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
                  const Icon(Icons.home, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations?.translate('addUnit') ?? 'Add Unit',
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
                            // Project
                            DropdownButtonFormField<String>(
                              initialValue: _selectedProject,
                              decoration: InputDecoration(
                                labelText: '${localizations?.translate('project') ?? 'Project'} *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: _projects.map((project) {
                                return DropdownMenuItem(
                                  value: project.name,
                                  child: Text(project.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedProject = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return localizations?.translate('projectRequired') ?? 'Project is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Bedrooms and Bathrooms in a row
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _bedroomsController,
                                    decoration: InputDecoration(
                                      labelText: '${localizations?.translate('bedrooms') ?? 'Bedrooms'} *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    textDirection: TextDirection.ltr,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return localizations?.translate('bedroomsRequired') ?? 'Bedrooms is required';
                                      }
                                      final bedrooms = int.tryParse(value.trim());
                                      if (bedrooms == null) {
                                        return localizations?.translate('invalidNumber') ?? 'Invalid number';
                                      }
                                      if (bedrooms < 0) {
                                        return localizations?.translate('invalidNumber') ?? 'Number must be greater than or equal to 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _bathroomsController,
                                    decoration: InputDecoration(
                                      labelText: '${localizations?.translate('bathrooms') ?? 'Bathrooms'} *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    textDirection: TextDirection.ltr,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return localizations?.translate('bathroomsRequired') ?? 'Bathrooms is required';
                                      }
                                      final bathrooms = int.tryParse(value.trim());
                                      if (bathrooms == null) {
                                        return localizations?.translate('invalidNumber') ?? 'Invalid number';
                                      }
                                      if (bathrooms < 0) {
                                        return localizations?.translate('invalidNumber') ?? 'Number must be greater than or equal to 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Price
                            TextFormField(
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
                            const SizedBox(height: 16),
                            // Type and Finishing in a row
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedType,
                                    decoration: InputDecoration(
                                      labelText: localizations?.translate('type') ?? 'Type',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'Apartment',
                                        child: Text(localizations?.translate('apartment') ?? 'Apartment'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Villa',
                                        child: Text(localizations?.translate('villa') ?? 'Villa'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedType = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedFinishing,
                                    decoration: InputDecoration(
                                      labelText: localizations?.translate('finishing') ?? 'Finishing',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'Finished',
                                        child: Text(localizations?.translate('finished') ?? 'Finished'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Semi-Finished',
                                        child: Text(localizations?.translate('semiFinished') ?? 'Semi-Finished'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedFinishing = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // City, District, Zone in a row
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
                                const SizedBox(width: 8),
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
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _zoneController,
                                    decoration: InputDecoration(
                                      labelText: localizations?.translate('zone') ?? 'Zone',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Sold toggle
                            SwitchListTile(
                              title: Text(localizations?.translate('sold') ?? 'Sold'),
                              value: _isSold,
                              onChanged: (value) {
                                setState(() {
                                  _isSold = value;
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

