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
          final leadsData = leadsResponse['results'] as List<dynamic>? ?? [];
          final targetId = widget.deal.leadId ?? widget.deal.client;

          dynamic leadData;
          try {
            leadData = leadsData.firstWhere((l) {
              if (l is LeadModel) {
                return l.id == targetId;
              } else if (l is Map<String, dynamic>) {
                return l['id'] == targetId;
              }
              return false;
            });
          } catch (_) {
            leadData = null;
          }

          if (leadData != null) {
            if (leadData is LeadModel) {
              _lead = leadData;
            } else if (leadData is Map<String, dynamic>) {
              _lead = LeadModel.fromJson(leadData);
            }
          }
        } catch (e) {
          debugPrint('Failed to load lead: $e');
        }
      }

      // Load users
      try {
        final usersResponse = await _apiService.getUsers();
        final usersData = usersResponse['results'] as List<dynamic>? ?? [];

        if (widget.deal.startedBy != null) {
          dynamic startedByData;
          try {
            startedByData = usersData.firstWhere((u) {
              if (u is UserModel) {
                return u.id == widget.deal.startedBy;
              } else if (u is Map<String, dynamic>) {
                return u['id'] == widget.deal.startedBy;
              }
              return false;
            });
          } catch (_) {
            startedByData = null;
          }

          if (startedByData != null) {
            if (startedByData is UserModel) {
              _startedByUser = startedByData;
            } else if (startedByData is Map<String, dynamic>) {
              _startedByUser = UserModel.fromJson(startedByData);
            }
          }
        }

        if (widget.deal.closedBy != null) {
          dynamic closedByData;
          try {
            closedByData = usersData.firstWhere((u) {
              if (u is UserModel) {
                return u.id == widget.deal.closedBy;
              } else if (u is Map<String, dynamic>) {
                return u['id'] == widget.deal.closedBy;
              }
              return false;
            });
          } catch (_) {
            closedByData = null;
          }

          if (closedByData != null) {
            if (closedByData is UserModel) {
              _closedByUser = closedByData;
            } else if (closedByData is Map<String, dynamic>) {
              _closedByUser = UserModel.fromJson(closedByData);
            }
          }
        }

        if (widget.deal.employee != null) {
          dynamic employeeData;
          try {
            employeeData = usersData.firstWhere((u) {
              if (u is UserModel) {
                return u.id == widget.deal.employee;
              } else if (u is Map<String, dynamic>) {
                return u['id'] == widget.deal.employee;
              }
              return false;
            });
          } catch (_) {
            employeeData = null;
          }

          if (employeeData != null) {
            if (employeeData is UserModel) {
              _employee = employeeData;
            } else if (employeeData is Map<String, dynamic>) {
              _employee = UserModel.fromJson(employeeData);
            }
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
                (p) =>
                    p.id.toString() == widget.deal.project?.toString() ||
                    p.name == widget.deal.project?.toString(),
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
              _unit = units.firstWhere((u) => u.code == widget.deal.unitCode);
            } catch (_) {
              // Unit not found
            }
          } else if (widget.deal.unit != null) {
            try {
              _unit = units.firstWhere(
                (u) =>
                    u.id.toString() == widget.deal.unit?.toString() ||
                    u.code == widget.deal.unit?.toString(),
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

  String _getUserDisplayName(UserModel? user) {
    if (user == null) return '-';
    if (user.name != null && user.name!.isNotEmpty) return user.name!;
    if (user.firstName != null || user.lastName != null) {
      return [
        user.firstName,
        user.lastName,
      ].where((n) => n != null && n.isNotEmpty).join(' ').trim();
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
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
                    localizations?.translate('dealInformation') ??
                        'Deal Information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InfoRow(
                    icon: Icons.tag,
                    label: localizations?.translate('dealId') ?? 'Deal ID',
                    value: '#${deal.id}',
                  ),
                  InfoRow(
                    icon: Icons.person,
                    label:
                        localizations?.translate('clientName') ?? 'Client Name',
                    value: deal.clientName,
                  ),
                  if (_lead != null)
                    InfoRow(
                      icon: Icons.contacts,
                      label: localizations?.translate('lead') ?? 'Lead',
                      value: _lead!.name,
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 18,
                          color: _getStageColor(deal.stage),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations?.translate('stage') ?? 'Stage',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              StatusBadge(
                                text: _formatStage(deal.stage, localizations),
                                color: _getStageColor(deal.stage),
                                icon: _getStageIcon(deal.stage),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info,
                          size: 18,
                          color: _getStatusColor(deal.status),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations?.translate('status') ?? 'Status',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              StatusBadge(
                                text: _formatStatus(deal.status, localizations),
                                color: _getStatusColor(deal.status),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  InfoRow(
                    icon: Icons.payment,
                    label:
                        localizations?.translate('paymentMethod') ??
                        'Payment Method',
                    value: _formatPaymentMethod(
                      deal.paymentMethod,
                      localizations,
                    ),
                  ),
                  InfoRow(
                    icon: Icons.calendar_today,
                    label:
                        localizations?.translate('startDate') ?? 'Start Date',
                    value: _formatDate(deal.startDate),
                  ),
                  InfoRow(
                    icon: Icons.event,
                    label:
                        localizations?.translate('closedDate') ?? 'Closed Date',
                    value: _formatDate(deal.closedDate),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Real Estate Info
            if (_currentUser != null &&
                SpecializationHelper.isRealEstate(_currentUser))
              InventoryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.translate('realEstateInformation') ??
                          'Real Estate Information',
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
                    localizations?.translate('financialInformation') ??
                        'Financial Information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InfoRow(
                    icon: Icons.attach_money,
                    label:
                        localizations?.translate('originalValue') ??
                        'Original Value',
                    value: originalValue > 0
                        ? NumberFormat('#,##0').format(originalValue)
                        : '-',
                  ),
                  if (discountPercentage > 0)
                    InfoRow(
                      icon: Icons.percent,
                      label:
                          localizations?.translate('discountPercentage') ??
                          'Discount Percentage',
                      value: '${discountPercentage.toStringAsFixed(2)}%',
                    ),
                  if (discountAmount > 0)
                    InfoRow(
                      icon: Icons.remove_circle,
                      label:
                          localizations?.translate('discountAmount') ??
                          'Discount Amount',
                      value: NumberFormat('#,##0').format(discountAmount),
                    ),
                  if (salesCommissionPercentage > 0)
                    InfoRow(
                      icon: Icons.percent,
                      label:
                          localizations?.translate(
                            'salesCommissionPercentage',
                          ) ??
                          'Sales Commission %',
                      value: '${salesCommissionPercentage.toStringAsFixed(2)}%',
                    ),
                  if (salesCommissionAmount > 0)
                    InfoRow(
                      icon: Icons.account_balance_wallet,
                      label:
                          localizations?.translate('salesCommissionAmount') ??
                          'Sales Commission Amount',
                      value: NumberFormat(
                        '#,##0',
                      ).format(salesCommissionAmount),
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.payments,
                            size: 20,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            localizations?.translate('totalValue') ??
                                'Total Value',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Text(
                        totalValue > 0
                            ? NumberFormat('#,##0').format(totalValue)
                            : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
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
                    localizations?.translate('personnelInformation') ??
                        'Personnel Information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InfoRow(
                    icon: Icons.person,
                    label:
                        localizations?.translate('startedBy') ?? 'Started By',
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
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        deal.description!,
                        style: theme.textTheme.bodyMedium,
                      ),
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
                    label:
                        localizations?.translate('createdAt') ?? 'Created At',
                    value: _formatDate(deal.createdAt),
                  ),
                  InfoRow(
                    icon: Icons.update,
                    label:
                        localizations?.translate('updatedAt') ?? 'Updated At',
                    value: _formatDate(deal.updatedAt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
