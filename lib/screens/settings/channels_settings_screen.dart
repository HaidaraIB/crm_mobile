import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../services/error_logger.dart';
import 'modals/add_channel_modal.dart';
import 'modals/edit_channel_modal.dart';

class ChannelsSettingsScreen extends StatefulWidget {
  const ChannelsSettingsScreen({super.key});

  @override
  State<ChannelsSettingsScreen> createState() => _ChannelsSettingsScreenState();
}

class _ChannelsSettingsScreenState extends State<ChannelsSettingsScreen> {
  final ApiService _apiService = ApiService();
  List<ChannelModel> _channels = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final channels = await _apiService.getChannels();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _isLoading = false;
      });
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/settings/channels/',
        method: 'GET',
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteChannel(int channelId) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteChannel') ?? 'Delete Channel'),
        content: Text(
          localizations?.translate('confirmDeleteChannel') ?? 
          'Are you sure you want to delete this channel?',
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
      await _apiService.deleteChannel(channelId);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('channelDeletedSuccessfully') ?? 
              'Channel deleted successfully',
        );
        _loadChannels();
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

  String _getLocalizedChannelType(String type, AppLocalizations? localizations) {
    switch (type.toLowerCase()) {
      case 'web': return localizations?.translate('channelTypeWeb') ?? 'Web';
      case 'social': return localizations?.translate('channelTypeSocial') ?? 'Social';
      case 'advertising': return localizations?.translate('channelTypeAdvertising') ?? 'Advertising';
      case 'email': return localizations?.translate('channelTypeEmail') ?? 'Email';
      case 'phone': return localizations?.translate('channelTypePhone') ?? 'Phone';
      case 'sms': return localizations?.translate('channelTypeSMS') ?? 'SMS';
      case 'whatsapp': return localizations?.translate('channelTypeWhatsApp') ?? 'WhatsApp';
      case 'telegram': return localizations?.translate('channelTypeTelegram') ?? 'Telegram';
      case 'instagram': return localizations?.translate('channelTypeInstagram') ?? 'Instagram';
      case 'facebook': return localizations?.translate('channelTypeFacebook') ?? 'Facebook';
      case 'linkedin': return localizations?.translate('channelTypeLinkedIn') ?? 'LinkedIn';
      case 'twitter': return localizations?.translate('channelTypeTwitter') ?? 'Twitter';
      case 'tiktok': return localizations?.translate('channelTypeTikTok') ?? 'TikTok';
      case 'youtube': return localizations?.translate('channelTypeYouTube') ?? 'YouTube';
      case 'other': return localizations?.translate('channelTypeOther') ?? 'Other';
      default: return type;
    }
  }

  String _getLocalizedPriority(String priority, AppLocalizations? localizations) {
    switch (priority.toLowerCase()) {
      case 'high': return localizations?.translate('high') ?? 'High';
      case 'medium': return localizations?.translate('medium') ?? 'Medium';
      case 'low': return localizations?.translate('low') ?? 'Low';
      default: return priority;
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
              onPressed: _loadChannels,
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
                localizations?.translate('activeChannels') ?? 'Active Channels',
                style: theme.textTheme.titleLarge,
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddChannelModal(
                      onChannelCreated: () {
                        _loadChannels();
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: Text(localizations?.translate('addChannel') ?? 'Add Channel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Channels List
        Expanded(
          child: _channels.isEmpty
              ? Center(
                  child: Text(
                    localizations?.translate('noChannelsAvailable') ?? 'No channels available',
                    style: theme.textTheme.bodyLarge,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _channels.length,
                  itemBuilder: (context, index) {
                    final channel = _channels[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(channel.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${localizations?.translate('type') ?? 'Type'}: ${_getLocalizedChannelType(channel.type, localizations)}'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('${localizations?.translate('priority') ?? 'Priority'}: '),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: channel.priority.toLowerCase() == 'high'
                                        ? Colors.red.withValues(alpha: 0.2)
                                        : channel.priority.toLowerCase() == 'medium'
                                            ? Colors.orange.withValues(alpha: 0.2)
                                            : Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getLocalizedPriority(channel.priority, localizations),
                                    style: TextStyle(
                                      color: channel.priority.toLowerCase() == 'high'
                                          ? Colors.red
                                          : channel.priority.toLowerCase() == 'medium'
                                              ? Colors.orange
                                              : Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
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
                                  builder: (context) => EditChannelModal(
                                    channel: channel,
                                    onChannelUpdated: () {
                                      _loadChannels();
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteChannel(channel.id),
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

