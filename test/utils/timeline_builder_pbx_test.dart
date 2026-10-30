// Loop Cloud PBX calls on the lead timeline: parity with CRM-project
// (pages/ViewLeadPage.tsx formatPbxCallSummary + components/Timeline.tsx).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:crm_mobile/models/client_call_model.dart';
import 'package:crm_mobile/models/timeline_entry.dart';
import 'package:crm_mobile/utils/timeline_builder.dart';

const _strings = {
  'pbxCallSource': 'Phone system',
  'pbxDirection_outbound': 'Outgoing',
  'pbxStatus_answered': 'Answered',
  'pbxStatus_missed': 'Missed',
  'pbxDirection_inbound': 'Incoming',
  'callDurationSeconds': '{n}s',
  'call': 'Call',
};

List<TimelineEntry> _build(List<Map<String, dynamic>> calls) =>
    buildLeadTimeline(
      TimelineBuilderInput(
        tasks: const [],
        calls: calls.map(ClientCallModel.fromJson).toList(),
        visits: const [],
        fieldVisits: const [],
        events: const [],
        smsMessages: const [],
        whatsappMessages: const [],
        users: const [],
        statuses: const [],
        channels: const [],
        stages: const [],
        callMethods: const [],
        visitTypes: const [],
        t: (k) => _strings[k] ?? k,
        locale: const Locale('en'),
        leadContactName: 'Lead',
        leadContactPhone: '+9647801234567',
      ),
    );

Map<String, dynamic> _pbxCall({
  String direction = 'outbound',
  String status = 'answered',
  int? seconds = 61,
  String? recordingId,
  String? recordingStatus,
}) => {
  'id': 7,
  'client': 1,
  'source': 'pbx',
  'notes': 'Phone call · Outgoing · Answered · 61s',
  'call_datetime': '2026-10-15T10:00:00Z',
  'created_at': '2026-10-15T10:01:06Z',
  'created_by': 3,
  'pbx_call_id': '0b5e3c2a-9d8f-4e1b-a6c7-8d9e0f1a2b3c',
  'pbx_direction': direction,
  'pbx_call_status': status,
  'pbx_duration_sec': seconds,
  'pbx_recording_id': recordingId,
  'pbx_recording_status': recordingStatus,
};

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('PBX call is summarised from typed fields, not the English notes', () {
    final [entry] = _build([
      _pbxCall(),
    ]).where((e) => e.type == TimelineEntryType.call).toList();
    expect(entry.action, 'Outgoing · Answered · 61s');
    expect(entry.stage, 'Phone system');
    expect(entry.color, '#2563eb');
    expect(entry.details, '');
    expect(entry.recordingUrl, isNull);
  });

  test('recording plays through its id once ready', () {
    final [entry] = _build([
      _pbxCall(
        recordingId: '5c1d2e3f-0000-4000-8000-000000000002',
        recordingStatus: 'ready',
      ),
    ]).where((e) => e.type == TimelineEntryType.call).toList();
    expect(entry.recordingStatus, 'ready');
    expect(entry.pbxRecordingId, '5c1d2e3f-0000-4000-8000-000000000002');
  });

  test('missed inbound call without talk time', () {
    final [entry] = _build([
      _pbxCall(direction: 'inbound', status: 'missed', seconds: 0),
    ]).where((e) => e.type == TimelineEntryType.call).toList();
    expect(entry.action, 'Incoming · Missed');
  });

  test('round-trips through JSON', () {
    final model = ClientCallModel.fromJson(
      _pbxCall(recordingStatus: 'pending'),
    );
    final again = ClientCallModel.fromJson(model.toJson());
    expect(again.isPbx, isTrue);
    expect(again.pbxDurationSec, 61);
    expect(again.timelineRecordingStatus, 'pending');
  });
}
