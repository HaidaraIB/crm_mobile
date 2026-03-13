import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import 'modals/add_call_method_modal.dart';
import 'modals/edit_call_method_modal.dart';
import 'widgets/settings_list_card.dart';

class CallMethodsSettingsScreen extends StatefulWidget {
  const CallMethodsSettingsScreen({super.key});

  @override
  State<CallMethodsSettingsScreen> createState() => _CallMethodsSettingsScreenState();
}

class _CallMethodsSettingsScreenState extends State<CallMethodsSettingsScreen> {
  final ApiService _apiService = ApiService();
  List<CallMethodModel> _callMethods = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCallMethods();
  }

  Future<void> _loadCallMethods() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final callMethods = await _apiService.getCallMethods();
      if (!mounted) return;
      setState(() {
        _callMethods = callMethods;
        _isLoading = false;
      });
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/settings/call-methods/',
        method: 'GET',
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showAddCallMethodModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddCallMethodModal(
        onCallMethodCreated: () {
          _loadCallMethods();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditCallMethodModal(CallMethodModel callMethod) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditCallMethodModal(
        callMethod: callMethod,
        onCallMethodUpdated: () {
          _loadCallMethods();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _setDefaultCallMethod(CallMethodModel callMethod) async {
    if (callMethod.isDefault) return;
    try {
      await _apiService.updateCallMethod(
        callMethodId: callMethod.id,
        name: callMethod.name,
        description: callMethod.description,
        color: callMethod.color,
        isDefault: true,
      );
      if (!mounted) return;
      _loadCallMethods();
      SnackbarHelper.showSuccess(
        context,
        AppLocalizations.of(context)?.translate('callMethodUpdatedSuccessfully') ?? 'Call method updated',
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, e.toString());
    }
  }

  Future<void> _deleteCallMethod(CallMethodModel callMethod) async {
    if (callMethod.isDefault) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('cannotDeleteDefault') ?? 'Cannot delete default call method',
        );
      }
      return;
    }

    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteCallMethod') ?? 'Delete Call Method'),
        content: Text(
          localizations?.translate('confirmDeleteCallMethod') ??
              'Are you sure you want to delete this call method?',
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
      await _apiService.deleteCallMethod(callMethod.id);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          localizations?.translate('callMethodDeleted') ?? 'Call method deleted successfully',
        );
        _loadCallMethods();
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
              onPressed: _loadCallMethods,
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
                localizations?.translate('callMethods') ?? 'Call Methods',
                style: theme.textTheme.titleLarge,
              ),
              ElevatedButton.icon(
                onPressed: _showAddCallMethodModal,
                icon: const Icon(Icons.add),
                label: Text(localizations?.translate('addCallMethod') ?? 'Add Call Method'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _callMethods.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phone_in_talk_outlined,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        localizations?.translate('noCallMethodsFound') ?? 'No call methods found',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _callMethods.length,
                  itemBuilder: (context, index) {
                    final callMethod = _callMethods[index];
                    return SettingsListCard(
                      child: ListTile(
                        contentPadding: SettingsListCard.listTilePadding,
                        leading: CircleAvatar(
                          backgroundColor: _parseColor(callMethod.color),
                          radius: 22,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                callMethod.name,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (callMethod.isDefault) ...[
                              const SizedBox(width: 8),
                              SettingsDefaultChip(
                                label: localizations?.translate('default') ?? 'Default',
                              ),
                            ],
                          ],
                        ),
                        subtitle: callMethod.description != null && callMethod.description!.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  callMethod.description!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!callMethod.isDefault)
                              TextButton(
                                onPressed: () => _setDefaultCallMethod(callMethod),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(48, 48),
                                ),
                                child: Text(
                                  localizations?.translate('setAsDefault') ?? 'Set as default',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showEditCallMethodModal(callMethod),
                            ),
                            if (!callMethod.isDefault)
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                onPressed: () => _deleteCallMethod(callMethod),
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
}
