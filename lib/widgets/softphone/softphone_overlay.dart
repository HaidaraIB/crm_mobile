import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/localization/app_localizations.dart';
import '../../services/softphone_service.dart';

class SoftphoneOverlay extends StatefulWidget {
  const SoftphoneOverlay({super.key});

  @override
  State<SoftphoneOverlay> createState() => _SoftphoneOverlayState();
}

class _SoftphoneOverlayState extends State<SoftphoneOverlay> {
  final _service = SoftphoneService.instance;
  SoftphoneRegState _regState = SoftphoneRegState.idle;
  SoftphoneErrorKind _errorKind = SoftphoneErrorKind.none;
  String? _errorDetail;
  SoftphoneCallInfo? _incoming;
  SoftphoneCallInfo? _active;
  bool _muted = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _regState = _service.currentRegState;
    _errorKind = _service.lastErrorKind;
    _errorDetail = _service.lastErrorDetail;
    _service.registrationState.listen((s) {
      if (mounted) setState(() => _regState = s);
    });
    _service.errorKind.listen((k) {
      if (mounted) {
        setState(() {
          _errorKind = k;
          _errorDetail = _service.lastErrorDetail;
        });
      }
    });
    _service.incomingCalls.listen((c) {
      if (mounted) setState(() => _incoming = c);
    });
    _service.activeCall.listen((c) {
      if (mounted) {
        setState(() {
          _active = c;
          if (c != null) _incoming = null;
        });
      }
    });
  }

  String _statusLabel(AppLocalizations? loc) {
    return switch (_regState) {
      SoftphoneRegState.registered =>
        loc?.translate('softphoneRegistered') ?? 'Registered',
      SoftphoneRegState.connecting =>
        loc?.translate('softphoneConnecting') ?? 'Connecting…',
      SoftphoneRegState.error =>
        loc?.translate('softphoneErrorTitle') ?? 'Phone system unavailable',
      SoftphoneRegState.idle => loc?.translate('softphoneOffline') ?? 'Offline',
    };
  }

  String _errorMessage(AppLocalizations? loc) {
    final base = switch (_errorKind) {
      SoftphoneErrorKind.micDenied =>
        loc?.translate('softphoneErrorMic') ??
            'Microphone access is required for calls.',
      SoftphoneErrorKind.notProvisioned =>
        loc?.translate('softphoneErrorNotProvisioned') ??
            'SIP credentials are missing.',
      SoftphoneErrorKind.transportFailed =>
        loc?.translate('softphoneErrorTransport') ??
            'Could not connect to the phone server.',
      SoftphoneErrorKind.registrationFailed =>
        loc?.translate('softphoneErrorRegistration') ??
            'Could not register your extension.',
      SoftphoneErrorKind.none =>
        loc?.translate('softphoneErrorGeneric') ??
            'Softphone could not start.',
    };
    final detail = _errorDetail?.trim();
    if (detail != null && detail.isNotEmpty) {
      return '$base ($detail)';
    }
    return base;
  }

  Future<void> _onRetry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await _service.retryRegistration();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _openMicSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final showBar = _regState != SoftphoneRegState.idle ||
        _incoming != null ||
        _active != null;
    if (!showBar) {
      return const SizedBox.shrink();
    }

    // Registered with no call: minimal indicator only.
    if (_regState == SoftphoneRegState.registered &&
        _incoming == null &&
        _active == null) {
      return const SizedBox.shrink();
    }

    final loc = AppLocalizations.of(context);
    final isError = _regState == SoftphoneRegState.error;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 88,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.phone_in_talk,
                    color: _regState == SoftphoneRegState.registered
                        ? Colors.green
                        : (isError ? Colors.red : Colors.orange),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isError ? _errorMessage(loc) : 'Softphone — ${_statusLabel(loc)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (isError) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_errorKind == SoftphoneErrorKind.micDenied)
                      TextButton(
                        onPressed: _retrying ? null : _openMicSettings,
                        child: Text(loc?.translate('settings') ?? 'Settings'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _retrying ? null : _onRetry,
                      child: _retrying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(loc?.translate('retry') ?? 'Retry'),
                    ),
                  ],
                ),
              ],
              if (_incoming != null) ...[
                const SizedBox(height: 8),
                Text('Incoming: ${_incoming!.remote}'),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _service.answerIncoming(),
                        child: const Text('Answer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _service.rejectIncoming(),
                        child: const Text('Decline'),
                      ),
                    ),
                  ],
                ),
              ],
              if (_active != null) ...[
                const SizedBox(height: 8),
                Text('On call: ${_active!.remote}'),
                Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        _muted = !_muted;
                        await _service.setMuted(_muted);
                        setState(() {});
                      },
                      icon: Icon(_muted ? Icons.mic_off : Icons.mic),
                    ),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => _service.hangup(),
                        child: const Text('Hang up'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
