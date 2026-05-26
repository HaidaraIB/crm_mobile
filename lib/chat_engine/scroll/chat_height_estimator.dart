class ChatHeightEstimator {
  final Map<int, double> _measuredHeights = <int, double>{};

  void recordHeight(int messageId, double height) {
    if (height <= 0) return;
    _measuredHeights[messageId] = height;
  }

  double? measured(int messageId) => _measuredHeights[messageId];

  void forgetExcept(Set<int> keepIds) {
    _measuredHeights.removeWhere((k, _) => !keepIds.contains(k));
  }
}

