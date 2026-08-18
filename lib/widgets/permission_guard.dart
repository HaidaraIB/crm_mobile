import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

/// Denies a screen to users who don't pass [allowed] before any request is made.
///
/// Buttons/nav entries that lead to a screen are hidden per-role, but any
/// `Navigator.push` to that screen bypasses those checks unless the screen
/// itself is guarded too — same reasoning as `WhatsAppAccessGuard`, generalized
/// so every screen that needs entry-level gating doesn't need its own copy.
class RoleAccessGuard extends StatefulWidget {
  const RoleAccessGuard({
    super.key,
    required this.allowed,
    required this.builder,
    this.deniedBuilder,
  });

  /// Evaluated against the current user once loaded.
  final bool Function(UserModel user) allowed;

  /// Built only once access is confirmed.
  final WidgetBuilder builder;

  /// Built when access is denied. Defaults to [AccessDeniedScreen].
  final WidgetBuilder? deniedBuilder;

  @override
  State<RoleAccessGuard> createState() => _RoleAccessGuardState();
}

class _RoleAccessGuardState extends State<RoleAccessGuard> {
  bool _loading = true;
  bool _allowedResult = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    bool result;
    try {
      final UserModel user = await ApiService().getCurrentUser();
      result = widget.allowed(user);
    } catch (_) {
      // Cannot prove access — fail closed rather than showing the real screen.
      result = false;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _allowedResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_allowedResult) {
      return widget.deniedBuilder?.call(context) ?? const AccessDeniedScreen();
    }
    return widget.builder(context);
  }
}

/// Generic "you do not have access" screen for entry points guarded by
/// [RoleAccessGuard] without a feature-specific denial screen.
class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    String t(String k) => localizations?.translate(k) ?? k;

    return Scaffold(
      appBar: AppBar(title: Text(t('accessDeniedTitle'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(t('accessDeniedMessage'), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
