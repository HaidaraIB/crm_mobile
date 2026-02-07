import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/settings_model.dart';
import '../../../services/api_service.dart';
import '../../../services/error_logger.dart';

class EditStageModal extends StatefulWidget {
  final StageModel stage;
  final VoidCallback? onStageUpdated;

  const EditStageModal({
    super.key,
    required this.stage,
    this.onStageUpdated,
  });

  @override
  State<EditStageModal> createState() => _EditStageModalState();
}

class _EditStageModalState extends State<EditStageModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final ApiService _apiService = ApiService();

  late String _selectedColor;
  late bool _isRequired;
  late bool _autoAdvance;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.stage.name);
    _descriptionController = TextEditingController(text: widget.stage.description ?? '');
    _selectedColor = widget.stage.color;
    _isRequired = widget.stage.required;
    _autoAdvance = widget.stage.autoAdvance;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.updateStage(
        stageId: widget.stage.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        color: _selectedColor,
        required: _isRequired,
        autoAdvance: _autoAdvance,
      );

      if (mounted) {
        widget.onStageUpdated?.call();
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('stageUpdatedSuccessfully') ?? 
              'Stage updated successfully',
        );
      }
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/settings/stages/${widget.stage.id}/',
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
                        localizations?.translate('editStage') ?? 'Edit Stage',
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
                            labelText: '${localizations?.translate('stageName') ?? 'Stage Name'} *',
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
                        // Required
                        SwitchListTile(
                          title: Text(localizations?.translate('required') ?? 'Required'),
                          value: _isRequired,
                          onChanged: (value) {
                            setState(() {
                              _isRequired = value;
                            });
                          },
                        ),
                        // Auto Advance
                        SwitchListTile(
                          title: Text(localizations?.translate('autoAdvance') ?? 'Auto Advance'),
                          value: _autoAdvance,
                          onChanged: (value) {
                            setState(() {
                              _autoAdvance = value;
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

