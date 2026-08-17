import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/api_error_helper.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import '../../widgets/pull_to_refresh_body.dart';
import 'modals/add_tag_modal.dart';
import 'modals/edit_tag_modal.dart';
import 'widgets/settings_list_card.dart';

class TagsSettingsScreen extends StatefulWidget {
  const TagsSettingsScreen({super.key});

  @override
  State<TagsSettingsScreen> createState() => _TagsSettingsScreenState();
}

class _TagsSettingsScreenState extends State<TagsSettingsScreen> {
  final ApiService _apiService = ApiService();
  List<TagModel> _tags = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tags = await _apiService.getTags(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _tags = tags;
        _isLoading = false;
      });
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/settings/tags/',
        method: 'GET',
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiErrorHelper.toUserMessage(context, e);
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTag(int tagId) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteTag') ?? 'Delete Tag'),
        content: Text(
          localizations?.translate('confirmDeleteTag') ??
              'Are you sure you want to delete this tag?',
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
      await _apiService.deleteTag(tagId);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('tagDeletedSuccessfully') ??
              'Tag deleted successfully',
        );
        _loadTags();
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget body;
    if (_isLoading) {
      body = PullToRefreshBody(
        onRefresh: () => _loadTags(forceRefresh: true),
        child: const CircularProgressIndicator(),
      );
    } else if (_errorMessage != null) {
      body = PullToRefreshBody(
        onRefresh: () => _loadTags(forceRefresh: true),
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
              onPressed: _loadTags,
              child: Text(localizations?.translate('retry') ?? 'Retry'),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    localizations?.translate('availableTags') ?? 'Available Tags',
                    style: theme.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: localizations?.translate('refresh') ?? 'Refresh',
                  onPressed: () => _loadTags(forceRefresh: true),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tags.isEmpty
                ? PullToRefreshBody(
                    onRefresh: () => _loadTags(forceRefresh: true),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sell_outlined,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          localizations?.translate('noTagsFound') ?? 'No tags found',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            localizations?.translate('tagsSettingsHint') ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : PullToRefreshBody.list(
                    onRefresh: () => _loadTags(forceRefresh: true),
                    listPadding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: _tags.length,
                    itemBuilder: (context, index) {
                      final tag = _tags[index];
                      return SettingsListCard(
                        child: Padding(
                          padding: SettingsListCard.listTilePadding,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: _parseColor(tag.color),
                                radius: 22,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tag.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      if (tag.description != null &&
                                          tag.description!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          tag.description!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
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
                                        builder: (context) => EditTagModal(
                                          tag: tag,
                                          onTagUpdated: () {
                                            _loadTags();
                                            Navigator.pop(context);
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: theme.colorScheme.error),
                                    onPressed: () => _deleteTag(tag.id),
                                  ),
                                ],
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

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AddTagModal(
              onTagCreated: () {
                _loadTags();
                Navigator.pop(context);
              },
            ),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        tooltip: localizations?.translate('addTag') ?? 'Add Tag',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
