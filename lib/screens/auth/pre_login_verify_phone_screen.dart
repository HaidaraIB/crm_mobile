import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/api_service.dart';

/// In-app phone OTP verification (owner pre-login), matching web `/verify-phone` flow.
class PreLoginVerifyPhoneScreen extends StatefulWidget {
  const PreLoginVerifyPhoneScreen({
    super.key,
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  @override
  State<PreLoginVerifyPhoneScreen> createState() => _PreLoginVerifyPhoneScreenState();
}

class _PreLoginVerifyPhoneScreenState extends State<PreLoginVerifyPhoneScreen> {
  static const _cooldownKey = 'mobile_prelogin_phone_resend_cd';
  static const int _cooldownSec = 60;

  final _codeCtrl = TextEditingController();
  final _newPhoneCtrl = TextEditingController();
  bool _showChange = false;
  bool _busy = false;
  bool _sendBusy = false;
  int _cd = 0;
  Timer? _tick;
  String? _channel;

  @override
  void dispose() {
    _tick?.cancel();
    _codeCtrl.dispose();
    _newPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_syncCooldownFromStorage());
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

  String _channelHint(AppLocalizations? loc) {
    if (_channel == 'twilio_sms') {
      return loc?.translate('verifyPhoneSmsHint') ?? '';
    }
    if (_channel == 'whatsapp') {
      return loc?.translate('verifyPhoneWhatsAppHint') ?? '';
    }
    return loc?.translate('preLoginVerifyPhoneHint') ?? '';
  }

  Future<void> _sendCode() async {
    if (_cd > 0 || _sendBusy) return;
    if (!mounted) return;
    setState(() => _sendBusy = true);
    final sentMsg =
        AppLocalizations.of(context)?.translate('preLoginPhoneCodeSent') ?? 'Verification code sent.';
    try {
      final data = await ApiService().preLoginPhoneSendOtp(
        username: widget.username,
        password: widget.password,
      );
      final ch = data['channel']?.toString();
      if (mounted) {
        setState(() {
          _channel = ch;
          _cd = _cooldownSec;
        });
        await _persistCooldown();
        _startTicker();
        if (!mounted) return;
        SnackbarHelper.showSuccess(context, sentMsg);
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _sendBusy = false);
    }
  }

  Future<void> _onVerify() async {
    final code = _codeCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
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
      await ApiService().preLoginPhoneVerifyOtp(
        username: widget.username,
        password: widget.password,
        code: code,
      );
      if (!mounted) return;
      final okMsg = AppLocalizations.of(context)?.translate('phoneVerifiedShort') ??
          'Phone verified. Return to login and sign in.';
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cooldownKey);
      if (!mounted) return;
      SnackbarHelper.showSuccess(context, okMsg);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onChangePhone() async {
    final raw = _newPhoneCtrl.text.trim();
    if (raw.length < 8) {
      SnackbarHelper.showError(
        context,
        AppLocalizations.of(context)?.translate('invalidPhone') ?? 'Invalid phone',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService().preLoginPhoneChange(
        username: widget.username,
        password: widget.password,
        newPhone: raw,
      );
      if (!mounted) return;
      setState(() {
        _codeCtrl.clear();
        _channel = null;
        _showChange = false;
        _newPhoneCtrl.clear();
        _cd = 0;
      });
      final updatedMsg = AppLocalizations.of(context)?.translate('preLoginPhoneUpdated') ??
          'Phone updated. Send a new code.';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.translate('preLoginVerifyPhoneTitle') ?? 'Verify your phone'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc?.translate('preLoginVerifyPhoneHint') ??
                    'Send a code, enter it below, then tap Verify.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_sendBusy || _cd > 0) ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _sendBusy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(loc?.translate('preLoginSendCodeButton') ?? 'Send verification code'),
              ),
              if (_channel != null && _channel!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _channelHint(loc),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: isRTL ? TextAlign.right : TextAlign.left,
                ),
              ],
              const SizedBox(height: 16),
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
                  onPressed: (_cd > 0 || _sendBusy || _busy) ? null : _sendCode,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: _sendBusy
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
                              ? (loc?.translate('preLoginResendCodeCountdown') ?? 'Resend code ({countdown}s)')
                                  .replaceAll('{countdown}', '$_cd')
                              : (loc?.translate('preLoginResendCode') ?? 'Resend code'),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                            decoration: TextDecoration.none,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
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
                    loc?.translate('preLoginChangePhoneLabel') ?? 'Change phone',
                    style: const TextStyle(decoration: TextDecoration.none),
                  ),
                ),
              ),
              if (_showChange) ...[
                TextField(
                  controller: _newPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: loc?.translate('preLoginNewPhoneLabel') ?? 'New phone number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _busy ? null : _onChangePhone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(loc?.translate('preLoginUpdatePhone') ?? 'Update phone'),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _busy ? null : _onVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(loc?.translate('verify') ?? 'Verify'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
