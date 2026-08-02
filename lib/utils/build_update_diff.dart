// Build a sparse update payload containing only keys whose values actually changed.
// Treats null and '' (whitespace-only strings) as equivalent empties.

dynamic _normalizeEmpty(dynamic value) {
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  return value;
}

String _stableStringify(dynamic value) {
  final normalized = _normalizeEmpty(value);
  if (normalized == null) return 'null';
  if (normalized is num || normalized is bool) {
    return normalized.toString();
  }
  if (normalized is String) {
    return '"${normalized.replaceAll('"', r'\"')}"';
  }
  if (normalized is List) {
    return '[${normalized.map(_stableStringify).join(',')}]';
  }
  if (normalized is Map) {
    final keys = normalized.keys.map((k) => k.toString()).toList()..sort();
    return '{${keys.map((k) => '"$k":${_stableStringify(normalized[k])}').join(',')}}';
  }
  return '"$normalized"';
}

/// Normalize phone rows for equality (ignore ids/timestamps/server-only fields).
List<Map<String, dynamic>> normalizePhoneNumbersForCompare(dynamic phones) {
  if (phones is! List) return [];
  final rows = <Map<String, dynamic>>[];
  for (final p in phones) {
    if (p is! Map) continue;
    final phone = (p['phone_number'] ?? p['phone'] ?? '').toString().trim();
    if (phone.isEmpty) continue;
    rows.add({
      'phone_number': phone,
      'phone_type': (p['phone_type'] ?? 'mobile').toString(),
      'is_primary': p['is_primary'] == true,
    });
  }
  rows.sort(
    (a, b) => (a['phone_number'] as String).compareTo(b['phone_number'] as String),
  );
  return rows;
}

bool valuesEqual(dynamic a, dynamic b) {
  final na = _normalizeEmpty(a);
  final nb = _normalizeEmpty(b);
  if (na == nb) return true;
  if (na == null && nb == null) return true;

  if (na is num && nb is num) {
    return na.isFinite && nb.isFinite && na == nb;
  }

  // Numeric string vs number (e.g. budget "100" vs 100)
  if ((na is num && nb is String) || (nb is num && na is String)) {
    final numA = na is num ? na : double.tryParse(nb as String);
    final numB = nb is num ? nb : double.tryParse(na as String);
    if (numA != null && numB != null && numA.isFinite && numB.isFinite && numA == numB) {
      return true;
    }
  }

  if (na is List || nb is List) {
    return _stableStringify(na) == _stableStringify(nb);
  }

  if (na is Map || nb is Map) {
    return _stableStringify(na) == _stableStringify(nb);
  }

  return na.toString() == nb.toString();
}

/// Returns only keys in [next] that differ from [initial].
/// Keys present only in [initial] are ignored (PATCH omit = leave unchanged).
Map<String, dynamic> buildUpdateDiff(
  Map<String, dynamic> initial,
  Map<String, dynamic> next, {
  List<String> phoneListKeys = const ['phone_numbers'],
}) {
  final phoneKeys = phoneListKeys.toSet();
  final diff = <String, dynamic>{};

  for (final key in next.keys) {
    final nextVal = next[key];
    final initialVal = initial[key];

    if (phoneKeys.contains(key)) {
      final initialNorm = _stableStringify(normalizePhoneNumbersForCompare(initialVal));
      final nextNorm = _stableStringify(normalizePhoneNumbersForCompare(nextVal));
      if (initialNorm != nextNorm) {
        diff[key] = nextVal;
      }
      continue;
    }

    if (!valuesEqual(initialVal, nextVal)) {
      diff[key] = nextVal;
    }
  }

  return diff;
}
