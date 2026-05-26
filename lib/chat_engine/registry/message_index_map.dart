class MessageIndexMap {
  MessageIndexMap._(this._idToIndex);

  final Map<int, int> _idToIndex;

  static MessageIndexMap fromOrderedIds(List<int> ids) {
    final map = <int, int>{};
    for (var i = 0; i < ids.length; i++) {
      map[ids[i]] = i;
    }
    return MessageIndexMap._(map);
  }

  int? indexOf(int messageId) => _idToIndex[messageId];
  bool contains(int messageId) => _idToIndex.containsKey(messageId);
}

