import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/api_error_helper.dart';
import '../../models/deal_model.dart';
import '../../models/user_model.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../widgets/inventory_card.dart';
import '../../widgets/pull_to_refresh_body.dart';
import '../../core/utils/app_locales.dart';
import '../../core/utils/specialization_helper.dart';
import '../../core/utils/snackbar_helper.dart';
import 'view_deal_screen.dart';
import 'deal_form_screen.dart';
import 'package:crm_mobile/widgets/auto_dir_text_field.dart';
import '../../core/utils/input_text_direction.dart';
import '../../widgets/scrolling_single_line_text.dart';

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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final deals = await _apiService.getDealsList();
      if (!mounted) return;
      setState(() {
        _deals = deals;
        _filteredDeals = deals;
        _isLoading = false;
      });
      if (mounted) {
        _filterDeals();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiErrorHelper.toUserMessage(context, e);
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
        return Colors.purple;
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
      final loc = AppLocalizations.of(context)?.locale ?? AppLocales.english;
      return formatLatin(
        DateFormat('MMM dd, yyyy', AppLocales.intlDateFormat(loc)),
        date,
      );
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
          SnackbarHelper.showSuccess(
            context,
            localizations?.translate('dealDeletedSuccessfully') ?? 'Deal deleted successfully',
          );
          _loadDeals();
        }
      } catch (e) {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            localizations?.translate('failedToDeleteDeal') ?? 'Failed to delete deal',
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
    
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && mounted) {
          // Refresh data when popping (going back)
          // Use microtask to ensure widget is still mounted
          Future.microtask(() {
            if (mounted) {
              _loadDeals();
            }
          });
        }
      },
      child: Scaffold(
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
            child: AutoDirTextField(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DealFormScreen(deal: null),
            ),
          ).then((result) {
            if (result == true) {
              _loadDeals();
            }
          });
        },
        backgroundColor: AppTheme.primaryColor,
        tooltip: localizations?.translate('createDeal') ?? 'Create Deal',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildContent(AppLocalizations? localizations, ThemeData theme, bool isRealEstate) {
    if (_isLoading) {
      return const PullToRefreshBody.loading();
    }
    
    if (_errorMessage != null) {
      return PullToRefreshBody(
        onRefresh: _loadDeals,
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
      return PullToRefreshBody(
        onRefresh: _loadDeals,
        child: Text(
          localizations?.translate('noDealsFound') ?? 'No deals found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return PullToRefreshBody.list(
      onRefresh: _loadDeals,
      listPadding: const EdgeInsets.all(16),
      itemCount: _filteredDeals.length,
      itemBuilder: (context, index) {
          final deal = _filteredDeals[index];
          return _buildDealCard(
            deal: deal,
            localizations: localizations,
            theme: theme,
            isRealEstate: isRealEstate,
          );
        },
    );
  }

  TextDirection _directionForUserContent(String text) {
    final t = text.trim();
    if (t.isEmpty) return Directionality.of(context);
    if (RegExp(r'^[\d\s\-./]+$').hasMatch(t)) return TextDirection.ltr;
    return resolveBubbleTextDirection(t);
  }

  Future<void> _openDealView(DealModel deal) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ViewDealScreen(deal: deal)),
    );
    if (result == true && mounted) {
      _loadDeals();
    }
  }

  Widget _buildDealMetaChip({
    required IconData icon,
    required String label,
    required Color color,
    TextDirection? valueDirection,
  }) {
    final maxChipWidth = MediaQuery.sizeOf(context).width - 64;
    final textWidget = Flexible(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            if (valueDirection != null)
              Flexible(
                child: Directionality(
                  textDirection: valueDirection,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            else
              textWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildDealCard({
    required DealModel deal,
    required AppLocalizations? localizations,
    required ThemeData theme,
    required bool isRealEstate,
  }) {
    final clientName =
        deal.clientName.trim().isNotEmpty ? deal.clientName.trim() : '-';
    final nameStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: theme.colorScheme.onSurface,
    );

    final metaChips = <Widget>[
      _buildDealMetaChip(
        icon: Icons.payment_outlined,
        label: _formatPaymentMethod(deal.paymentMethod, localizations),
        color: theme.colorScheme.onSurfaceVariant,
      ),
      if (deal.startDate != null)
        _buildDealMetaChip(
          icon: Icons.calendar_today_outlined,
          label: _formatDate(deal.startDate),
          color: theme.colorScheme.onSurfaceVariant,
          valueDirection: TextDirection.ltr,
        ),
      if (deal.closedDate != null)
        _buildDealMetaChip(
          icon: Icons.event_outlined,
          label: _formatDate(deal.closedDate),
          color: theme.colorScheme.onSurfaceVariant,
          valueDirection: TextDirection.ltr,
        ),
    ];

    if (isRealEstate) {
      final project =
          deal.projectName ?? (deal.project is String ? deal.project as String : null);
      if (project != null && project.trim().isNotEmpty) {
        metaChips.add(
          _buildDealMetaChip(
            icon: Icons.business_outlined,
            label: project.trim(),
            color: theme.colorScheme.onSurfaceVariant,
            valueDirection: _directionForUserContent(project),
          ),
        );
      }
      final unit =
          deal.unitCode ?? (deal.unit is String ? deal.unit as String : null);
      if (unit != null && unit.trim().isNotEmpty) {
        metaChips.add(
          _buildDealMetaChip(
            icon: Icons.home_outlined,
            label: unit.trim(),
            color: theme.colorScheme.onSurfaceVariant,
            valueDirection: _directionForUserContent(unit),
          ),
        );
      }
    }

    return InventoryCard(
      onTap: () => _openDealView(deal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '#${deal.id}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: resolveBubbleTextDirection(clientName),
            child: ScrollingSingleLineText(
              text: clientName,
              style: nameStyle,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                text: _formatStage(deal.stage, localizations),
                color: _getStageColor(deal.stage),
                icon: _getStageIcon(deal.stage),
              ),
              StatusBadge(
                text: _formatStatus(deal.status, localizations),
                color: _getStatusColor(deal.status),
              ),
            ],
          ),
          if (metaChips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metaChips,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: PriceDisplay(price: deal.value),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DealFormScreen(deal: deal),
                    ),
                  );
                  if (result == true && mounted) {
                    _loadDeals();
                  }
                },
                tooltip: localizations?.translate('edit') ?? 'Edit',
                color: theme.colorScheme.primary,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    _showDeleteConfirmation(deal, localizations),
                tooltip: localizations?.translate('delete') ?? 'Delete',
                color: theme.colorScheme.error,
              ),
            ],
          ),
        ],
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
                        child: AutoDirTextField(
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
                        child: AutoDirTextField(
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
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.brightness == Brightness.dark
                                ? const Color(0xFFF3F4F6)
                                : AppTheme.primaryColor,
                            backgroundColor: theme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.10)
                                : null,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.42)
                                  : AppTheme.primaryColor.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            localizations?.translate('reset') ?? 'Reset',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _filterDeals();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            localizations?.translate('apply') ?? 'Apply',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

