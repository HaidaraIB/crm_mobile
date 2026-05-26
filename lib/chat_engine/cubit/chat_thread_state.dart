import 'package:equatable/equatable.dart';

import '../models/chat_list_row.dart';

class ChatThreadState extends Equatable {
  const ChatThreadState({
    required this.loading,
    required this.loadingOlder,
    required this.rows,
    required this.hasOlder,
    required this.hasNewer,
    required this.error,
    required this.version,
  });

  const ChatThreadState.initial()
      : loading = false,
        loadingOlder = false,
        rows = const [],
        hasOlder = true,
        hasNewer = false,
        error = null,
        version = 0;

  final bool loading;
  final bool loadingOlder;
  final List<ChatListRow> rows;
  final bool hasOlder;
  final bool hasNewer;
  final String? error;
  final int version;

  ChatThreadState copyWith({
    bool? loading,
    bool? loadingOlder,
    List<ChatListRow>? rows,
    bool? hasOlder,
    bool? hasNewer,
    String? error,
    int? version,
    bool clearError = false,
  }) {
    return ChatThreadState(
      loading: loading ?? this.loading,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      rows: rows ?? this.rows,
      hasOlder: hasOlder ?? this.hasOlder,
      hasNewer: hasNewer ?? this.hasNewer,
      error: clearError ? null : (error ?? this.error),
      version: version ?? this.version,
    );
  }

  int? rowIndexForMessage(int messageId) {
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is ChatMessageRow && row.message.id == messageId) {
        return i;
      }
    }
    return null;
  }

  @override
  List<Object?> get props =>
      [loading, loadingOlder, rows, hasOlder, hasNewer, error, version];
}
