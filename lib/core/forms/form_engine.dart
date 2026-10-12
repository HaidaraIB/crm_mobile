class ValidationIssue {
  ValidationIssue(this.code, [Map<String, Object?>? params])
      : params = params ?? const {};

  final String code;
  final Map<String, Object?> params;
}

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
const _latinDigits = '01234567890123456789';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _phoneRe = RegExp(r'^\+[1-9]\d{1,14}$');
final _usernameRe = RegExp(r'^[A-Za-z0-9._-]+$');
final _slugRe = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$');

String latinDigits(String value) {
  final buffer = StringBuffer();
  for (final char in value.split('')) {
    final index = _arabicDigits.indexOf(char);
    buffer.write(index >= 0 ? _latinDigits[index] : char);
  }
  return buffer.toString();
}

bool isBlank(Object? value) {
  if (value == null) return true;
  if (value is String && value.trim().isEmpty) return true;
  if (value is List && value.isEmpty) return true;
  return false;
}

ValidationIssue _issue(String code, [Map<String, Object?> params = const {}]) {
  final full = code.startsWith('validation.') ? code : 'validation.$code';
  return ValidationIssue(full, params);
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

bool _whenMatches(Object? when, Map<String, Object?> context) {
  if (when == null) return true;
  if (when is String) return context[when] == true;
  if (when is Map) {
    final flag = when['flag']?.toString() ?? '';
    if (when.containsKey('equals')) return context[flag] == when['equals'];
    if (when.containsKey('not')) return context[flag] != when['not'];
    return context[flag] == true;
  }
  return true;
}

bool _ruleActive(Map rule, Map<String, Object?> context, bool enforceClientOnly) {
  if (rule['client_only'] == true && !enforceClientOnly) return false;
  if (rule['type'] == 'remote') return false;
  return _whenMatches(rule['when'], context);
}

({Object? value, bool present}) _lookup(Map data, String key, Map field) {
  if (data.containsKey(key)) return (value: data[key], present: true);
  final uiKey = field['ui_key']?.toString();
  if (uiKey != null && data.containsKey(uiKey)) {
    return (value: data[uiKey], present: true);
  }
  return (value: null, present: false);
}

Object? _normalize(Map field, Object? value) {
  if (value is! String) return value;
  var text = latinDigits(value);
  final rules = (field['rules'] as List?) ?? const [];
  final types = rules.whereType<Map>().map((rule) => rule['type']).toSet();
  if (field['type'] == 'string' && !types.contains('password_policy')) {
    text = text.trim();
  }
  if (types.contains('phone_e164')) {
    text = text.trim().replaceAll(RegExp(r'[\s()-]'), '');
  }
  if (types.contains('email')) text = text.trim().toLowerCase();
  return text;
}

num? _asNumber(Object? value) {
  if (value is bool) return null;
  if (value is num) return value;
  if (value is String && value.trim().isNotEmpty) return num.tryParse(value.trim());
  return null;
}

Object? _sibling(Map data, String name, Map fields) {
  if (data.containsKey(name)) return data[name];
  for (final entry in fields.entries) {
    final field = _map(entry.value);
    if (field['ui_key'] == name && data.containsKey(entry.key)) return data[entry.key];
    if (entry.key == name && field['ui_key'] != null && data.containsKey(field['ui_key'])) {
      return data[field['ui_key']];
    }
  }
  return null;
}

ValidationIssue? _applyRule(Map rule, Object? value, Map data, Map fields) {
  final params = _map(rule['params']);
  final type = rule['type']?.toString() ?? '';
  switch (type) {
    case 'required':
      return isBlank(value) ? _issue('validation.required') : null;
    case 'min_length':
      if (isBlank(value) || value is! String) return null;
      final min = num.tryParse('${params['min'] ?? 0}')?.toInt() ?? 0;
      return value.length < min ? _issue('validation.min_length', {'min': min}) : null;
    case 'max_length':
      if (isBlank(value) || value is! String) return null;
      final max = num.tryParse('${params['max'] ?? 0}')?.toInt() ?? 0;
      return value.length > max ? _issue('validation.max_length', {'max': max}) : null;
    case 'pattern':
      if (isBlank(value)) return null;
      final regex = '${params['regex'] ?? ''}';
      return RegExp('^(?:$regex)\$').hasMatch('$value') ? null : _issue('validation.pattern', {'regex': regex});
    case 'email':
      return isBlank(value) || _emailRe.hasMatch('$value'.trim()) ? null : _issue('validation.email');
    case 'phone_e164':
      if (isBlank(value)) return null;
      final text = '$value'.trim().replaceAll(RegExp(r'[\s()-]'), '');
      return _phoneRe.hasMatch(text) && text.length >= 8 ? null : _issue('validation.phone_e164');
    case 'username':
      if (isBlank(value)) return null;
      final text = '$value'.trim();
      final min = num.tryParse('${params['min'] ?? 3}')?.toInt() ?? 3;
      return text.length >= min && _usernameRe.hasMatch(text)
          ? null
          : _issue('validation.username', {'min': min});
    case 'slug':
      return isBlank(value) || _slugRe.hasMatch('$value'.trim()) ? null : _issue('validation.slug');
    case 'url':
      if (isBlank(value)) return null;
      final parsed = Uri.tryParse('$value'.trim());
      if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https') || parsed.host.isEmpty) {
        return _issue('validation.url');
      }
      return null;
    case 'number_range':
      if (isBlank(value)) return null;
      final number = _asNumber(value);
      if (number == null) return _issue('validation.number_range', params.cast<String, Object?>());
      final min = params['min'] == null ? null : num.tryParse('${params['min']}');
      final max = params['max'] == null ? null : num.tryParse('${params['max']}');
      if (min != null && number < min) return _issue('validation.number_range', {'min': params['min']});
      if (max != null && number > max) {
        return _issue('validation.number_range', {'max': params['max'], 'min': params['min']});
      }
      return null;
    case 'integer':
      if (isBlank(value)) return null;
      if (value is bool) return _issue('validation.integer');
      if (value is num) return value == value.roundToDouble() ? null : _issue('validation.integer');
      return RegExp(r'^-?\d+$').hasMatch('$value'.trim()) ? null : _issue('validation.integer');
    case 'decimal_places':
      if (isBlank(value)) return null;
      final text = '$value';
      final fraction = text.contains('.') ? text.split('.').last : '';
      final places = num.tryParse('${params['max'] ?? 0}')?.toInt() ?? 0;
      return fraction.length > places
          ? _issue('validation.decimal_places', {'places': places, 'max': places})
          : null;
    case 'one_of':
      if (isBlank(value)) return null;
      final allowed = (params['values'] as List?) ?? const [];
      if (allowed.contains(value)) return null;
      return allowed.map((item) => '$item').contains('$value')
          ? null
          : _issue('validation.one_of', {'values': allowed});
    case 'matches_field':
      if (isBlank(value)) return null;
      final otherName = '${params['field'] ?? ''}';
      return _sibling(data, otherName, fields) == value
          ? null
          : _issue('validation.matches_field', {'field': otherName});
    case 'required_if':
      final otherName = '${params['field'] ?? ''}';
      final other = _sibling(data, otherName, fields);
      var needed = false;
      if (params.containsKey('equals')) {
        needed = other == params['equals'] || '$other' == '${params['equals']}';
      } else if (params['not_empty'] == true) {
        needed = !isBlank(other);
      } else if (params['in'] is List) {
        needed = (params['in'] as List).contains(other);
      }
      return needed && isBlank(value) ? _issue('validation.required_if', {'field': otherName}) : null;
    case 'date_range':
      if (isBlank(value)) return null;
      final current = DateTime.tryParse('$value');
      if (current == null) return _issue('validation.date');
      if (params['gte_field'] != null) {
        final other = DateTime.tryParse('${_sibling(data, '${params['gte_field']}', fields) ?? ''}');
        if (other != null && current.isBefore(other)) {
          return _issue('validation.date_range', {'gte_field': params['gte_field']});
        }
      }
      if (params['lte_field'] != null) {
        final other = DateTime.tryParse('${_sibling(data, '${params['lte_field']}', fields) ?? ''}');
        if (other != null && current.isAfter(other)) {
          return _issue('validation.date_range', {'lte_field': params['lte_field']});
        }
      }
      return null;
    case 'file':
      if (isBlank(value) || value is! Map) return null;
      final size = value['size'];
      final maxBytes = params['max_bytes'];
      if (maxBytes != null && size is num && size > num.parse('$maxBytes')) {
        return _issue('validation.file', {'reason': 'too_large', 'max_bytes': maxBytes});
      }
      final allowed = (params['mime'] as List?)?.map((item) => '$item').toList() ?? const <String>[];
      final mime = value['type'] ?? value['mime'];
      if (allowed.isNotEmpty && mime != null && !allowed.contains('$mime')) {
        return _issue('validation.file', {'reason': 'mime', 'mime': allowed});
      }
      return null;
    case 'password_policy':
      if (isBlank(value)) return null;
      final text = '$value';
      final min = num.tryParse('${params['min_length'] ?? 8}')?.toInt() ?? 8;
      if (text.length < min) return _issue('validation.password_policy', {'reason': 'min_length', 'min': min});
      if (params['reject_numeric'] != false && RegExp(r'^\d+$').hasMatch(text)) {
        return _issue('validation.password_policy', {'reason': 'numeric', 'min': min});
      }
      final sample = ((params['common_sample'] as List?) ?? const [])
          .map((item) => '$item'.toLowerCase())
          .toSet();
      if (params['reject_common'] == true && sample.contains(text.toLowerCase())) {
        return _issue('validation.password_policy', {'reason': 'common', 'min': min});
      }
      return null;
    case 'array':
      if (value == null) return null;
      if (value is! List) return _issue('validation.array');
      final min = params['min'] == null ? null : num.tryParse('${params['min']}')?.toInt();
      final max = params['max'] == null ? null : num.tryParse('${params['max']}')?.toInt();
      if (min != null && value.length < min) return _issue('validation.array', {'min': min});
      if (max != null && value.length > max) return _issue('validation.array', {'max': max});
      return null;
    default:
      if (type.startsWith('custom:')) return null;
      return null;
  }
}

void _add(Map<String, List<ValidationIssue>> issues, String path, ValidationIssue? found) {
  if (found == null) return;
  final key = path.isEmpty ? 'non_field' : path;
  issues.putIfAbsent(key, () => []).add(found);
}

void _validateScalar(
  Map field,
  Object? value,
  String path,
  Map data,
  Map<String, List<ValidationIssue>> issues,
  Map<String, Object?> context,
  bool enforceClientOnly,
) {
  final normalized = _normalize(field, value);
  for (final raw in (field['rules'] as List?) ?? const []) {
    if (raw is! Map) continue;
    if (!_ruleActive(raw, context, enforceClientOnly)) continue;
    final found = _applyRule(raw, normalized, data, const {});
    if (found != null) {
      _add(issues, path, found);
      if (raw['type'] == 'required' || raw['type'] == 'required_if') break;
    }
  }
}

void _walk(
  Map fields,
  Map data,
  String prefix,
  Map<String, List<ValidationIssue>> issues,
  Map<String, Object?> context,
  bool partial,
  bool enforceClientOnly,
) {
  for (final entry in fields.entries) {
    final key = entry.key.toString();
    final field = _map(entry.value);
    final path = prefix.isEmpty ? key : '$prefix.$key';
    final found = _lookup(data, key, field);
    var value = found.present ? _normalize(field, found.value) : found.value;
    var requiredFailed = false;
    for (final raw in (field['rules'] as List?) ?? const []) {
      if (raw is! Map) continue;
      if (!_ruleActive(raw, context, enforceClientOnly)) continue;
      if (raw['type'] == 'required' && partial && !found.present) continue;
      if (!found.present && raw['type'] != 'required' && raw['type'] != 'required_if') continue;
      final failure = _applyRule(raw, value, data, fields);
      if (failure != null) {
        _add(issues, path, failure);
        if (raw['type'] == 'required' || raw['type'] == 'required_if') {
          requiredFailed = true;
          break;
        }
      }
    }
    if (requiredFailed || !found.present) continue;
    if (field['type'] == 'object' && field['fields'] is Map && value is Map) {
      _walk(_map(field['fields']), _map(value), path, issues, context, partial, enforceClientOnly);
    } else if (field['type'] == 'array' && field['item'] is Map && value is List) {
      final item = _map(field['item']);
      for (var index = 0; index < value.length; index++) {
        final itemPath = '$path.$index';
        final current = value[index];
        if (item['fields'] is Map && current is Map) {
          _walk(_map(item['fields']), _map(current), itemPath, issues, context, false, enforceClientOnly);
        } else {
          _validateScalar(item, current, itemPath, data, issues, context, enforceClientOnly);
        }
      }
    }
  }
}

Map<String, List<ValidationIssue>> evaluateForm(
  Map form,
  Map? data, {
  Map<String, Object?> context = const {},
  bool partial = false,
  bool enforceClientOnly = true,
}) {
  final issues = <String, List<ValidationIssue>>{};
  _walk(_map(form['fields']), _map(data), '', issues, context, partial, enforceClientOnly);
  return issues;
}
