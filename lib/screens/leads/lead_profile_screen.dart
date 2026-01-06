import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../models/lead_model.dart';
import '../../models/settings_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/modals/assign_lead_modal.dart';
import '../../widgets/modals/add_action_modal.dart';
import 'edit_lead_screen.dart';

class LeadProfileScreen extends StatefulWidget {
  final int leadId;
  
  const LeadProfileScreen({super.key, required this.leadId});

  @override
  State<LeadProfileScreen> createState() => _LeadProfileScreenState();
}

class _LeadProfileScreenState extends State<LeadProfileScreen> {
  final ApiService _apiService = ApiService();
  LeadModel? _lead;
  bool _isLoading = true;
  String? _errorMessage;
  List<StatusModel> _statuses = [];
  bool _isUpdatingStatus = false;
  List<UserModel> _users = [];
  UserModel? _currentUser;
  bool _leadWasUpdated = false;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadLead();
    _loadStatuses();
    _loadUsers();
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
  bool _canModifyLead() {
    if (_currentUser == null || _lead == null) return false;
    // Admin can modify any lead
    if (_currentUser!.isAdmin) return true;
    // Employee can only modify leads assigned to them
    return _lead!.assignedTo == _currentUser!.id;
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
    
    final user = _users.firstWhere(
      (u) => u.id == assignedToId,
      orElse: () => UserModel(
        id: assignedToId,
        role: 'Employee',
        phone: '',
        name: 'User $assignedToId',
      ),
    );
    
    return user.displayName;
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
  
  StatusModel? _getCurrentStatus() {
    if (_lead?.statusName == null || _statuses.isEmpty) return null;
    return _statuses.firstWhere(
      (s) => s.name == _lead!.statusName,
      orElse: () => _statuses.first,
    );
  }
  
  Future<void> _updateStatus(StatusModel? newStatus) async {
    if (newStatus == null || _lead == null) return;
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    try {
      final updatedLead = await _apiService.updateLead(
        id: _lead!.id,
        status: newStatus.id.toString(),
      );
      
      setState(() {
        _lead = updatedLead;
        _isUpdatingStatus = false;
        _leadWasUpdated = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status updated to ${newStatus.name}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUpdatingStatus = false;
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
  
  Future<void> _showDeleteConfirmation(BuildContext context, AppLocalizations? localizations) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteLead') ?? 'Delete Lead'),
        content: Text(
          localizations?.translate('deleteLeadConfirm') ?? 
          'Are you sure you want to delete ${_lead?.name ?? 'this lead'}?',
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
                if (_lead != null) {
                  await _apiService.deleteLead(_lead!.id);
                  if (!mounted) return;
                  Navigator.pop(this.context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        localizations?.translate('leadDeletedSuccessfully') ?? 
                        'Lead deleted successfully',
                      ),
                    ),
                  );
                }
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
  
  Future<void> _loadLead() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final lead = await _apiService.getLeadById(widget.leadId);
      
      setState(() {
        _lead = lead;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _makeCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
  
  Future<void> _openWhatsApp(String phoneNumber) async {
    final uri = Uri.parse('https://wa.me/$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(localizations?.translate('leadProfile') ?? 'Lead Profile'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_errorMessage != null || _lead == null) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(localizations?.translate('leadProfile') ?? 'Lead Profile'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.iconTheme.color?.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Lead not found',
                style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadLead,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
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
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          result = _leadWasUpdated;
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(localizations?.translate('leadProfile') ?? 'Lead Profile'),
          actions: [
            // Filter Button
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                // Show filter options
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => _buildFilterSheet(localizations),
                );
              },
              tooltip: localizations?.translate('filter') ?? 'Filter',
            ),
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) {
                final canModify = _canModifyLead();
                final isAdmin = _currentUser?.isAdmin ?? false;
                
                return [
                  // Edit - only if can modify
                  if (canModify)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: theme.textTheme.bodyMedium?.color),
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
                          Icon(Icons.person_add, size: 20, color: theme.textTheme.bodyMedium?.color),
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
              },
              onSelected: (value) {
                if (value == 'edit' && _lead != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditLeadScreen(
                        lead: _lead!,
                        onLeadUpdated: (updatedLead) {
                          setState(() {
                            _lead = updatedLead;
                            _leadWasUpdated = true;
                          });
                          _loadLead();
                        },
                      ),
                    ),
                  );
                } else if (value == 'assign' && _lead != null) {
                  // Small delay to allow popup menu to close first
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (!mounted) return;
                    showDialog(
                      context: this.context,
                      builder: (context) => AssignLeadModal(
                        leadIds: [_lead!.id],
                        currentAssignedUserId: _lead!.assignedTo > 0 ? _lead!.assignedTo : null,
                        onAssigned: () {
                          setState(() {
                            _leadWasUpdated = true;
                          });
                          _loadLead();
                          _loadUsers(); // Reload users in case assignment changed
                        },
                      ),
                    );
                  });
                } else if (value == 'delete') {
                  _showDeleteConfirmation(context, localizations);
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // Combined Profile and Status Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Section with Avatar and Contact Info
                  Row(
                    children: [
                      // Avatar Stack with Channel Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
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
                                _lead!.name.isNotEmpty ? _lead!.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Channel Badge
                          if (_lead!.communicationWay != null)
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: 28,
                                height: 28,
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
                                  size: 16,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      
                      // Name and Phone Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lead!.name.isNotEmpty ? _lead!.name : 'Unnamed Lead',
                              style: TextStyle(
                                fontSize: 22,
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
                                Icon(Icons.phone, size: 16, color: theme.iconTheme.color?.withValues(alpha: 0.7)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _lead!.phone,
                                    style: TextStyle(
                                      fontSize: 15,
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
                            onPressed: () => _openWhatsApp(_lead!.phone),
                            isWhatsApp: true,
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            icon: Icons.phone_outlined,
                            color: AppTheme.primaryColor,
                            onPressed: () => _makeCall(_lead!.phone),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Divider
                  Divider(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2),
                    height: 1,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Status Dropdown with Color
                  if (_statuses.isNotEmpty && _lead!.statusName != null)
                    _buildStatusDropdown(context, localizations)
                  else if (_lead!.statusName != null)
                    _buildStatusDisplay(localizations),
                  const SizedBox(height: 16),
                  
                  // Assignment Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _lead!.assignedTo > 0
                              ? AppTheme.primaryColor
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _lead!.assignedTo > 0 ? Icons.person : Icons.person_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _getAssignedUserName(
                                  _lead!.assignedTo > 0 ? _lead!.assignedTo : null,
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
                      if (_lead!.communicationWay != null)
                        _buildInfoChip(
                          icon: Icons.home_outlined,
                          label: _lead!.communicationWay!,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      if (_lead!.lastFeedback != null)
                        _buildInfoChip(
                          icon: Icons.work_outline,
                          label: _lead!.lastFeedback!,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        )
                      else
                        _buildInfoChip(
                          icon: Icons.work_outline,
                          label: localizations?.translate('noFeedback') ?? 'No Feedback',
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5) ?? theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Main Content Area (Scrollable)
            Expanded(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: _buildLeadInfoTab(context, _lead!, localizations),
              ),
            ),
            
            // Add Action Button at Bottom
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: theme.brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddActionModal(
                      leadId: _lead!.id,
                      onSave: (stageId, notes, reminderDate) async {
                        // Modal is already closed by AddActionModal
                        try {
                          await _apiService.addActionToLead(
                            leadId: _lead!.id,
                            stage: stageId,
                            notes: notes,
                            reminderDate: reminderDate,
                          );
                          if (!mounted) return;
                          _loadLead();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                localizations?.translate('actionAdded') ?? 'Action added successfully',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to add action: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline, size: 22),
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
          width: 48,
          height: 48,
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
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to icon if image fails to load
                    return Icon(icon, color: color, size: 22);
                  },
                )
              : Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
  
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isHighlighted
            ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
            : null,
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
  
  Widget _buildLeadInfoTab(
    BuildContext context,
    LeadModel lead,
    AppLocalizations? localizations,
  ) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            localizations?.translate('leadInformation') ?? 'Lead Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.titleLarge?.color ?? theme.colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          
          // Detailed Info Cards - All visible
          _buildDetailCard(
            icon: Icons.person_outline,
            label: localizations?.translate('assignedTo') ?? 'Assigned To',
            value: _getAssignedUserName(lead.assignedTo > 0 ? lead.assignedTo : null, localizations),
            iconColor: AppTheme.primaryColor,
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.category_outlined,
            label: localizations?.translate('type') ?? 'Type',
            value: lead.type,
            iconColor: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.attach_money_outlined,
            label: localizations?.translate('budget') ?? 'Budget',
            value: NumberFormatter.formatCurrency(lead.budget),
            iconColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.work_outline,
            label: localizations?.translate('channel') ?? 'Channel',
            value: lead.communicationWay ?? '--',
            iconColor: const Color(0xFFF59E0B),
          ),
          if (lead.phoneNumbers != null && lead.phoneNumbers!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.phone,
              label: localizations?.translate('phoneNumbers') ?? 'Phone Numbers',
              value: lead.phoneNumbers!.map((p) => p.phoneNumber).join(', '),
              iconColor: const Color(0xFF3B82F6),
            ),
          ],
          if (lead.notes != null && lead.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.note_outlined,
              label: localizations?.translate('notes') ?? 'Notes',
              value: lead.notes!,
              iconColor: const Color(0xFF6B7280),
              isMultiline: true,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool isMultiline = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: isMultiline ? null : 2,
                  overflow: isMultiline ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusDropdown(BuildContext context, AppLocalizations? localizations) {
    final theme = Theme.of(context);
    final currentStatus = _getCurrentStatus();
    final statusColor = currentStatus != null 
        ? _parseColor(currentStatus.color) 
        : AppTheme.primaryColor;
    
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
      child: _isUpdatingStatus
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
                    _updateStatus(newStatus);
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
  
  Widget _buildStatusDisplay(AppLocalizations? localizations) {
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
            _lead!.statusName!,
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
  
  Widget _buildFilterSheet(AppLocalizations? localizations) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 24, color: theme.iconTheme.color),
              const SizedBox(width: 12),
              Text(
                localizations?.translate('filter') ?? 'Filter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            localizations?.translate('filterOptions') ?? 'Filter Options',
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodySmall?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Filter options can be added here
          ListTile(
            leading: Icon(Icons.assignment, color: theme.iconTheme.color),
            title: Text(localizations?.translate('byStatus') ?? 'By Status'),
            trailing: Icon(Icons.chevron_right, color: theme.iconTheme.color),
            onTap: () {
              Navigator.pop(context);
              // Implement status filter
            },
          ),
          ListTile(
            leading: Icon(Icons.category, color: theme.iconTheme.color),
            title: Text(localizations?.translate('byType') ?? 'By Type'),
            trailing: Icon(Icons.chevron_right, color: theme.iconTheme.color),
            onTap: () {
              Navigator.pop(context);
              // Implement type filter
            },
          ),
          ListTile(
            leading: Icon(Icons.person, color: theme.iconTheme.color),
            title: Text(localizations?.translate('byAssignee') ?? 'By Assignee'),
            trailing: Icon(Icons.chevron_right, color: theme.iconTheme.color),
            onTap: () {
              Navigator.pop(context);
              // Implement assignee filter
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}


