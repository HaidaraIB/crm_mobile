import 'package:flutter/material.dart';
import '../../../core/forms/catalog_form_binding.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/api_error_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/settings_model.dart';
import '../../../services/api_service.dart';
import '../../../services/error_logger.dart';
import 'add_tag_modal.dart' show TagColorPickerRow;
import 'package:crm_mobile/widgets/auto_dir_text_field.dart';

class EditTagModal extends StatefulWidget {
  final TagModel tag;
  final VoidCallback? onTagUpdated;

  const EditTagModal({super.key, required this.tag, this.onTagUpdated});

  @override
  State<EditTagModal> createState() => _EditTagModalState();
}

class _EditTagModalState extends State<EditTagModal> {
  final _formKey = GlobalKey<FormState>();
  final _catalog = CatalogFormBinding('tag.upsert');
  final _nameFocus = FocusNode();
  final _descriptionFocus = FocusNode();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final ApiService _apiService = ApiService();

  late String _selectedColor;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _catalog.load();
    _catalog.watch(_nameFocus, 'name', () => _blurNamed('name'));
    _catalog.watch(_descriptionFocus, 'description', () => _blurNamed('description'));

    _nameController = TextEditingController(text: widget.tag.name);
    _descriptionController =
        TextEditingController(text: widget.tag.description ?? '');
    _selectedColor = widget.tag.color;
  }

  Map<String, dynamic> _namedValues() => {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'color': _selectedColor,
      };

  Future<void> _blurNamed(String key) async {
    await _catalog.validate(context, _namedValues(), only: key);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _descriptionFocus.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = await _catalog.validate(context, _namedValues());
    if (!valid) {
      if (mounted) setState(() {});
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.updateTag(
        tagId: widget.tag.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        color: _selectedColor,
      );

      if (mounted) {
        widget.onTagUpdated?.call();
        SnackbarHelper.showSuccess(
          context,
          AppLocalizations.of(context)?.translate('tagUpdatedSuccessfully') ??
              'Tag updated successfully',
        );
      }
    } catch (e) {
      ErrorLogger().logError(
        error: e.toString(),
        endpoint: '/settings/tags/${widget.tag.id}/',
        method: 'PATCH',
      );
      if (mounted) {
        if (e is ApiFieldException && _catalog.applyApiError(AppLocalizations.of(context), e)) {
          setState(() => _isLoading = false);
          return;
        }
        setState(() {
          _errorMessage = ApiErrorHelper.toUserMessage(context, e);
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
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        localizations?.translate('editTag') ?? 'Edit Tag',
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
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AutoDirTextFormField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          onEditingComplete: () => _blurNamed('name'),
                          decoration: InputDecoration(
                            errorText: _catalog.errors['name'],
                            labelText: '${localizations?.translate('name') ?? 'Name'} *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AutoDirTextFormField(
                          controller: _descriptionController,
                          focusNode: _descriptionFocus,
                          onEditingComplete: () => _blurNamed('description'),
                          decoration: InputDecoration(
                            errorText: _catalog.errors['description'],
                            labelText:
                                localizations?.translate('description') ?? 'Description',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TagColorPickerRow(
                          selectedColor: _selectedColor,
                          onColorChanged: (hex) => setState(() => _selectedColor = hex),
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
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(localizations?.translate('save') ?? 'Save'),
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
