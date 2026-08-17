import 'dart:async';

/// Thin FCM `invalidate` keys (e.g. `whatsapp:conversations`).
class SyncInvalidation {
  SyncInvalidation._();
  static final SyncInvalidation instance = SyncInvalidation._();

  final StreamController<Map<String, String>> _controller =
      StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get stream => _controller.stream;

  void emit(Map<String, String> event) {
    if (event.isEmpty) return;
    _controller.add(event);
  }

  void emitResumeRefresh() {
    emit({'invalidate': 'whatsapp:conversations'});
    emit({'invalidate': 'tenant_chat:messages'});
  }
}
