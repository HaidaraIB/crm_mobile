import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/api_service.dart';

/// In-app email verification (owner pre-login), matching web `/verify-email` flow.
class PreLoginVerifyEmailScreen extends StatefulWidget {
  const PreLoginVerifyEmailScreen({
    super.key,
    required this.username,
    required this.password,
    required this.verifyEmailHref,
  });

  final String username;
  final String password;
  final String verifyEmailHref;

  @override
  State<PreLoginVerifyEmailScreen> createState() => _PreLoginVerifyEmailScreenState();
}

class _PreLoginVerifyEmailScreenState extends State<PreLoginVerifyEmailScreen> {
  static const _cooldownKey = 'mobile_prelogin_email_resend_cd';
  static const int _cooldownSec = 60;

  final _codeCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  late String? _email;
  bool _showChange = false;
  bool _busy = false;
  bool _resendBusy = false;
  int _cd = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _email = _parseEmail(widget.verifyEmailHref);
    unawaited(_syncCooldownFromStorage());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _codeCtrl.dispose();
    _newEmailCtrl.dispose();
    super.dispose();
  }

  String? _parseEmail(String href) {
    try {
      final h = href.trim();
      final uri = h.startsWith('http://') || h.startsWith('https://')
          ? Uri.parse(h)
          : Uri.parse('https://placeholder.invalid${h.startsWith('/') ? h : '/$h'}');
      final e = uri.queryParameters['email'];
      if (e == null || e.isEmpty) return null;
      return Uri.decodeComponent(e);
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncCooldownFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cooldownKey);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['u']?.toString() != widget.username) {
        await prefs.remove(_cooldownKey);
        return;
      }
      final ts = m['t'] as int? ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - ts;
      final left = _cooldownSec - (elapsed ~/ 1000);
      if (left > 0 && mounted) setState(() => _cd = left);
    } catch (_) {
      await prefs.remove(_cooldownKey);
    }
    _startTicker();
  }

  void _startTicker() {
    _tick?.cancel();
    if (_cd <= 0) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (_cd <= 1) {
        _tick?.cancel();
        setState(() => _cd = 0);
        final p = await SharedPreferences.getInstance();
        await p.remove(_cooldownKey);
        return;
      }
      setState(() => _cd--);
    });
  }

  Future<void> _persistCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cooldownKey,
      jsonEncode({'u': widget.username, 't': DateTime.now().millisecondsSinceEpoch}),
    );
  }

  Future<void> _onResend() async {
    if (_cd > 0 || _resendBusy) return;
    if (!mounted) return;
    setState(() => _resendBusy = true);
    final loc = AppLocalizations.of(context);
    final sentMsg = loc?.translate('preLoginEmailResent') ?? 'Verification email sent.';
    try {
      await ApiService().preLoginEmailResend(
        username: widget.username,
        password: widget.password,
      );
      if (!mounted) return;
      setState(() => _cd = _cooldownSec);
      await _persistCooldown();
      _startTicker();
      if (mounted) {
        SnackbarHelper.showSuccess(context, sentMsg);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _resendBusy = false);
    }
  }

  Future<void> _onVerify() async {
    final email = _email;
    if (email == null || email.isEmpty) return;
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      SnackbarHelper.showError(
        context,
        AppLocalizations.of(context)?.translate('pleaseEnter2FACode') ??
            'Please enter the verification code.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService().verifyEmail(email: email, code: code);
      if (!mounted) return;
      SnackbarHelper.showSuccess(
        context,
        AppLocalizations.of(context)?.translate('emailVerifiedShort') ??
            'Email verified. Return to login and sign in.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onChangeEmail() async {
    final next = _newEmailCtrl.text.trim().toLowerCase();
    if (next.isEmpty || !next.contains('@')) {
      SnackbarHelper.showError(
        context,
        AppLocalizations.of(context)?.translate('invalidEmail') ?? 'Invalid email',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService().preLoginEmailChange(
        username: widget.username,
        password: widget.password,
        newEmail: next,
      );
      if (!mounted) return;
      setState(() {
        _email = next;
        _codeCtrl.clear();
        _showChange = false;
        _newEmailCtrl.clear();
        _cd = 0;
      });
      final updatedMsg = AppLocalizations.of(context)?.translate('preLoginEmailUpdated') ??
          'Email updated. Check your inbox.';
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cooldownKey);
      if (!mounted) return;
      SnackbarHelper.showSuccess(context, updatedMsg);
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isRTL = loc?.isRTL ?? false;

    if (_email == null || _email!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(loc?.translate('preLoginVerifyEmailTitle') ?? 'Verify your email')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              loc?.translate('preLoginInvalidVerifyLink') ?? 'Invalid verification link.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.translate('preLoginVerifyEmailTitle') ?? 'Verify your email'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc?.translate('preLoginVerifyEmailHint') ??
                    'Enter the code from your verification email, then tap Verify.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _showChange = !_showChange),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Align(
                  alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    loc?.translate('preLoginChangeEmailLabel') ?? 'Change email',
                    style: const TextStyle(decoration: TextDecoration.none),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_showChange) ...[
                TextField(
                  controller: _newEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: loc?.translate('preLoginNewEmailLabel') ?? 'New email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _busy ? null : _onChangeEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(loc?.translate('preLoginUpdateEmailSend') ?? 'Update email & send code'),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                _email!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.none,
                    ),
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: loc?.translate('verificationCode') ?? 'Verification code',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                child: TextButton(
                  onPressed: (_cd > 0 || _resendBusy) ? null : _onResend,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: _resendBusy
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : Text(
                          _cd > 0
                              ? (loc?.translate('preLoginResendEmailCountdown') ?? 'Resend email ({countdown}s)')
                                  .replaceAll('{countdown}', '$_cd')
                              : (loc?.translate('preLoginResendEmail') ?? 'Resend email'),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                            decoration: TextDecoration.none,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : _onVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _busy
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(loc?.translate('verify') ?? 'Verify'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
