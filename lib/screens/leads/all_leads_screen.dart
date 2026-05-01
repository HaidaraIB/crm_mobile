import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/api_error_helper.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/number_formatter.dart';
import '../../models/lead_model.dart';
import '../../models/settings_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/modals/add_action_modal.dart';
import '../../widgets/modals/add_call_modal.dart';
import '../../widgets/modals/add_visit_modal.dart';
import '../../widgets/modals/send_sms_modal.dart';
import '../../widgets/modals/assign_lead_modal.dart';
import '../../widgets/lead_contact_action_button.dart';
import '../../widgets/lead_status_badge.dart';
import '../../widgets/scrolling_single_line_text.dart';
import 'create_lead_screen.dart';
import 'edit_lead_screen.dart';
import 'import_leads_screen.dart';
import 'lead_profile_screen.dart';
import '../../services/leads_excel_service.dart';

/// Formats phone for display so the plus sign always appears at the start (works in both LTR and RTL).
String _formatPhoneForDisplay(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return raw;
  return '+$digits';
}

/// Label/checkmark color on selected filter chips (readable on tinted fills).
Color _filterChipOnBase(Color baseColor) {
  return ThemeData.estimateBrightnessForColor(baseColor) == Brightness.light
      ? const Color(0xFF111827)
      : Colors.white;
}

class AllLeadsScreen extends StatefulWidget {
  final String? type; // 'fresh', 'cold', or null for all
  final String? status; // 'untouched', 'touched', 'following', or null for all
  final bool showAppBar;
  final Function(VoidCallback)?
  onFilterRequested; // Callback to register filter function
  final Function(bool Function())?
  onHasActiveFiltersRequested; // Callback to register hasActiveFilters function
  final Function(VoidCallback)?
  onImportRequested; // Register import callback for parent app bar
  final Function(VoidCallback)?
  onExportRequested; // Register export callback for parent app bar

  const AllLeadsScreen({
    super.key,
    this.type,
    this.status,
    this.showAppBar = true,
    this.onFilterRequested,
    this.onHasActiveFiltersRequested,
    this.onImportRequested,
    this.onExportRequested,
  });

  @override
  State<AllLeadsScreen> createState() => _AllLeadsScreenState();
}

class _AllLeadsScreenState extends State<AllLeadsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<LeadModel> _leads = [];
  List<LeadModel> _filteredLeads = [];
  bool _isLoading = true;
  String? _errorMessage;
  List<StatusModel> _statuses = [];
  final Map<int, bool> _updatingStatusMap =
      {}; // Track which leads are updating status
  List<UserModel> _users = [];
  final Map<int, UserModel> _userCache =
      {}; // Cache for users fetched individually
  UserModel? _currentUser;

  // Filter state
  String? _selectedType; // 'fresh', 'cold', or null for all
  String?
  _selectedStatus; // 'untouched', 'touched', 'following', or null for all
  int? _selectedAssigneeId; // User ID or null for all

  /// Key for export button; used to get sharePositionOrigin on iPad/iOS.
  final GlobalKey _exportButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Initialize filters from widget parameters
    _selectedType = widget.type;
    _selectedStatus = widget.status;
    _loadCurrentUser();
    _loadLeads();
    _loadStatuses();
    _loadUsers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register callbacks after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onFilterRequested?.call(showFilterModal);
        widget.onHasActiveFiltersRequested?.call(hasActiveFilters);
        widget.onImportRequested?.call(_openImportLeads);
        widget.onExportRequested?.call(_exportLeads);
      }
    });
  }

  Future<void> _loadCurrentUser({bool forceRefresh = false}) async {
    try {
      final user = await _apiService.getCurrentUser(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      debugPrint('Failed to load current user: $e');
    }
  }

  // Check if user can edit/delete this lead
  bool _canModifyLead(LeadModel lead) {
    if (_currentUser == null) return false;
    if (_currentUser!.isDataEntry) return false;
    if (_currentUser!.isAdmin) return true;
    if (_currentUser!.hasSupervisorPermission('can_manage_leads')) return true;
    return lead.assignedTo == _currentUser!.id;
  }

  Future<void> _loadUsers() async {
    try {
      final usersData = await _apiService.getUsers();
      if (!mounted) return;
      setState(() {
        _users = (usersData['results'] as List).cast<UserModel>();
      });
    } catch (e) {
      // Silently fail - users are optional for display
    }
  }

  String _getAssignedUserName(
    int? assignedToId,
    AppLocalizations? localizations,
  ) {
    if (assignedToId == null || assignedToId <= 0) {
      return localizations?.translate('notAssigned') ?? 'Not assigned';
    }

    // Check cache first
    if (_userCache.containsKey(assignedToId)) {
      return _userCache[assignedToId]!.displayName;
    }

    // Try to find user in the list
    try {
      final user = _users.firstWhere((u) => u.id == assignedToId);
      // Cache it for future use
      _userCache[assignedToId] = user;
      return user.displayName;
    } catch (e) {
      // User not found - try to fetch it individually
      if (!_userCache.containsKey(assignedToId)) {
        _fetchUserById(assignedToId);
        // Return loading while fetching
        return localizations?.translate('loading') ?? 'Loading...';
      }
      // Should not reach here, but fallback
      return localizations?.translate('assigned') ?? 'Assigned';
    }
  }

  Future<void> _fetchUserById(int userId) async {
    // Don't fetch if already in cache or already fetching
    if (_userCache.containsKey(userId)) return;

    try {
      final user = await _apiService.getUserById(userId);
      if (mounted) {
        setState(() {
          _userCache[userId] = user;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch user $userId: $e');
    }
  }

  Future<void> _loadStatuses() async {
    try {
      final statuses = await _apiService.getStatuses();
      if (!mounted) return;
      setState(() {
        _statuses = statuses.where((s) => !s.isHidden).toList();
      });
    } catch (e) {
      // Silently fail - statuses are optional
    }
  }

  Color _parseColor(String colorString) {
    try {
      // Remove # if present
      String hex = colorString.replaceAll('#', '');
      // Handle 3-digit hex
      if (hex.length == 3) {
        hex = hex.split('').map((c) => c + c).join();
      }
      // Add alpha if not present
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return AppTheme.primaryColor;
    }
  }

  StatusModel? _getCurrentStatus(LeadModel lead) {
    if (lead.statusName == null || _statuses.isEmpty) return null;
    return _statuses.firstWhere(
      (s) => s.name == lead.statusName,
      orElse: () => _statuses.first,
    );
  }

  Future<void> _updateStatus(LeadModel lead, StatusModel? newStatus) async {
    if (newStatus == null) return;

    if (!mounted) return;
    setState(() {
      _updatingStatusMap[lead.id] = true;
    });

    try {
      final updatedLead = await _apiService.updateLead(
        id: lead.id,
        statusId: newStatus.id,
      );

      if (!mounted) return;
      // Update the lead in the list
      setState(() {
        final index = _leads.indexWhere((l) => l.id == lead.id);
        if (index != -1) {
          _leads[index] = updatedLead;
        }
        final filteredIndex = _filteredLeads.indexWhere((l) => l.id == lead.id);
        if (filteredIndex != -1) {
          _filteredLeads[filteredIndex] = updatedLead;
        }
        _updatingStatusMap[lead.id] = false;
      });

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        SnackbarHelper.showSuccess(
          context,
          localizations?.translate('statusUpdatedSuccessfully') ??
              'Status updated to ${newStatus.name}',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updatingStatusMap[lead.id] = false;
      });

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        SnackbarHelper.showError(
          context,
          '${localizations?.translate('failedToUpdateStatus') ?? 'Failed to update status'}: ${e.toString()}',
        );
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleLeadsReloadFromSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _loadLeads();
    });
  }

  Future<void> _loadLeads({bool forceRefresh = false}) async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final searchTerm = _searchController.text.trim();
      final result = await _apiService.getLeads(
        type: widget.type,
        status: widget.status,
        search: searchTerm.isEmpty ? null : searchTerm,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      final leads = (result['results'] as List).cast<LeadModel>();

      // Apply client-side filtering to ensure accuracy
      List<LeadModel> filteredLeads = leads;

      // Filter by type if provided
      if (widget.type != null) {
        filteredLeads = filteredLeads.where((lead) {
          return lead.type.toLowerCase() == widget.type!.toLowerCase();
        }).toList();
      }

      // Filter by status if provided
      if (widget.status != null) {
        filteredLeads = filteredLeads.where((lead) {
          final leadStatus = (lead.statusName ?? lead.status ?? '')
              .toLowerCase();
          return leadStatus == widget.status!.toLowerCase();
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        _leads = filteredLeads;
        _isLoading = false;
      });
      _filterLeads();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _getErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  void _filterLeads() {
    setState(() {
      var filtered = _leads;

      // Apply type filter
      if (_selectedType != null) {
        filtered = filtered.where((lead) {
          return lead.type.toLowerCase() == _selectedType!.toLowerCase();
        }).toList();
      }

      // Apply status filter
      if (_selectedStatus != null) {
        filtered = filtered.where((lead) {
          final leadStatus = (lead.statusName ?? lead.status ?? '')
              .toLowerCase();
          return leadStatus == _selectedStatus!.toLowerCase();
        }).toList();
      }

      // Apply assignee filter
      if (_selectedAssigneeId != null) {
        filtered = filtered.where((lead) {
          return lead.assignedTo == _selectedAssigneeId;
        }).toList();
      }

      _filteredLeads = filtered;
    });
  }

  void _applyFilters() {
    _filterLeads();
    setState(() {}); // Trigger rebuild to update filter indicator
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    try {
      // Clean phone number - remove all non-digit characters
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.isEmpty) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          SnackbarHelper.showError(
            context,
            localizations?.translate('invalidPhoneNumber') ??
                'Invalid phone number',
          );
        }
        return;
      }

      final uri = Uri.parse('https://wa.me/$cleanPhone');
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        final localizations = AppLocalizations.of(context);
        SnackbarHelper.showError(
          context,
          localizations?.translate('couldNotOpenWhatsApp') ??
              'Could not open WhatsApp',
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        SnackbarHelper.showError(
          context,
          localizations?.translate('couldNotOpenWhatsApp') ??
              'Could not open WhatsApp',
        );
      }
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    try {
      final uri = Uri.parse('tel:$phoneNumber');
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        final localizations = AppLocalizations.of(context);
        SnackbarHelper.showError(
          context,
          localizations?.translate('couldNotMakeCall') ?? 'Could not make call',
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        SnackbarHelper.showError(
          context,
          localizations?.translate('couldNotMakeCall') ?? 'Could not make call',
        );
      }
    }
  }

  void _showAddActionModal(LeadModel lead) {
    showDialog(
      context: context,
      builder: (context) => AddActionModal(
        leadId: lead.id,
        onSave: (stageId, notes, reminderDate) {
          // Refresh leads list after action is added
          _loadLeads(forceRefresh: true);
        },
      ),
    );
  }

  void _showAddCallModal(LeadModel lead) {
    showDialog(
      context: context,
      builder: (context) => AddCallModal(
        leadId: lead.id,
        onSave: (callMethodId, notes, followUpDate) {
          // Refresh leads list after call is added
          _loadLeads(forceRefresh: true);
        },
      ),
    );
  }

  bool _companySupportsVisits() {
    final s = _currentUser?.company?.specialization;
    return s == 'real_estate' || s == 'services';
  }

  void _showAddVisitModal(LeadModel lead) {
    showDialog(
      context: context,
      builder: (context) => AddVisitModal(
        leadId: lead.id,
        onSave: (_, __, ___) => _loadLeads(forceRefresh: true),
      ),
    );
  }

  void _showSendSMSModal(LeadModel lead) {
    final phone = lead.phone.trim();
    if (phone.isEmpty) {
      final loc = AppLocalizations.of(context);
      SnackbarHelper.showError(
        context,
        loc?.translate('enterPhone') ?? 'Enter phone number',
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) =>
          SendSMSModal(
            leadId: lead.id,
            phoneNumber: phone,
            onSent: () => _loadLeads(forceRefresh: true),
          ),
    );
  }

  Future<void> _openImportLeads() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportLeadsScreen(
          onImportDone: () {
            _loadLeads(forceRefresh: true);
          },
        ),
      ),
    );
    _loadLeads(forceRefresh: true);
  }

  Future<void> _exportLeads() async {
    final localizations = AppLocalizations.of(context);
    if (_leads.isEmpty) {
      SnackbarHelper.showError(
        context,
        localizations?.translate('noLeadsFound') ?? 'No leads to export',
      );
      return;
    }
    Rect? sharePositionOrigin;
    final box = _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
    }
    try {
      await LeadsExcelService.exportLeadsToExcelAndShare(
        _leads,
        sharePositionOrigin: sharePositionOrigin,
      );
      if (!mounted) return;
      SnackbarHelper.showSuccess(
        context,
        localizations?.translate('exportLeads') ?? 'Export to Excel',
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, ApiErrorHelper.toUserMessage(context, e));
    }
  }

  String _getErrorMessage(dynamic error) {
    return ApiErrorHelper.toDisplayCodeOrMessage(error);
  }

  Widget _buildErrorWidget(
    BuildContext context,
    AppLocalizations? localizations,
    ThemeData theme,
  ) {
    final isNoInternet = _errorMessage == ApiErrorHelper.noInternetCode;
    final isTimeout = _errorMessage == ApiErrorHelper.connectionTimeoutCode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNoInternet ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isNoInternet
                  ? (localizations?.translate('noInternetConnection') ??
                        'No Internet Connection')
                  : isTimeout
                  ? (localizations?.translate('connectionError') ??
                        'Connection Error')
                  : (localizations?.translate('errorOccurred') ??
                        'An error occurred'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isNoInternet
                  ? (localizations?.translate('noInternetMessage') ??
                        'Please check your internet connection and try again')
                  : isTimeout
                  ? (localizations?.translate('connectionErrorMessage') ??
                        'Unable to connect to the server. Please try again later')
                  : _errorMessage!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
            onPressed: () => _loadLeads(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle(AppLocalizations? localizations) {
    if (widget.status != null) {
      if (widget.status!.toLowerCase() == 'untouched') {
        return localizations?.translate('untouched') ?? 'Untouched';
      } else if (widget.status!.toLowerCase() == 'touched') {
        return localizations?.translate('touched') ?? 'Touched';
      } else if (widget.status!.toLowerCase() == 'following') {
        return localizations?.translate('following') ?? 'Following';
      }
    }
    if (widget.type == 'fresh') {
      return localizations?.translate('freshLeads') ?? 'Fresh Leads';
    } else if (widget.type == 'cold') {
      return localizations?.translate('coldLeads') ?? 'Cold Leads';
    }
    return localizations?.translate('allLeads') ?? 'All Leads';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && mounted) {
          // Refresh data when popping (going back)
          // Use microtask to ensure widget is still mounted
          Future.microtask(() {
            if (mounted) {
              _loadLeads(forceRefresh: true);
            }
          });
        }
      },
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: Text(_getTitle(localizations)),
                actions: [
                  if (_currentUser?.isDataEntry != true)
                  IconButton(
                    key: _exportButtonKey,
                    icon: const Icon(Icons.file_upload_outlined),
                    tooltip:
                        localizations?.translate('exportLeads') ??
                        'Export to Excel',
                    onPressed: _exportLeads,
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined),
                    tooltip:
                        localizations?.translate('importLeads') ??
                        'Import from Excel',
                    onPressed: _openImportLeads,
                  ),
                  IconButton(
                    icon: Stack(
                      children: [
                        const Icon(Icons.filter_list),
                        if (_selectedType != null ||
                            _selectedStatus != null ||
                            _selectedAssigneeId != null)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () {
                      _showFilterModal(context, localizations);
                    },
                    tooltip: localizations?.translate('filter') ?? 'Filter',
                  ),
                ],
              )
            : null,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorWidget(context, localizations, theme)
            : Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _scheduleLeadsReloadFromSearch(),
                      decoration: InputDecoration(
                        hintText:
                            localizations?.translate('searchLeadsByNameOrPhone') ??
                            'Search by name or phone',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Leads List
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _loadLeads(forceRefresh: true),
                      child: _filteredLeads.isEmpty
                          ? Center(
                              child: Text(
                                localizations?.translate('noLeadsFound') ??
                                    'No leads found',
                                style: theme.textTheme.bodyLarge,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _filteredLeads.length,
                              itemBuilder: (context, index) {
                                final lead = _filteredLeads[index];
                                return _buildLeadCard(
                                  context,
                                  lead,
                                  localizations,
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateLeadScreen(
                  onLeadCreated: (lead) {
                    _loadLeads(forceRefresh: true);
                  },
                ),
              ),
            );
          },
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    LeadModel lead,
    AppLocalizations? localizations,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteLead') ?? 'Delete Lead'),
        content: Text(
          localizations?.translate('deleteLeadConfirm') ??
              'Are you sure you want to delete ${lead.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _apiService.deleteLead(lead.id);
                if (!mounted) return;
                _loadLeads(forceRefresh: true);
                SnackbarHelper.showSuccess(
                  this.context,
                  localizations?.translate('leadDeletedSuccessfully') ??
                      'Lead deleted successfully',
                );
              } catch (e) {
                if (!mounted) return;
                SnackbarHelper.showError(
                  this.context,
                  '${localizations?.translate('error') ?? 'Error'}: ${e.toString()}',
                );
              }
            },
            child: Text(
              localizations?.translate('delete') ?? 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeadCardContextMenu(
    BuildContext context,
    LeadModel lead,
    AppLocalizations? localizations,
  ) {
    final canModify = _canModifyLead(lead);
    final canAssign =
        (_currentUser?.isAdmin ?? false) ||
        (_currentUser?.hasSupervisorPermission('can_manage_leads') ?? false);
    if (!canModify && !canAssign) return;

    final theme = Theme.of(context);
    final menuItems = <PopupMenuEntry<String>>[
      if (canModify)
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit,
                size: 20,
                color: theme.textTheme.bodyMedium?.color,
              ),
              const SizedBox(width: 12),
              Text(localizations?.translate('edit') ?? 'Edit'),
            ],
          ),
        ),
      if (canAssign)
        PopupMenuItem<String>(
          value: 'assign',
          child: Row(
            children: [
              Icon(
                Icons.person_add,
                size: 20,
                color: theme.textTheme.bodyMedium?.color,
              ),
              const SizedBox(width: 12),
              Text(localizations?.translate('assign') ?? 'Assign'),
            ],
          ),
        ),
      if (canModify)
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete, size: 20, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                localizations?.translate('delete') ?? 'Delete',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
    ];

    if (_currentUser?.isDataEntry == true) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;
    final position = RelativeRect.fromRect(
      box.localToGlobal(Offset.zero) & box.size,
      Offset.zero & overlayBox.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: menuItems,
    ).then((value) {
      if (value == null || !context.mounted) return;
      if (value == 'edit') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EditLeadScreen(
                  lead: lead,
                  onLeadUpdated: (_) => _loadLeads(forceRefresh: true),
                ),
          ),
        );
      } else if (value == 'assign') {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (context) => AssignLeadModal(
              leadIds: [lead.id],
              currentAssignedUserId: lead.assignedTo > 0
                  ? lead.assignedTo
                  : null,
              onAssigned: () => _loadLeads(forceRefresh: true),
            ),
          );
        });
      } else if (value == 'delete') {
        _showDeleteConfirmation(context, lead, localizations);
      }
    });
  }

  Widget _buildLeadCard(
    BuildContext context,
    LeadModel lead,
    AppLocalizations? localizations,
  ) {
    final theme = Theme.of(context);
    return Builder(
      builder: (cardContext) {
        return GestureDetector(
          onLongPress: _currentUser?.isDataEntry == true
              ? null
              : () =>
                  _showLeadCardContextMenu(cardContext, lead, localizations),
          behavior: HitTestBehavior.deferToChild,
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _currentUser?.isDataEntry == true
                  ? null
                  : () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeadProfileScreen(leadId: lead.id),
                  ),
                );

                if (result == true) {
                  _loadLeads(forceRefresh: true);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// HEADER
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Avatar
                        _LeadAvatar(lead: lead),

                        const SizedBox(width: 14),

                        /// Name + Phone
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ScrollingSingleLineText(
                                text: lead.name.isNotEmpty
                                    ? lead.name
                                    : "Unnamed Lead",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  _formatPhoneForDisplay(lead.phone),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              if (lead.leadCompanyName != null &&
                                  lead.leadCompanyName!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  lead.leadCompanyName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        /// Quick actions (hidden for data entry — intake-only role)
                        if (_currentUser?.isDataEntry != true)
                          _LeadQuickActions(
                            lead: lead,
                            onWhatsapp: () => _openWhatsApp(lead.phone),
                            onCall: () => _makeCall(lead.phone),
                            onSms: () => _showSendSMSModal(lead),
                          ),

                        /// Menu
                      ],
                    ),

                    const SizedBox(height: 18),

                    /// STATUS
                    if (_statuses.isNotEmpty && lead.statusName != null)
                      _buildStatusDropdown(lead, localizations)
                    else if (lead.statusName != null)
                      _buildStatusDisplay(lead, localizations),

                    const SizedBox(height: 14),

                    /// Assigned user
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.86,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: lead.assignedTo > 0
                                ? (theme.brightness == Brightness.dark
                                    ? AppTheme.primaryColor.withValues(alpha: 0.25)
                                    : AppTheme.primaryColor)
                                : theme.colorScheme.tertiaryContainer.withValues(
                                    alpha: 0.85,
                                  ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: lead.assignedTo > 0
                                  ? (theme.brightness == Brightness.dark
                                      ? AppTheme.primaryColor.withValues(alpha: 0.8)
                                      : Color.lerp(
                                          AppTheme.primaryColor,
                                          Colors.black,
                                          0.18,
                                        )!)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                lead.assignedTo > 0
                                    ? Icons.person
                                    : Icons.person_outline,
                                size: 16,
                                color: lead.assignedTo > 0
                                    ? Colors.white
                                    : theme.colorScheme.onTertiaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            '${localizations?.translate('assignedTo') ?? 'Assigned To'}: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: lead.assignedTo > 0
                                              ? Colors.white
                                              : theme
                                                  .colorScheme
                                                  .onTertiaryContainer,
                                        ),
                                      ),
                                      TextSpan(
                                        text: _getAssignedUserName(
                                          lead.assignedTo > 0
                                              ? lead.assignedTo
                                              : null,
                                          localizations,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: lead.assignedTo > 0
                                              ? Colors.white
                                              : theme
                                                  .colorScheme
                                                  .onTertiaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// INFO CHIPS
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (lead.communicationWay != null)
                          _buildInfoChip(
                            icon: Icons.home_outlined,
                            label: lead.communicationWay!,
                            color: Colors.grey.shade700,
                          ),

                        _buildInfoChip(
                          icon: Icons.work_outline,
                          label:
                              lead.lastFeedback ??
                              lead.lastStage ??
                              (localizations?.translate('noFeedback') ??
                                  'No Feedback'),
                          color: Colors.grey.shade700,
                        ),

                        if (lead.budget > 0)
                          _buildInfoChip(
                            icon: Icons.attach_money,
                            label: NumberFormatter.formatCurrency(lead.budget),
                            color: const Color(0xFF16A34A),
                          ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    /// CTA (same style as lead profile screen)
                    if (_currentUser?.isDataEntry != true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showAddActionModal(lead),
                                  icon: const Icon(Icons.bolt),
                                  label: Text(
                                    localizations?.translate('addAction') ?? 'Add Action',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddCallModal(lead),
                                  icon: const Icon(Icons.phone, color: Colors.white),
                                  label: Text(
                                    localizations?.translate('addCall') ?? 'Add Call',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_companySupportsVisits()) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => _showAddVisitModal(lead),
                              icon: const Icon(Icons.place_outlined),
                              label: Text(
                                localizations?.translate('addVisit') ?? 'Add Visit',
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(LeadModel lead, AppLocalizations? localizations) {
    final currentStatus = _getCurrentStatus(lead);
    final statusColor = currentStatus != null
        ? _parseColor(currentStatus.color)
        : AppTheme.primaryColor;
    final isUpdating = _updatingStatusMap[lead.id] ?? false;

    if (_statuses.isEmpty) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (currentStatus == null) {
      return LeadStatusBadge(
        accentColor: statusColor,
        label: lead.statusName ?? '—',
        parseColor: _parseColor,
        isLoading: isUpdating,
      );
    }

    if (_currentUser?.isDataEntry == true) {
      return LeadStatusBadge(
        accentColor: statusColor,
        label: currentStatus.name,
        parseColor: _parseColor,
        isLoading: isUpdating,
      );
    }

    return LeadStatusBadge(
      accentColor: statusColor,
      label: currentStatus.name,
      parseColor: _parseColor,
      statuses: _statuses,
      selected: currentStatus,
      isLoading: isUpdating,
      onStatusSelected: (s) => _updateStatus(lead, s),
    );
  }

  Widget _buildStatusDisplay(LeadModel lead, AppLocalizations? localizations) {
    return LeadStatusBadge(
      accentColor: AppTheme.primaryColor,
      label: lead.statusName!,
      parseColor: _parseColor,
    );
  }

  // Public method to show filter modal (can be called from parent)
  void showFilterModal() {
    final localizations = AppLocalizations.of(context);
    _showFilterModal(context, localizations);
  }

  // Public method to check if any filters are active
  bool hasActiveFilters() {
    return _selectedType != null ||
        _selectedStatus != null ||
        _selectedAssigneeId != null;
  }

  void _showFilterModal(BuildContext context, AppLocalizations? localizations) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.iconTheme.color?.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations?.translate('filter') ?? 'Filter',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Type Filter
                    Text(
                      localizations?.translate('byType') ?? 'By Type',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: localizations?.translate('all') ?? 'All',
                          isSelected: _selectedType == null,
                          onTap: () {
                            setState(() {
                              _selectedType = null;
                            });
                            setModalState(() {}); // Update modal UI
                          },
                          theme: theme,
                        ),
                        _buildFilterChip(
                          label:
                              localizations?.translate('freshLeads') ??
                              'Fresh Leads',
                          isSelected: _selectedType == 'fresh',
                          onTap: () {
                            setState(() {
                              _selectedType = 'fresh';
                            });
                            setModalState(() {}); // Update modal UI
                          },
                          theme: theme,
                        ),
                        _buildFilterChip(
                          label:
                              localizations?.translate('coldLeads') ??
                              'Cold Leads',
                          isSelected: _selectedType == 'cold',
                          onTap: () {
                            setState(() {
                              _selectedType = 'cold';
                            });
                            setModalState(() {}); // Update modal UI
                          },
                          theme: theme,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Status Filter
                    Text(
                      localizations?.translate('byStatus') ?? 'By Status',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _statuses.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFilterChip(
                                label: localizations?.translate('all') ?? 'All',
                                isSelected: _selectedStatus == null,
                                onTap: () {
                                  setState(() {
                                    _selectedStatus = null;
                                  });
                                  setModalState(() {}); // Update modal UI
                                },
                                theme: theme,
                              ),
                              ..._statuses.map((status) {
                                final statusName = status.name.toLowerCase();
                                return _buildFilterChip(
                                  label:
                                      localizations?.translate(statusName) ??
                                      status.name,
                                  isSelected:
                                      _selectedStatus?.toLowerCase() ==
                                      statusName,
                                  onTap: () {
                                    setState(() {
                                      _selectedStatus = statusName;
                                    });
                                    setModalState(() {}); // Update modal UI
                                  },
                                  theme: theme,
                                  color: _parseColor(status.color),
                                );
                              }),
                            ],
                          ),
                    const SizedBox(height: 24),

                    // Assignee Filter - only for admin
                    if ((_currentUser?.isAdmin ?? false) ||
                        (_currentUser?.hasSupervisorPermission(
                              'can_manage_leads',
                            ) ??
                            false)) ...[
                      Text(
                        localizations?.translate('byAssignee') ?? 'By Assignee',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _users.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            )
                          : DropdownButtonFormField<int?>(
                              initialValue: _selectedAssigneeId,
                              decoration: InputDecoration(
                                hintText:
                                    localizations?.translate('all') ?? 'All',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.cardColor,
                              ),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    localizations?.translate('all') ?? 'All',
                                  ),
                                ),
                                ..._users.map((user) {
                                  return DropdownMenuItem<int?>(
                                    value: user.id,
                                    child: Text(user.displayName),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedAssigneeId = value;
                                });
                                setModalState(() {}); // Update modal UI
                              },
                            ),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 24),

                    // Reset + Apply (aligned with Filter Deals)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedType = null;
                                _selectedStatus = null;
                                _selectedAssigneeId = null;
                              });
                              setModalState(() {});
                              Navigator.pop(context);
                              _applyFilters();
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
                              Navigator.pop(context);
                              _applyFilters();
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
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    Color? color,
  }) {
    final base = color ?? AppTheme.primaryColor;
    final selectedFill = base.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.88 : 0.82,
    );
    final onSelected = _filterChipOnBase(base);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: selectedFill,
      checkmarkColor: isSelected ? onSelected : base,
      labelStyle: TextStyle(
        color: isSelected
            ? onSelected
            : theme.textTheme.bodyMedium?.color,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? base
            : (theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.3)),
        width: isSelected ? 2 : 1,
      ),
    );
  }
}

class _LeadAvatar extends StatelessWidget {
  final LeadModel lead;

  const _LeadAvatar({required this.lead});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0.35)
        : AppTheme.primaryColor;
    const fg = Colors.white;
    final borderColor = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0.85)
        : Color.lerp(AppTheme.primaryColor, Colors.black, 0.2)!;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: CircleAvatar(
        radius: 28,
        backgroundColor: bg,
        foregroundColor: fg,
        child: Text(
          lead.name.isNotEmpty ? lead.name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _LeadQuickActions extends StatelessWidget {
  final LeadModel lead;
  final VoidCallback onWhatsapp;
  final VoidCallback onCall;
  final VoidCallback onSms;

  const _LeadQuickActions({
    required this.lead,
    required this.onWhatsapp,
    required this.onCall,
    required this.onSms,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final whatsappLabel = loc?.translate('whatsapp') ?? 'WhatsApp';
    final smsLabel = loc?.translate('channelTypeSMS') ?? 'SMS';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LeadContactActionButton(
          accentColor: LeadContactActionButton.whatsappGreen,
          isWhatsApp: true,
          onPressed: onWhatsapp,
          tooltip: whatsappLabel,
        ),
        const SizedBox(width: 8),
        LeadContactActionButton(
          accentColor: AppTheme.primaryColor,
          icon: Icons.phone_outlined,
          onPressed: onCall,
        ),
        const SizedBox(width: 8),
        LeadContactActionButton(
          accentColor: AppTheme.smsButtonColor,
          icon: Icons.sms_outlined,
          onPressed: onSms,
          tooltip: smsLabel,
        ),
      ],
    );
  }
}
