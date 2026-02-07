import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../services/api_service.dart';
import '../../../services/error_logger.dart';

class AddChannelModal extends StatefulWidget {
  final VoidCallback? onChannelCreated;

  const AddChannelModal({
    super.key,
    this.onChannelCreated,
  });

  @override
  State<AddChannelModal> createState() => _AddChannelModalState();
}

class _AddChannelModalState extends State<AddChannelModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final ApiService _apiService = ApiService();

  String? _selectedType;
  String? _selectedPriority = 'Medium';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _channelTypes = [
    'Web',
    'Social',
    'Advertising',
    'Email',
    'Phone',
    'SMS',
    'WhatsApp',
    'Telegram',
    'Instagram',
    'Facebook',
    'LinkedIn',
    'Twitter',
    'TikTok',
    'YouTube',
    'Other',
  ];

  final List<String> _priorities = ['High', 'Medium', 'Low'];

  String _getLocalizedChannelType(String type, AppLocalizations? localizations) {
    final typeLower = type.toLowerCase();
    switch (typeLower) {
      case 'web':
        return localizations?.translate('web') ?? 'Web';
      case 'social':
        return localizations?.translate('social') ?? 'Social';
      case 'advertising':
        return localizations?.translate('advertising') ?? 'Advertising';
      case 'email':
        return localizations?.translate('channelTypeEmail') ?? 'Email';
      case 'phone':
        return localizations?.translate('channelTypePhone') ?? 'Phone';
      case 'sms':
        return localizations?.translate('channelTypeSMS') ?? 'SMS';
      case 'whatsapp':
        return localizations?.translate('whatsapp') ?? 'WhatsApp';
      case 'telegram':
        return localizations?.translate('telegram') ?? 'Telegram';
      case 'instagram':
        return localizations?.translate('instagram') ?? 'Instagram';
      case 'facebook':
        return localizations?.translate('facebook') ?? 'Facebook';
      case 'linkedin':
        return localizations?.translate('linkedin') ?? 'LinkedIn';
      case 'twitter':
        return localizations?.translate('twitter') ?? 'Twitter';
      case 'tiktok':
        return localizations?.translate('tiktok') ?? 'TikTok';
      case 'youtube':
        return localizations?.translate('youtube') ?? 'YouTube';
      case 'other':
        return localizations?.translate('other') ?? 'Other';
      default:
        return type;
    }
  }

  String _getLocalizedPriority(String priority, AppLocalizations? localizations) {
    final priorityLower = priority.toLowerCase();
    switch (priorityLower) {
      case 'high':
        return localizations?.translate('high') ?? 'High';
      case 'medium':
        return localizations?.translate('medium') ?? 'Medium';
      case 'low':
        return localizations?.translate('low') ?? 'Low';
      default:
        return priority;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == null) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)?.translate('typeRequired') ?? 'Type is required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.createChannel(
        name: _nameController.text.trim(),
        type: _selectedType!,
        priority: _selectedPriority!,
      );

      if (mounted) {
        widget.onChannelCreated?.call();
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('channelCreatedSuccessfully') ?? 
              'Channel created successfully',
        );
      }
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/settings/channels/',
        method: 'POST',
      );
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        localizations?.translate('addChannel') ?? 'Add Channel',
                        style: theme.textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Form
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: '${localizations?.translate('name') ?? 'Name'} *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizations?.translate('nameRequired') ?? 'Name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Type
                        DropdownButtonFormField<String>(
                          initialValue: _selectedType,
                          decoration: InputDecoration(
                            labelText: '${localizations?.translate('type') ?? 'Type'} *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _channelTypes.map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(_getLocalizedChannelType(type, localizations)),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value;
                              _errorMessage = null;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return localizations?.translate('typeRequired') ?? 'Type is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Priority
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPriority,
                          decoration: InputDecoration(
                            labelText: localizations?.translate('priority') ?? 'Priority',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _priorities.map((priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(_getLocalizedPriority(priority, localizations)),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPriority = value;
                            });
                          },
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Submit Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(localizations?.translate('create') ?? 'Create'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

