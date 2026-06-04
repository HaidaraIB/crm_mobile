import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/maintenance_gate.dart';
import 'splash_screen.dart';

/// Full-screen gate while platform maintenance mode is active.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({
    super.key,
    required this.message,
  });

  final String message;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _isChecking = false;

  static const _defaultMessageEn =
      'The system is under maintenance. Please try again later.';

  String _localizedBody(AppLocalizations? loc) {
    final fallback =
        loc?.translate('maintenanceModeMessage') ?? _defaultMessageEn;
    final trimmed = widget.message.trim();
    if (trimmed.isEmpty || trimmed == _defaultMessageEn) {
      return fallback;
    }
    return trimmed;
  }

  Future<void> _retry() async {
    if (_isChecking) return;
    final loc = AppLocalizations.of(context);
    setState(() => _isChecking = true);
    final gate = await MaintenanceGate.evaluate();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (gate.outcome == MaintenanceGateOutcome.allowed) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      );
      return;
    }

    final stillActive = loc?.translate('maintenanceModeStillActive') ??
        'The system is still under maintenance. Please try again later.';
    SnackbarHelper.showWarning(context, stillActive, clearSnackBars: true);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title =
        loc?.translate('maintenanceModeTitle') ?? 'System under maintenance';
    final body = _localizedBody(loc);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Icon(
                  Icons.construction,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isChecking ? null : _retry,
                  icon: _isChecking
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _isChecking
                        ? (loc?.translate('maintenanceModeChecking') ??
                            'Checking system status…')
                        : (loc?.translate('maintenanceModeRetry') ?? 'Try again'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
