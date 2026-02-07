import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/settings_model.dart';
import '../../../services/api_service.dart';
import '../../../services/error_logger.dart';

class EditStatusModal extends StatefulWidget {
  final StatusModel status;
  final VoidCallback? onStatusUpdated;

  const EditStatusModal({
    super.key,
    required this.status,
    this.onStatusUpdated,
  });

  @override
  State<EditStatusModal> createState() => _EditStatusModalState();
}

class _EditStatusModalState extends State<EditStatusModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final ApiService _apiService = ApiService();

  late String _selectedColor;
  late String _selectedCategory;
  late bool _isDefault;
  late bool _isHidden;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _categories = ['Active', 'Inactive', 'Follow Up', 'Closed'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.status.name);
    _descriptionController = TextEditingController(text: widget.status.description ?? '');
    _selectedColor = widget.status.color;
    // Normalize category from backend (lowercase/follow_up) to dropdown format (capitalized)
    final categoryLower = widget.status.category.toLowerCase();
    if (categoryLower == 'active') {
      _selectedCategory = 'Active';
    } else if (categoryLower == 'inactive') {
      _selectedCategory = 'Inactive';
    } else if (categoryLower == 'follow_up' || categoryLower == 'follow up' || categoryLower == 'followup') {
      _selectedCategory = 'Follow Up';
    } else if (categoryLower == 'closed') {
      _selectedCategory = 'Closed';
    } else {
      _selectedCategory = widget.status.category; // Fallback to original if unknown
    }
    _isDefault = widget.status.isDefault;
    _isHidden = widget.status.isHidden;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if setting as default and there's already a different default status
    if (_isDefault && !widget.status.isDefault) {
      final localizations = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            localizations?.translate('setAsDefault') ?? 'Set as Default',
            textAlign: TextAlign.center,
          ),
          content: Text(
            '${localizations?.translate('setAsDefaultMessage') ?? 'There may already be a default status'}. ${localizations?.translate('setAsDefaultMessage2') ?? 'Setting this status as default will unset the previous default. Do you want to continue?'}',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(localizations?.translate('cancel') ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(localizations?.translate('continue') ?? 'Continue'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) {
        return; // User cancelled
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.updateStatus(
        statusId: widget.status.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        category: _selectedCategory,
        color: _selectedColor,
        isDefault: _isDefault,
        isHidden: _isHidden,
      );

      if (mounted) {
        widget.onStatusUpdated?.call();
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('statusUpdatedSuccessfully') ?? 
              'Status updated successfully',
        );
      }
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/settings/statuses/${widget.status.id}/',
        method: 'PATCH',
      );
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
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

  String _getCategoryLabel(String category, AppLocalizations? localizations) {
    final categoryLower = category.toLowerCase();
    if (categoryLower == 'active') {
      return localizations?.translate('active') ?? 'Active';
    } else if (categoryLower == 'follow up' || categoryLower == 'follow_up' || categoryLower == 'followup') {
      return localizations?.translate('followUp') ?? 'Follow Up';
    } else if (categoryLower == 'inactive') {
      return localizations?.translate('inactive') ?? 'Inactive';
    } else if (categoryLower == 'closed') {
      return localizations?.translate('closed') ?? 'Closed';
    }
    return category;
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
        initialChildSize: 0.8,
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
                        localizations?.translate('editStatus') ?? 'Edit Status',
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
                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: localizations?.translate('description') ?? 'Description',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        // Category
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: '${localizations?.translate('category') ?? 'Category'} *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _categories.map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(_getCategoryLabel(category, localizations)),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Color
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${localizations?.translate('color') ?? 'Color'}:',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final color = await showDialog<Color>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(localizations?.translate('selectColor') ?? 'Select Color'),
                                    content: SingleChildScrollView(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          '#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF', '#00FFFF',
                                          '#808080', '#800000', '#008000', '#000080', '#808000', '#800080',
                                          '#008080', '#C0C0C0', '#FF8080', '#80FF80', '#8080FF', '#FFFF80',
                                        ].map((hex) {
                                          final color = _parseColor(hex);
                                          return GestureDetector(
                                            onTap: () => Navigator.pop(context, color),
                                            child: Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                );
                                if (color != null) {
                                  setState(() {
                                    _selectedColor = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                                  });
                                }
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _parseColor(_selectedColor),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedColor,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Is Default
                        SwitchListTile(
                          title: Text(localizations?.translate('default') ?? 'Default'),
                          value: _isDefault,
                          onChanged: (value) {
                            setState(() {
                              _isDefault = value;
                            });
                          },
                        ),
                        // Is Hidden
                        SwitchListTile(
                          title: Text(localizations?.translate('hidden') ?? 'Hidden'),
                          value: _isHidden,
                          onChanged: (value) {
                            setState(() {
                              _isHidden = value;
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
                              : Text(localizations?.translate('update') ?? 'Update'),
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

