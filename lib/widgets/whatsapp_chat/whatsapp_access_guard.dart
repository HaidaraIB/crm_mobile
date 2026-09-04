import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/whatsapp_chat_unread_holder.dart';
import '../../utils/whatsapp_access.dart';
import 'whatsapp_chat_theme.dart';

/// Hides WhatsApp Chats nav (app bar / drawer) when the user cannot use it.
///
/// Role/toggle via [canAccessWhatsAppChats]; company plan/policy via the digest
/// (`whatsapp_unread` omitted). Grey-out is worse than hide: the green logo
/// reads as available, and tapping it used to open a dead Retry screen.
class WhatsAppChatsEntryGate extends StatelessWidget {
  const WhatsAppChatsEntryGate({
    super.key,
    required this.user,
    required this.child,
  });

  final UserModel? user;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!canAccessWhatsAppChats(user)) return const SizedBox.shrink();
    return ValueListenableBuilder<bool?>(
      valueListenable: WhatsAppChatUnreadHolder.chatsAvailable,
      builder: (context, available, _) {
        if (available == false) return const SizedBox.shrink();
        return child;
      },
    );
  }
}

/// Denies WhatsApp Chats to users without access before any request is made.
///
/// Notification deep links (`/whatsapp-chat`, `/whatsapp-chat/thread`) are
/// reachable regardless of role, so without this a disabled user lands on a
/// screen where every call 403s. The web dashboard denies the same way at page
/// level in `pages/ChatsPage.tsx`.
class WhatsAppAccessGuard extends StatefulWidget {
  const WhatsAppAccessGuard({super.key, required this.builder});

  /// Built only once access is confirmed.
  final WidgetBuilder builder;

  @override
  State<WhatsAppAccessGuard> createState() => _WhatsAppAccessGuardState();
}

class _WhatsAppAccessGuardState extends State<WhatsAppAccessGuard> {
  bool _loading = true;
  bool _allowed = false;
  String _messageKey = 'whatsappChatAccessDisabled';

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    if (WhatsAppChatUnreadHolder.chatsAvailable.value == false) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _allowed = false;
        _messageKey = 'whatsappChatsUnavailable';
      });
      return;
    }
    bool allowed;
    String messageKey = 'whatsappChatAccessDisabled';
    try {
      final UserModel user = await ApiService().getCurrentUser();
      allowed = canAccessWhatsAppChats(user);
      if (allowed && WhatsAppChatUnreadHolder.chatsAvailable.value == false) {
        allowed = false;
        messageKey = 'whatsappChatsUnavailable';
      }
    } catch (_) {
      // Cannot prove access — fail closed rather than 403-looping.
      allowed = false;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _allowed = allowed;
      _messageKey = messageKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_allowed) {
      return WhatsAppAccessDeniedScreen(messageKey: _messageKey);
    }
    return widget.builder(context);
  }
}

/// Standalone "you do not have access" screen for WhatsApp Chats.
class WhatsAppAccessDeniedScreen extends StatelessWidget {
  const WhatsAppAccessDeniedScreen({
    super.key,
    this.messageKey = 'whatsappChatAccessDisabled',
  });

  final String messageKey;

  @override
  Widget build(BuildContext context) {
    final localizations =
        AppLocalizations.of(context) ?? AppLocalizations(const Locale('en'));
    String t(String k) => localizations.translate(k);
    final colors = WhatsAppChatColors.of(context);

    return Scaffold(
      backgroundColor: colors.threadBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBg,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(t('whatsappChats')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: colors.metaIn),
              const SizedBox(height: 12),
              Text(
                t(messageKey),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.bubbleInFg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
