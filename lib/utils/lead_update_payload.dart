import '../core/utils/lead_location.dart';
import 'build_update_diff.dart';

/// Canonical API body for a lead edit form (same shape every save).
Map<String, dynamic> buildLeadUpdatePayload({
  required String name,
  required List<Map<String, dynamic>> phoneNumbers,
  required String phoneFallback,
  required double? budget,
  required double? budgetMax,
  required int? assignedTo,
  required String? type,
  required int? channelId,
  required String? priority,
  required int? statusId,
  required String? leadCompanyName,
  required String? profession,
  required String? notes,
  double? locationLatitude,
  double? locationLongitude,
  bool includeLocation = false,
}) {
  final finalPhoneNumbers = phoneNumbers.isNotEmpty
      ? phoneNumbers
          .where((p) => p['phone_number'].toString().trim().isNotEmpty)
          .map(
            (pn) => {
              'phone_number': pn['phone_number'].toString().trim(),
              'phone_type': (pn['phone_type'] ?? 'mobile').toString(),
              'is_primary': pn['is_primary'] == true,
              'notes': (pn['notes'] ?? '').toString(),
            },
          )
          .toList()
      : phoneFallback.trim().isNotEmpty
          ? [
              {
                'phone_number': phoneFallback.trim(),
                'phone_type': 'mobile',
                'is_primary': true,
                'notes': '',
              },
            ]
          : <Map<String, dynamic>>[];

  Map<String, dynamic>? primaryPhoneMap;
  for (final pn in finalPhoneNumbers) {
    if (pn['is_primary'] == true) {
      primaryPhoneMap = pn;
      break;
    }
  }
  primaryPhoneMap ??= finalPhoneNumbers.isNotEmpty ? finalPhoneNumbers.first : null;
  final primaryPhone = primaryPhoneMap?['phone_number']?.toString() ?? '';

  final payload = <String, dynamic>{
    'name': name.trim(),
    'phone_numbers': finalPhoneNumbers,
    'budget': budget,
    'budget_max': budgetMax,
    'assigned_to': assignedTo != null && assignedTo > 0 ? assignedTo : null,
    'type': type?.toLowerCase(),
    'communication_way': channelId,
    'priority': priority?.toLowerCase(),
    'status': statusId,
    'lead_company_name':
        leadCompanyName == null || leadCompanyName.trim().isEmpty
            ? null
            : leadCompanyName.trim(),
    'profession':
        profession == null || profession.trim().isEmpty ? null : profession.trim(),
    'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
  };

  if (primaryPhone.isNotEmpty) {
    payload['phone_number'] = primaryPhone;
  }

  if (includeLocation) {
    payload.addAll(
      buildLeadLocationApiBody(
        latitude: locationLatitude,
        longitude: locationLongitude,
      ),
    );
  }

  return payload;
}

/// Sparse PATCH body: only keys that differ from the snapshot taken at form load.
Map<String, dynamic> buildLeadUpdateDiff(
  Map<String, dynamic> initial,
  Map<String, dynamic> next,
) {
  return buildUpdateDiff(initial, next, phoneListKeys: const ['phone_numbers']);
}
