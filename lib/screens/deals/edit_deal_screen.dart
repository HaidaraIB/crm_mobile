import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/deal_model.dart';
import '../../models/user_model.dart';
import '../../models/lead_model.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../widgets/inventory_card.dart';
import '../../core/utils/specialization_helper.dart';

class EditDealScreen extends StatefulWidget {
  final DealModel deal;

  const EditDealScreen({super.key, required this.deal});

  @override
  State<EditDealScreen> createState() => _EditDealScreenState();
}

class _EditDealScreenState extends State<EditDealScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  // Data lists
  List<LeadModel> _leads = [];
  List<UserModel> _users = [];
  List<Project> _projects = [];
  List<Unit> _units = [];
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Filtered units based on selected project
  List<Unit> get _filteredUnits {
    if (!_isRealEstate || _formState['project'] == null || _formState['project'] == '') {
      return _units;
    }
    final projectId = _formState['project'];
    if (projectId == null || projectId.isEmpty) return _units;
    return _units.where((u) => u.project == projectId).toList();
  }
  
  bool get _isRealEstate => _currentUser != null && SpecializationHelper.isRealEstate(_currentUser);
  
  // Form state
  final Map<String, String> _formState = {};
  final Map<String, String> _errors = {};
  
  // Calculated values
  double get _calculatedDiscountAmount {
    final value = double.tryParse(_formState['value'] ?? '0') ?? 0;
    final discountPercent = double.tryParse(_formState['discountPercentage'] ?? '0') ?? 0;
    return value * (discountPercent / 100);
  }
  
  double get _calculatedTotalValue {
    final value = double.tryParse(_formState['value'] ?? '0') ?? 0;
    return value - _calculatedDiscountAmount;
  }
  
  double get _calculatedSalesCommissionAmount {
    final commissionPercent = double.tryParse(_formState['salesCommissionPercentage'] ?? '0') ?? 0;
    return _calculatedTotalValue * (commissionPercent / 100);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final currentUser = await _apiService.getCurrentUser();
      setState(() {
        _currentUser = currentUser;
      });
      
      // Load leads
      final leadsResponse = await _apiService.getLeads();
      final leadsData = leadsResponse['results'] as List<dynamic>? ?? [];
      final leads = leadsData.map((l) => LeadModel.fromJson(l as Map<String, dynamic>)).toList();
      
      // Load users
      final usersResponse = await _apiService.getUsers();
      final usersData = usersResponse['results'] as List<dynamic>? ?? [];
      final users = usersData.map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
      
      // Load projects and units if real estate
      List<Project> projects = [];
      List<Unit> units = [];
      if (_isRealEstate) {
        projects = await _apiService.getProjects();
        units = await _apiService.getUnits();
      }
      
      setState(() {
        _leads = leads;
        _users = users;
        _projects = projects;
        _units = units;
      });
      
      // Initialize form state from deal
      _initializeFormState();
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeFormState() {
    final deal = widget.deal;
    
    // Handle project
    String projectValue = '';
    if (deal.projectName != null) {
      try {
        final project = _projects.firstWhere(
          (p) => p.name == deal.projectName,
        );
        projectValue = project.id.toString();
      } catch (_) {
        try {
          final project = _projects.firstWhere(
            (p) => p.id.toString() == deal.project?.toString(),
          );
          projectValue = project.id.toString();
        } catch (_) {
          if (_projects.isNotEmpty) {
            projectValue = _projects.first.id.toString();
          }
        }
      }
    } else if (deal.project != null) {
      projectValue = deal.project.toString();
    }
    
    // Handle unit
    String unitValue = '';
    if (deal.unitCode != null) {
      try {
        final unit = _units.firstWhere(
          (u) => u.code == deal.unitCode,
        );
        unitValue = unit.id.toString();
      } catch (_) {
        // Unit not found
      }
    } else if (deal.unit != null) {
      unitValue = deal.unit.toString();
    }
    
    // Calculate original value (before discount)
    final totalValue = deal.value;
    final discountAmount = deal.discountAmount ?? 0.0;
    final originalValue = totalValue + discountAmount;
    
    // Format dates for date inputs (YYYY-MM-DD)
    String formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return '';
      if (dateStr.contains('T')) return dateStr.split('T')[0];
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('yyyy-MM-dd').format(date);
      } catch (e) {
        return '';
      }
    }
    
    setState(() {
      _formState['project'] = projectValue;
      _formState['unit'] = unitValue;
      _formState['leadId'] = (deal.leadId ?? deal.client ?? 0).toString();
      _formState['employee'] = (deal.employee ?? _currentUser?.id ?? 0).toString();
      _formState['startedBy'] = (deal.startedBy ?? _currentUser?.id ?? 0).toString();
      _formState['closedBy'] = (deal.closedBy ?? _currentUser?.id ?? 0).toString();
      _formState['paymentMethod'] = deal.paymentMethod.isNotEmpty 
          ? deal.paymentMethod[0].toUpperCase() + deal.paymentMethod.substring(1).toLowerCase()
          : 'Cash';
      _formState['status'] = deal.status.isNotEmpty
          ? deal.status[0].toUpperCase() + deal.status.substring(1).toLowerCase()
          : 'Reservation';
      _formState['stage'] = deal.stage.isNotEmpty ? deal.stage : 'in_progress';
      _formState['startDate'] = formatDate(deal.startDate);
      _formState['closedDate'] = formatDate(deal.closedDate);
      _formState['value'] = originalValue > 0 ? originalValue.toString() : '';
      _formState['discountPercentage'] = (deal.discountPercentage ?? 0.0).toString();
      _formState['discountAmount'] = discountAmount.toString();
      _formState['salesCommissionPercentage'] = (deal.salesCommissionPercentage ?? 0.0).toString();
      _formState['description'] = deal.description ?? '';
    });
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() {
        _errors.remove(field);
      });
    }
  }

  bool _validateForm() {
    final newErrors = <String, String>{};
    
    if (_formState['leadId'] == null || _formState['leadId'] == '0') {
      newErrors['leadId'] = 'Lead is required';
    }
    
    if (_formState['value'] == null || _formState['value']!.isEmpty || 
        (double.tryParse(_formState['value']!) ?? 0) <= 0) {
      newErrors['value'] = 'Deal value is required and must be greater than 0';
    }
    
    if (_isRealEstate && (_formState['project'] == null || _formState['project']!.isEmpty)) {
      newErrors['project'] = 'Project is required';
    }
    
    if (_isRealEstate && (_formState['unit'] == null || _formState['unit']!.isEmpty)) {
      newErrors['unit'] = 'Unit is required';
    }
    
    setState(() {
      _errors.clear();
      _errors.addAll(newErrors);
    });
    
    return newErrors.isEmpty;
  }

  Future<void> _saveDeal() async {
    if (!_validateForm()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final payload = <String, dynamic>{
        'client': int.parse(_formState['leadId']!),
        'employee': int.tryParse(_formState['employee'] ?? '') ?? _currentUser?.id,
        'started_by': int.tryParse(_formState['startedBy'] ?? '') ?? _currentUser?.id,
        'closed_by': int.tryParse(_formState['closedBy'] ?? '') ?? _currentUser?.id,
        'payment_method': _formState['paymentMethod']?.toLowerCase() ?? 'cash',
        'status': _formState['status']?.toLowerCase() ?? 'reservation',
        'stage': _formState['stage'] ?? 'in_progress',
        'value': _calculatedTotalValue,
        'start_date': _formState['startDate']?.isNotEmpty == true ? _formState['startDate'] : null,
        'closed_date': _formState['closedDate']?.isNotEmpty == true ? _formState['closedDate'] : null,
        'discount_percentage': double.tryParse(_formState['discountPercentage'] ?? '0') ?? 0,
        'discount_amount': _calculatedDiscountAmount,
        'sales_commission_percentage': double.tryParse(_formState['salesCommissionPercentage'] ?? '0') ?? 0,
        'sales_commission_amount': _calculatedSalesCommissionAmount,
        'description': _formState['description'] ?? '',
      };
      
      if (_isRealEstate) {
        if (_formState['project']?.isNotEmpty == true) {
          payload['project'] = int.parse(_formState['project']!);
        }
        if (_formState['unit']?.isNotEmpty == true) {
          payload['unit'] = int.parse(_formState['unit']!);
        }
      }
      
      await _apiService.updateDeal(widget.deal.id, payload);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deal updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update deal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _getUserDisplayName(UserModel? user) {
    if (user == null) return 'Unknown';
    if (user.name != null && user.name!.isNotEmpty) return user.name!;
    if (user.firstName != null || user.lastName != null) {
      return [user.firstName, user.lastName].where((n) => n != null && n.isNotEmpty).join(' ').trim();
    }
    return user.username ?? user.email ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations?.translate('editDeal') ?? 'Edit Deal'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('editDeal') ?? 'Edit Deal'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveDeal,
              tooltip: localizations?.translate('save') ?? 'Save',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errors.isNotEmpty)
                InventoryCard(
                  child: Column(
                    children: _errors.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.value,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              if (_errors.isNotEmpty) const SizedBox(height: 16),
              // Real Estate Fields
              if (_isRealEstate) ...[
                InventoryCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations?.translate('realEstateInformation') ?? 'Real Estate Information',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: _formState['project'],
                        decoration: InputDecoration(
                          labelText: '${localizations?.translate('project') ?? 'Project'} *',
                          errorText: _errors['project'],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _projects.map((p) => DropdownMenuItem(
                          value: p.id.toString(),
                          child: Text(p.name),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _formState['project'] = value ?? '';
                            _formState['unit'] = ''; // Reset unit when project changes
                          });
                          _clearError('project');
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _formState['unit'],
                        decoration: InputDecoration(
                          labelText: '${localizations?.translate('unit') ?? 'Unit'} *',
                          errorText: _errors['unit'],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _filteredUnits.map((u) => DropdownMenuItem(
                          value: u.id.toString(),
                          child: Text(u.code),
                        )).toList(),
                        onChanged: _formState['project']?.isEmpty == true ? null : (value) {
                          setState(() {
                            _formState['unit'] = value ?? '';
                          });
                          _clearError('unit');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Basic Information
              InventoryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.translate('basicInformation') ?? 'Basic Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _formState['leadId'],
                      decoration: InputDecoration(
                        labelText: '${localizations?.translate('lead') ?? 'Lead'} *',
                        errorText: _errors['leadId'],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _leads.map((l) => DropdownMenuItem(
                        value: l.id.toString(),
                        child: Text(l.name),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _formState['leadId'] = value ?? '';
                        });
                        _clearError('leadId');
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _formState['stage'],
                      decoration: InputDecoration(
                        labelText: '${localizations?.translate('stage') ?? 'Stage'} *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text(localizations?.translate('inProgress') ?? 'In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'on_hold',
                          child: Text(localizations?.translate('onHold') ?? 'On Hold'),
                        ),
                        DropdownMenuItem(
                          value: 'won',
                          child: Text(localizations?.translate('won') ?? 'Won'),
                        ),
                        DropdownMenuItem(
                          value: 'lost',
                          child: Text(localizations?.translate('lost') ?? 'Lost'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text(localizations?.translate('cancelled') ?? 'Cancelled'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _formState['stage'] = value ?? 'in_progress';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _formState['status'],
                      decoration: InputDecoration(
                        labelText: localizations?.translate('status') ?? 'Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Reservation',
                          child: Text(localizations?.translate('reservation') ?? 'Reservation'),
                        ),
                        DropdownMenuItem(
                          value: 'Contracted',
                          child: Text(localizations?.translate('contracted') ?? 'Contracted'),
                        ),
                        DropdownMenuItem(
                          value: 'Closed',
                          child: Text(localizations?.translate('closed') ?? 'Closed'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _formState['status'] = value ?? 'Reservation';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _formState['paymentMethod'],
                      decoration: InputDecoration(
                        labelText: localizations?.translate('paymentMethod') ?? 'Payment Method',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text(localizations?.translate('cash') ?? 'Cash'),
                        ),
                        DropdownMenuItem(
                          value: 'Installment',
                          child: Text(localizations?.translate('installment') ?? 'Installment'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _formState['paymentMethod'] = value ?? 'Cash';
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Dates
              InventoryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.translate('dates') ?? 'Dates',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: _formState['startDate'],
                      decoration: InputDecoration(
                        labelText: localizations?.translate('startDate') ?? 'Start Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      keyboardType: TextInputType.datetime,
                      onChanged: (value) {
                        setState(() {
                          _formState['startDate'] = value;
                        });
                      },
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _formState['startDate']?.isNotEmpty == true
                              ? DateTime.tryParse(_formState['startDate']!) ?? DateTime.now()
                              : DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() {
                            _formState['startDate'] = DateFormat('yyyy-MM-dd').format(date);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _formState['closedDate'],
                      decoration: InputDecoration(
                        labelText: localizations?.translate('closedDate') ?? 'Closed Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: const Icon(Icons.event),
                      ),
                      keyboardType: TextInputType.datetime,
                      onChanged: (value) {
                        setState(() {
                          _formState['closedDate'] = value;
                        });
                      },
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _formState['closedDate']?.isNotEmpty == true
                              ? DateTime.tryParse(_formState['closedDate']!) ?? DateTime.now()
                              : DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() {
                            _formState['closedDate'] = DateFormat('yyyy-MM-dd').format(date);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Financial Information
              InventoryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.translate('financialInformation') ?? 'Financial Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: _formState['value'],
                      decoration: InputDecoration(
                        labelText: '${localizations?.translate('value') ?? 'Value'} *',
                        errorText: _errors['value'],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _formState['value'] = value;
                        });
                        _clearError('value');
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _formState['discountPercentage'],
                      decoration: InputDecoration(
                        labelText: localizations?.translate('discountPercentage') ?? 'Discount Percentage',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixText: '%',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _formState['discountPercentage'] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _calculatedDiscountAmount.toStringAsFixed(2),
                      decoration: InputDecoration(
                        labelText: localizations?.translate('discountAmount') ?? 'Discount Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.remove_circle),
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _calculatedTotalValue.toStringAsFixed(2),
                      decoration: InputDecoration(
                        labelText: localizations?.translate('totalValue') ?? 'Total Value',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.payments),
                      ),
                      readOnly: true,
                      enabled: false,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _formState['salesCommissionPercentage'],
                      decoration: InputDecoration(
                        labelText: localizations?.translate('salesCommissionPercentage') ?? 'Sales Commission Percentage',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixText: '%',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _formState['salesCommissionPercentage'] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _calculatedSalesCommissionAmount.toStringAsFixed(2),
                      decoration: InputDecoration(
                        labelText: localizations?.translate('salesCommissionAmount') ?? 'Sales Commission Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.account_balance_wallet),
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Personnel
              InventoryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.translate('personnelInformation') ?? 'Personnel Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _formState['employee'],
                      decoration: InputDecoration(
                        labelText: localizations?.translate('employee') ?? 'Employee',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _users.map((u) => DropdownMenuItem(
                        value: u.id.toString(),
                        child: Text(_getUserDisplayName(u)),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _formState['employee'] = value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _formState['startedBy'],
                      decoration: InputDecoration(
                        labelText: localizations?.translate('startedBy') ?? 'Started By',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _users.map((u) => DropdownMenuItem(
                        value: u.id.toString(),
                        child: Text(_getUserDisplayName(u)),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _formState['startedBy'] = value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _formState['closedBy'],
                      decoration: InputDecoration(
                        labelText: localizations?.translate('closedBy') ?? 'Closed By',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _users.map((u) => DropdownMenuItem(
                        value: u.id.toString(),
                        child: Text(_getUserDisplayName(u)),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _formState['closedBy'] = value ?? '';
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Description
              InventoryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.translate('description') ?? 'Description',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: _formState['description'],
                      decoration: InputDecoration(
                        labelText: localizations?.translate('description') ?? 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 4,
                      onChanged: (value) {
                        setState(() {
                          _formState['description'] = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

