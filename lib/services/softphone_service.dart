import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sip_ua/sip_ua.dart';

import '../core/storage/softphone_credentials_storage.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'softphone_push_handler.dart';
import 'softphone_timing.dart';
import 'softphone_voip_bridge.dart';

// sip_ua 1.0.1 API assumptions: TransportType WS/TCP only; buildCallOptions(true)
// positional; stop/mute/unmute return void.

enum SoftphoneRegState { idle, connecting, registered, error }

class SoftphoneCallInfo {
  final String id;
  final String remote;
  final bool inbound;
  final Call? call;

  const SoftphoneCallInfo({
    required this.id,
    required this.remote,
    required this.inbound,
    this.call,
  });
}

class SoftphoneService implements SipUaHelperListener {
  SoftphoneService._();
  static final SoftphoneService instance = SoftphoneService._();

  final SIPUAHelper _helper = SIPUAHelper();
  final ApiService _api = ApiService();

  final _regStateController = StreamController<SoftphoneRegState>.broadcast();
  final _incomingController = StreamController<SoftphoneCallInfo>.broadcast();
  final _activeCallController = StreamController<SoftphoneCallInfo?>.broadcast();

  Stream<SoftphoneRegState> get registrationState => _regStateController.stream;
  Stream<SoftphoneCallInfo> get incomingCalls => _incomingController.stream;
  Stream<SoftphoneCallInfo?> get activeCall => _activeCallController.stream;

  SoftphoneRegState _regState = SoftphoneRegState.idle;
  SoftphoneRegState get currentRegState => _regState;
  SoftphoneCallInfo? _active;
  Call? _pendingIncoming;
  bool _started = false;
  String? _activeCallKitId;
  Completer<Call?>? _incomingInviteCompleter;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  List<ConnectivityResult> _lastConnectivity = const [];

  bool get hasPendingIncomingInvite => _pendingIncoming != null;

  Future<bool> initializeIfEnabled() async {
    SoftphoneVoipBridge.instance.ensureListening();
    final settings = await _api.getPbxSettings();
    if (settings == null) return false;
    if (settings['is_enabled'] != true) return false;
    if (settings['softphone_enabled'] != true) return false;

    final config = await _api.getSoftphoneConfig(
      platform: Platform.isIOS ? 'ios' : 'android',
    );
    if (config == null) return false;

    final pwd = config['sip_password'] as String? ?? '';
    if (pwd.isNotEmpty) {
      await SoftphoneCredentialsStorage.instance.writeSipPassword(pwd);
    }

    await _registerDeviceTokens();
    await start(config);
    return true;
  }

  Future<void> refreshDeviceRegistration() async {
    try {
      final settings = await _api.getPbxSettings();
      if (settings == null || settings['softphone_enabled'] != true) return;
      await _registerDeviceTokens();
    } catch (e) {
      debugPrint('Softphone device refresh failed: $e');
    }
  }

  Future<void> _registerDeviceTokens() async {
    try {
      final fcm = NotificationService().fcmToken;
      String? voip;
      if (Platform.isIOS) {
        try {
          voip = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        } catch (_) {}
      }
      if ((fcm == null || fcm.isEmpty) && (voip == null || voip.isEmpty)) return;
      await _api.registerSoftphoneDevice(
        platform: Platform.isIOS ? 'ios' : 'android',
        fcmToken: fcm,
        voipToken: voip,
      );
    } catch (e) {
      debugPrint('Softphone device registration failed: $e');
    }
  }

  void trackIncomingPushCallKitId(String callKitId) {
    _activeCallKitId = callKitId;
  }

  void clearIncomingPushCallKitId(String callKitId) {
    if (_activeCallKitId == callKitId) {
      _activeCallKitId = null;
    }
  }

  Future<void> start(Map<String, dynamic> config) async {
    if (_started) return;
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _setRegState(SoftphoneRegState.error);
      return;
    }

    _helper.addSipUaHelperListener(this);
    final settings = UaSettings();
    settings.uri = config['sip_uri'] as String? ?? '';
    final cachedPwd = await SoftphoneCredentialsStorage.instance.readSipPassword();
    settings.password = (config['sip_password'] as String?)?.isNotEmpty == true
        ? config['sip_password'] as String
        : (cachedPwd ?? '');
    settings.displayName =
        config['display_name'] as String? ?? config['extension'] as String? ?? '';
    settings.userAgent = 'LOOP CRM Mobile';
    settings.dtmfMode = DtmfMode.RFC2833;

    final wssUri = (config['wss_uri'] as String?)?.trim() ?? '';
    final transport = (config['transport'] as String? ?? '').toLowerCase();
    if (wssUri.isNotEmpty || transport == 'wss') {
      settings.webSocketUrl = wssUri;
      settings.transportType = TransportType.WS;
    } else {
      settings.transportType = TransportType.TCP;
      settings.host = config['sip_domain'] as String? ?? '';
      settings.port = '${config['sip_port'] ?? 5162}';
      settings.webSocketUrl = null;
    }

    _setRegState(SoftphoneRegState.connecting);
    SoftphoneTiming.instance.log('sip_register_sent');
    await _helper.start(settings);
    _started = true;
    _ensureConnectivityListener();
  }

  void _ensureConnectivityListener() {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      _onConnectivityChanged(results);
    });
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final hasNet = results.any((r) => r != ConnectivityResult.none);
    final hadNet = _lastConnectivity.any((r) => r != ConnectivityResult.none);
    _lastConnectivity = results;
    if (!hasNet || !hadNet) return;
    if (_active?.call == null && _pendingIncoming == null) return;

    SoftphoneTiming.instance.log('connectivity_handoff');
    try {
      final call = _active?.call ?? _pendingIncoming;
      if (call == null) return;
      await _helper.renegotiate(
        call: call,
        voiceOnly: true,
        useUpdate: true,
        done: (result) {
          SoftphoneTiming.instance.log(
            result != null ? 'ice_restart_ok' : 'ice_restart_failed',
          );
        },
      );
    } catch (e) {
      debugPrint('ICE restart attempt failed: $e');
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _helper.removeSipUaHelperListener(this);
    _helper.stop();
    _started = false;
    _active = null;
    _pendingIncoming = null;
    _incomingInviteCompleter = null;
    _activeCallController.add(null);
    _setRegState(SoftphoneRegState.idle);
  }

  Future<void> shutdownOnLogout() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}
    await stop();
    await SoftphoneCredentialsStorage.instance.clear();
    try {
      await _api.unregisterSoftphoneDevice(
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (e) {
      debugPrint('Softphone device unregister failed: $e');
    }
    _activeCallKitId = null;
    SoftphoneTiming.instance.reset();
  }

  Future<void> dial(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    await _helper.call(cleaned, voiceOnly: true);
  }

  Future<void> answerIncoming({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final call = await _waitForIncomingInvite(timeout: timeout);
    if (call == null) {
      await _endCallKitUi();
      return;
    }
    call.answer(_helper.buildCallOptions(true));
    _pendingIncoming = null;
    _incomingInviteCompleter = null;
    SoftphoneTiming.instance.log('call_answered');
  }

  Future<void> rejectIncoming() async {
    final call = _pendingIncoming;
    if (call != null) {
      call.hangup();
      _pendingIncoming = null;
    }
    _incomingInviteCompleter = null;
    await _endCallKitUi();
  }

  Future<void> hangup() async {
    if (_active?.call != null) {
      _active!.call!.hangup();
    } else if (_pendingIncoming != null) {
      _pendingIncoming!.hangup();
      _pendingIncoming = null;
    }
    _incomingInviteCompleter = null;
    await _endCallKitUi();
  }

  Future<void> setMuted(bool muted) async {
    final call = _active?.call;
    if (call == null) return;
    if (muted) {
      call.mute(true, false);
    } else {
      call.unmute(true, false);
    }
  }

  Future<Call?> _waitForIncomingInvite({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_pendingIncoming != null) {
      return _pendingIncoming;
    }
    _incomingInviteCompleter ??= Completer<Call?>();
    try {
      return await _incomingInviteCompleter!.future.timeout(timeout);
    } on TimeoutException {
      return _pendingIncoming;
    }
  }

  Future<void> _endCallKitUi() async {
    final id = _activeCallKitId;
    _activeCallKitId = null;
    try {
      if (id != null && id.isNotEmpty) {
        await FlutterCallkitIncoming.endCall(id);
      } else {
        await FlutterCallkitIncoming.endAllCalls();
      }
    } catch (_) {}
  }

  void _setRegState(SoftphoneRegState state) {
    _regState = state;
    _regStateController.add(state);
  }

  void _completeIncomingInvite(Call call) {
    _pendingIncoming = call;
    SoftphonePushHandler.instance.onInviteReceived(_activeCallKitId);
    final completer = _incomingInviteCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(call);
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    final remote = call.remote_identity ?? 'Unknown';
    if (state.state == CallStateEnum.CALL_INITIATION ||
        state.state == CallStateEnum.PROGRESS ||
        state.state == CallStateEnum.CONFIRMED ||
        state.state == CallStateEnum.ACCEPTED) {
      final info = SoftphoneCallInfo(
        id: call.id ?? remote,
        remote: remote,
        inbound: call.direction == 'INCOMING',
        call: call,
      );
      _active = info;
      _activeCallController.add(info);
    }
    if (state.state == CallStateEnum.ENDED ||
        state.state == CallStateEnum.FAILED) {
      if (_active?.call?.id == call.id) {
        _active = null;
        _activeCallController.add(null);
      }
      if (_pendingIncoming?.id == call.id) {
        _pendingIncoming = null;
      }
      _incomingInviteCompleter = null;
      unawaited(_endCallKitUi());
    }
    if (state.state == CallStateEnum.CALL_INITIATION &&
        call.direction == 'INCOMING') {
      _completeIncomingInvite(call);
      _incomingController.add(
        SoftphoneCallInfo(
          id: call.id ?? remote,
          remote: remote,
          inbound: true,
          call: call,
        ),
      );
    }
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    if (state.state == RegistrationStateEnum.REGISTERED) {
      _setRegState(SoftphoneRegState.registered);
      SoftphoneTiming.instance.log('sip_register_200');
    } else if (state.state == RegistrationStateEnum.UNREGISTERED) {
      _setRegState(SoftphoneRegState.idle);
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      _setRegState(SoftphoneRegState.error);
    }
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify notify) {}

  @override
  void onNewReinvite(ReInvite event) {
    SoftphoneTiming.instance.log('sip_reinvite');
  }
}
