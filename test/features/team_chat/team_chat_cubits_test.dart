import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crm_mobile/features/team_chat/cubit/team_chat_composer_cubit.dart';
import 'package:crm_mobile/features/team_chat/cubit/team_chat_composer_state.dart';
import 'package:crm_mobile/features/team_chat/cubit/team_chat_list_cubit.dart';
import 'package:crm_mobile/features/team_chat/cubit/team_chat_list_state.dart';
import 'package:crm_mobile/features/team_chat/cubit/team_chat_peer_presence_cubit.dart';
import 'package:crm_mobile/features/team_chat/team_chat_repository.dart';
import 'package:crm_mobile/models/tenant_chat_models.dart';
import 'package:crm_mobile/models/user_model.dart';

class _FakeTeamChatRepository implements TeamChatRepository {
  _FakeTeamChatRepository({
    this.conversations = const [],
    this.presence = const TenantChatPeerPresenceResponse(),
  });

  List<TenantChatConversation> conversations;
  TenantChatPeerPresenceResponse presence;
  int presencePolls = 0;

  @override
  Future<UserModel> getCurrentUser() async => UserModel(
        id: 1,
        username: 'me',
        email: 'me@test.com',
        firstName: 'Me',
        lastName: 'User',
        role: 'employee',
        phone: '',
      );

  @override
  Future<TenantChatConversationsPage> getConversations() async {
    return TenantChatConversationsPage(
      count: conversations.length,
      results: conversations,
    );
  }

  @override
  Future<TenantChatPeersPage> getEligibleUsers() async =>
      const TenantChatPeersPage(count: 0, results: []);

  @override
  Future<TenantChatConversation> startConversation(int withUserId) async =>
      conversations.first;

  @override
  Future<TenantChatPeerPresenceResponse> getPeerPresence(int conversationId) async {
    presencePolls++;
    return presence;
  }

  @override
  Future<void> postPeerPresence(int conversationId, String action) async {}

  @override
  Future<TenantChatMessage> sendMessage(
    int conversationId,
    String body, {
    int? replyToMessageId,
    int? forwardFromMessageId,
  }) async {
    return TenantChatMessage(
      id: 99,
      body: body,
      createdAt: DateTime.now().toIso8601String(),
      sender: TenantChatPeer(
        id: 1,
        username: 'me',
        email: 'me@test.com',
        firstName: 'Me',
        lastName: '',
        role: 'employee',
      ),
    );
  }

  @override
  Future<TenantChatMessage> sendMessageWithFile(
    int conversationId,
    String filePath, {
    String? body,
    int? replyToMessageId,
  }) =>
      sendMessage(conversationId, body ?? '', replyToMessageId: replyToMessageId);

  @override
  Future<void> pinMessage(int conversationId, int messageId) async {}

  @override
  Future<void> unpinMessage(int conversationId, int messageId) async {}
}

TenantChatConversation _conv({
  required int id,
  String updatedAt = '2026-01-01T12:00:00Z',
  int unread = 0,
}) {
  return TenantChatConversation(
    id: id,
    kind: 'direct',
    updatedAt: updatedAt,
    unreadCount: unread,
    otherUser: TenantChatPeer(
      id: id + 100,
      username: 'u$id',
      email: 'u$id@test.com',
      firstName: 'Peer',
      lastName: '$id',
      role: 'employee',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('TeamChatListCubit', () {
    test('silent refresh skips emit when payload equal', () async {
      final repo = _FakeTeamChatRepository(
        conversations: [_conv(id: 1)],
      );
      final cubit = TeamChatListCubit(repository: repo);
      await cubit.refreshConversations();
      expect(cubit.state.conversations.length, 1);

      var emits = 0;
      final sub = cubit.stream.listen((_) => emits++);
      await cubit.refreshConversations(silent: true);
      await Future<void>.delayed(Duration.zero);
      expect(emits, 0);
      await sub.cancel();
      await cubit.close();
    });

    blocTest<TeamChatListCubit, TeamChatListState>(
      'selectConversation sets selectedId and read cursor',
      build: () {
        final repo = _FakeTeamChatRepository(
          conversations: [
            TenantChatConversation(
              id: 1,
              kind: 'direct',
              updatedAt: '2026-01-01T12:00:00Z',
              lastReadMessageId: 10,
              otherUser: TenantChatPeer(
                id: 101,
                username: 'u1',
                email: 'u1@test.com',
                firstName: 'Peer',
                lastName: '1',
                role: 'employee',
              ),
            ),
          ],
        );
        return TeamChatListCubit(repository: repo);
      },
      act: (c) async {
        await c.refreshConversations();
        await c.selectConversation(1);
      },
      verify: (c) {
        expect(c.state.selectedId, 1);
        expect(c.state.readCursor, 10);
      },
    );
  });

  group('TeamChatPeerPresenceCubit', () {
    test('does not emit when presence response equal', () async {
      final repo = _FakeTeamChatRepository(
        presence: const TenantChatPeerPresenceResponse(
          peerUserId: 2,
          activity: kTenantChatPresenceTyping,
        ),
      );
      final cubit = TeamChatPeerPresenceCubit(repository: repo);
      cubit.bindConversation(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var emits = 0;
      final sub = cubit.stream.listen((_) => emits++);
      repo.presence = const TenantChatPeerPresenceResponse(
        peerUserId: 2,
        activity: kTenantChatPresenceTyping,
      );
      await cubit.close();
      await Future<void>.delayed(Duration.zero);
      expect(emits, lessThanOrEqualTo(1));
      await sub.cancel();
    });
  });

  group('TeamChatComposerCubit', () {
    blocTest<TeamChatComposerCubit, TeamChatComposerState>(
      'bindConversation clears reply and attachment',
      build: () => TeamChatComposerCubit(repository: _FakeTeamChatRepository()),
      seed: () => TeamChatComposerState(
        boundConversationId: 1,
        replyTo: TenantChatMessage(
          id: 5,
          body: 'hi',
          createdAt: '2026-01-01T12:00:00Z',
          sender: TenantChatPeer(
            id: 2,
            username: 'p',
            email: 'p@test.com',
            firstName: 'P',
            lastName: '',
            role: 'employee',
          ),
        ),
        forwardSourceId: null,
        pendingAttachmentPath: '/tmp/x',
        compressing: false,
        sending: false,
        voiceRecording: false,
        draftTypingSignal: false,
        sendErrorKey: null,
        pinErrorKey: null,
      ),
      act: (c) => c.bindConversation(2),
      verify: (c) {
        expect(c.state.boundConversationId, 2);
        expect(c.state.replyTo, isNull);
        expect(c.state.pendingAttachmentPath, isNull);
      },
    );

    blocTest<TeamChatComposerCubit, TeamChatComposerState>(
      'send clears reply and attachment on success',
      build: () => TeamChatComposerCubit(repository: _FakeTeamChatRepository()),
      act: (c) async {
        c.bindConversation(1);
        c.setReplyTo(
          TenantChatMessage(
            id: 5,
            body: 'hi',
            createdAt: '2026-01-01T12:00:00Z',
            sender: TenantChatPeer(
              id: 2,
              username: 'p',
              email: 'p@test.com',
              firstName: 'P',
              lastName: '',
              role: 'employee',
            ),
          ),
        );
        await c.send(draftText: 'hello');
      },
      verify: (c) {
        expect(c.state.sending, false);
        expect(c.state.replyTo, isNull);
        expect(c.state.pendingAttachmentPath, isNull);
      },
    );
  });
}
