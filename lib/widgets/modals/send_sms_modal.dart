import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/api_service.dart';

class SendSMSModal extends StatefulWidget {
  final int leadId;
  final String phoneNumber;
  final VoidCallback? onSent;

  const SendSMSModal({
    super.key,
    required this.leadId,
    required this.phoneNumber,
    this.onSent,
  });

  @override
  State<SendSMSModal> createState() => _SendSMSModalState();
}

class _SendSMSModalState extends State<SendSMSModal> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openMessagingApp() async {
    final body = _messageController.text.trim();
    final encoded = body.isNotEmpty ? Uri.encodeComponent(body) : '';
    final uri = Uri.parse(
      'sms:${widget.phoneNumber}${encoded.isNotEmpty ? '?body=$encoded' : ''}',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!launched) {
        final loc = AppLocalizations.of(context);
        SnackbarHelper.showError(
          context,
          loc?.translate('couldNotOpenMessagingApp') ??
              'Could not open messaging app',
        );
      }
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      SnackbarHelper.showError(
        context,
        '${loc?.translate('couldNotOpenMessagingApp') ?? 'Could not open messaging app'}: $e',
      );
    }
  }

  Future<void> _sendViaCrm() async {
    final localizations = AppLocalizations.of(context);
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      SnackbarHelper.showError(
        context,
        localizations?.translate('smsMessageRequired') ?? 'Please enter a message',
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _apiService.sendLeadSMS(
        leadId: widget.leadId,
        phoneNumber: widget.phoneNumber,
        body: message,
      );

      if (!mounted) return;

      Navigator.pop(context);
      SnackbarHelper.showSuccess(
        context,
        localizations?.translate('smsSent') ?? 'SMS sent successfully',
      );
      widget.onSent?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      final String message = e is SmsException
          ? (localizations?.translate(e.errorKey) ?? e.fallbackMessage)
          : e.toString().replaceFirst('Exception: ', '');
      SnackbarHelper.showError(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                localizations?.translate('sendSms') ?? 'Send SMS',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localizations?.translate('to') ?? 'To',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                widget.phoneNumber,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      localizations?.translate('smsMessagePlaceholder') ??
                          'Type your message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isSending ? null : _openMessagingApp,
                icon: const Icon(Icons.open_in_new, size: 20),
                label: Text(
                  localizations?.translate('openInMessagingApp') ??
                      'Open in messaging app',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isSending ? null : _sendViaCrm,
                icon: _isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        size: 20,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                label: Text(
                  _isSending
                      ? (localizations?.translate('sending') ?? 'Sending...')
                      : (localizations?.translate('sendViaCrm') ??
                          'Send via CRM'),
                  style: TextStyle(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
