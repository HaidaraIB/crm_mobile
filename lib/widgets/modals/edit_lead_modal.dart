import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lead_model.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import '../../widgets/phone_input.dart';

class EditLeadModal extends StatefulWidget {
  final LeadModel lead;
  final Function(LeadModel)? onLeadUpdated;

  const EditLeadModal({super.key, required this.lead, this.onLeadUpdated});

  @override
  State<EditLeadModal> createState() => _EditLeadModalState();
}

class _EditLeadModalState extends State<EditLeadModal> {
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

  List<Map<String, dynamic>> _phoneNumbers = [];

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadData();
  }

  void _initializeForm() {
    _nameController.text = widget.lead.name;
    _phoneController.text = widget.lead.phone;
    _budgetController.text = widget.lead.budget > 0
        ? widget.lead.budget.toString()
        : '';
    _selectedType = widget.lead.type.toLowerCase();
    _selectedPriority = widget.lead.priority?.toLowerCase();
    _selectedStatus = widget.lead.statusName;
    _selectedChannel = widget.lead.communicationWay;
    _selectedUserId = widget.lead.assignedTo > 0
        ? widget.lead.assignedTo
        : null;

    if (widget.lead.phoneNumbers != null &&
        widget.lead.phoneNumbers!.isNotEmpty) {
      _phoneNumbers = widget.lead.phoneNumbers!
          .map(
            (pn) => {
              'phone_number': pn.phoneNumber,
              'phone_type': pn.phoneType,
              'is_primary': pn.isPrimary,
              'notes': pn.notes ?? '',
            },
          )
          .toList();
    } else {
      _phoneNumbers = [
        {
          'phone_number': widget.lead.phone,
          'phone_type': 'mobile',
          'is_primary': true,
          'notes': '',
        },
      ];
    }
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

      final lead = await _apiService.updateLead(
        id: widget.lead.id,
        name: _nameController.text.trim(),
        phone: primaryPhone,
        phoneNumbers: phoneNumbers,
        budget: _budgetController.text.trim().isNotEmpty
            ? double.tryParse(_budgetController.text.trim())
            : null,
        assignedTo: _selectedUserId,
        type: _selectedType,
        communicationWayId: channelId,
        priority: _selectedPriority,
        statusId: statusId,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onLeadUpdated?.call(lead);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                    context,
                  )?.translate('leadUpdatedSuccessfully') ??
                  'Lead updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/clients/${widget.lead.id}/',
        method: 'PATCH',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.translate('error') ?? 'Error'}: ${e.toString()}'), backgroundColor: Colors.red),
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
                        localizations?.translate('editClient') ?? 'Edit Client',
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

                                ...List.generate(_phoneNumbers.length, (index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
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
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        localizations?.translate(
                                              'unassigned',
                                            ) ??
                                            'Unassigned',
                                      ),
                                    ),
                                    ..._users.map(
                                      (user) => DropdownMenuItem(
                                        value: user.id,
                                        child: Text(user.displayName),
                                      ),
                                    ),
                                  ],
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
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('None'),
                                    ),
                                    ..._channels.map(
                                      (channel) => DropdownMenuItem(
                                        value: channel.name,
                                        child: Text(channel.name),
                                      ),
                                    ),
                                  ],
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
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('None'),
                                    ),
                                    ..._statuses
                                        .where((s) => !s.isHidden)
                                        .map(
                                          (status) => DropdownMenuItem(
                                            value: status.name,
                                            child: Text(status.name),
                                          ),
                                        ),
                                  ],
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
                                                  'saveChanges',
                                                ) ??
                                                'Save Changes',
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
