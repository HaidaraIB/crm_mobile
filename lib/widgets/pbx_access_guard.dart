import 'package:flutter/material.dart';

import '../models/pbx_call_model.dart';
import '../services/pbx_call_launcher.dart';
import 'permission_guard.dart';

/// Prevents direct routes and deep links from building PBX screens unless the
/// shared pilot policy and `/telephony/me/` discovery both allow the feature.
class PbxAccessGuard extends StatefulWidget {
  const PbxAccessGuard({
    super.key,
    required this.builder,
    this.loadMe,
    this.deniedBuilder,
  });

  final WidgetBuilder builder;

  /// Optional test seam; production uses [PbxCallLauncher.me].
  final Future<PbxMe?> Function()? loadMe;

  final WidgetBuilder? deniedBuilder;

  @override
  State<PbxAccessGuard> createState() => _PbxAccessGuardState();
}

class _PbxAccessGuardState extends State<PbxAccessGuard> {
  bool _loading = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    PbxMe? me;
    try {
      me = await (widget.loadMe ?? PbxCallLauncher.me)();
    } catch (_) {
      me = null;
    }
    if (!mounted) return;
    setState(() {
      _allowed = PbxCallLauncher.canAccessCallHistory(me);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_allowed) {
      return widget.deniedBuilder?.call(context) ?? const AccessDeniedScreen();
    }
    return widget.builder(context);
  }
}
