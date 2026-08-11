import 'package:equatable/equatable.dart';

import '../../../models/lead_whatsapp_message_model.dart';
import '../../../models/whatsapp_conversation_model.dart';
import '../../../models/whatsapp_template_model.dart';

class WhatsAppChatThreadState extends Equatable {
  const WhatsAppChatThreadState({
    required this.messages,
    required this.loading,
    required this.sending,
    required this.loadError,
    required this.sendError,
    required this.sessionWindow,
    required this.newMessagesBeforeApiId,
    required this.initialScrollDone,
    required this.templates,
    required this.templatesLoading,
    required this.templatesExpanded,
    required this.connectedPhoneNumberId,
    required this.composerAlert,
    required this.playOpenThreadSound,
  });

  const WhatsAppChatThreadState.initial()
      : messages = const [],
        loading = true,
        sending = false,
        loadError = null,
        sendError = null,
        sessionWindow = null,
        newMessagesBeforeApiId = null,
        initialScrollDone = false,
        templates = const [],
        templatesLoading = false,
        templatesExpanded = false,
        connectedPhoneNumberId = null,
        composerAlert = null,
        playOpenThreadSound = false;

  /// Oldest-first for display.
  final List<LeadWhatsAppMessageModel> messages;
  final bool loading;
  final bool sending;
  final String? loadError;
  final String? sendError;
  final WhatsAppSessionWindow? sessionWindow;
  /// Captured once before first mark-read.
  final int? newMessagesBeforeApiId;
  final bool initialScrollDone;
  final List<WhatsAppTemplateModel> templates;
  final bool templatesLoading;
  final bool templatesExpanded;
  final String? connectedPhoneNumberId;
  /// Sticky composer warning (session / display name / reconnect).
  final String? composerAlert;
  /// One-shot flag for inbound sound while thread is open.
  final bool playOpenThreadSound;

  WhatsAppChatThreadState copyWith({
    List<LeadWhatsAppMessageModel>? messages,
    bool? loading,
    bool? sending,
    String? loadError,
    bool clearLoadError = false,
    String? sendError,
    bool clearSendError = false,
    WhatsAppSessionWindow? sessionWindow,
    int? newMessagesBeforeApiId,
    bool clearNewMessagesBefore = false,
    bool? initialScrollDone,
    List<WhatsAppTemplateModel>? templates,
    bool? templatesLoading,
    bool? templatesExpanded,
    String? connectedPhoneNumberId,
    String? composerAlert,
    bool clearComposerAlert = false,
    bool? playOpenThreadSound,
  }) {
    return WhatsAppChatThreadState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      sendError: clearSendError ? null : (sendError ?? this.sendError),
      sessionWindow: sessionWindow ?? this.sessionWindow,
      newMessagesBeforeApiId: clearNewMessagesBefore
          ? null
          : (newMessagesBeforeApiId ?? this.newMessagesBeforeApiId),
      initialScrollDone: initialScrollDone ?? this.initialScrollDone,
      templates: templates ?? this.templates,
      templatesLoading: templatesLoading ?? this.templatesLoading,
      templatesExpanded: templatesExpanded ?? this.templatesExpanded,
      connectedPhoneNumberId: connectedPhoneNumberId ?? this.connectedPhoneNumberId,
      composerAlert: clearComposerAlert ? null : (composerAlert ?? this.composerAlert),
      playOpenThreadSound: playOpenThreadSound ?? this.playOpenThreadSound,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        loading,
        sending,
        loadError,
        sendError,
        sessionWindow,
        newMessagesBeforeApiId,
        initialScrollDone,
        templates,
        templatesLoading,
        templatesExpanded,
        connectedPhoneNumberId,
        composerAlert,
        playOpenThreadSound,
      ];
}
