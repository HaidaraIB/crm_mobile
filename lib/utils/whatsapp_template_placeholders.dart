/// Replace common WhatsApp template placeholders (parity with web `replaceTemplatePlaceholders`).
String replaceWhatsAppTemplatePlaceholders(
  String content, {
  String? customerName,
  String? phone,
}) {
  var out = content;
  final name = (customerName ?? '').trim();
  final phoneVal = (phone ?? '').trim();
  out = out.replaceAll('[Customer Name]', name);
  out = out.replaceAll('[customer name]', name);
  out = out.replaceAll('{{1}}', name.isNotEmpty ? name : phoneVal);
  out = out.replaceAll('{{customer_name}}', name);
  out = out.replaceAll('{{phone}}', phoneVal);
  out = out.replaceAll('[Phone]', phoneVal);
  return out;
}
