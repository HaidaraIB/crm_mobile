import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import 'modals/add_stage_modal.dart';
import 'modals/edit_stage_modal.dart';
import 'widgets/settings_list_card.dart';

class StagesSettingsScreen extends StatefulWidget {
  const StagesSettingsScreen({super.key});

  @override
  State<StagesSettingsScreen> createState() => _StagesSettingsScreenState();
}

class _StagesSettingsScreenState extends State<StagesSettingsScreen> {
  final ApiService _apiService = ApiService();
  List<StageModel> _stages = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStages();
  }

  Future<void> _loadStages({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stages = await _apiService.getStages(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _stages = stages;
        _isLoading = false;
      });
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/settings/stages/',
        method: 'GET',
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _setDefaultStage(StageModel stage) async {
    if (stage.isDefault) return;
    try {
      await _apiService.updateStage(
        stageId: stage.id,
        name: stage.name,
        description: stage.description,
        color: stage.color,
        required: stage.required,
        autoAdvance: stage.autoAdvance,
        isDefault: true,
      );
      if (!mounted) return;
      _loadStages();
      SnackbarHelper.showSuccess(
        context,
        AppLocalizations.of(context)?.translate('stageUpdatedSuccessfully') ?? 'Stage updated',
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, e.toString());
    }
  }

  Future<void> _deleteStage(StageModel stage) async {
    if (stage.isDefault) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('cannotDeleteDefault') ??
              'Cannot delete default stage',
        );
      }
      return;
    }

    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteStage') ?? 'Delete Stage'),
        content: Text(
          localizations?.translate('confirmDeleteStage') ??
              'Are you sure you want to delete this stage?',
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
      await _apiService.deleteStage(stage.id);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('stageDeletedSuccessfully') ?? 
              'Stage deleted successfully',
        );
        _loadStages();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
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
              onPressed: _loadStages,
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
                localizations?.translate('leadStages') ?? 'Lead Stages',
                style: theme.textTheme.titleLarge,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: localizations?.translate('refresh') ?? 'Refresh',
                    onPressed: () => _loadStages(forceRefresh: true),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddStageModal(
                      onStageCreated: () {
                        _loadStages();
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
                    icon: const Icon(Icons.add),
                    label: Text(localizations?.translate('addStage') ?? 'Add Stage'),
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
        // Stages List
        Expanded(
          child: _stages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        localizations?.translate('noStagesFound') ?? 'No stages found',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _stages.length,
                  itemBuilder: (context, index) {
                    final stage = _stages[index];
                    return SettingsListCard(
                      child: InkWell(
                        onDoubleTap: stage.isDefault
                            ? null
                            : () => _setDefaultStage(stage),
                        child: Padding(
                          padding: SettingsListCard.listTilePadding,
                          child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: _parseColor(stage.color),
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
                                            stage.name,
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: true,
                                            maxLines: 1,
                                          ),
                                        ),
                                        if (stage.isDefault) ...[
                                          const SizedBox(width: 8),
                                          SettingsDefaultChip(
                                            label: localizations?.translate('default') ?? 'Default',
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (stage.description != null && stage.description!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        stage.description!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (stage.required) ...[
                                      if (stage.description != null && stage.description!.isNotEmpty) const SizedBox(height: 4),
                                      SettingsLabelChip(
                                        label: localizations?.translate('required') ?? 'Required',
                                        color: Colors.blue,
                                      ),
                                    ],
                                    if (!stage.isDefault) ...[
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
                                      builder: (context) => EditStageModal(
                                        stage: stage,
                                        onStageUpdated: () {
                                          _loadStages();
                                          Navigator.pop(context);
                                        },
                                      ),
                                    );
                                  },
                                ),
                                if (!stage.isDefault)
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                    onPressed: () => _deleteStage(stage),
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

