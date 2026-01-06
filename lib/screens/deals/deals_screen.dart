import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/deal_model.dart';
import '../../models/user_model.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../widgets/inventory_card.dart';
import '../../core/utils/specialization_helper.dart';
import 'view_deal_screen.dart';
import 'edit_deal_screen.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<DealModel> _deals = [];
  List<DealModel> _filteredDeals = [];
  bool _isLoading = true;
  String? _errorMessage;
  UserModel? _currentUser;
  
  // For real estate filtering
  List<Project> _projects = [];
  
  // Filter state
  String _selectedStatus = 'All';
  String _selectedPaymentMethod = 'All';
  String _selectedStage = 'All';
  String _selectedProject = 'All';
  String _selectedUnit = 'All';
  String _valueMin = '';
  String _valueMax = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadDeals();
    _searchController.addListener(_filterDeals);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      setState(() {
        _currentUser = user;
      });
      // Load projects and units if real estate
      if (SpecializationHelper.isRealEstate(user)) {
        _loadProjectsAndUnits();
      }
    } catch (e) {
      debugPrint('Failed to load current user: $e');
    }
  }

  Future<void> _loadProjectsAndUnits() async {
    try {
      final projects = await _apiService.getProjects();
      setState(() {
        _projects = projects;
      });
    } catch (e) {
      debugPrint('Failed to load projects: $e');
    }
  }

  Future<void> _loadDeals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final deals = await _apiService.getDealsList();
      setState(() {
        _deals = deals;
        _filteredDeals = deals;
        _isLoading = false;
      });
      _filterDeals();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterDeals() {
    final query = _searchController.text.toLowerCase();
    final isRealEstate = SpecializationHelper.isRealEstate(_currentUser);
    
    setState(() {
      _filteredDeals = _deals.where((deal) {
        // Search filter
        if (query.isNotEmpty) {
          final matchesSearch = deal.clientName.toLowerCase().contains(query) ||
              deal.id.toString().contains(query);
          if (!matchesSearch) return false;
        }
        
        // Status filter
        if (_selectedStatus != 'All') {
          if (deal.status.toLowerCase() != _selectedStatus.toLowerCase()) {
            return false;
          }
        }
        
        // Payment method filter
        if (_selectedPaymentMethod != 'All') {
          if (deal.paymentMethod.toLowerCase() != _selectedPaymentMethod.toLowerCase()) {
            return false;
          }
        }
        
        // Stage filter
        if (_selectedStage != 'All') {
          if (deal.stage != _selectedStage) {
            return false;
          }
        }
        
        // Project filter (for real estate)
        if (isRealEstate && _selectedProject != 'All') {
          final projectName = deal.projectName ?? (deal.project is String ? deal.project as String : '');
          if (projectName != _selectedProject) {
            return false;
          }
        }
        
        // Unit filter (for real estate)
        if (isRealEstate && _selectedUnit != 'All') {
          final unitCode = deal.unitCode ?? (deal.unit is String ? deal.unit as String : '');
          if (unitCode != _selectedUnit) {
            return false;
          }
        }
        
        // Value range filter
        if (_valueMin.isNotEmpty) {
          final minValue = double.tryParse(_valueMin);
          if (minValue != null && deal.value < minValue) {
            return false;
          }
        }
        if (_valueMax.isNotEmpty) {
          final maxValue = double.tryParse(_valueMax);
          if (maxValue != null && deal.value > maxValue) {
            return false;
          }
        }
        
        return true;
      }).toList();
    });
  }

  Color _getStageColor(String? stage) {
    if (stage == null) return Colors.grey;
    switch (stage.toLowerCase()) {
      case 'in_progress':
        return Colors.blue;
      case 'on_hold':
        return Colors.orange;
      case 'won':
        return Colors.green;
      case 'lost':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'reservation':
        return Colors.orange;
      case 'contracted':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatStage(String? stage, AppLocalizations? localizations) {
    if (stage == null) return '-';
    switch (stage.toLowerCase()) {
      case 'in_progress':
        return localizations?.translate('inProgress') ?? 'In Progress';
      case 'on_hold':
        return localizations?.translate('onHold') ?? 'On Hold';
      case 'won':
        return localizations?.translate('won') ?? 'Won';
      case 'lost':
        return localizations?.translate('lost') ?? 'Lost';
      case 'cancelled':
        return localizations?.translate('cancelled') ?? 'Cancelled';
      default:
        return stage;
    }
  }

  String _formatStatus(String? status, AppLocalizations? localizations) {
    if (status == null) return '-';
    switch (status.toLowerCase()) {
      case 'reservation':
        return localizations?.translate('reservation') ?? 'Reservation';
      case 'contracted':
        return localizations?.translate('contracted') ?? 'Contracted';
      case 'closed':
        return localizations?.translate('closed') ?? 'Closed';
      default:
        return status;
    }
  }

  String _formatPaymentMethod(String? method, AppLocalizations? localizations) {
    if (method == null) return '-';
    switch (method.toLowerCase()) {
      case 'cash':
        return localizations?.translate('cash') ?? 'Cash';
      case 'installment':
        return localizations?.translate('installment') ?? 'Installment';
      default:
        return method;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _showDeleteConfirmation(DealModel deal, AppLocalizations? localizations) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            localizations?.translate('deleteDeal') ?? 'Delete Deal',
            textAlign: TextAlign.center,
          ),
          content: Text(
            '${localizations?.translate('confirmDeleteDeal') ?? 'Are you sure you want to delete the deal for'} ${deal.clientName}?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(localizations?.translate('cancel') ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text(localizations?.translate('delete') ?? 'Delete'),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true && mounted) {
      try {
        await _apiService.deleteDeal(deal.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.translate('dealDeletedSuccessfully') ?? 'Deal deleted successfully',
              ),
            ),
          );
          _loadDeals();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.translate('failedToDeleteDeal') ?? 'Failed to delete deal',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isRealEstate = SpecializationHelper.isRealEstate(_currentUser);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('deals') ?? 'Deals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterBottomSheet(context, localizations, theme, isRealEstate),
            tooltip: localizations?.translate('filter') ?? 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: localizations?.translate('typeToSearch') ?? 'Type to search...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Deals list
          Expanded(
            child: _buildContent(localizations, theme, isRealEstate),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppLocalizations? localizations, ThemeData theme, bool isRealEstate) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              localizations?.translate('failedToLoadData') ?? 'Failed to load data',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDeals,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredDeals.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noDealsFound') ?? 'No deals found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadDeals,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredDeals.length,
        itemBuilder: (context, index) {
          final deal = _filteredDeals[index];
          return InventoryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with ID, client name, and status badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${deal.id}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            deal.clientName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadge(
                          text: _formatStage(deal.stage, localizations),
                          color: _getStageColor(deal.stage),
                          icon: _getStageIcon(deal.stage),
                        ),
                        const SizedBox(height: 8),
                        StatusBadge(
                          text: _formatStatus(deal.status, localizations),
                          color: _getStatusColor(deal.status),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Deal details
                if (isRealEstate) ...[
                  if (deal.projectName != null || (deal.project is String && (deal.project as String).isNotEmpty))
                    InfoRow(
                      icon: Icons.business,
                      label: localizations?.translate('project') ?? 'Project',
                      value: deal.projectName ?? (deal.project as String? ?? '-'),
                    ),
                  if (deal.unitCode != null || (deal.unit is String && (deal.unit as String).isNotEmpty))
                    InfoRow(
                      icon: Icons.home,
                      label: localizations?.translate('unit') ?? 'Unit',
                      value: deal.unitCode ?? (deal.unit as String? ?? '-'),
                    ),
                ],
                InfoRow(
                  icon: Icons.payment,
                  label: localizations?.translate('paymentMethod') ?? 'Payment Method',
                  value: _formatPaymentMethod(deal.paymentMethod, localizations),
                ),
                if (deal.startDate != null)
                  InfoRow(
                    icon: Icons.calendar_today,
                    label: localizations?.translate('startDate') ?? 'Start Date',
                    value: _formatDate(deal.startDate),
                  ),
                if (deal.closedDate != null)
                  InfoRow(
                    icon: Icons.event,
                    label: localizations?.translate('closedDate') ?? 'Closed Date',
                    value: _formatDate(deal.closedDate),
                  ),
                const SizedBox(height: 12),
                // Price display
                Align(
                  alignment: Alignment.centerRight,
                  child: PriceDisplay(price: deal.value),
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewDealScreen(deal: deal),
                          ),
                        );
                      },
                      tooltip: localizations?.translate('view') ?? 'View',
                      color: Colors.green,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditDealScreen(deal: deal),
                          ),
                        ).then((_) {
                          // Reload deals after editing
                          _loadDeals();
                        });
                      },
                      tooltip: localizations?.translate('edit') ?? 'Edit',
                      color: Colors.blue,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _showDeleteConfirmation(deal, localizations),
                      tooltip: localizations?.translate('delete') ?? 'Delete',
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getStageIcon(String? stage) {
    if (stage == null) return Icons.help_outline;
    switch (stage.toLowerCase()) {
      case 'in_progress':
        return Icons.trending_up;
      case 'on_hold':
        return Icons.pause_circle;
      case 'won':
        return Icons.check_circle;
      case 'lost':
        return Icons.cancel;
      case 'cancelled':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  void _showFilterBottomSheet(
    BuildContext context,
    AppLocalizations? localizations,
    ThemeData theme,
    bool isRealEstate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        localizations?.translate('filterDeals') ?? 'Filter Deals',
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
                  const SizedBox(height: 24),
                  // Status filter
                  Text(
                    localizations?.translate('status') ?? 'Status',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                      DropdownMenuItem(
                        value: 'All',
                        child: Text(localizations?.translate('all') ?? 'All'),
                      ),
                      DropdownMenuItem(
                        value: 'reservation',
                        child: Text(localizations?.translate('reservation') ?? 'Reservation'),
                      ),
                      DropdownMenuItem(
                        value: 'contracted',
                        child: Text(localizations?.translate('contracted') ?? 'Contracted'),
                      ),
                      DropdownMenuItem(
                        value: 'closed',
                        child: Text(localizations?.translate('closed') ?? 'Closed'),
                      ),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        _selectedStatus = value ?? 'All';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Stage filter
                  Text(
                    localizations?.translate('stage') ?? 'Stage',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStage,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'All',
                        child: Text(localizations?.translate('all') ?? 'All'),
                      ),
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
                      setModalState(() {
                        _selectedStage = value ?? 'All';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Payment method filter
                  Text(
                    localizations?.translate('paymentMethod') ?? 'Payment Method',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentMethod,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'All',
                        child: Text(localizations?.translate('all') ?? 'All'),
                      ),
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text(localizations?.translate('cash') ?? 'Cash'),
                      ),
                      DropdownMenuItem(
                        value: 'installment',
                        child: Text(localizations?.translate('installment') ?? 'Installment'),
                      ),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        _selectedPaymentMethod = value ?? 'All';
                      });
                    },
                  ),
                  // Real estate specific filters
                  if (isRealEstate) ...[
                    const SizedBox(height: 16),
                    Text(
                      localizations?.translate('project') ?? 'Project',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedProject,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text(localizations?.translate('all') ?? 'All'),
                        ),
                        ..._projects.map((project) => DropdownMenuItem(
                          value: project.name,
                          child: Text(project.name),
                        )),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          _selectedProject = value ?? 'All';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localizations?.translate('unit') ?? 'Unit',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text(localizations?.translate('all') ?? 'All'),
                        ),
                        ..._deals
                            .where((deal) {
                              final unitCode = deal.unitCode ?? (deal.unit is String ? deal.unit as String : '');
                              return unitCode.isNotEmpty;
                            })
                            .map((deal) => deal.unitCode ?? (deal.unit is String ? deal.unit as String : ''))
                            .toSet()
                            .map((unitCode) => DropdownMenuItem(
                              value: unitCode,
                              child: Text(unitCode),
                            )),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          _selectedUnit = value ?? 'All';
                        });
                      },
                    ),
                  ],
                  // Value range filters
                  const SizedBox(height: 16),
                  Text(
                    localizations?.translate('valueRangeStart') ?? 'Value Range',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: _valueMin)
                            ..selection = TextSelection.collapsed(offset: _valueMin.length),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: localizations?.translate('valueRangeStart') ?? 'Min',
                            hintText: localizations?.translate('eg500000') ?? 'e.g. 500000',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _valueMin = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: _valueMax)
                            ..selection = TextSelection.collapsed(offset: _valueMax.length),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: localizations?.translate('valueRangeEnd') ?? 'Max',
                            hintText: localizations?.translate('eg1000000') ?? 'e.g. 1000000',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _valueMax = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatus = 'All';
                              _selectedPaymentMethod = 'All';
                              _selectedStage = 'All';
                              _selectedProject = 'All';
                              _selectedUnit = 'All';
                              _valueMin = '';
                              _valueMax = '';
                            });
                            _filterDeals();
                            Navigator.pop(context);
                          },
                          child: Text(localizations?.translate('reset') ?? 'Reset'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _filterDeals();
                            Navigator.pop(context);
                          },
                          child: Text(localizations?.translate('apply') ?? 'Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

