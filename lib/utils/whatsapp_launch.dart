import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization/app_localizations.dart';
import '../core/utils/snackbar_helper.dart';
import '../models/user_model.dart';
import '../screens/whatsapp_chat/whatsapp_chat_thread_screen.dart';
import '../services/api_service.dart';
import 'whatsapp_access.dart';

/// Digits-only form wa.me expects (drops the leading `+` and any separators).
String toWaDigits(String? phone) =>
    (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');

/// The single decision point behind every WhatsApp button on a lead's phone number.
///
/// Connected tenant + a user allowed to use Chats → open the conversation in the
/// CRM, on the exact number that was tapped. Anything else (no integration, no
/// permission, no lead) → hand off to the official WhatsApp via wa.me, so the
/// button always does something useful. Mirrors `useWhatsAppLeadAction` in
/// CRM-project (hooks/useWhatsAppLeadAction.ts).
Future<void> openWhatsAppForLead(
  BuildContext context, {
  required String phoneNumber,
  int? clientId,
  String? clientName,
  UserModel? currentUser,
}) async {
  final digits = toWaDigits(phoneNumber);
  if (digits.isEmpty) {
    final localizations = AppLocalizations.of(context);
    SnackbarHelper.showError(
      context,
      localizations?.translate('invalidPhoneNumber') ?? 'Invalid phone number',
    );
    return;
  }

  final phone = phoneNumber.trim();
  if (clientId != null && canAccessWhatsAppChats(currentUser)) {
    // Tenant-level connectivity — without a connected account the in-app thread
    // cannot send, so fall through to wa.me instead of stranding the user there.
    final status = await ApiService().getWhatsAppAccountStatus();
    if (!context.mounted) return;
    if (status?.connected == true) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'WhatsAppChatThreadScreen'),
          builder: (_) => WhatsAppChatThreadScreen(
            clientId: clientId,
            clientName: (clientName ?? '').trim().isNotEmpty
                ? clientName!.trim()
                : phone,
            phoneNumber: phone,
          ),
        ),
      );
      return;
    }
  }

  await _launchWaMe(context, digits);
}

Future<void> _launchWaMe(BuildContext context, String digits) async {
  var launched = false;
  try {
    launched = await launchUrl(
      Uri.parse('https://wa.me/$digits'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    launched = false;
  }
  if (launched || !context.mounted) return;
  final localizations = AppLocalizations.of(context);
  SnackbarHelper.showError(
    context,
    localizations?.translate('couldNotOpenWhatsApp') ?? 'Could not open WhatsApp',
  );
}
