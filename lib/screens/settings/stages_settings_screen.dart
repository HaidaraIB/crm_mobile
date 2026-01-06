import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import 'modals/add_stage_modal.dart';
import 'modals/edit_stage_modal.dart';

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

  Future<void> _loadStages() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stages = await _apiService.getStages();
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

  Future<void> _deleteStage(int stageId) async {
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
      await _apiService.deleteStage(stageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('stageDeletedSuccessfully') ?? 
              'Stage deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadStages();
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
        ),
        // Stages List
        Expanded(
          child: _stages.isEmpty
              ? Center(
                  child: Text(
                    localizations?.translate('noStagesFound') ?? 'No stages found',
                    style: theme.textTheme.bodyLarge,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _stages.length,
                  itemBuilder: (context, index) {
                    final stage = _stages[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _parseColor(stage.color),
                          radius: 20,
                        ),
                        title: Text(stage.name),
                        subtitle: stage.description != null && stage.description!.isNotEmpty
                            ? Text(stage.description!)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (stage.required)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  localizations?.translate('required') ?? 'Required',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit),
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
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteStage(stage.id),
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

