import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/api_error_helper.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import 'modals/add_status_modal.dart';
import 'modals/edit_status_modal.dart';
import 'widgets/settings_list_card.dart';

class StatusesSettingsScreen extends StatefulWidget {
  const StatusesSettingsScreen({super.key});

  @override
  State<StatusesSettingsScreen> createState() => _StatusesSettingsScreenState();
}

class _StatusesSettingsScreenState extends State<StatusesSettingsScreen> {
  final ApiService _apiService = ApiService();
  List<StatusModel> _statuses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statuses = await _apiService.getStatuses(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _statuses = statuses;
        _isLoading = false;
      });
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/settings/statuses/',
        method: 'GET',
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiErrorHelper.toUserMessage(context, e);
        _isLoading = false;
      });
    }
  }

  Future<void> _setDefaultStatus(StatusModel status) async {
    if (status.isDefault) return;
    try {
      await _apiService.updateStatus(
        statusId: status.id,
        name: status.name,
        description: status.description,
        category: status.category,
        color: status.color,
        isDefault: true,
        isHidden: status.isHidden,
        includeAutoDeleteAfterHours: true,
        autoDeleteAfterHours: status.autoDeleteAfterHours,
      );
      if (!mounted) return;
      _loadStatuses();
      SnackbarHelper.showSuccess(
        context,
        AppLocalizations.of(context)?.translate('statusUpdatedSuccessfully') ??
            'Status updated successfully',
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, ApiErrorHelper.toUserMessage(context, e));
    }
  }

  Future<void> _deleteStatus(int statusId) async {
    final status = _statuses.firstWhere((s) => s.id == statusId);
    if (status.isDefault) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('cannotDeleteDefault') ?? 
              'Cannot delete default status',
        );
      }
      return;
    }

    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteStatus') ?? 'Delete Status'),
        content: Text(
          localizations?.translate('confirmDeleteStatus') ?? 
          'Are you sure you want to delete this status?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations?.translate('delete') ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.deleteStatus(statusId);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('statusDeletedSuccessfully') ?? 
              'Status deleted successfully',
        );
        _loadStatuses();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          ApiErrorHelper.toUserMessage(context, e),
        );
      }
    }
  }

  String _getCategoryLabel(String category, AppLocalizations? localizations) {
    final categoryLower = category.toLowerCase();
    if (categoryLower == 'active' || categoryLower == 'follow up' || categoryLower == 'follow_up' || categoryLower == 'followup') {
      return localizations?.translate('active') ?? 'Active';
    } else if (categoryLower == 'inactive') {
      return localizations?.translate('inactive') ?? 'Inactive';
    } else if (categoryLower == 'closed') {
      return localizations?.translate('closed') ?? 'Closed';
    }
    return category;
  }

  Color _getCategoryColor(String category) {
    final categoryLower = category.toLowerCase();
    if (categoryLower == 'active' || categoryLower == 'follow up' || categoryLower == 'follow_up' || categoryLower == 'followup') {
      return Colors.green;
    } else if (categoryLower == 'inactive') {
      return Colors.grey;
    } else if (categoryLower == 'closed') {
      return Colors.purple;
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStatuses,
              child: Text(localizations?.translate('retry') ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Add Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations?.translate('availableStatuses') ?? 'Available Statuses',
                style: theme.textTheme.titleLarge,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: localizations?.translate('refresh') ?? 'Refresh',
                    onPressed: () => _loadStatuses(forceRefresh: true),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddStatusModal(
                      onStatusCreated: () {
                        _loadStatuses();
                        Navigator.pop(context);
                      },
                      existingStatuses: _statuses,
                    ),
                  );
                },
                    icon: const Icon(Icons.add),
                    label: Text(localizations?.translate('addStatus') ?? 'Add Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Statuses List
        Expanded(
          child: _statuses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        localizations?.translate('noStatusesFound') ?? 'No statuses found',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _statuses.length,
                  itemBuilder: (context, index) {
                    final status = _statuses[index];
                    return SettingsListCard(
                      child: InkWell(
                        onDoubleTap: status.isDefault
                            ? null
                            : () => _setDefaultStatus(status),
                        child: Padding(
                          padding: SettingsListCard.listTilePadding,
                          child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: _parseColor(status.color),
                              radius: 22,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            status.name,
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: true,
                                            maxLines: 1,
                                          ),
                                        ),
                                        if (status.isDefault) ...[
                                          const SizedBox(width: 8),
                                          SettingsDefaultChip(
                                            label: localizations?.translate('default') ?? 'Default',
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (status.description != null && status.description!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        status.description!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    SettingsLabelChip(
                                      label: _getCategoryLabel(status.category, localizations),
                                      color: _getCategoryColor(status.category),
                                    ),
                                    if (status.autoDeleteAfterHours != null &&
                                        status.autoDeleteAfterHours! >= 1) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '${localizations?.translate('autoDeleteSlidable') ?? 'Auto-delete'}: ${status.autoDeleteAfterHours}h',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    if (!status.isDefault) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '${localizations?.translate('setAsDefault') ?? 'Set as default'} (double-tap)',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => EditStatusModal(
                                        status: status,
                                        onStatusUpdated: () {
                                          _loadStatuses();
                                          Navigator.pop(context);
                                        },
                                      ),
                                    );
                                  },
                                ),
                                if (!status.isDefault)
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                    onPressed: () => _deleteStatus(status.id),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceAll('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.grey;
    }
  }
}

