import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';

class EditProjectModal extends StatefulWidget {
  final Project project;
  final Function(Project)? onProjectUpdated;
  
  const EditProjectModal({
    super.key,
    required this.project,
    this.onProjectUpdated,
  });

  @override
  State<EditProjectModal> createState() => _EditProjectModalState();
}

class _EditProjectModalState extends State<EditProjectModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _typeController;
  late TextEditingController _cityController;
  late TextEditingController _paymentMethodController;
  final ApiService _apiService = ApiService();
  
  String? _selectedDeveloper;
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  List<Developer> _developers = [];
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _typeController = TextEditingController(text: widget.project.type ?? '');
    _cityController = TextEditingController(text: widget.project.city ?? '');
    _paymentMethodController = TextEditingController(text: widget.project.paymentMethod ?? '');
    _selectedDeveloper = widget.project.developer.isNotEmpty ? widget.project.developer : null;
    _loadData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _cityController.dispose();
    _paymentMethodController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    try {
      final developers = await _apiService.getDevelopers();
      if (mounted) {
        setState(() {
          _developers = developers;
          // Verify that the selected developer exists in the list
          if (_selectedDeveloper != null) {
            final exists = developers.any((d) => d.name == _selectedDeveloper);
            if (!exists && developers.isNotEmpty) {
              // If the developer doesn't exist, set to first developer or null
              _selectedDeveloper = developers.first.name;
            } else if (!exists) {
              _selectedDeveloper = null;
            }
          } else if (developers.isNotEmpty) {
            _selectedDeveloper = developers.first.name;
          }
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
      // Find developer ID
      int? developerId;
      if (_selectedDeveloper != null && _selectedDeveloper!.isNotEmpty) {
        try {
          final developer = _developers.firstWhere(
            (d) => d.name == _selectedDeveloper,
          );
          developerId = developer.id;
        } catch (e) {
          // Developer not found in list, try to find by name
          if (_developers.isNotEmpty) {
            developerId = _developers.first.id;
          }
        }
      } else if (_developers.isNotEmpty) {
        // If no developer selected, use first one
        developerId = _developers.first.id;
      }
      
      if (developerId == null) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations?.translate('developerRequired') ?? 'Developer is required'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final projectData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'developer': developerId,
      };
      
      // Only include optional fields if they have values
      final typeValue = _typeController.text.trim();
      if (typeValue.isNotEmpty) {
        projectData['type'] = typeValue;
      }
      
      final cityValue = _cityController.text.trim();
      if (cityValue.isNotEmpty) {
        projectData['city'] = cityValue;
      }
      
      final paymentMethodValue = _paymentMethodController.text.trim();
      if (paymentMethodValue.isNotEmpty) {
        projectData['payment_method'] = paymentMethodValue;
      }
      
      debugPrint('Updating project ${widget.project.id} with data: $projectData');
      debugPrint('Selected developer: $_selectedDeveloper, Developer ID: $developerId');
      
      final project = await _apiService.updateProject(widget.project.id, projectData);
      
      if (mounted) {
        widget.onProjectUpdated?.call(project);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('projectUpdated') ?? 'Project updated successfully'),
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
                      localizations?.translate('editProject') ?? 'Edit Project',
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
                            // Developer
                            DropdownButtonFormField<String>(
                              initialValue: _selectedDeveloper != null && _developers.any((d) => d.name == _selectedDeveloper)
                                  ? _selectedDeveloper
                                  : (_developers.isNotEmpty ? _developers.first.name : null),
                              decoration: InputDecoration(
                                labelText: '${localizations?.translate('developer') ?? 'Developer'} *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: _developers.map((developer) {
                                return DropdownMenuItem(
                                  value: developer.name,
                                  child: Text(developer.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDeveloper = value;
                                  debugPrint('Developer changed to: $value');
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return localizations?.translate('developerRequired') ?? 'Developer is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Type and City in a row
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _typeController,
                                    decoration: InputDecoration(
                                      labelText: localizations?.translate('type') ?? 'Type',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
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
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Payment Method
                            TextFormField(
                              controller: _paymentMethodController,
                              decoration: InputDecoration(
                                labelText: localizations?.translate('paymentMethod') ?? 'Payment Method',
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
            ),
          ],
        ),
      ),
    );
  }
}

