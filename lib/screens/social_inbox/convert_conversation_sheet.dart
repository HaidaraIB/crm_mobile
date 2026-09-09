import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../models/social_conversation_model.dart';
import '../../widgets/app_switch.dart';

/// Convert an inbox conversation into a CRM lead.
///
/// Phone is optional and must stay optional: Instagram and Messenger carry no
/// phone number, and the backend deliberately refuses to fabricate a placeholder
/// (it would consume the company-wide unique phone key).
class ConvertConversationSheet extends StatefulWidget {
  const ConvertConversationSheet({
    super.key,
    required this.conversation,
    required this.onConvert,
  });

  final SocialConversationModel conversation;

  /// Returns the created lead id, or null when the conversion failed.
  final Future<int?> Function({
    String? name,
    String? phone,
    int? assignedTo,
    bool autoAssign,
    String? notes,
  }) onConvert;

  @override
  State<ConvertConversationSheet> createState() => _ConvertConversationSheetState();
}

class _ConvertConversationSheetState extends State<ConvertConversationSheet> {
  late final TextEditingController _nameController;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _autoAssign = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final contact = widget.conversation.contact;
    _nameController = TextEditingController(text: contact.label);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit(String Function(String) t) async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final clientId = await widget.onConvert(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      autoAssign: _autoAssign,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (clientId != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t('convertedToLead'))));
    }
    // On failure the cubit already emitted a sendErrorKey; the thread screen
    // surfaces it, so the sheet stays open with the agent's input intact.
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    String t(String key) =>
        (localizations ?? AppLocalizations(const Locale('en'))).translate(key);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('convertConversationTitle'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              t('convertConversationHint'),
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t('leadName'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: t('phoneOptional'),
                helperText: t('phoneOptionalHint'),
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            AppSwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoAssign,
              onChanged: (value) => setState(() => _autoAssign = value),
              title: Text(t('autoAssign')),
            ),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t('notes'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    child: Text(t('cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : () => _submit(t),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t('convertToLead')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
