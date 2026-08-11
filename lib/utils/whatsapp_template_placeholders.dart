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

String _normKey(String raw) => raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

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
}) {
  final name = (customerName ?? '').trim();
  final phoneVal = (phone ?? '').trim();
  final employee = (employeeName ?? '').trim();

  var out = _renderAliases(content, {
    'customer_name': name,
    'phone': phoneVal,
    'employee_name': employee,
  });

  out = out.replaceAll('{{1}}', name.isNotEmpty ? name : phoneVal);
  out = out.replaceAll('{{customer_name}}', name);
  out = out.replaceAll('{{phone}}', phoneVal);
  if (employee.isNotEmpty) {
    out = out.replaceAll('{{employee_name}}', employee);
  }
  return out;
}
