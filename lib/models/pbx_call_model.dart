/// Loop Cloud PBX: the agent's own phone-system context and call history
/// (`GET /telephony/me/`, `GET /telephony/calls/`). See CRM-api-1 docs/TELEPHONY.md.
library;

/// `GET /telephony/me/`: what the phone system offers this user.
class PbxMe {
  final bool provisioned;
  final bool outboundSuspended;
  final String? extensionNumber;

  /// `webrtc` (browser), `desk_phone` or `softphone`: the device that rings first on click-to-call.
  final String? deviceType;
  final bool registered;
  final bool canClickToCall;

  const PbxMe({
    required this.provisioned,
    required this.outboundSuspended,
    required this.extensionNumber,
    required this.deviceType,
    required this.registered,
    required this.canClickToCall,
  });

  bool get hasExtension =>
      extensionNumber != null && extensionNumber!.isNotEmpty;

  factory PbxMe.fromJson(Map<String, dynamic> json) {
    final ext = json['extension'] is Map
        ? Map<String, dynamic>.from(json['extension'] as Map)
        : null;
    return PbxMe(
      provisioned: json['provisioned'] == true,
      outboundSuspended: json['outbound_suspended'] == true,
      extensionNumber: ext?['number']?.toString(),
      deviceType: ext?['device_type']?.toString(),
      registered: ext?['registered'] == true,
      canClickToCall: json['can_click_to_call'] == true,
    );
  }
}

/// One row of `GET /telephony/calls/`.
class PbxCallRecord {
  final String id;
  final String direction; // inbound | outbound | internal | ''
  final String status;
  final String fromParty;
  final String toParty;
  final String? extensionNumber;
  final String? answeredByNumber;
  final int? crmContactId;
  final String? crmContactName;
  final int? billsecS;
  final bool hasRecording;
  final DateTime? startedAt;

  const PbxCallRecord({
    required this.id,
    required this.direction,
    required this.status,
    required this.fromParty,
    required this.toParty,
    this.extensionNumber,
    this.answeredByNumber,
    this.crmContactId,
    this.crmContactName,
    this.billsecS,
    required this.hasRecording,
    this.startedAt,
  });

  static const missedStatuses = {'missed', 'no_answer', 'abandoned'};

  bool get isMissed =>
      direction == 'inbound' && missedStatuses.contains(status);

  /// The outside party: who called in, or who was called.
  String get remoteParty => direction == 'inbound' ? fromParty : toParty;

  factory PbxCallRecord.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
    return PbxCallRecord(
      id: json['id']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      fromParty: json['from_party']?.toString() ?? '',
      toParty: json['to_party']?.toString() ?? '',
      extensionNumber: json['extension_number']?.toString(),
      answeredByNumber: json['answered_by_number']?.toString(),
      crmContactId: asInt(json['crm_contact']),
      crmContactName: json['crm_contact_name']?.toString(),
      billsecS: asInt(json['billsec_s']),
      hasRecording: json['has_recording'] == true,
      startedAt: DateTime.tryParse(
        json['started_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

class PbxCallsPage {
  final List<PbxCallRecord> results;

  /// Opaque cursor for the next (older) page, from the `next` link; null at the end.
  final String? nextCursor;

  const PbxCallsPage({required this.results, this.nextCursor});

  static String? cursorFromNextUrl(String? next) {
    if (next == null || next.isEmpty) return null;
    return Uri.tryParse(next)?.queryParameters['cursor'];
  }
}

/// Result of `POST /telephony/calls/` (click-to-call).
class PbxPlaceCallResult {
  final bool ok;

  /// API error code when refused (`phone_not_registered`, `concurrency_limit`, …).
  final String? code;

  const PbxPlaceCallResult.ok() : ok = true, code = null;
  const PbxPlaceCallResult.refused(this.code) : ok = false;
}
