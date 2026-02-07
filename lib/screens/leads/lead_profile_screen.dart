import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/number_formatter.dart';
import '../../models/lead_model.dart';
import '../../models/settings_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/modals/assign_lead_modal.dart';
import '../../widgets/modals/add_action_modal.dart';
import '../../widgets/modals/add_call_modal.dart';
import '../../widgets/phone_input.dart';
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
  final Map<String, bool> _updatingPrimaryMap = {}; // Track which phone numbers are being set as primary
  
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
        statusId: newStatus.id,
      );
      
      setState(() {
        _lead = updatedLead;
        _isUpdatingStatus = false;
        _leadWasUpdated = true;
      });
      
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        SnackbarHelper.showSuccess(
          context,
          localizations?.translate('statusUpdatedSuccessfully') ?? 'Status updated successfully',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      setState(() {
        _isUpdatingStatus = false;
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
                  Navigator.pop(this.context, true); // Pass true to indicate deletion
                  SnackbarHelper.showSuccess(
                    this.context,
                    localizations?.translate('leadDeletedSuccessfully') ?? 
                        'Lead deleted successfully',
                  );
                }
              } catch (e) {
                if (!mounted) return;
                SnackbarHelper.showError(this.context, e.toString());
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
    try {
      final uri = Uri.parse('tel:$phoneNumber');
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('cannotMakeCall') ?? 'Could not make call',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('cannotMakeCall') ?? 'Could not make call',
        );
      }
    }
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
            localizations?.translate('invalidPhoneNumber') ?? 'Invalid phone number',
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
          localizations?.translate('couldNotOpenWhatsApp') ?? 'Could not open WhatsApp',
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        SnackbarHelper.showError(
          context,
          localizations?.translate('couldNotOpenWhatsApp') ?? 'Could not open WhatsApp',
        );
      }
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
          Navigator.of(context).pop(_leadWasUpdated);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(localizations?.translate('leadProfile') ?? 'Lead Profile'),
          actions: [
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
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  padding: const EdgeInsets.all(16),
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
                  
                  const SizedBox(height: 16),
                  
                  // Divider
                  Divider(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2),
                    height: 1,
                  ),
                  
                  const SizedBox(height: 16),
                  
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
                  const SizedBox(height: 12),
                  
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
            
            // Add Action and Add Call Buttons at Bottom
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
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AddActionModal(
                            leadId: _lead!.id,
                            onSave: (stageId, notes, reminderDate) {
                              // Refresh lead data after action is added
                              _loadLead();
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AddCallModal(
                            leadId: _lead!.id,
                            onSave: (callMethodId, notes, followUpDate) {
                              // Refresh lead data after call is added
                              _loadLead();
                            },
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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
                          const Icon(Icons.phone, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            localizations?.translate('addCall') ?? 'Add Call',
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
          // Phone Numbers Section with WhatsApp and Call buttons
          const SizedBox(height: 12),
          _buildPhoneNumbersSection(lead, localizations),
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
  
  Widget _buildPhoneNumbersSection(LeadModel lead, AppLocalizations? localizations) {
    final theme = Theme.of(context);
    final List<PhoneNumber> allPhones = [];
    
    // Collect all phone numbers from phoneNumbers list
    if (lead.phoneNumbers != null && lead.phoneNumbers!.isNotEmpty) {
      allPhones.addAll(lead.phoneNumbers!);
    }
    
    // Add primary phone only if it's not already in the phoneNumbers list
    if (lead.phone.isNotEmpty) {
      final isPrimaryPhoneInList = allPhones.any(
        (phone) => phone.phoneNumber == lead.phone || 
                   (phone.isPrimary && phone.phoneNumber == lead.phone),
      );
      
      if (!isPrimaryPhoneInList) {
        allPhones.insert(0, PhoneNumber(
          id: 0,
          phoneNumber: lead.phone,
          phoneType: 'mobile',
          isPrimary: true,
        ));
      }
    }
    
    if (allPhones.isEmpty) {
      return _buildDetailCard(
        icon: Icons.phone,
        label: localizations?.translate('phoneNumbers') ?? 'Phone Numbers',
        value: localizations?.translate('noPhoneNumbers') ?? 'No phone numbers',
        iconColor: const Color(0xFF3B82F6),
      );
    }
    
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations?.translate('phoneNumbers') ?? 'Phone Numbers',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleLarge?.color ?? theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (_canModifyLead())
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  color: AppTheme.primaryColor,
                  onPressed: () => _showAddPhoneNumberModal(lead, localizations),
                  tooltip: localizations?.translate('addPhoneNumber') ?? 'Add Phone',
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...allPhones.map((phone) => _buildPhoneNumberItem(phone, localizations)),
        ],
      ),
    );
  }
  
  Widget _buildPhoneNumberItem(PhoneNumber phone, AppLocalizations? localizations) {
    final theme = Theme.of(context);
    
    String phoneTypeLabel;
    if (phone.phoneType == 'mobile') {
      phoneTypeLabel = localizations?.translate('phoneTypeMobile') ?? 'Mobile';
    } else if (phone.phoneType == 'home') {
      phoneTypeLabel = localizations?.translate('phoneTypeHome') ?? 'Home';
    } else if (phone.phoneType == 'work') {
      phoneTypeLabel = localizations?.translate('phoneTypeWork') ?? 'Work';
    } else {
      phoneTypeLabel = localizations?.translate('phoneTypeOther') ?? 'Other';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primary Banner (if primary)
                if (phone.isPrimary) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 12,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          localizations?.translate('primary') ?? 'Primary',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                // Phone Number (full width)
                Text(
                  phone.phoneNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phoneTypeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
                        theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Set as Primary Button (only for non-primary numbers)
          if (!phone.isPrimary && _canModifyLead())
            _updatingPrimaryMap[phone.phoneNumber] == true
                ? SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  )
                : _buildPhoneActionButton(
                    icon: Icons.star_outline,
                    color: AppTheme.primaryColor,
                    onPressed: () => _setPhoneAsPrimary(phone, localizations),
                    tooltip: localizations?.translate('setAsPrimary') ?? 'Set as Primary',
                  ),
          if (!phone.isPrimary && _canModifyLead())
            const SizedBox(width: 8),
          // WhatsApp Button
          _buildPhoneActionButton(
            icon: Icons.chat_bubble,
            color: const Color(0xFF25D366),
            onPressed: () => _openWhatsApp(phone.phoneNumber),
            isWhatsApp: true,
          ),
          const SizedBox(width: 8),
          // Call Button
          _buildPhoneActionButton(
            icon: Icons.phone_outlined,
            color: AppTheme.primaryColor,
            onPressed: () => _makeCall(phone.phoneNumber),
          ),
        ],
      ),
    );
  }
  
  Future<void> _setPhoneAsPrimary(PhoneNumber phone, AppLocalizations? localizations) async {
    if (_lead == null) return;
    
    setState(() {
      _updatingPrimaryMap[phone.phoneNumber] = true;
    });
    
    try {
      // Get current phone numbers
      List<Map<String, Object>> phoneNumbers = [];
      
      // Add existing phone numbers
      if (_lead!.phoneNumbers != null && _lead!.phoneNumbers!.isNotEmpty) {
        phoneNumbers = _lead!.phoneNumbers!.map((pn) => <String, Object>{
          'phone_number': pn.phoneNumber,
          'phone_type': pn.phoneType,
          'is_primary': pn.id == phone.id, // Set as primary only if it's the selected phone
          'notes': pn.notes ?? '',
        }).toList();
      } else if (_lead!.phone.isNotEmpty) {
        // If no phoneNumbers list but has primary phone, check if the selected phone matches
        if (_lead!.phone == phone.phoneNumber) {
          // The phone is already primary, no need to update
          return;
        }
        // If no phoneNumbers list but has primary phone, add it
        phoneNumbers = [
          <String, Object>{
            'phone_number': _lead!.phone,
            'phone_type': 'mobile',
            'is_primary': false, // Remove primary from old phone
            'notes': '',
          },
        ];
        // Add the new primary phone
        phoneNumbers.add(<String, Object>{
          'phone_number': phone.phoneNumber,
          'phone_type': phone.phoneType,
          'is_primary': true,
          'notes': phone.notes ?? '',
        });
      }

      // Update lead with new phone numbers
      final updatedLead = await _apiService.updateLead(
        id: _lead!.id,
        phoneNumbers: phoneNumbers,
      );

      if (mounted) {
        setState(() {
          _lead = updatedLead;
          _leadWasUpdated = true;
          _updatingPrimaryMap[phone.phoneNumber] = false;
        });
        SnackbarHelper.showSuccess(
          context,
          localizations?.translate('phoneNumberSetAsPrimary') ?? 
              'Phone number set as primary',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updatingPrimaryMap[phone.phoneNumber] = false;
        });
        SnackbarHelper.showError(
          context,
          '${localizations?.translate('error') ?? 'Error'}: ${e.toString()}',
        );
      }
    }
  }
  
  Future<void> _showAddPhoneNumberModal(LeadModel lead, AppLocalizations? localizations) async {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final navigatorContext = context; // Save context before async operation

    await showDialog(
      context: context,
      builder: (dialogContext) {
        String phoneNumber = '';
        String phoneType = 'mobile';
        bool isPrimary = false;
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations?.translate('addPhoneNumber') ?? 'Add Phone Number',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone Number Input
                  Text(
                    localizations?.translate('phoneNumber') ?? 'Phone Number',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PhoneInput(
                    value: phoneNumber,
                    hintText: localizations?.translate('enterPhoneNumber') ?? 'Enter phone number',
                    onChanged: (value) {
                      setModalState(() {
                        phoneNumber = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  // Phone Type Dropdown
                  Text(
                    localizations?.translate('phoneType') ?? 'Phone Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: phoneType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'mobile',
                        child: Text(localizations?.translate('phoneTypeMobile') ?? 'Mobile'),
                      ),
                      DropdownMenuItem(
                        value: 'home',
                        child: Text(localizations?.translate('phoneTypeHome') ?? 'Home'),
                      ),
                      DropdownMenuItem(
                        value: 'work',
                        child: Text(localizations?.translate('phoneTypeWork') ?? 'Work'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text(localizations?.translate('phoneTypeOther') ?? 'Other'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() {
                          phoneType = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  // Primary Checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: isPrimary,
                        onChanged: (value) {
                          setModalState(() {
                            isPrimary = value ?? false;
                          });
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              isPrimary = !isPrimary;
                            });
                          },
                          child: Text(
                            localizations?.translate('setAsPrimary') ?? 'Set as Primary',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(
                localizations?.translate('cancel') ?? 'Cancel',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (phoneNumber.trim().isEmpty) {
                  SnackbarHelper.showError(
                    dialogContext,
                    localizations?.translate('phoneNumberRequiredSingle') ?? 'Phone number is required',
                  );
                  return;
                }

                setModalState(() {
                  isLoading = true;
                });

                try {
                  // Get current phone numbers
                  List<Map<String, Object>> phoneNumbers = [];
                  
                  // Add existing phone numbers
                  if (lead.phoneNumbers != null && lead.phoneNumbers!.isNotEmpty) {
                    phoneNumbers = lead.phoneNumbers!.map((pn) => <String, Object>{
                      'phone_number': pn.phoneNumber,
                      'phone_type': pn.phoneType,
                      'is_primary': isPrimary ? false : pn.isPrimary, // Remove primary from existing if new is primary
                      'notes': pn.notes ?? '',
                    }).toList();
                  } else if (lead.phone.isNotEmpty) {
                    // If no phoneNumbers list but has primary phone, add it
                    phoneNumbers = [
                      <String, Object>{
                        'phone_number': lead.phone,
                        'phone_type': 'mobile',
                        'is_primary': isPrimary ? false : true, // Remove primary if new is primary
                        'notes': '',
                      },
                    ];
                  }

                  // Add new phone number
                  phoneNumbers.add(<String, Object>{
                    'phone_number': phoneNumber.trim(),
                    'phone_type': phoneType,
                    'is_primary': isPrimary,
                    'notes': '',
                  });

                  // Update lead with new phone numbers
                  final updatedLead = await _apiService.updateLead(
                    id: lead.id,
                    phoneNumbers: phoneNumbers,
                  );

                  if (mounted && navigatorContext.mounted) {
                    Navigator.pop(dialogContext);
                    setState(() {
                      _lead = updatedLead;
                      _leadWasUpdated = true;
                    });
                    SnackbarHelper.showSuccess(
                      navigatorContext,
                      localizations?.translate('phoneNumberAddedSuccessfully') ?? 
                          'Phone number added successfully',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setModalState(() {
                      isLoading = false;
                    });
                    if (navigatorContext.mounted) {
                      SnackbarHelper.showError(
                        navigatorContext,
                        '${localizations?.translate('error') ?? 'Error'}: ${e.toString()}',
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(localizations?.translate('add') ?? 'Add'),
            ),
          ],
        ),
        );
      },
    );
  }

  Widget _buildPhoneActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isWhatsApp = false,
    String? tooltip,
  }) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: isWhatsApp
              ? Image.asset(
                  'assets/images/whatsapp_logo.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(icon, color: color, size: 18);
                  },
                )
              : Icon(icon, color: color, size: 18),
        ),
      ),
    );
    
    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }
    return button;
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
  
}


