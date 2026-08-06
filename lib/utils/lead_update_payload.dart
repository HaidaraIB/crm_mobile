import '../core/utils/lead_location.dart';
import 'build_update_diff.dart';

/// API body for interested_developer / interested_project / interested_unit.
Map<String, dynamic> buildInterestedInventoryApiBody({
  required String? specialization,
  int? interestedDeveloper,
  int? interestedProject,
  int? interestedUnit,
}) {
  if (specialization != 'real_estate') return {};
  return {
    'interested_developer':
        interestedDeveloper != null && interestedDeveloper > 0
            ? interestedDeveloper
            : null,
    'interested_project':
        interestedProject != null && interestedProject > 0
            ? interestedProject
            : null,
    'interested_unit':
        interestedUnit != null && interestedUnit > 0 ? interestedUnit : null,
  };
}

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
  required bool isUrgent,
  required int? statusId,
  required String? leadCompanyName,
  required String? profession,
  required String? notes,
  String? residence,
  String? specialization,
  int? interestedDeveloper,
  int? interestedProject,
  int? interestedUnit,
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
  primaryPhoneMap ??=
      finalPhoneNumbers.isNotEmpty ? finalPhoneNumbers.first : null;
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
    'is_urgent': isUrgent,
    'status': statusId,
    'lead_company_name':
        leadCompanyName == null || leadCompanyName.trim().isEmpty
            ? null
            : leadCompanyName.trim(),
    'profession':
        profession == null || profession.trim().isEmpty
            ? null
            : profession.trim(),
    'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
    'residence':
        residence == null || residence.trim().isEmpty
            ? null
            : residence.trim(),
  };

  if (primaryPhone.isNotEmpty) {
    payload['phone_number'] = primaryPhone;
  }

  payload.addAll(
    buildInterestedInventoryApiBody(
      specialization: specialization,
      interestedDeveloper: interestedDeveloper,
      interestedProject: interestedProject,
      interestedUnit: interestedUnit,
    ),
  );

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
