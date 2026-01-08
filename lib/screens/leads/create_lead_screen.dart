import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lead_model.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import '../../widgets/phone_input.dart';

class CreateLeadScreen extends StatefulWidget {
  final Function(LeadModel)? onLeadCreated;
  
  const CreateLeadScreen({
    super.key,
    this.onLeadCreated,
  });

  @override
  State<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _budgetController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  String? _selectedType;
  String? _selectedPriority;
  String? _selectedStatus;
  String? _selectedChannel;
  int? _selectedUserId;
  
  List<UserModel> _users = [];
  List<ChannelModel> _channels = [];
  List<StatusModel> _statuses = [];
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  final List<Map<String, dynamic>> _phoneNumbers = [];
  final Map<String, String> _errors = {};
  
  @override
  void initState() {
    super.initState();
    _selectedType = 'fresh';
    _selectedPriority = 'medium';
    _loadData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _budgetController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    try {
      final usersData = await _apiService.getUsers();
      final channels = await _apiService.getChannels();
      final statuses = await _apiService.getStatuses();
      
      setState(() {
        _users = (usersData['results'] as List).cast<UserModel>();
        _channels = channels;
        _statuses = statuses;
        _isLoadingData = false;
        
        // Set defaults
        if (_channels.isNotEmpty && _selectedChannel == null) {
          _selectedChannel = _channels.first.name;
        }
        if (_statuses.isNotEmpty && _selectedStatus == null) {
          final defaultStatus = _statuses.firstWhere(
            (s) => s.isDefault && !s.isHidden,
            orElse: () => _statuses.first,
          );
          _selectedStatus = defaultStatus.name;
        }
      });
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/users/',
        method: 'GET',
      );
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
  
  bool _validateForm() {
    _errors.clear();
    bool isValid = true;
    
    if (_nameController.text.trim().isEmpty) {
      _errors['name'] = AppLocalizations.of(context)?.translate('nameRequired') ?? 'Name is required';
      isValid = false;
    }
    
    final finalPhoneNumbers = _phoneNumbers.isNotEmpty
        ? _phoneNumbers.where((p) => p['phone_number'].toString().trim().isNotEmpty).toList()
        : _phoneController.text.trim().isNotEmpty
            ? [{
                'phone_number': _phoneController.text.trim(),
                'phone_type': 'mobile',
                'is_primary': true,
                'notes': '',
              }]
            : [];
    
    if (finalPhoneNumbers.isEmpty) {
      _errors['phone'] = AppLocalizations.of(context)?.translate('phoneNumberRequired') ?? 'At least one phone number is required';
      isValid = false;
    }
    
    if (_selectedChannel == null || _selectedChannel!.isEmpty) {
      _errors['communicationWay'] = AppLocalizations.of(context)?.translate('communicationWayRequired') ?? 'Communication channel is required';
      isValid = false;
    }
    
    if (_selectedStatus == null || _selectedStatus!.isEmpty) {
      _errors['status'] = AppLocalizations.of(context)?.translate('statusRequired') ?? 'Status is required';
      isValid = false;
    }
    
    if (_selectedPriority == null || _selectedPriority!.isEmpty) {
      _errors['priority'] = AppLocalizations.of(context)?.translate('priorityRequired') ?? 'Priority is required';
      isValid = false;
    }
    
    if (_selectedType == null || _selectedType!.isEmpty) {
      _errors['type'] = AppLocalizations.of(context)?.translate('typeRequired') ?? 'Type is required';
      isValid = false;
    }
    
    setState(() {});
    return isValid;
  }
  
  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() {
        _errors.remove(field);
      });
    }
  }
  
  void _addPhoneNumber() {
    setState(() {
      _phoneNumbers.add({
        'phone_number': '',
        'phone_type': 'mobile',
        'is_primary': _phoneNumbers.isEmpty,
        'notes': '',
      });
    });
  }
  
  void _removePhoneNumber(int index) {
    setState(() {
      _phoneNumbers.removeAt(index);
      if (_phoneNumbers.isNotEmpty && !_phoneNumbers.any((p) => p['is_primary'] == true)) {
        _phoneNumbers[0]['is_primary'] = true;
      }
    });
  }
  
  void _setPrimaryPhone(int index) {
    setState(() {
      for (int i = 0; i < _phoneNumbers.length; i++) {
        _phoneNumbers[i]['is_primary'] = i == index;
      }
    });
  }
  
  Future<void> _submit() async {
    if (!_validateForm()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final phoneNumbers = _phoneNumbers.isNotEmpty
          ? _phoneNumbers.where((p) => p['phone_number'].toString().trim().isNotEmpty).toList()
          : [{
              'phone_number': _phoneController.text.trim(),
              'phone_type': 'mobile',
              'is_primary': true,
              'notes': '',
            }];
      
      Map<String, dynamic> primaryPhoneMap;
      try {
        primaryPhoneMap = phoneNumbers.firstWhere(
          (p) => p['is_primary'] == true,
        );
      } catch (e) {
        primaryPhoneMap = phoneNumbers.first;
      }
      final primaryPhone = primaryPhoneMap['phone_number'] as String;
      
      // Convert channel name to ID
      int? channelId;
      if (_selectedChannel != null) {
        final channel = _channels.firstWhere(
          (c) => c.name == _selectedChannel,
          orElse: () => _channels.first,
        );
        channelId = channel.id;
      }
      
      // Convert status name to ID
      int? statusId;
      if (_selectedStatus != null) {
        final status = _statuses.firstWhere(
          (s) => s.name == _selectedStatus,
          orElse: () => _statuses.first,
        );
        statusId = status.id;
      }
      
      final lead = await _apiService.createLead(
        name: _nameController.text.trim(),
        phone: primaryPhone,
        phoneNumbers: phoneNumbers,
        budget: _budgetController.text.trim().isNotEmpty
            ? double.tryParse(_budgetController.text.trim())
            : null,
        assignedTo: _selectedUserId,
        type: _selectedType ?? 'fresh',
        communicationWayId: channelId,
        priority: _selectedPriority,
        statusId: statusId,
      );
      
      if (mounted) {
        widget.onLeadCreated?.call(lead);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('leadCreatedSuccessfully') ?? 
              'Lead created successfully',
            ),
          ),
        );
      }
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/clients/',
        method: 'POST',
      );
      if (mounted) {
        setState(() {
          _errors['general'] = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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
    final theme = Theme.of(context);
    final isRTL = localizations?.isRTL ?? false;
    
    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(localizations?.translate('createNewLead') ?? 'Create New Lead'),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          localizations?.translate('leadInformation') ?? 'Lead Information',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 32),
                        
                        // Errors
                        if (_errors.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_errors.containsKey('general'))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      _errors['general']!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (_errors.keys.where((k) => k != 'general').isNotEmpty) ...[
                                  if (!_errors.containsKey('general'))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        localizations?.translate('pleaseFixErrors') ?? 'Please fix the following errors:',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ..._errors.entries
                                      .where((e) => e.key != 'general')
                                      .map((e) => Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              '• ${e.value}',
                                              style: const TextStyle(color: Colors.red),
                                            ),
                                          )),
                                ],
                              ],
                            ),
                          ),
                        
                        // Form fields
                        Column(
                              children: [
                                // Name
                                _buildTextField(
                                  label: '${localizations?.translate('clientName') ?? 'Client Name'} *',
                                  controller: _nameController,
                                  hint: localizations?.translate('enterClientName') ?? 'Enter client name',
                                  error: _errors['name'],
                                  onChanged: () => _clearError('name'),
                                ),
                                const SizedBox(height: 16),
                                
                                // Budget
                                _buildTextField(
                                  label: localizations?.translate('budget') ?? 'Budget',
                                  controller: _budgetController,
                                  hint: localizations?.translate('enterBudget') ?? 'Enter budget',
                                  keyboardType: TextInputType.number,
                                  error: _errors['budget'],
                                  onChanged: () => _clearError('budget'),
                                ),
                                const SizedBox(height: 16),
                                
                                // Phone Numbers
                                _buildPhoneNumbersSection(localizations, theme),
                                const SizedBox(height: 16),
                                
                                // Assigned To
                                _buildDropdown<int>(
                                  label: localizations?.translate('assignedTo') ?? 'Assigned To',
                                  value: _selectedUserId,
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(localizations?.translate('unassigned') ?? 'Unassigned'),
                                    ),
                                    ..._users.map((user) => DropdownMenuItem(
                                          value: user.id,
                                          child: Text(user.displayName),
                                        )),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedUserId = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // Type
                                _buildDropdown<String>(
                                  label: '${localizations?.translate('type') ?? 'Type'} *',
                                  value: _selectedType,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'fresh',
                                      child: Text(localizations?.translate('fresh') ?? 'Fresh'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'cold',
                                      child: Text(localizations?.translate('cold') ?? 'Cold'),
                                    ),
                                  ],
                                  error: _errors['type'],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedType = value;
                                      _clearError('type');
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // Communication Way
                                _buildDropdown<String>(
                                  label: '${localizations?.translate('communicationWay') ?? 'Communication Way'} *',
                                  value: _selectedChannel,
                                  items: _channels.map((channel) => DropdownMenuItem(
                                        value: channel.name,
                                        child: Text(channel.name),
                                      )).toList(),
                                  error: _errors['communicationWay'],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedChannel = value;
                                      _clearError('communicationWay');
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // Priority
                                _buildDropdown<String>(
                                  label: '${localizations?.translate('priority') ?? 'Priority'} *',
                                  value: _selectedPriority,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'high',
                                      child: Text(localizations?.translate('high') ?? 'High'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'medium',
                                      child: Text(localizations?.translate('medium') ?? 'Medium'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'low',
                                      child: Text(localizations?.translate('low') ?? 'Low'),
                                    ),
                                  ],
                                  error: _errors['priority'],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPriority = value;
                                      _clearError('priority');
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // Status
                                _buildDropdown<String>(
                                  label: '${localizations?.translate('status') ?? 'Status'} *',
                                  value: _selectedStatus,
                                  items: _statuses
                                      .where((s) => !s.isHidden)
                                      .map((status) => DropdownMenuItem(
                                            value: status.name,
                                            child: Text(status.name),
                                          ))
                                      .toList(),
                                  error: _errors['status'],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value;
                                      _clearError('status');
                                    });
                                  },
                                ),
                              ],
                            ),
                        
                        const SizedBox(height: 24),
                        
                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isLoading ? null : () => Navigator.pop(context),
                              child: Text(localizations?.translate('cancel') ?? 'Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(localizations?.translate('createLead') ?? 'Create Lead'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
  
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    String? error,
    VoidCallback? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorBorder: error != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  )
                : null,
          ),
          keyboardType: keyboardType,
          onChanged: (_) => onChanged?.call(),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
  
  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorBorder: error != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  )
                : null,
          ),
          items: items,
          onChanged: onChanged,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
  
  Widget _buildPhoneNumbersSection(AppLocalizations? localizations, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${localizations?.translate('phoneNumbers') ?? 'Phone Numbers'} *',
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: _addPhoneNumber,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                localizations?.translate('addPhoneNumber') ?? 'Add Phone',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_phoneNumbers.isEmpty)
          PhoneInput(
            value: _phoneController.text,
            hintText: localizations?.translate('enterPhoneNumber') ?? 'Enter phone number',
            onChanged: (value) {
              _phoneController.text = value;
              _clearError('phone');
            },
            error: _errors.containsKey('phone'),
          ),
        if (_phoneNumbers.isNotEmpty)
          ...List.generate(_phoneNumbers.length, (index) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phone Number Input Row
                    PhoneInput(
                      value: _phoneNumbers[index]['phone_number'] as String? ?? '',
                      hintText: localizations?.translate('enterPhoneNumber') ?? 'Enter phone number',
                      onChanged: (value) {
                        setState(() {
                          _phoneNumbers[index]['phone_number'] = value;
                        });
                      },
                      error: _errors.containsKey('phone'),
                    ),
                    const SizedBox(height: 12),
                    // Options Row
                    Row(
                      children: [
                        // Phone Type Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _phoneNumbers[index]['phone_type'] as String? ?? 'mobile',
                            decoration: InputDecoration(
                              labelText: localizations?.translate('type') ?? 'Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'mobile',
                                child: Text(
                                  localizations?.translate('phoneTypeMobile') ?? 'Mobile',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'home',
                                child: Text(
                                  localizations?.translate('phoneTypeHome') ?? 'Home',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'work',
                                child: Text(
                                  localizations?.translate('phoneTypeWork') ?? 'Work',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text(
                                  localizations?.translate('phoneTypeOther') ?? 'Other',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _phoneNumbers[index]['phone_type'] = value;
                              });
                            },
                            isExpanded: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Primary Checkbox
                        Row(
                          children: [
                            Checkbox(
                              value: _phoneNumbers[index]['is_primary'] as bool? ?? false,
                              onChanged: (value) {
                                setState(() {
                                  _setPrimaryPhone(index);
                                });
                              },
                            ),
                            Text(
                              localizations?.translate('primary') ?? 'Primary',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removePhoneNumber(index),
                          tooltip: localizations?.translate('delete') ?? 'Delete',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        if (_errors.containsKey('phone'))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errors['phone']!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

