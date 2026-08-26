import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../models/settings_model.dart';

/// Collects the mandatory justification for moving a lead into a status that was
/// flagged `requires_change_reason` in settings.
///
/// Returns the entered reason, or `null` when the user cancelled.
class StatusChangeReasonDialog extends StatefulWidget {
  const StatusChangeReasonDialog({super.key, this.statusName});

  /// Name of the status the lead is being moved into, shown for context.
  final String? statusName;

  @override
  State<StatusChangeReasonDialog> createState() => _StatusChangeReasonDialogState();
}

class _StatusChangeReasonDialogState extends State<StatusChangeReasonDialog> {
  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        localizations?.translate('statusChangeReasonTitle') ?? 'Reason for status change',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.statusName != null) ...[
            Text(
              (localizations?.translate('statusChangeReasonIntro') ??
                      'You are moving this lead to "{status}".')
                  .replaceAll('{status}', widget.statusName!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 1000,
            textInputAction: TextInputAction.newline,
            onChanged: (_) {
              if (_showError) setState(() => _showError = false);
            },
            decoration: InputDecoration(
              labelText: localizations?.translate('statusChangeReasonLabel') ?? 'Reason',
              hintText: localizations?.translate('statusChangeReasonPlaceholder'),
              errorText: _showError
                  ? (localizations?.translate('statusChangeReasonRequired') ??
                      'A reason is required for this status')
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations?.translate('cancel') ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: Text(
            localizations?.translate('statusChangeReasonConfirm') ?? 'Confirm',
          ),
        ),
      ],
    );
  }
}

/// Prompts for a reason when [status] requires one.
///
/// Returns `(proceed: true, reason: ...)` when the change may go ahead — either
/// because no reason was needed or because the user supplied one — and
/// `(proceed: false, ...)` when they cancelled the prompt.
Future<({bool proceed, String? reason})> resolveStatusChangeReason(
  BuildContext context,
  StatusModel? status,
) async {
  if (status == null || !status.requiresChangeReason) {
    return (proceed: true, reason: null);
  }
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => StatusChangeReasonDialog(statusName: status.name),
  );
  if (reason == null || reason.isEmpty) {
    return (proceed: false, reason: null);
  }
  return (proceed: true, reason: reason);
}
