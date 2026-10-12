import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../api/api_exceptions.dart';
import '../localization/app_localizations.dart';
import '../utils/form_api_errors.dart';
import 'catalog_field_errors.dart';
import 'form_engine.dart';
import 'format_issue.dart';
import 'validation_catalog.dart';

/// Asset-backed catalog cache plus inline errors for an existing screen.
///
/// Does not hit the network. Widgets keep [spec] after [load] from initState.
class CatalogFormBinding {
  CatalogFormBinding(this.formId);

  final String formId;
  Map<String, dynamic>? spec;
  final errors = <String, String>{};
  final touched = <String>{};

  static ValidationCatalog? _cached;

  static Future<ValidationCatalog> loadCatalog() async {
    final existing = _cached;
    if (existing != null) return existing;
    final raw = await rootBundle.loadString('assets/validation/catalog.json');
    final catalog = ValidationCatalog(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
    _cached = catalog;
    return catalog;
  }

  Future<void> load() async {
    final catalog = await loadCatalog();
    spec = catalog.form(formId);
  }

  /// Marks [key] touched while focused, then validates that field on blur.
  void watch(FocusNode node, String key, VoidCallback onBlur) {
    node.addListener(() {
      if (node.hasFocus) {
        touched.add(key);
        return;
      }
      if (touched.contains(key)) onBlur();
    });
  }

  Future<bool> validate(
    BuildContext context,
    Map<String, dynamic> values, {
    Map<String, Object?> formContext = const {},
    String? only,
    Set<String>? keys,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (spec == null) await load();
    final form = spec;
    if (form == null) return false;
    final next = catalogFieldErrors(
      form: form,
      values: values,
      l10n: l10n,
      context: formContext,
    );
    if (only != null) {
      if (next.containsKey(only)) {
        errors[only] = next[only]!;
      } else {
        errors.remove(only);
      }
      return !next.containsKey(only);
    }
    if (keys != null) {
      for (final key in keys) {
        if (next.containsKey(key)) {
          errors[key] = next[key]!;
        } else {
          errors.remove(key);
        }
      }
      _foldPhone(next, keys);
      return keys.every((key) => !errors.containsKey(key));
    }
    errors
      ..clear()
      ..addAll(next);
    _foldPhone(next, null);
    return errors.isEmpty;
  }

  void _foldPhone(Map<String, String> next, Set<String>? keys) {
    if (keys != null && !keys.contains('phone')) return;
    for (final entry in next.entries) {
      if (entry.key == 'phone' || entry.key.startsWith('phone_numbers')) {
        errors.putIfAbsent('phone', () => entry.value);
      }
    }
  }

  /// Prefer coded [ApiFieldException.fieldIssues]. String [ApiFieldException.fields]
  /// are used only when coded issues are absent.
  bool applyApiError(AppLocalizations? l10n, Object error) {
    if (error is! ApiFieldException) return false;
    var applied = false;
    final coded = error.fieldIssues;
    if (coded != null) {
      coded.forEach((key, value) {
        final ui = uiKey(key);
        final issue = _firstIssue(value);
        if (issue != null) {
          errors[ui] = formatIssue(l10n, issue);
          applied = true;
          return;
        }
        final text = _plain(value);
        if (text.isNotEmpty) {
          errors[ui] = l10n?.translateParams(text, const {}) ?? text;
          applied = true;
        }
      });
    } else if (error.fields != null && error.fields!.isNotEmpty) {
      final mapped = mapApiFieldsToUiErrors(
        error.fields,
        (key) => l10n?.translate(key) ?? key,
        fieldMap: _apiToUi(),
      );
      if (mapped.isNotEmpty) {
        errors.addAll(mapped);
        applied = true;
      }
    }
    final nonField = error.nonField;
    if (nonField != null && nonField.isNotEmpty) {
      final issue = _firstIssue(nonField);
      errors['_general'] = issue == null
          ? _plain(nonField)
          : formatIssue(l10n, issue);
      applied = true;
    }
    return applied;
  }

  String uiKey(String path) {
    final aliases = spec?['aliases'];
    if (aliases is Map) {
      for (final entry in aliases.entries) {
        if (entry.value == path) return entry.key.toString();
      }
    }
    return path;
  }

  Map<String, String> _apiToUi() {
    final aliases = spec?['aliases'];
    final map = <String, String>{};
    if (aliases is Map) {
      aliases.forEach((ui, api) {
        map['$api'] = '$ui';
      });
    }
    return map;
  }

  ValidationIssue? _firstIssue(Object? raw) {
    if (raw is! List || raw.isEmpty) return null;
    final first = raw.first;
    if (first is! Map) return null;
    final code = first['code']?.toString();
    if (code == null || code.isEmpty) return null;
    final params = first['params'];
    return ValidationIssue(
      code,
      params is Map
          ? params.map((key, value) => MapEntry('$key', value))
          : const {},
    );
  }

  String _plain(Object? raw) {
    if (raw is List) {
      if (raw.isEmpty) return '';
      return _plain(raw.first);
    }
    if (raw == null) return '';
    return raw.toString().trim();
  }
}
