import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import 'modals/add_call_method_modal.dart';
import 'modals/edit_call_method_modal.dart';

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
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddCallMethodModal() async {
    final result = await showDialog<CallMethodModel>(
      context: context,
      builder: (context) => const AddCallMethodModal(),
    );

    if (result != null && mounted) {
      _loadCallMethods();
    }
  }

  Future<void> _showEditCallMethodModal(CallMethodModel callMethod) async {
    final result = await showDialog<CallMethodModel>(
      context: context,
      builder: (context) => EditCallMethodModal(callMethod: callMethod),
    );

    if (result != null && mounted) {
      _loadCallMethods();
    }
  }

  Future<void> _deleteCallMethod(CallMethodModel callMethod) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteCallMethod') ?? 'Delete Call Method'),
        content: Text(
          localizations?.translate('confirmDeleteCallMethod') ?? 
          'Are you sure you want to delete "${callMethod.name}"?',
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

    if (confirmed == true && mounted) {
      try {
        await _apiService.deleteCallMethod(callMethod.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.translate('callMethodDeleted') ?? 'Call method deleted successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _loadCallMethods();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${localizations?.translate('failedToDeleteCallMethod') ?? 'Failed to delete call method'}: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        localizations?.translate('errorLoadingCallMethods') ?? 'Error loading call methods',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCallMethods,
                        child: Text(localizations?.translate('retry') ?? 'Retry'),
                      ),
                    ],
                  ),
                )
              : _callMethods.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_disabled,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            localizations?.translate('noCallMethodsFound') ?? 'No call methods found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _callMethods.length,
                      itemBuilder: (context, index) {
                        final callMethod = _callMethods[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Color(int.parse(callMethod.color.replaceFirst('#', '0xFF'))),
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              callMethod.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: callMethod.description != null && callMethod.description!.isNotEmpty
                                ? Text(callMethod.description!)
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEditCallMethodModal(callMethod),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteCallMethod(callMethod),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCallMethodModal,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
