import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/whatsapp_access.dart';
import 'whatsapp_chat_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    bool allowed;
    try {
      final UserModel user = await ApiService().getCurrentUser();
      allowed = canAccessWhatsAppChats(user);
    } catch (_) {
      // Cannot prove access — fail closed rather than 403-looping.
      allowed = false;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _allowed = allowed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_allowed) return const WhatsAppAccessDeniedScreen();
    return widget.builder(context);
  }
}

/// Standalone "you do not have access" screen for WhatsApp Chats.
class WhatsAppAccessDeniedScreen extends StatelessWidget {
  const WhatsAppAccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    String t(String k) => localizations?.translate(k) ?? k;
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
                t('whatsappChatAccessDisabled'),
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
