import 'package:flutter/foundation.dart';

class PinnedMessageRef {
  const PinnedMessageRef({
    required this.messageId,
    required this.preview,
  });

  final int messageId;
  final String preview;
}

class PinnedMessagesController {
  final ValueNotifier<List<PinnedMessageRef>> pinned = ValueNotifier<List<PinnedMessageRef>>(const []);
  final ValueNotifier<bool> visible = ValueNotifier<bool>(true);

  void setPinned(List<PinnedMessageRef> value) {
    pinned.value = value;
  }

  void setVisible(bool value) {
    visible.value = value;
  }

  void dispose() {
    pinned.dispose();
    visible.dispose();
  }
}

