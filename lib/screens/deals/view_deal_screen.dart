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

class ViewDealScreen extends StatefulWidget {
  final DealModel deal;

  const ViewDealScreen({super.key, required this.deal});

  @override
  State<ViewDealScreen> createState() => _ViewDealScreenState();
}

class _ViewDealScreenState extends State<ViewDealScreen> {
  final ApiService _apiService = ApiService();
  LeadModel? _lead;
  UserModel? _startedByUser;
  UserModel? _closedByUser;
  UserModel? _employee;
  Project? _project;
  Unit? _unit;
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRelatedData();
  }

  Future<void> _loadRelatedData() async {
    try {
      final currentUser = await _apiService.getCurrentUser();
      setState(() {
        _currentUser = currentUser;
      });
      final isRealEstate = SpecializationHelper.isRealEstate(currentUser);

      // Load lead
      if (widget.deal.leadId != null || widget.deal.client != null) {
        try {
          final leadsResponse = await _apiService.getLeads();
          final leads = leadsResponse['results'] as List<dynamic>? ?? [];
          final leadData = leads.firstWhere(
            (l) => l['id'] == (widget.deal.leadId ?? widget.deal.client),
            orElse: () => null,
          );
          if (leadData != null) {
            _lead = LeadModel.fromJson(leadData as Map<String, dynamic>);
          }
        } catch (e) {
          debugPrint('Failed to load lead: $e');
        }
      }

      // Load users
      try {
        final usersResponse = await _apiService.getUsers();
        final users = usersResponse['results'] as List<dynamic>? ?? [];
        
        if (widget.deal.startedBy != null) {
          final startedByData = users.firstWhere(
            (u) => u['id'] == widget.deal.startedBy,
            orElse: () => null,
          );
          if (startedByData != null) {
            _startedByUser = UserModel.fromJson(startedByData as Map<String, dynamic>);
          }
        }
        
        if (widget.deal.closedBy != null) {
          final closedByData = users.firstWhere(
            (u) => u['id'] == widget.deal.closedBy,
            orElse: () => null,
          );
          if (closedByData != null) {
            _closedByUser = UserModel.fromJson(closedByData as Map<String, dynamic>);
          }
        }
        
        if (widget.deal.employee != null) {
          final employeeData = users.firstWhere(
            (u) => u['id'] == widget.deal.employee,
            orElse: () => null,
          );
          if (employeeData != null) {
            _employee = UserModel.fromJson(employeeData as Map<String, dynamic>);
          }
        }
      } catch (e) {
        debugPrint('Failed to load users: $e');
      }

      // Load project and unit for real estate
      if (isRealEstate) {
        try {
          final projects = await _apiService.getProjects();
          if (widget.deal.projectName != null) {
            try {
              _project = projects.firstWhere(
                (p) => p.name == widget.deal.projectName,
              );
            } catch (_) {
              try {
                _project = projects.firstWhere(
                  (p) => p.id.toString() == widget.deal.project?.toString(),
                );
              } catch (_) {
                if (projects.isNotEmpty) {
                  _project = projects.first;
                }
              }
            }
          } else if (widget.deal.project != null) {
            try {
              _project = projects.firstWhere(
                (p) => p.id.toString() == widget.deal.project?.toString() || p.name == widget.deal.project?.toString(),
              );
            } catch (_) {
              // Project not found
            }
          }
        } catch (e) {
          debugPrint('Failed to load project: $e');
        }

        try {
          final units = await _apiService.getUnits();
          if (widget.deal.unitCode != null) {
            try {
              _unit = units.firstWhere(
                (u) => u.code == widget.deal.unitCode,
              );
            } catch (_) {
              // Unit not found
            }
          } else if (widget.deal.unit != null) {
            try {
              _unit = units.firstWhere(
                (u) => u.id.toString() == widget.deal.unit?.toString() || u.code == widget.deal.unit?.toString(),
              );
            } catch (_) {
              // Unit not found
            }
          }
        } catch (e) {
          debugPrint('Failed to load unit: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading related data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  String _getUserDisplayName(UserModel? user) {
    if (user == null) return '-';
    if (user.name != null && user.name!.isNotEmpty) return user.name!;
    if (user.firstName != null || user.lastName != null) {
      return [user.firstName, user.lastName].where((n) => n != null && n.isNotEmpty).join(' ').trim();
    }
    return user.username ?? user.email ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final deal = widget.deal;

    // Calculate financial values
    final totalValue = deal.value;
    final discountAmount = deal.discountAmount ?? 0.0;
    final discountPercentage = deal.discountPercentage ?? 0.0;
    final salesCommissionPercentage = deal.salesCommissionPercentage ?? 0.0;
    final salesCommissionAmount = deal.salesCommissionAmount ?? 0.0;
    
    // Calculate original value (before discount)
    double originalValue = totalValue;
    if (discountAmount > 0) {
      originalValue = totalValue + discountAmount;
    } else if (discountPercentage > 0 && totalValue > 0) {
      originalValue = totalValue / (1 - discountPercentage / 100);
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations?.translate('viewDeal') ?? 'View Deal'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('viewDeal') ?? 'View Deal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card with Key Info
            InventoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations?.translate('dealInformation') ?? 'Deal Information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildInfoItem(
                        theme,
                        localizations?.translate('dealId') ?? 'Deal ID',
                        '#${deal.id}',
                      ),
                      _buildInfoItem(
                        theme,
                        localizations?.translate('clientName') ?? 'Client Name',
                        deal.clientName,
                      ),
                      if (_lead != null)
                        _buildInfoItem(
                          theme,
                          localizations?.translate('lead') ?? 'Lead',
                          _lead!.name,
                        ),
                      _buildInfoItemWithBadge(
                        theme,
                        localizations?.translate('stage') ?? 'Stage',
                        _formatStage(deal.stage, localizations),
                        _getStageColor(deal.stage),
                      ),
                      _buildInfoItemWithBadge(
                        theme,
                        localizations?.translate('status') ?? 'Status',
                        _formatStatus(deal.status, localizations),
                        _getStatusColor(deal.status),
                      ),
                      _buildInfoItem(
                        theme,
                        localizations?.translate('paymentMethod') ?? 'Payment Method',
                        _formatPaymentMethod(deal.paymentMethod, localizations),
                      ),
                      _buildInfoItem(
                        theme,
                        localizations?.translate('startDate') ?? 'Start Date',
                        _formatDate(deal.startDate),
                      ),
                      _buildInfoItem(
                        theme,
                        localizations?.translate('closedDate') ?? 'Closed Date',
                        _formatDate(deal.closedDate),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Real Estate Info
            if (_currentUser != null && SpecializationHelper.isRealEstate(_currentUser))
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
                    if (_project != null || deal.projectName != null)
                      InfoRow(
                        icon: Icons.business,
                        label: localizations?.translate('project') ?? 'Project',
                        value: _project?.name ?? deal.projectName ?? '-',
                      ),
                    if (_unit != null || deal.unitCode != null)
                      InfoRow(
                        icon: Icons.home,
                        label: localizations?.translate('unit') ?? 'Unit',
                        value: _unit?.code ?? deal.unitCode ?? '-',
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
                  InfoRow(
                    icon: Icons.attach_money,
                    label: localizations?.translate('originalValue') ?? 'Original Value',
                    value: originalValue > 0 ? NumberFormat('#,##0').format(originalValue) : '-',
                  ),
                  if (discountPercentage > 0)
                    InfoRow(
                      icon: Icons.percent,
                      label: localizations?.translate('discountPercentage') ?? 'Discount Percentage',
                      value: '${discountPercentage.toStringAsFixed(2)}%',
                    ),
                  if (discountAmount > 0)
                    InfoRow(
                      icon: Icons.remove_circle,
                      label: localizations?.translate('discountAmount') ?? 'Discount Amount',
                      value: NumberFormat('#,##0').format(discountAmount),
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payments, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          const SizedBox(width: 8),
                          Text(
                            localizations?.translate('totalValue') ?? 'Total Value',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Text(
                        totalValue > 0 ? NumberFormat('#,##0').format(totalValue) : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (salesCommissionPercentage > 0)
                    InfoRow(
                      icon: Icons.percent,
                      label: localizations?.translate('salesCommissionPercentage') ?? 'Sales Commission %',
                      value: '${salesCommissionPercentage.toStringAsFixed(2)}%',
                    ),
                  if (salesCommissionAmount > 0)
                    InfoRow(
                      icon: Icons.account_balance_wallet,
                      label: localizations?.translate('salesCommissionAmount') ?? 'Sales Commission Amount',
                      value: NumberFormat('#,##0').format(salesCommissionAmount),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Personnel Information
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
                  InfoRow(
                    icon: Icons.person,
                    label: localizations?.translate('startedBy') ?? 'Started By',
                    value: _getUserDisplayName(_startedByUser),
                  ),
                  InfoRow(
                    icon: Icons.person,
                    label: localizations?.translate('closedBy') ?? 'Closed By',
                    value: _getUserDisplayName(_closedByUser),
                  ),
                  if (_employee != null)
                    InfoRow(
                      icon: Icons.badge,
                      label: localizations?.translate('employee') ?? 'Employee',
                      value: _getUserDisplayName(_employee),
                    ),
                ],
              ),
            ),
            if (deal.description != null && deal.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
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
                    const SizedBox(height: 12),
                    Text(
                      deal.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Timestamps
            InventoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations?.translate('timestamps') ?? 'Timestamps',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InfoRow(
                    icon: Icons.calendar_today,
                    label: localizations?.translate('createdAt') ?? 'Created At',
                    value: _formatDate(deal.createdAt),
                  ),
                  InfoRow(
                    icon: Icons.update,
                    label: localizations?.translate('updatedAt') ?? 'Updated At',
                    value: _formatDate(deal.updatedAt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItemWithBadge(ThemeData theme, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        StatusBadge(
          text: value,
          color: color,
        ),
      ],
    );
  }
}

