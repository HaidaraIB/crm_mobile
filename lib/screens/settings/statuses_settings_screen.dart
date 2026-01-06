import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import 'modals/add_status_modal.dart';
import 'modals/edit_status_modal.dart';

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

  Future<void> _loadStatuses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statuses = await _apiService.getStatuses();
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
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteStatus(int statusId) async {
    final status = _statuses.firstWhere((s) => s.id == statusId);
    if (status.isDefault) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('cannotDeleteDefault') ?? 
              'Cannot delete default status',
            ),
            backgroundColor: Colors.orange,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('statusDeletedSuccessfully') ?? 
              'Status deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadStatuses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
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
              style: const TextStyle(color: Colors.red),
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
        ),
        // Statuses List
        Expanded(
          child: _statuses.isEmpty
              ? Center(
                  child: Text(
                    localizations?.translate('noStatusesFound') ?? 'No statuses found',
                    style: theme.textTheme.bodyLarge,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _statuses.length,
                  itemBuilder: (context, index) {
                    final status = _statuses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _parseColor(status.color),
                          radius: 20,
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(status.name)),
                            if (status.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  localizations?.translate('default') ?? 'Default',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (status.description != null && status.description!.isNotEmpty)
                              Text(status.description!),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(status.category).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getCategoryLabel(status.category, localizations),
                                style: TextStyle(
                                  color: _getCategoryColor(status.category),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
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
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteStatus(status.id),
                              ),
                          ],
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

