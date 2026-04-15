import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/snackbar_helper.dart';
import 'splash_screen.dart';

/// Full-screen gate: update from store or retry policy fetch (fail-closed).
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({
    super.key,
    required this.couldNotVerify,
    required this.storeUrl,
  });

  final bool couldNotVerify;
  final String storeUrl;

  Future<void> _openStore(BuildContext context) async {
    final url = storeUrl.trim();
    if (url.isEmpty) {
      if (!context.mounted) return;
      final msg = AppLocalizations.of(context)?.translate('forceUpdateStoreUrlMissing') ??
          'Store link is not set. Add the Play Store or App Store URL in system settings, then try again.';
      SnackbarHelper.showInfo(context, msg, clearSnackBars: true);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = couldNotVerify
        ? (loc?.translate('versionCheckFailedTitle') ?? 'Cannot verify app version')
        : (loc?.translate('updateRequiredTitle') ?? 'Update required');
    final body = couldNotVerify
        ? (loc?.translate('versionCheckFailedMessage') ??
            'Check your connection and try again.')
        : (loc?.translate('updateRequiredMessage') ??
            'Install the latest version from the store.');

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
                  couldNotVerify ? Icons.cloud_off : Icons.system_update,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Spacer(),
                if (!couldNotVerify)
                  FilledButton.icon(
                    onPressed: () => _openStore(context),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(loc?.translate('updateFromStore') ?? 'Update from store'),
                  ),
                if (!couldNotVerify) const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(loc?.translate('retry') ?? 'Retry'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
