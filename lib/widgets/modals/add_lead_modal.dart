import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lead_model.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import '../../widgets/phone_input.dart';

class AddLeadModal extends StatefulWidget {
  final Function(LeadModel)? onLeadCreated;

  const AddLeadModal({super.key, this.onLeadCreated});

  @override
  State<AddLeadModal> createState() => _AddLeadModalState();
}

class _AddLeadModalState extends State<AddLeadModal> {
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

  @override
  void initState() {
    super.initState();
    _loadData();
    _selectedType = 'fresh';
    _selectedPriority = 'low';
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

      if (mounted) {
        setState(() {
          _users = (usersData['results'] as List).cast<UserModel>();
          _channels = channels;
          _statuses = statuses;
          _isLoadingData = false;

          // Set defaults
          if (_users.isNotEmpty && _selectedUserId == null) {
            _selectedUserId = _users.first.id;
          }
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
      }
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/users/',
        method: 'GET',
      );
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.translate('failedToLoadData') ?? 'Failed to load data'}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      if (_phoneNumbers.isNotEmpty &&
          !_phoneNumbers.any((p) => p['is_primary'] == true)) {
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
    if (!_formKey.currentState!.validate()) return;

    if (_phoneNumbers.isEmpty && _phoneController.text.trim().isEmpty) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.translate('phoneNumberRequired') ??
                'Please enter at least one phone number',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final phoneNumbers = _phoneNumbers.isNotEmpty
          ? _phoneNumbers
                .where((p) => p['phone_number'].toString().trim().isNotEmpty)
                .toList()
          : [
              {
                'phone_number': _phoneController.text.trim(),
                'phone_type': 'mobile',
                'is_primary': true,
                'notes': '',
              },
            ];

      if (phoneNumbers.isEmpty) {
        throw Exception('At least one phone number is required');
      }

      final primaryPhone =
          phoneNumbers.firstWhere(
                (p) => p['is_primary'] == true,
                orElse: () => phoneNumbers.first,
              )['phone_number']
              as String;

      final lead = await _apiService.createLead(
        name: _nameController.text.trim(),
        phone: primaryPhone,
        phoneNumbers: phoneNumbers,
        budget: _budgetController.text.trim().isNotEmpty
            ? double.tryParse(_budgetController.text.trim()) ?? 0
            : null,
        assignedTo: _selectedUserId,
        type: _selectedType ?? 'fresh',
        communicationWay: _selectedChannel,
        priority: _selectedPriority,
        status: _selectedStatus,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onLeadCreated?.call(lead);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                    context,
                  )?.translate('leadCreatedSuccessfully') ??
                  'Lead created successfully',
            ),
            backgroundColor: Colors.green,
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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations?.translate('error') ?? 'Error'}: ${e.toString()}'), backgroundColor: Colors.red),
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
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        localizations?.translate('addNewLead') ??
                            'Add New Lead',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _isLoadingData
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name
                                Text(
                                  localizations?.translate('clientName') ??
                                      'Client Name',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    hintText:
                                        localizations?.translate(
                                          'enterClientName',
                                        ) ??
                                        'Enter client name',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return localizations?.translate(
                                            'pleaseEnterClientName',
                                          ) ??
                                          'Please enter client name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Phone Numbers
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      localizations?.translate(
                                            'phoneNumbers',
                                          ) ??
                                          'Phone Numbers',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    TextButton.icon(
                                      onPressed: _addPhoneNumber,
                                      icon: const Icon(Icons.add, size: 18),
                                      label: Text(
                                        localizations?.translate(
                                              'addPhoneNumber',
                                            ) ??
                                            'Add Phone',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                if (_phoneNumbers.isEmpty)
                                  PhoneInput(
                                    value: _phoneController.text,
                                    onChanged: (value) {
                                      setState(() {
                                        _phoneController.text = value;
                                      });
                                    },
                                    hintText:
                                        localizations?.translate(
                                          'enterPhoneNumber',
                                        ) ??
                                        'Enter phone number',
                                  ),

                                if (_phoneNumbers.isNotEmpty)
                                  ...List.generate(_phoneNumbers.length, (
                                    index,
                                  ) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: PhoneInput(
                                              value:
                                                  _phoneNumbers[index]['phone_number']
                                                      as String? ??
                                                  '',
                                              onChanged: (value) {
                                                setState(() {
                                                  _phoneNumbers[index]['phone_number'] =
                                                      value;
                                                });
                                              },
                                              hintText:
                                                  localizations?.translate(
                                                    'enterPhoneNumber',
                                                  ) ??
                                                  'Phone',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 100,
                                            child: DropdownButtonFormField<String>(
                                              initialValue:
                                                  _phoneNumbers[index]['phone_type']
                                                      as String? ??
                                                  'mobile',
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              items:
                                                  [
                                                        'mobile',
                                                        'home',
                                                        'work',
                                                        'other',
                                                      ]
                                                      .map(
                                                        (
                                                          type,
                                                        ) => DropdownMenuItem(
                                                          value: type,
                                                          child: Text(
                                                            type.toUpperCase(),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _phoneNumbers[index]['phone_type'] =
                                                      value;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Checkbox(
                                            value:
                                                _phoneNumbers[index]['is_primary']
                                                    as bool? ??
                                                false,
                                            onChanged: (value) {
                                              setState(() {
                                                _setPrimaryPhone(index);
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _removePhoneNumber(index),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                const SizedBox(height: 16),

                                // Budget
                                Text(
                                  localizations?.translate('budget') ??
                                      'Budget',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _budgetController,
                                  decoration: InputDecoration(
                                    hintText:
                                        localizations?.translate(
                                          'enterBudget',
                                        ) ??
                                        'Enter budget',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 16),

                                // Assigned To
                                Text(
                                  localizations?.translate('assignedTo') ??
                                      'Assigned To',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedUserId,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: _users
                                      .map(
                                        (user) => DropdownMenuItem(
                                          value: user.id,
                                          child: Text(user.displayName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedUserId = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Type
                                Text(
                                  localizations?.translate('type') ?? 'Type',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedType,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'fresh',
                                      child: Text(
                                        localizations?.translate('fresh') ??
                                            'Fresh',
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'cold',
                                      child: Text(
                                        localizations?.translate('cold') ??
                                            'Cold',
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedType = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Communication Way
                                Text(
                                  localizations?.translate(
                                        'communicationWay',
                                      ) ??
                                      'Communication Way',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedChannel,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: _channels
                                      .map(
                                        (channel) => DropdownMenuItem(
                                          value: channel.name,
                                          child: Text(channel.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedChannel = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Priority
                                Text(
                                  localizations?.translate('priority') ??
                                      'Priority',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedPriority,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'high',
                                      child: Text(
                                        localizations?.translate('high') ??
                                            'High',
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'medium',
                                      child: Text(
                                        localizations?.translate('medium') ??
                                            'Medium',
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'low',
                                      child: Text(
                                        localizations?.translate('low') ??
                                            'Low',
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPriority = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Status
                                Text(
                                  localizations?.translate('status') ??
                                      'Status',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedStatus,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: _statuses
                                      .where((s) => !s.isHidden)
                                      .map(
                                        (status) => DropdownMenuItem(
                                          value: status.name,
                                          child: Text(status.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 24),

                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            localizations?.translate(
                                                  'submit',
                                                ) ??
                                                'Submit',
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
