import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import 'modals/add_visit_type_modal.dart';
import 'modals/edit_visit_type_modal.dart';
import 'widgets/settings_list_card.dart';

class VisitTypesSettingsScreen extends StatefulWidget {
  const VisitTypesSettingsScreen({super.key});

  @override
  State<VisitTypesSettingsScreen> createState() => _VisitTypesSettingsScreenState();
}

class _VisitTypesSettingsScreenState extends State<VisitTypesSettingsScreen> {
  final ApiService _apiService = ApiService();
  List<VisitTypeModel> _visitTypes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVisitTypes();
  }

  Future<void> _loadVisitTypes({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await _apiService.getVisitTypes(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _visitTypes = list;
        _isLoading = false;
      });
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/settings/visit-types/',
        method: 'GET',
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddVisitTypeModal(
        onVisitTypeCreated: () {
          _loadVisitTypes();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditModal(VisitTypeModel vt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditVisitTypeModal(
        visitType: vt,
        onVisitTypeUpdated: () {
          _loadVisitTypes();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _setDefault(VisitTypeModel vt) async {
    if (vt.isDefault) return;
    try {
      await _apiService.updateVisitType(
        visitTypeId: vt.id,
        name: vt.name,
        description: vt.description,
        color: vt.color,
        isDefault: true,
      );
      if (!mounted) return;
      _loadVisitTypes();
      SnackbarHelper.showSuccess(
        context,
        AppLocalizations.of(context)?.translate('visitTypeUpdatedSuccessfully') ??
            'Visit type updated',
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, e.toString());
    }
  }

  Future<void> _delete(VisitTypeModel vt) async {
    if (vt.isDefault) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('cannotDeleteDefault') ??
              'Cannot delete default visit type',
        );
      }
      return;
    }
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteVisitType') ?? 'Delete visit type'),
        content: Text(
          localizations?.translate('confirmDeleteVisitType') ??
              'Are you sure you want to delete this visit type?',
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
      await _apiService.deleteVisitType(vt.id);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          localizations?.translate('visitTypeDeleted') ?? 'Visit type deleted',
        );
        _loadVisitTypes();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceAll('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.grey;
    }
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
              onPressed: _loadVisitTypes,
              child: Text(localizations?.translate('retry') ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations?.translate('visitTypes') ?? 'Visit types',
                style: theme.textTheme.titleLarge,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: localizations?.translate('refresh') ?? 'Refresh',
                    onPressed: () => _loadVisitTypes(forceRefresh: true),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddModal,
                    icon: const Icon(Icons.add),
                    label: Text(localizations?.translate('addVisitType') ?? 'Add visit type'),
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
        Expanded(
          child: _visitTypes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.place_outlined, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        localizations?.translate('noVisitTypesFound') ?? 'No visit types found',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _visitTypes.length,
                  itemBuilder: (context, index) {
                    final vt = _visitTypes[index];
                    return SettingsListCard(
                      child: InkWell(
                        onDoubleTap: vt.isDefault ? null : () => _setDefault(vt),
                        child: Padding(
                          padding: SettingsListCard.listTilePadding,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: _parseColor(vt.color),
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
                                              vt.name,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          if (vt.isDefault) ...[
                                            const SizedBox(width: 8),
                                            SettingsDefaultChip(
                                              label: localizations?.translate('default') ?? 'Default',
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (vt.description != null && vt.description!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          vt.description!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      if (!vt.isDefault) ...[
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
                                    onPressed: () => _showEditModal(vt),
                                  ),
                                  if (!vt.isDefault)
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                      onPressed: () => _delete(vt),
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
}
