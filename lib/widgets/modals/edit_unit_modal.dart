import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';

class EditUnitModal extends StatefulWidget {
  final Unit unit;
  final Function(Unit)? onUnitUpdated;
  
  const EditUnitModal({
    super.key,
    required this.unit,
    this.onUnitUpdated,
  });

  @override
  State<EditUnitModal> createState() => _EditUnitModalState();
}

class _EditUnitModalState extends State<EditUnitModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bedroomsController;
  late TextEditingController _bathroomsController;
  late TextEditingController _priceController;
  late TextEditingController _cityController;
  late TextEditingController _districtController;
  late TextEditingController _zoneController;
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
    _nameController = TextEditingController(text: widget.unit.name);
    _bedroomsController = TextEditingController(text: widget.unit.bedrooms.toString());
    _bathroomsController = TextEditingController(text: widget.unit.bathrooms.toString());
    _priceController = TextEditingController(text: widget.unit.price.toString());
    _cityController = TextEditingController(text: widget.unit.city ?? '');
    _districtController = TextEditingController(text: widget.unit.district ?? '');
    _zoneController = TextEditingController(text: widget.unit.zone ?? '');
    _selectedProject = widget.unit.project;
    _selectedType = widget.unit.type;
    _selectedFinishing = widget.unit.finishing;
    _isSold = widget.unit.isSold;
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
          // Verify that the selected project exists in the list
          if (_selectedProject != null) {
            final exists = projects.any((p) => p.name == _selectedProject);
            if (!exists && projects.isNotEmpty) {
              // If the project doesn't exist, set to first project or null
              _selectedProject = projects.first.name;
            } else if (!exists) {
              _selectedProject = null;
            }
          } else if (projects.isNotEmpty) {
            _selectedProject = projects.first.name;
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
      
      final unit = await _apiService.updateUnit(widget.unit.id, unitData);
      
      if (mounted) {
        widget.onUnitUpdated?.call(unit);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('unitUpdated') ?? 'Unit updated successfully'),
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
                      localizations?.translate('editUnit') ?? 'Edit Unit',
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
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return localizations?.translate('bedroomsRequired') ?? 'Bedrooms is required';
                                      }
                                      if (int.tryParse(value.trim()) == null) {
                                        return localizations?.translate('invalidNumber') ?? 'Invalid number';
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
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return localizations?.translate('bathroomsRequired') ?? 'Bathrooms is required';
                                      }
                                      if (int.tryParse(value.trim()) == null) {
                                        return localizations?.translate('invalidNumber') ?? 'Invalid number';
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

