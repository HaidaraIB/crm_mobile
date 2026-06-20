import '../../models/lead_model.dart';

/// Resolve the lead's primary dial/display number from phone_numbers or legacy phone field.
String resolvePrimaryPhone(LeadModel lead) {
  final numbers = lead.phoneNumbers;
  if (numbers != null && numbers.isNotEmpty) {
    final primary = numbers.firstWhere(
      (p) => p.isPrimary,
      orElse: () => numbers.first,
    );
    if (primary.phoneNumber.isNotEmpty) {
      return primary.phoneNumber;
    }
  }
  return lead.phone.trim();
}

/// Formats phone for display so the plus sign always appears at the start (works in both LTR and RTL).
String formatPhoneForDisplay(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return raw;
  return '+$digits';
}
