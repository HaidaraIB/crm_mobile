import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';

class AddProjectModal extends StatefulWidget {
  final Function(Project)? onProjectCreated;
  
  const AddProjectModal({
    super.key,
    this.onProjectCreated,
  });

  @override
  State<AddProjectModal> createState() => _AddProjectModalState();
}

class _AddProjectModalState extends State<AddProjectModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _cityController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  String? _selectedDeveloper;
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  List<Developer> _developers = [];
  
  @override
  void initState() {
    super.initState();
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
          _isLoadingData = false;
          if (_developers.isNotEmpty && _selectedDeveloper == null) {
            _selectedDeveloper = _developers.first.name;
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
      // Find developer ID
      int? developerId;
      if (_selectedDeveloper != null) {
        final developer = _developers.firstWhere(
          (d) => d.name == _selectedDeveloper,
          orElse: () => _developers.first,
        );
        developerId = developer.id;
      }
      
      final projectData = {
        'name': _nameController.text.trim(),
        'developer': developerId,
        'type': _typeController.text.trim().isNotEmpty ? _typeController.text.trim() : null,
        'city': _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        'payment_method': _paymentMethodController.text.trim().isNotEmpty ? _paymentMethodController.text.trim() : null,
      };
      
      final project = await _apiService.createProject(projectData);
      
      if (mounted) {
        widget.onProjectCreated?.call(project);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('projectCreated') ?? 'Project created successfully'),
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
                  const Icon(Icons.apartment, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations?.translate('addProject') ?? 'Add Project',
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
                              initialValue: _selectedDeveloper,
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

