import '../localization/app_localizations.dart';
import 'form_engine.dart';

/// Shared by [CatalogFormBinding] (catalog_form_binding.dart) to render a
/// [ValidationIssue] as localized text, with an optional field label.
String formatIssue(AppLocalizations? l10n, ValidationIssue issue, {String? label}) {
  if (l10n == null) return issue.code;
  final reason = issue.params['reason'];
  final key = reason is String ? '${issue.code}.$reason' : issue.code;
  final params = <String, Object?>{...issue.params, 'label': label ?? ''};
  final translated = l10n.translateParams(key, params);
  if (translated == key || translated == issue.code) {
    final fallback = l10n.translateParams(issue.code, params);
    return fallback == issue.code ? issue.code : fallback;
  }
  return translated;
}
