/// Replace common WhatsApp template placeholders (parity with web `replaceTemplatePlaceholders`).
///
/// Aliases mirror `CRM-project/utils/messagePlaceholders.ts` so a template written
/// with the web chips (e.g. `{ اسم الموظف }` / `{ Employee Name }`) renders the same here.
const Map<String, List<String>> _placeholderAliases = {
  'customer_name': [
    'اسم العميل',
    'اسم_العميل',
    'customer name',
    'customer_name',
    'name',
    'client_name',
  ],
  'phone': ['رقم الهاتف', 'رقم_الهاتف', 'الهاتف', 'phone', 'phone_number'],
  'employee_name': [
    'اسم الموظف',
    'اسم_الموظف',
    'employee name',
    'employee_name',
    'assigned_to',
    'staff_name',
  ],
};

String _normKey(String raw) {
  // Mirror API `_norm_key` / web `normKey`: strip bidi/ZWSP, fold alef, strip harakat.
  var text = raw;
  final buf = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    // Format chars (Cf): bidi marks, ZWSP, BOM, etc.
    if ((rune >= 0x200b && rune <= 0x200f) ||
        rune == 0x061c ||
        rune == 0xfeff ||
        (rune >= 0x202a && rune <= 0x202e) ||
        (rune >= 0x2060 && rune <= 0x2064) ||
        (rune >= 0x2066 && rune <= 0x206f)) {
      continue;
    }
    buf.write(ch);
  }
  text = buf.toString();
  text = text.replaceAll(RegExp(r'[أإآٱ]'), 'ا');
  text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
  return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

final Map<String, String> _aliasToCanonical = {
  for (final entry in _placeholderAliases.entries)
    for (final alias in entry.value) _normKey(alias): entry.key,
};

/// Replaces `[alias]` and `{ alias }` (not Meta `{{1}}` positional tokens).
/// Unknown or unresolved aliases are left untouched, like the web renderer.
String _renderAliases(String text, Map<String, String> values) {
  String resolve(Match m) {
    final canonical = _aliasToCanonical[_normKey(m.group(1) ?? '')];
    final value = canonical == null ? null : values[canonical];
    return (value == null || value.isEmpty) ? m.group(0)! : value;
  }

  var out = text.replaceAllMapped(RegExp(r'\[([^\]]+)\]'), resolve);
  out = out.replaceAllMapped(RegExp(r'(?<!\{)\{([^{}]+)\}(?!\})'), resolve);
  return out;
}

String replaceWhatsAppTemplatePlaceholders(
  String content, {
  String? customerName,
  String? phone,
  String? employeeName,
  /// `meta_variable_map.body`: the CRM variable behind each Meta `{{n}}`, in order.
  /// Meta freezes that numbering at approval, so it beats guessing by position.
  List<String> bodyVariables = const [],
}) {
  final values = {
    'customer_name': (customerName ?? '').trim(),
    'phone': (phone ?? '').trim(),
    'employee_name': (employeeName ?? '').trim(),
  };
  final name = values['customer_name']!;
  final phoneVal = values['phone']!;

  var out = _renderAliases(content, values);

  if (bodyVariables.isNotEmpty) {
    out = out.replaceAllMapped(RegExp(r'\{\{\s*(\d+)\s*\}\}'), (m) {
      final idx = (int.tryParse(m.group(1) ?? '') ?? 0) - 1;
      if (idx < 0 || idx >= bodyVariables.length) return m.group(0)!;
      // Unknown or empty variable: leave the token rather than substitute a
      // different field — that is what made {{1}} show the customer's name.
      final value = values[bodyVariables[idx]];
      return (value == null || value.isEmpty) ? m.group(0)! : value;
    });
  } else {
    out = out.replaceAll('{{1}}', name.isNotEmpty ? name : phoneVal);
  }

  out = out.replaceAll('{{customer_name}}', name);
  out = out.replaceAll('{{phone}}', phoneVal);
  if (values['employee_name']!.isNotEmpty) {
    out = out.replaceAll('{{employee_name}}', values['employee_name']!);
  }
  return out;
}
