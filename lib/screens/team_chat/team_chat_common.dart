import '../../models/tenant_chat_models.dart';

/// [VideoPlayerController.dataSource] for file-backed playback is a `file://` URI string.
/// [File], ExoPlayer, and [Gal.putVideo] need a native filesystem path.
String tenantChatNativeFilePath(String pathOrUri) {
  final s = pathOrUri.trim();
  if (s.startsWith('file://')) {
    try {
      return Uri.parse(s).toFilePath();
    } catch (_) {
      return s;
    }
  }
  return s;
}

String tenantChatPeerName(TenantChatPeer p) {
  final n = '${p.firstName} ${p.lastName}'.trim();
  return n.isNotEmpty
      ? n
      : (p.username.isNotEmpty ? p.username : '#${p.id}');
}

String tenantChatPeerInitials(TenantChatPeer p) {
  final fn = p.firstName.trim();
  final ln = p.lastName.trim();
  if (fn.isNotEmpty || ln.isNotEmpty) {
    final a = fn.isNotEmpty ? fn[0].toUpperCase() : '';
    final b = ln.isNotEmpty
        ? ln[0].toUpperCase()
        : (fn.length > 1 ? fn[1].toUpperCase() : '');
    final combined = a + b;
    return combined.substring(0, combined.length > 2 ? 2 : combined.length);
  }
  final raw = (p.username.isNotEmpty ? p.username : 'u${p.id}').replaceAll(
    RegExp(r'[^a-zA-Z0-9]'),
    '',
  );
  return raw.length >= 2
      ? raw.substring(0, 2).toUpperCase()
      : (raw.isNotEmpty ? raw.toUpperCase() : '?');
}

String tenantChatConversationTitle(
  TenantChatConversation c,
  String companyRoomLabel,
) {
  if (c.isCompanyGroup) {
    final t = c.groupTitle?.trim() ?? '';
    return t.isNotEmpty ? t : companyRoomLabel;
  }
  final ou = c.otherUser;
  return ou != null ? tenantChatPeerName(ou) : '';
}

String tenantChatConversationAvatarLetters(
  TenantChatConversation c,
  String companyRoomLabel,
) {
  if (c.isCompanyGroup) {
    final raw = (c.groupTitle?.trim().isNotEmpty == true
            ? c.groupTitle!.trim()
            : companyRoomLabel)
        .trim();
    final buf = StringBuffer();
    for (final r in raw.runes) {
      final letterOrDigit = (r >= 0x30 && r <= 0x39) ||
          (r >= 0x41 && r <= 0x5A) ||
          (r >= 0x61 && r <= 0x7A) ||
          (r >= 0x0600 && r <= 0x06FF) ||
          (r >= 0x0400 && r <= 0x04FF);
      if (letterOrDigit) {
        buf.writeCharCode(r);
        if (buf.length >= 2) break;
      }
    }
    if (buf.isEmpty) {
      if (raw.isEmpty) return '#';
      return raw.length >= 2
          ? raw.substring(0, 2).toUpperCase()
          : raw[0].toUpperCase();
    }
    return buf.toString().toUpperCase();
  }
  final ou = c.otherUser;
  return ou != null ? tenantChatPeerInitials(ou) : '?';
}

/// Short role label for chat badges (keys via [tr]).
String tenantChatPeerRoleLabel(String role, String Function(String key) tr) {
  switch (role.toLowerCase()) {
    case 'admin':
      return tr('teamChatRoleAdmin');
    case 'super_admin':
      return tr('teamChatRoleSuperAdmin');
    case 'supervisor':
      return tr('supervisor');
    case 'employee':
      return tr('employee');
    case 'data_entry':
      return tr('dataEntry');
    default:
      if (role.isEmpty) return '';
      return role.replaceAll('_', ' ');
  }
}

int _presencePriority(String act) {
  if (act == kTenantChatPresenceRecording) return 4;
  if (act == kTenantChatPresenceTyping) return 3;
  if (act == kTenantChatPresenceUploading) return 2;
  if (act == kTenantChatPresenceSending) return 1;
  return 0;
}

/// Telegram-style line for group typing / recording / etc.
String? tenantChatGroupPresenceLine(
  List<TenantChatGroupPresencePeer> peers,
  String Function(String key) tr,
) {
  if (peers.isEmpty) return null;
  var best = peers.first.activity;
  var bestP = _presencePriority(best);
  for (final p in peers) {
    final pv = _presencePriority(p.activity);
    if (pv > bestP) {
      best = p.activity;
      bestP = pv;
    }
  }
  final same = peers.where((p) => p.activity == best).toList();
  const maxShow = 3;
  final names = same
      .take(maxShow)
      .map((p) => tenantChatPeerName(p.peer))
      .toList();
  var nameStr = names.join(', ');
  if (same.length > maxShow) {
    nameStr = '$nameStr +${same.length - maxShow}';
  }
  if (best == kTenantChatPresenceTyping) {
    return tr('teamChatGroupTyping').replaceAll('{names}', nameStr);
  }
  if (best == kTenantChatPresenceRecording) {
    return tr('teamChatGroupRecording').replaceAll('{names}', nameStr);
  }
  if (best == kTenantChatPresenceUploading) {
    return tr('teamChatGroupUploading').replaceAll('{names}', nameStr);
  }
  if (best == kTenantChatPresenceSending) {
    return tr('teamChatGroupSending').replaceAll('{names}', nameStr);
  }
  return null;
}

bool tenantChatPresenceResponsesEqual(
  TenantChatPeerPresenceResponse? a,
  TenantChatPeerPresenceResponse b,
) {
  if (identical(a, b)) return true;
  if (a == null) return false;
  if (a.isGroupMode != b.isGroupMode) return false;
  if (a.isGroupMode) {
    if (a.groupPeers.length != b.groupPeers.length) return false;
    for (var i = 0; i < a.groupPeers.length; i++) {
      final x = a.groupPeers[i], y = b.groupPeers[i];
      if (x.userId != y.userId || x.activity != y.activity) return false;
    }
    return true;
  }
  return a.peerUserId == b.peerUserId && a.activity == b.activity;
}
