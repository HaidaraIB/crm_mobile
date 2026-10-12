import '../localization/app_localizations.dart';
import 'form_engine.dart';

String _message(AppLocalizations? l10n, ValidationIssue issue) {
  if (l10n == null) return issue.code;
  final reason = issue.params['reason'];
  final key = reason is String ? '${issue.code}.$reason' : issue.code;
  final translated = l10n.translateParams(key, issue.params);
  if (translated == key) return l10n.translateParams(issue.code, issue.params);
  return translated;
}

String _uiKey(Map form, String path) {
  final aliases = form['aliases'];
  if (aliases is Map) {
    for (final entry in aliases.entries) {
      if (entry.value == path) return entry.key.toString();
    }
  }
  return path;
}

/// Inline errors for an existing screen. Keys follow catalog aliases.
Map<String, String> catalogFieldErrors({
  required Map form,
  required Map<String, dynamic> values,
  AppLocalizations? l10n,
  Map<String, Object?> context = const {},
}) {
  final issues = evaluateForm(form, values, context: context, enforceClientOnly: true);
  final errors = <String, String>{};
  issues.forEach((path, list) {
    if (list.isEmpty) return;
    final key = path == 'non_field' ? '_general' : _uiKey(form, path);
    errors[key] = _message(l10n, list.first);
  });
  return errors;
}
