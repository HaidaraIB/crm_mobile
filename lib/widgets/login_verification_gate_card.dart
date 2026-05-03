import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_constants.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../screens/auth/pre_login_verify_email_screen.dart';
import '../screens/auth/pre_login_verify_phone_screen.dart';
import '../services/api_service.dart';

/// Shown when login or 2FA request fails with email/phone verification required (owner).
class LoginVerificationGateCard extends StatelessWidget {
  const LoginVerificationGateCard({
    super.key,
    required this.gate,
    this.onDismiss,
    this.preloginUsername,
    this.preloginPassword,
  });

  final LoginVerificationRequiredException gate;
  final VoidCallback? onDismiss;
  /// When set with [preloginPassword], "Verify now" opens in-app screens instead of the browser.
  final String? preloginUsername;
  final String? preloginPassword;

  bool get _canNavigateInApp {
    final u = preloginUsername?.trim() ?? '';
    final p = preloginPassword;
    return u.isNotEmpty && p != null && p.isNotEmpty;
  }

  Future<void> _openHref(BuildContext context, String href) async {
    final loc = AppLocalizations.of(context);
    final trimmed = href.trim();
    if (trimmed.isEmpty) return;

    final Uri uri;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      uri = Uri.parse(trimmed);
    } else {
      final base = AppConstants.webAppBaseUrl;
      final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      uri = Uri.parse('$base$path');
    }

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc?.translate('couldNotOpenLink') ??
                  'Could not open link. Copy the address from your browser.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc?.translate('couldNotOpenLink') ??
                  'Could not open link. Try again from a browser.',
            ),
          ),
        );
      }
    }
  }

  void _openVerifyEmail(BuildContext context, String href) {
    if (!_canNavigateInApp) {
      _openHref(context, href);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreLoginVerifyEmailScreen(
          username: preloginUsername!.trim(),
          password: preloginPassword!,
          verifyEmailHref: href,
        ),
      ),
    );
  }

  void _openVerifyPhone(BuildContext context, {required String href}) {
    if (!_canNavigateInApp) {
      _openHref(context, href);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreLoginVerifyPhoneScreen(
          username: preloginUsername!.trim(),
          password: preloginPassword!,
        ),
      ),
    );
  }

  bool get _hasDirectVerifyLinks {
    final e = gate.verifyEmailUrl?.trim() ?? '';
    final p = gate.verifyPhoneUrl?.trim() ?? '';
    return e.isNotEmpty || p.isNotEmpty;
  }

  bool get _showBrowserFootnote {
    if (_hasDirectVerifyLinks && _canNavigateInApp) return false;
    if (_hasDirectVerifyLinks && !_canNavigateInApp) return true;
    return gate.actions.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isRTL = loc?.isRTL ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.amber.shade800, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: _hasDirectVerifyLinks
                    ? Column(
                        crossAxisAlignment:
                            isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if ((gate.verifyEmailUrl ?? '').trim().isNotEmpty)
                            _VerifyLinkLine(
                              label: loc?.translate('loginVerificationEmailRequired') ??
                                  'Email verification required.',
                              linkLabel: loc?.translate('verifyNow') ?? 'Verify now',
                              onTap: () => _openVerifyEmail(context, gate.verifyEmailUrl!),
                              isRTL: isRTL,
                            ),
                          if ((gate.verifyEmailUrl ?? '').trim().isNotEmpty &&
                              (gate.verifyPhoneUrl ?? '').trim().isNotEmpty)
                            const SizedBox(height: 8),
                          if ((gate.verifyPhoneUrl ?? '').trim().isNotEmpty)
                            _VerifyLinkLine(
                              label: loc?.translate('loginVerificationPhoneRequired') ??
                                  'Phone number verification required.',
                              linkLabel: loc?.translate('verifyNow') ?? 'Verify now',
                              onTap: () => _openVerifyPhone(context, href: gate.verifyPhoneUrl!),
                              isRTL: isRTL,
                            ),
                        ],
                      )
                    : Text(
                        gate.message,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                          fontSize: 14,
                        ),
                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                      ),
              ),
              if (onDismiss != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.close, size: 20, color: Colors.amber.shade900),
                  onPressed: onDismiss,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
            ],
          ),
          if (!_hasDirectVerifyLinks) ...[
            if (gate.hint != null && gate.hint!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                gate.hint!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Colors.amber.shade900.withValues(alpha: 0.9),
                ),
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              ),
            ],
            if (gate.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                loc?.translate('loginVerificationNextSteps') ?? 'What you can do next',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: Colors.amber.shade900,
                ),
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
              ),
              const SizedBox(height: 6),
              ...gate.actions.map((a) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _openHref(context, a.href),
                        child: Text(
                          a.label.isNotEmpty ? a.label : a.href,
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (a.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            a.description,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.amber.shade900.withValues(alpha: 0.88),
                            ),
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
            if (gate.changeCredentialsNote != null &&
                gate.changeCredentialsNote!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.amber.withValues(alpha: 0.35)),
              const SizedBox(height: 8),
              Text(
                gate.changeCredentialsNote!,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.amber.shade900.withValues(alpha: 0.88),
                ),
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              ),
            ],
          ],
          if (_showBrowserFootnote) ...[
            const SizedBox(height: 8),
            Text(
              loc?.translate('loginVerificationOpensBrowser') ??
                  'Links open in your browser (web CRM).',
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber.shade900.withValues(alpha: 0.75),
                fontStyle: FontStyle.italic,
              ),
              textAlign: isRTL ? TextAlign.right : TextAlign.left,
            ),
          ],
        ],
      ),
    );
  }
}

class _VerifyLinkLine extends StatelessWidget {
  const _VerifyLinkLine({
    required this.label,
    required this.linkLabel,
    required this.onTap,
    required this.isRTL,
  });

  final String label;
  final String linkLabel;
  final VoidCallback onTap;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 14,
      height: 1.35,
      color: Colors.amber.shade900,
      fontWeight: FontWeight.w500,
    );
    final linkStyle = TextStyle(
      color: AppTheme.primaryColor,
      decoration: TextDecoration.none,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: isRTL ? WrapAlignment.end : WrapAlignment.start,
      spacing: 6,
      children: [
        Text(label, style: textStyle),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            child: Text(linkLabel, style: linkStyle),
          ),
        ),
      ],
    );
  }
}
