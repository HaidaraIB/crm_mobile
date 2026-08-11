import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/lead_whatsapp_message_model.dart';
import '../../../models/whatsapp_conversation_model.dart';
import '../../../utils/whatsapp_thread_items.dart';
import '../whatsapp_chat_repository.dart';
import 'whatsapp_chat_thread_state.dart';

class WhatsAppChatThreadCubit extends Cubit<WhatsAppChatThreadState> {
  WhatsAppChatThreadCubit({
    required WhatsAppChatRepository repository,
    this.clientId,
    required this.phoneNumber,
    bool Function()? isForeground,
  })  : _repository = repository,
        _isForeground = isForeground ?? (() => true),
        super(const WhatsAppChatThreadState.initial());

  final WhatsAppChatRepository _repository;
  final int? clientId;
  final String phoneNumber;
  final bool Function() _isForeground;
  Timer? _timer;
  int _localIdSeq = -1;
  DateTime? _lastKnownInboundAt;
  bool _hydrated = false;
  bool _markReadOnce = false;
  bool _templatesFetched = false;

  Future<void> bootstrap() async {
    if (isClosed) return;
    emit(state.copyWith(loading: true));
    try {
      final results = await Future.wait([
        _repository.getMessages(
          clientId: clientId,
          phone: clientId == null ? phoneNumber : null,
        ),
        _repository.getSessionWindow(
          clientId: clientId,
          phone: clientId == null ? phoneNumber : null,
        ),
      ]);
      if (isClosed) return;

      final newestFirst = results[0] as List<LeadWhatsAppMessageModel>;
      final apiOldest = newestFirst.reversed.toList();
      final sessionRaw = results[1] as WhatsAppSessionWindow;
      final session = clientId == null
          ? const WhatsAppSessionWindow(inSession: true, hoursRemaining: 24)
          : sessionRaw;

      DateTime? latestInbound;
      for (final m in apiOldest) {
        if (m.isInbound &&
            (latestInbound == null || m.createdAt.isAfter(latestInbound))) {
          latestInbound = m.createdAt;
        }
      }
      _lastKnownInboundAt = latestInbound;
      _hydrated = true;

      WhatsAppSessionWindow window = session;
      if (deriveSessionOpenFromMessages(apiOldest)) {
        final hours = deriveHoursRemainingFromMessages(apiOldest);
        window = WhatsAppSessionWindow(
          inSession: true,
          lastInboundAt: latestInbound,
          hoursRemaining: hours ?? window.hoursRemaining,
          sessionExpiresAt: window.sessionExpiresAt,
        );
      }

      emit(
        state.copyWith(
          messages: apiOldest,
          loading: false,
          clearLoadError: true,
          newMessagesBeforeApiId: firstUnreadInboundId(apiOldest),
          sessionWindow: window,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, loadError: e.toString()));
    }

    if (isClosed) return;
    if (!_markReadOnce) {
      _markReadOnce = true;
      unawaited(markRead());
    }
    unawaited(_loadConnectedPhoneNumberId());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!isClosed && _isForeground()) {
        unawaited(refresh(silent: true));
      }
    });
  }

  void setForeground(bool value) {
    // Hook for WidgetsBindingObserver; poller checks _isForeground.
    if (value && !isClosed) unawaited(refresh(silent: true));
  }

  Future<void> refresh({bool silent = false}) async {
    if (isClosed) return;
    if (!silent) {
      emit(state.copyWith(loading: true));
    }
    try {
      final newestFirst = await _repository.getMessages(
        clientId: clientId,
        phone: clientId == null ? phoneNumber : null,
      );
      if (isClosed) return;
      final apiOldest = newestFirst.reversed.toList();

      // Keep optimistic sending/failed rows that aren't on the server yet.
      final optimistic = state.messages
          .where((m) => m.isOptimistic && (m.isSending || m.isFailed))
          .toList();

      final merged = <LeadWhatsAppMessageModel>[...apiOldest];
      for (final o in optimistic) {
        final already = apiOldest.any(
          (a) =>
              a.body == o.body &&
              a.direction == o.direction &&
              a.createdAt.difference(o.createdAt).abs() < const Duration(seconds: 90),
        );
        if (!already) merged.add(o);
      }
      merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      int? newBefore = state.newMessagesBeforeApiId;
      final wasHydrated = _hydrated;
      if (!_hydrated) {
        newBefore = firstUnreadInboundId(apiOldest);
        _hydrated = true;
      }

      DateTime? latestInbound;
      for (final m in merged) {
        if (m.isInbound && (latestInbound == null || m.createdAt.isAfter(latestInbound))) {
          latestInbound = m.createdAt;
        }
      }

      var playSound = false;
      if (wasHydrated &&
          _lastKnownInboundAt != null &&
          latestInbound != null &&
          latestInbound.isAfter(_lastKnownInboundAt!)) {
        playSound = silent;
        unawaited(_loadSessionWindow());
        unawaited(markRead());
      }
      if (_lastKnownInboundAt == null ||
          (latestInbound != null && latestInbound.isAfter(_lastKnownInboundAt!))) {
        _lastKnownInboundAt = latestInbound;
      }

      // Dual session: prefer API window, but open if messages say so.
      WhatsAppSessionWindow? window = state.sessionWindow;
      if (deriveSessionOpenFromMessages(merged)) {
        final hours = deriveHoursRemainingFromMessages(merged);
        window = WhatsAppSessionWindow(
          inSession: true,
          lastInboundAt: latestInbound,
          hoursRemaining: hours ?? window?.hoursRemaining,
          sessionExpiresAt: window?.sessionExpiresAt,
        );
      }

      if (isClosed) return;
      emit(
        state.copyWith(
          messages: merged,
          loading: false,
          clearLoadError: true,
          newMessagesBeforeApiId: newBefore,
          sessionWindow: window,
          playOpenThreadSound: playSound,
        ),
      );
      if (playSound && !isClosed) {
        // clear one-shot after emit so listeners can react once
        emit(state.copyWith(playOpenThreadSound: false));
      }
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          loadError: silent ? state.loadError : e.toString(),
        ),
      );
    }
  }

  Future<void> _loadSessionWindow() async {
    try {
      final window = await _repository.getSessionWindow(
        clientId: clientId,
        phone: clientId == null ? phoneNumber : null,
      );
      if (isClosed) return;
      // Manual (no client id) — do not block free text in UI (web parity).
      final effective = clientId == null
          ? const WhatsAppSessionWindow(inSession: true, hoursRemaining: 24)
          : window;
      emit(state.copyWith(sessionWindow: effective));
    } catch (_) {}
  }

  /// Lazy-load approved templates (only when the user opens the picker).
  Future<void> ensureTemplatesLoaded({bool force = false}) async {
    if (isClosed) return;
    if (!force && (_templatesFetched || state.templatesLoading)) return;
    emit(state.copyWith(templatesLoading: true));
    try {
      final list = await _repository.getApprovedTemplates();
      if (isClosed) return;
      _templatesFetched = true;
      emit(state.copyWith(templates: list, templatesLoading: false));
    } catch (_) {
      if (isClosed) return;
      // Allow retry on next open if the request failed.
      emit(state.copyWith(templatesLoading: false));
    }
  }

  Future<void> _loadConnectedPhoneNumberId() async {
    try {
      final id = await _repository.getConnectedPhoneNumberId();
      if (isClosed) return;
      if (id != null) emit(state.copyWith(connectedPhoneNumberId: id));
    } catch (_) {}
  }

  void setTemplatesExpanded(bool value) {
    if (isClosed) return;
    emit(state.copyWith(templatesExpanded: value));
  }

  void clearComposerAlert() {
    if (isClosed) return;
    emit(state.copyWith(clearComposerAlert: true));
  }

  void markInitialScrollDone() {
    if (isClosed) return;
    if (!state.initialScrollDone) {
      emit(state.copyWith(initialScrollDone: true));
    }
  }

  Future<void> markRead() async {
    try {
      await _repository.markConversationRead(
        clientId: clientId,
        phone: clientId == null ? phoneNumber : null,
      );
    } catch (_) {}
  }

  int _nextLocalId() => _localIdSeq--;

  void _applyComposerError(Object e) {
    if (isClosed) return;
    final msg = e.toString();
    String? alert;
    if (msg.contains('131047') || msg.contains('outside_session')) {
      alert = 'whatsappOutsideSessionUseTemplate';
    } else if (msg.contains('131037') || msg.contains('display_name')) {
      alert = 'whatsapp_display_name_not_approved';
    } else if (msg.contains('no_connected') || msg.contains('reconnect')) {
      alert = 'whatsappReconnectRequired';
    }
    emit(
      state.copyWith(
        sending: false,
        sendError: msg,
        composerAlert: alert,
      ),
    );
  }

  Future<bool> sendText(String message) async {
    if (message.trim().isEmpty || isClosed) return false;
    final localId = _nextLocalId();
    final optimistic = LeadWhatsAppMessageModel.optimisticText(
      localId: localId,
      clientId: clientId ?? 0,
      phone: phoneNumber,
      body: message.trim(),
    );
    emit(
      state.copyWith(
        messages: [...state.messages, optimistic],
        sending: true,
        clearSendError: true,
      ),
    );
    try {
      await _repository.sendMessage(
        to: phoneNumber,
        message: message.trim(),
        clientId: clientId,
      );
      if (isClosed) return false;
      emit(state.copyWith(sending: false));
      await refresh(silent: true);
      return true;
    } catch (e) {
      _failOptimistic(localId, e);
      return false;
    }
  }

  Future<bool> sendMedia(
    String filePath, {
    String? caption,
    bool isVoiceNote = false,
    String? kind,
  }) async {
    if (isClosed) return false;
    final localId = _nextLocalId();
    final optimistic = LeadWhatsAppMessageModel.optimisticMedia(
      localId: localId,
      clientId: clientId ?? 0,
      phone: phoneNumber,
      filePath: filePath,
      caption: caption,
      kind: kind ?? (isVoiceNote ? 'audio' : 'image'),
      isVoiceNote: isVoiceNote,
    );
    emit(
      state.copyWith(
        messages: [...state.messages, optimistic],
        sending: true,
        clearSendError: true,
      ),
    );
    try {
      await _repository.sendMedia(
        to: phoneNumber,
        filePath: filePath,
        clientId: clientId,
        caption: caption,
        isVoiceNote: isVoiceNote,
      );
      if (isClosed) return false;
      emit(state.copyWith(sending: false));
      await refresh(silent: true);
      return true;
    } catch (e) {
      _failOptimistic(localId, e);
      return false;
    }
  }

  Future<bool> sendLocation({
    required double latitude,
    required double longitude,
    String? name,
    String? address,
  }) async {
    if (isClosed) return false;
    final localId = _nextLocalId();
    final optimistic = LeadWhatsAppMessageModel.optimisticLocation(
      localId: localId,
      clientId: clientId ?? 0,
      phone: phoneNumber,
      latitude: latitude,
      longitude: longitude,
      name: name,
      address: address,
    );
    emit(
      state.copyWith(
        messages: [...state.messages, optimistic],
        sending: true,
        clearSendError: true,
      ),
    );
    try {
      await _repository.sendLocation(
        to: phoneNumber,
        latitude: latitude,
        longitude: longitude,
        clientId: clientId,
        name: name,
        address: address,
      );
      if (isClosed) return false;
      emit(state.copyWith(sending: false));
      await refresh(silent: true);
      return true;
    } catch (e) {
      _failOptimistic(localId, e);
      return false;
    }
  }

  Future<bool> sendTemplate(int templateId, {List<String>? bodyParameters}) async {
    if (isClosed) return false;
    emit(state.copyWith(sending: true, clearSendError: true));
    try {
      await _repository.sendTemplate(
        to: phoneNumber,
        templateId: templateId,
        clientId: clientId,
        bodyParameters: bodyParameters,
      );
      if (isClosed) return false;
      emit(state.copyWith(sending: false));
      await refresh(silent: true);
      await _loadSessionWindow();
      return true;
    } catch (e) {
      _applyComposerError(e);
      return false;
    }
  }

  void _failOptimistic(int localId, Object e) {
    if (isClosed) return;
    final updated = state.messages
        .map(
          (m) => m.id == localId
              ? m.copyWith(
                  localStatus: 'failed',
                  deliveryStatus: 'failed',
                  deliveryError: e.toString(),
                )
              : m,
        )
        .toList();
    _applyComposerError(e);
    if (isClosed) return;
    emit(state.copyWith(messages: updated, sending: false));
  }

  Future<void> resendFailed(LeadWhatsAppMessageModel msg) async {
    if (!msg.isFailed || isClosed) return;
    // Remove failed bubble then re-send.
    emit(state.copyWith(messages: state.messages.where((m) => m.id != msg.id).toList()));
    if (msg.isLocation && msg.locationLatitude != null && msg.locationLongitude != null) {
      await sendLocation(
        latitude: msg.locationLatitude!,
        longitude: msg.locationLongitude!,
        name: msg.locationName,
        address: msg.locationAddress,
      );
      return;
    }
    if (msg.localFilePath != null) {
      await sendMedia(
        msg.localFilePath!,
        caption: msg.localCaption ?? msg.body,
        isVoiceNote: msg.isVoiceNote,
        kind: msg.attachmentKind,
      );
      return;
    }
    await sendText(msg.body);
  }

  Future<void> deleteFailedOrServerMessage(LeadWhatsAppMessageModel msg) async {
    if (isClosed) return;
    if (msg.id < 0 || msg.isOptimistic) {
      emit(state.copyWith(messages: state.messages.where((m) => m.id != msg.id).toList()));
      return;
    }
    try {
      await _repository.deleteMessage(msg.id);
      if (isClosed) return;
      emit(state.copyWith(messages: state.messages.where((m) => m.id != msg.id).toList()));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(sendError: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
