import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/whatsapp_conversation_model.dart';
import '../../../services/whatsapp_chat_unread_holder.dart';
import '../../../utils/whatsapp_manual_chats_storage.dart';
import '../whatsapp_chat_repository.dart';
import 'whatsapp_conversation_list_state.dart';

class WhatsAppConversationListCubit extends Cubit<WhatsAppConversationListState> {
  WhatsAppConversationListCubit({
    required WhatsAppChatRepository repository,
    bool Function()? isForeground,
    this.includeManualChats = false,
  })  : _repository = repository,
        _isForeground = isForeground ?? (() => true),
        super(const WhatsAppConversationListState.initial());

  final WhatsAppChatRepository _repository;
  final bool Function() _isForeground;
  /// Owners/admins may persist manual phone threads locally.
  final bool includeManualChats;
  Timer? _timer;
  Timer? _awaySoundTimer;
  int _lastUnreadTotal = 0;
  final AudioPlayer _awayPlayer = AudioPlayer();

  Future<void> bootstrap() async {
    await refresh();
    if (isClosed) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!isClosed && _isForeground()) {
        unawaited(refresh(silent: true));
      }
    });
    // Away/other-thread unread sound (~2s while foreground).
    _awaySoundTimer?.cancel();
    _awaySoundTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!isClosed && _isForeground()) unawaited(_checkAwaySound());
    });
  }

  Future<void> _checkAwaySound() async {
    try {
      final n = await _repository.getUnreadCount();
      if (isClosed) return;
      if (n > _lastUnreadTotal && _lastUnreadTotal >= 0) {
        try {
          await _awayPlayer.play(AssetSource('sounds/notif_tenant_chat.wav'));
        } catch (_) {}
      }
      if (isClosed) return;
      _lastUnreadTotal = n;
      WhatsAppChatUnreadHolder.setTotal(n);
    } catch (_) {}
  }

  Future<void> refresh({bool silent = false}) async {
    if (isClosed) return;
    if (!silent) {
      emit(state.copyWith(loading: true));
    }
    try {
      final conversations = await _repository.getConversations();
      if (isClosed) return;
      var merged = List<WhatsAppConversationModel>.from(conversations);

      if (includeManualChats) {
        final manuals = await WhatsAppManualChatsStorage.load();
        if (isClosed) return;
        for (final m in manuals) {
          final digits = m.phoneNumber.replaceAll(RegExp(r'\D'), '');
          final exists = merged.any(
            (c) => c.phoneNumber.replaceAll(RegExp(r'\D'), '') == digits,
          );
          if (!exists) {
            merged.add(
              WhatsAppConversationModel(
                id: -digits.hashCode.abs(),
                name: m.name.isNotEmpty ? m.name : m.phoneNumber,
                phoneNumber: m.phoneNumber,
                lastMessageAt: m.lastMessageAt,
                lastMessagePreview: '',
                unreadCount: 0,
              ),
            );
          } else {
            // Upgrade: drop local manual when CRM lead exists.
            unawaited(WhatsAppManualChatsStorage.remove(m.phoneNumber));
          }
        }
      }

      final total = merged.fold<int>(0, (s, c) => s + c.unreadCount);
      WhatsAppChatUnreadHolder.setTotal(total);
      _lastUnreadTotal = total;
      if (isClosed) return;
      emit(
        state.copyWith(
          conversations: merged,
          loading: false,
          clearLoadError: true,
        ),
      );
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

  Future<void> deleteConversation(WhatsAppConversationModel c) async {
    try {
      if (c.id > 0) {
        await _repository.deleteConversation(clientId: c.id);
      } else {
        await _repository.deleteConversation(phone: c.phoneNumber);
        await WhatsAppManualChatsStorage.remove(c.phoneNumber);
      }
      if (isClosed) return;
      await refresh(silent: true);
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loadError: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _awaySoundTimer?.cancel();
    _awayPlayer.dispose();
    return super.close();
  }
}
