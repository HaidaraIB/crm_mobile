import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/api_error_helper.dart';
import '../../core/utils/week_off_utils.dart';
import '../../core/utils/lead_assignee_users.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';

class AssignLeadModal extends StatefulWidget {
  final List<int> leadIds;
  final int? currentAssignedUserId; // Current assigned user ID (if any)
  final Function()? onAssigned;

  const AssignLeadModal({
    super.key,
    required this.leadIds,
    this.currentAssignedUserId,
    this.onAssigned,
  });

  @override
  State<AssignLeadModal> createState() => _AssignLeadModalState();
}

class _AssignLeadModalState extends State<AssignLeadModal> {
  final ApiService _apiService = ApiService();
  int? _selectedUserId;
  bool _isUnassign = false;
  bool _isLoading = false;
  bool _isLoadingUsers = true;
  List<UserModel> _users = [];
  String _companyTz = 'UTC';

  @override
  void initState() {
    super.initState();
    // Pre-select current assigned user if provided
    if (widget.currentAssignedUserId != null && widget.currentAssignedUserId! > 0) {
      _selectedUserId = widget.currentAssignedUserId;
    }
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final usersData = await _apiService.getUsers();
      final raw = (usersData['results'] as List).cast<UserModel>();
      final pickable = usersForLeadAssigneePicker(raw);
      setState(() {
        _users = pickable;
        if (_users.isNotEmpty) {
          _companyTz = _users.first.company?.timezone?.trim().isNotEmpty == true
              ? _users.first.company!.timezone!
              : 'UTC';
        }
        _isLoadingUsers = false;
        final cur = widget.currentAssignedUserId;
        if (cur != null &&
            cur > 0 &&
            pickable.any((u) => u.id == cur)) {
          _selectedUserId = cur;
        } else {
          _selectedUserId = null;
        }
      });
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/users/',
        method: 'GET',
      );
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_isUnassign && _selectedUserId == null) {
      final localizations = AppLocalizations.of(context);
      SnackbarHelper.showError(
        context,
        localizations?.translate('pleaseSelectEmployee') ??
            'Please select an employee',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.assignLeads(
        clientIds: widget.leadIds,
        userId: _isUnassign ? null : _selectedUserId,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned?.call();
        SnackbarHelper.showSuccess(
          context,
          _isUnassign
              ? (AppLocalizations.of(context)?.translate('leadsUnassignedSuccessfully') ?? 'Leads unassigned successfully')
              : (AppLocalizations.of(context)?.translate('leadsAssignedSuccessfully') ?? 'Leads assigned successfully'),
        );
      }
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/clients/bulk_assign/',
        method: 'POST',
      );
      if (mounted) {
        SnackbarHelper.showError(context, ApiErrorHelper.toUserMessage(context, e));
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations?.translate('assignLead') ?? 'Assign Lead',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${localizations?.translate('leadsCount') ?? 'Leads count'}: ${widget.leadIds.length}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            if (_isLoadingUsers)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Unassign checkbox
              CheckboxListTile(
                title: Text(localizations?.translate('unassign') ?? 'Unassign'),
                value: _isUnassign,
                onChanged: (value) {
                  setState(() {
                    _isUnassign = value ?? false;
                    if (_isUnassign) {
                      _selectedUserId = null;
                    }
                  });
                },
              ),

              // User selection
              if (!_isUnassign) ...[
                const SizedBox(height: 8),
                Text(
                  localizations?.translate('selectEmployee') ??
                      'Select Employee',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _selectedUserId,
                  decoration: InputDecoration(
                    hintText: localizations?.translate('selectEmployee') ?? 'Select Employee',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _users
                      .map(
                        (user) {
                          final off = isUserOnWeeklyDayOff(
                            user.weeklyDayOff,
                            _companyTz,
                          );
                          return DropdownMenuItem<int>(
                            value: user.id,
                            enabled: !off,
                            child: Text(
                              off
                                  ? '${user.displayName} (${localizations?.translate('weeklyDayOff') ?? 'Day off'})'
                                  : user.displayName,
                            ),
                          );
                        },
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserId = value;
                      if (value != null) {
                        _isUnassign = false;
                      }
                    });
                  },
                ),
              ],

              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(localizations?.translate('cancel') ?? 'Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _isUnassign
                                ? (localizations?.translate('unassign') ??
                                      'Unassign')
                                : (localizations?.translate('assign') ??
                                      'Assign'),
                          ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
