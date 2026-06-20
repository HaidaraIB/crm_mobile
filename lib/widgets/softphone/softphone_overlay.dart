import 'package:flutter/material.dart';

import '../../services/softphone_service.dart';

class SoftphoneOverlay extends StatefulWidget {
  const SoftphoneOverlay({super.key});

  @override
  State<SoftphoneOverlay> createState() => _SoftphoneOverlayState();
}

class _SoftphoneOverlayState extends State<SoftphoneOverlay> {
  final _service = SoftphoneService.instance;
  SoftphoneRegState _regState = SoftphoneRegState.idle;
  SoftphoneCallInfo? _incoming;
  SoftphoneCallInfo? _active;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _service.registrationState.listen((s) {
      if (mounted) setState(() => _regState = s);
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

  @override
  Widget build(BuildContext context) {
    if (_regState == SoftphoneRegState.idle && _incoming == null && _active == null) {
      return const SizedBox.shrink();
    }

    final status = switch (_regState) {
      SoftphoneRegState.registered => 'Registered',
      SoftphoneRegState.connecting => 'Connecting…',
      SoftphoneRegState.error => 'Error',
      SoftphoneRegState.idle => 'Offline',
    };

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
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text('Softphone — $status', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
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
                        child: const Text('Reject'),
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
