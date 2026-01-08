import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../models/lead_model.dart';
import '../../models/settings_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/modals/add_action_modal.dart';
import '../../widgets/modals/assign_lead_modal.dart';
import 'create_lead_screen.dart';
import 'edit_lead_screen.dart';
import 'lead_profile_screen.dart';

class AllLeadsScreen extends StatefulWidget {
  final String? type; // 'fresh', 'cold', or null for all
  final String? status; // 'untouched', 'touched', 'following', or null for all
  final bool showAppBar;
  
  const AllLeadsScreen({
    super.key,
    this.type,
    this.status,
    this.showAppBar = true,
  });

  @override
  State<AllLeadsScreen> createState() => _AllLeadsScreenState();
}

class _AllLeadsScreenState extends State<AllLeadsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<LeadModel> _leads = [];
  List<LeadModel> _filteredLeads = [];
  bool _isLoading = true;
  String? _errorMessage;
  List<StatusModel> _statuses = [];
  final Map<int, bool> _updatingStatusMap = {}; // Track which leads are updating status
  List<UserModel> _users = [];
  final Map<int, UserModel> _userCache = {}; // Cache for users fetched individually
  UserModel? _currentUser;
  
  // Filter state
  String? _selectedType; // 'fresh', 'cold', or null for all
  String? _selectedStatus; // 'untouched', 'touched', 'following', or null for all
  int? _selectedAssigneeId; // User ID or null for all
  
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
    _searchController.addListener(_filterLeads);
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await _apiService.getCurrentUser();
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
    // Admin can modify any lead
    if (_currentUser!.isAdmin) return true;
    // Employee can only modify leads assigned to them
    return lead.assignedTo == _currentUser!.id;
  }
  
  Future<void> _loadUsers() async {
    try {
      final usersData = await _apiService.getUsers();
      setState(() {
        _users = (usersData['results'] as List).cast<UserModel>();
      });
    } catch (e) {
      // Silently fail - users are optional for display
    }
  }
  
  String _getAssignedUserName(int? assignedToId, AppLocalizations? localizations) {
    if (assignedToId == null || assignedToId <= 0) {
      return localizations?.translate('notAssigned') ?? 'Not assigned';
    }
    
    // Check cache first
    if (_userCache.containsKey(assignedToId)) {
      return _userCache[assignedToId]!.displayName;
    }
    
    // Try to find user in the list
    try {
      final user = _users.firstWhere(
        (u) => u.id == assignedToId,
      );
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
    
    setState(() {
      _updatingStatusMap[lead.id] = true;
    });
    
    try {
      final updatedLead = await _apiService.updateLead(
        id: lead.id,
        statusId: newStatus.id,
      );
      
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.translate('statusUpdatedSuccessfully') ?? 
              'Status updated to ${newStatus.name}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _updatingStatusMap[lead.id] = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadLeads() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final result = await _apiService.getLeads(
        type: widget.type,
        status: widget.status,
      );
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
          final leadStatus = (lead.statusName ?? lead.status ?? '').toLowerCase();
          return leadStatus == widget.status!.toLowerCase();
        }).toList();
      }
      
      setState(() {
        _leads = filteredLeads;
        _filteredLeads = filteredLeads;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
        _isLoading = false;
      });
    }
  }
  
  void _filterLeads() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      var filtered = _leads;
      
      // Apply search query
      if (query.isNotEmpty) {
        filtered = filtered.where((lead) {
          return lead.name.toLowerCase().contains(query) ||
              lead.phone.contains(query);
        }).toList();
      }
      
      // Apply type filter
      if (_selectedType != null) {
        filtered = filtered.where((lead) {
          return lead.type.toLowerCase() == _selectedType!.toLowerCase();
        }).toList();
      }
      
      // Apply status filter
      if (_selectedStatus != null) {
        filtered = filtered.where((lead) {
          final leadStatus = (lead.statusName ?? lead.status ?? '').toLowerCase();
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
  }
  
  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedStatus = null;
      _selectedAssigneeId = null;
    });
    _filterLeads();
  }
  
  Future<void> _openWhatsApp(String phoneNumber) async {
    try {
      // Clean phone number - remove all non-digit characters
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid phone number')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make call')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make call')),
        );
      }
    }
  }
  
  void _showAddActionModal(LeadModel lead) {
    final localizations = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddActionModal(
        leadId: lead.id,
        onSave: (stageId, notes, reminderDate) async {
          try {
            await _apiService.addActionToLead(
              leadId: lead.id,
              stage: stageId,
              notes: notes,
              reminderDate: reminderDate,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: Text(
                  localizations?.translate('actionAdded') ?? 'Action added successfully',
                ),
              ),
            );
            _loadLeads();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: Text(e.toString()),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
  
  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out')) {
      return 'NO_INTERNET';
    }
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'CONNECTION_TIMEOUT';
    }
    return error.toString();
  }

  Widget _buildErrorWidget(
    BuildContext context,
    AppLocalizations? localizations,
    ThemeData theme,
  ) {
    final isNoInternet = _errorMessage == 'NO_INTERNET';
    final isTimeout = _errorMessage == 'CONNECTION_TIMEOUT';
    
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
                  ? (localizations?.translate('noInternetConnection') ?? 'No Internet Connection')
                  : isTimeout
                      ? (localizations?.translate('connectionError') ?? 'Connection Error')
                      : (localizations?.translate('errorOccurred') ?? 'An error occurred'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isNoInternet
                  ? (localizations?.translate('noInternetMessage') ?? 'Please check your internet connection and try again')
                  : isTimeout
                      ? (localizations?.translate('connectionErrorMessage') ?? 'Unable to connect to the server. Please try again later')
                      : _errorMessage!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLeads,
              icon: const Icon(Icons.refresh),
              label: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(_getTitle(localizations)),
              actions: [
                IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.filter_list),
                      if (_selectedType != null || _selectedStatus != null || _selectedAssigneeId != null)
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
                        decoration: InputDecoration(
                          hintText: localizations?.translate('typeToSearch') ?? 'Type to search...',
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
                        onRefresh: _loadLeads,
                        child: _filteredLeads.isEmpty
                            ? Center(
                                child: Text(
                                  localizations?.translate('noLeadsFound') ?? 'No leads found',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  _loadLeads();
                },
              ),
            ),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              _loadLeads();
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    localizations?.translate('leadDeletedSuccessfully') ?? 
                    'Lead deleted successfully',
                  ),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: Colors.red,
                ),
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
  
  Widget _buildLeadCard(
    BuildContext context,
    LeadModel lead,
    AppLocalizations? localizations,
  ) {
    final theme = Theme.of(context);
    final isRTL = localizations?.isRTL ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LeadProfileScreen(leadId: lead.id),
            ),
          );
          // Refresh leads if the lead was updated
          if (result == true) {
            _loadLeads();
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar with Channel Badge, Name & Phone, Action Buttons, Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Stack with Channel Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Channel Badge
                      if (lead.communicationWay != null)
                        Positioned(
                          bottom: -2,
                          right: isRTL ? null : -2,
                          left: isRTL ? -2 : null,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.cardColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.black.withValues(alpha: 0.5)
                                      : Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.folder,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  // Name and Phone Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name.isNotEmpty ? lead.name : 'Unnamed Lead',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color ?? theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 14, color: theme.iconTheme.color?.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lead.phone,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Quick Action Buttons
                  Column(
                    children: [
                      _buildActionButton(
                        icon: Icons.chat_bubble,
                        color: const Color(0xFF25D366),
                        onPressed: () => _openWhatsApp(lead.phone),
                        isWhatsApp: true,
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.phone_outlined,
                        color: AppTheme.primaryColor,
                        onPressed: () => _makeCall(lead.phone),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  
                  // Menu Button
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.iconTheme.color,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) {
                      final canModify = _canModifyLead(lead);
                      final isAdmin = _currentUser?.isAdmin ?? false;
                      
                      return [
                        // Edit - only if can modify
                        if (canModify)
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18, color: theme.textTheme.bodyMedium?.color),
                                const SizedBox(width: 12),
                                Text(localizations?.translate('edit') ?? 'Edit'),
                              ],
                            ),
                          ),
                        // Assign - only for admin
                        if (isAdmin)
                          PopupMenuItem(
                            value: 'assign',
                            child: Row(
                              children: [
                                Icon(Icons.person_add, size: 18, color: theme.textTheme.bodyMedium?.color),
                                const SizedBox(width: 12),
                                Text(localizations?.translate('assign') ?? 'Assign'),
                              ],
                            ),
                          ),
                        // Delete - only if can modify
                        if (canModify)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, size: 18, color: Colors.red),
                                const SizedBox(width: 12),
                                Text(
                                  localizations?.translate('delete') ?? 'Delete',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                      ];
                    },
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditLeadScreen(
                              lead: lead,
                              onLeadUpdated: (updatedLead) {
                                _loadLeads();
                              },
                            ),
                          ),
                        );
                      } else if (value == 'assign') {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (!mounted) return;
                          showDialog(
                            context: this.context,
                            builder: (context) => AssignLeadModal(
                              leadIds: [lead.id],
                              currentAssignedUserId: lead.assignedTo > 0 ? lead.assignedTo : null,
                              onAssigned: () {
                                _loadLeads();
                                _loadUsers(); // Reload users in case assignment changed
                              },
                            ),
                          );
                        });
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(context, lead, localizations);
                      }
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Status Dropdown with Color
              if (_statuses.isNotEmpty && lead.statusName != null)
                _buildStatusDropdown(lead, localizations)
              else if (lead.statusName != null)
                _buildStatusDisplay(lead, localizations),
              
              const SizedBox(height: 16),
              
              // Assignment Status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: lead.assignedTo > 0
                          ? AppTheme.primaryColor
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          lead.assignedTo > 0 ? Icons.person : Icons.person_outline,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _getAssignedUserName(
                              lead.assignedTo > 0 ? lead.assignedTo : null,
                              localizations,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Additional Info Row
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (lead.communicationWay != null)
                    _buildInfoChip(
                      icon: Icons.home_outlined,
                      label: lead.communicationWay!,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  _buildInfoChip(
                    icon: Icons.work_outline,
                    label: lead.lastFeedback ?? 
                           lead.lastStage ?? 
                           (localizations?.translate('noFeedback') ?? 'No Feedback'),
                    color: lead.lastFeedback != null || lead.lastStage != null
                        ? (theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? theme.colorScheme.onSurface.withValues(alpha: 0.7))
                        : (theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5) ?? theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  if (lead.budget > 0)
                    _buildInfoChip(
                      icon: Icons.attach_money_outlined,
                      label: NumberFormatter.formatCurrency(lead.budget),
                      color: const Color(0xFF10B981),
                    ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Add Action Button (Full Width)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showAddActionModal(lead),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        localizations?.translate('addAction') ?? 'Add Action',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isWhatsApp = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: isWhatsApp
              ? Image.asset(
                  'assets/images/whatsapp_logo.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(icon, color: color, size: 20);
                  },
                )
              : Icon(icon, color: color, size: 20),
        ),
      ),
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
    final theme = Theme.of(context);
    final currentStatus = _getCurrentStatus(lead);
    final statusColor = currentStatus != null 
        ? _parseColor(currentStatus.color) 
        : AppTheme.primaryColor;
    final isUpdating = _updatingStatusMap[lead.id] ?? false;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: isUpdating
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<StatusModel>(
                value: currentStatus,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: statusColor),
                items: _statuses.map((status) {
                  final itemColor = _parseColor(status.color);
                  return DropdownMenuItem<StatusModel>(
                    value: status,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: itemColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            status.name,
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (StatusModel? newStatus) {
                  if (newStatus != null) {
                    _updateStatus(lead, newStatus);
                  }
                },
                selectedItemBuilder: (context) {
                  return _statuses.map((status) {
                    final itemColor = _parseColor(status.color);
                    return Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: itemColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            status.name,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
            ),
    );
  }
  
  Widget _buildStatusDisplay(LeadModel lead, AppLocalizations? localizations) {
    final statusColor = AppTheme.primaryColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            lead.statusName!,
            style: TextStyle(
              color: statusColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showFilterModal(BuildContext context, AppLocalizations? localizations) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                      if (_selectedType != null || _selectedStatus != null || _selectedAssigneeId != null)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _clearFilters();
                          },
                          child: Text(
                            localizations?.translate('clear') ?? 'Clear',
                            style: TextStyle(color: theme.colorScheme.error),
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
                        },
                        theme: theme,
                      ),
                      _buildFilterChip(
                        label: localizations?.translate('freshLeads') ?? 'Fresh Leads',
                        isSelected: _selectedType == 'fresh',
                        onTap: () {
                          setState(() {
                            _selectedType = 'fresh';
                          });
                        },
                        theme: theme,
                      ),
                      _buildFilterChip(
                        label: localizations?.translate('coldLeads') ?? 'Cold Leads',
                        isSelected: _selectedType == 'cold',
                        onTap: () {
                          setState(() {
                            _selectedType = 'cold';
                          });
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
                              },
                              theme: theme,
                            ),
                            ..._statuses.map((status) {
                              final statusName = status.name.toLowerCase();
                              return _buildFilterChip(
                                label: localizations?.translate(statusName) ?? status.name,
                                isSelected: _selectedStatus?.toLowerCase() == statusName,
                                onTap: () {
                                  setState(() {
                                    _selectedStatus = statusName;
                                  });
                                },
                                theme: theme,
                                color: _parseColor(status.color),
                              );
                            }),
                          ],
                        ),
                  const SizedBox(height: 24),
                  
                  // Assignee Filter - only for admin
                  if (_currentUser?.isAdmin == true) ...[
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
                              hintText: localizations?.translate('all') ?? 'All',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: theme.cardColor,
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(localizations?.translate('all') ?? 'All'),
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
                            },
                          ),
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 32),
                  
                  // Apply Button
                  SizedBox(
                    width: double.infinity,
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
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
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
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: color?.withValues(alpha: 0.2) ?? AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: color ?? AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected
            ? (color ?? AppTheme.primaryColor)
            : theme.textTheme.bodyMedium?.color,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? (color ?? AppTheme.primaryColor)
            : (theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.3)),
        width: isSelected ? 2 : 1,
      ),
    );
  }
}

