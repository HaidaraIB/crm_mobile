import 'dart:async';

import 'package:flutter/foundation.dart';

class MessageHighlightController {
  final ValueNotifier<int?> highlightedMessageId = ValueNotifier<int?>(null);
  Timer? _clearTimer;

  void highlight(int messageId, {Duration duration = const Duration(milliseconds: 1200)}) {
    _clearTimer?.cancel();
    highlightedMessageId.value = messageId;
    _clearTimer = Timer(duration, clear);
  }

  void clear() {
    highlightedMessageId.value = null;
  }

  void dispose() {
    _clearTimer?.cancel();
    highlightedMessageId.dispose();
  }
}

