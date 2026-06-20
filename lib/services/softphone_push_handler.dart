import 'dart:async';
import 'dart:io';

import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

import 'softphone_full_screen_intent.dart';
import 'softphone_service.dart';
import 'softphone_timing.dart';
import 'softphone_voip_bridge.dart';

/// Handles CRM VoIP push wake-up and native incoming call UI (CallKit / full-screen).
class SoftphonePushHandler {
  SoftphonePushHandler._() {
    SoftphonePushHandlerBridge.register(
      (data, {bool fromNativeIos = false}) =>
          handleIncomingPush(data, fromNativeIos: fromNativeIos),
    );
  }
  static final SoftphonePushHandler instance = SoftphonePushHandler._();

  static const Duration _inviteWaitTimeout = Duration(seconds: 5);

  bool _listenersReady = false;
  final Set<String> _shownCallIds = {};
  final Map<String, Timer> _inviteTimers = {};

  void ensureListeners() {
    if (_listenersReady) return;
    _listenersReady = true;
    SoftphoneVoipBridge.instance.ensureListening();

    FlutterCallkitIncoming.onEvent.listen((event) async {
      final body = event?.body;
      if (body == null) return;
      final name = body['name'] as String? ?? '';
      final callId = body['id'] as String? ?? '';

      switch (name) {
        case 'com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT':
        case 'ACTION_CALL_ACCEPT':
          SoftphoneTiming.instance.log('callkit_answered');
          await SoftphoneService.instance.initializeIfEnabled();
          await SoftphoneService.instance.answerIncoming();
          break;
        case 'com.hiennv.flutter_callkit_incoming.ACTION_CALL_DECLINE':
        case 'ACTION_CALL_DECLINE':
          await SoftphoneService.instance.rejectIncoming();
          _clearInviteTimer(callId);
          break;
        case 'com.hiennv.flutter_callkit_incoming.ACTION_CALL_ENDED':
        case 'ACTION_CALL_ENDED':
          await SoftphoneService.instance.hangup();
          _clearInviteTimer(callId);
          break;
        default:
          break;
      }
    });
  }

  Future<void> handleIncomingPush(
    Map<String, dynamic> data, {
    bool fromNativeIos = false,
  }) async {
    ensureListeners();
    final kind = data['kind'] ?? data['type'];
    if (kind != 'softphone_incoming_call') return;

    final callUuid = (data['call_uuid'] as String?)?.trim();
    final callIdRaw = (data['call_id'] as String?)?.trim();
    final id = callUuid?.isNotEmpty == true
        ? callUuid!
        : (callIdRaw?.isNotEmpty == true ? callIdRaw! : const Uuid().v4());

    if (_shownCallIds.contains(id)) {
      SoftphoneTiming.instance.log('push_deduped');
      return;
    }
    _shownCallIds.add(id);
    if (_shownCallIds.length > 32) {
      _shownCallIds.remove(_shownCallIds.first);
    }

    SoftphoneTiming.instance.bindCall(callIdRaw ?? id);
    SoftphoneTiming.instance.log('push_received');

    final caller = (data['caller'] as String?) ?? (data['handle'] as String?) ?? 'Unknown';
    final name = (data['nameCaller'] as String?) ??
        (data['client_name'] as String?) ??
        caller;

    final showNativeUi = !(Platform.isIOS && fromNativeIos);
    if (showNativeUi) {
      if (Platform.isAndroid) {
        final fsiOk = await SoftphoneFullScreenIntent.canUseFullScreenIntent();
        if (!fsiOk) {
          SoftphoneTiming.instance.log('fsi_permission_missing');
          await SoftphoneFullScreenIntent.openFullScreenIntentSettings();
        }
      }
      await FlutterCallkitIncoming.showCallkitIncoming(
        CallKitParams(
          id: id,
          nameCaller: name,
          appName: 'LOOP CRM',
          handle: caller,
          type: 0,
          duration: 45000,
          textAccept: 'Answer',
          textDecline: 'Decline',
          extra: data,
          android: const AndroidParams(
            isCustomNotification: true,
            isShowLogo: false,
            ringtonePath: 'system_ringtone_default',
            backgroundColor: '#0957DE',
            actionColor: '#4CAF50',
            incomingCallNotificationChannelName: 'Incoming Calls',
          ),
          ios: const IOSParams(
            handleType: 'generic',
            supportsVideo: false,
            maximumCallGroups: 1,
            maximumCallsPerCallGroup: 1,
            audioSessionMode: 'voiceChat',
            audioSessionActive: true,
            audioSessionPreferredSampleRate: 44100.0,
            audioSessionPreferredIOBufferDuration: 0.005,
          ),
          callingNotification: NotificationParams(
            showNotification: true,
            isShowCallback: true,
            subtitle: caller,
          ),
        ),
      );
      SoftphoneTiming.instance.log('callkit_shown');
    } else {
      SoftphoneTiming.instance.log('callkit_shown_native');
    }

    SoftphoneService.instance.trackIncomingPushCallKitId(id);
    _startInviteTimeout(id);

    unawaited(SoftphoneService.instance.initializeIfEnabled());
  }

  void _startInviteTimeout(String callKitId) {
    _clearInviteTimer(callKitId);
    _inviteTimers[callKitId] = Timer(_inviteWaitTimeout, () async {
      if (SoftphoneService.instance.hasPendingIncomingInvite) return;
      SoftphoneTiming.instance.log('invite_timeout');
      try {
        await FlutterCallkitIncoming.endCall(callKitId);
      } catch (_) {}
      SoftphoneService.instance.clearIncomingPushCallKitId(callKitId);
    });
  }

  void _clearInviteTimer(String callKitId) {
    _inviteTimers.remove(callKitId)?.cancel();
  }

  void onInviteReceived(String? callKitId) {
    final id = callKitId ?? _inviteTimers.keys.firstOrNull;
    if (id != null) {
      _clearInviteTimer(id);
    }
    SoftphoneTiming.instance.log('invite_received');
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
