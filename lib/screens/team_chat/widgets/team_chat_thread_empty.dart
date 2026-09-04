import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../widgets/chat_thread_empty.dart';

/// Centered placeholder when a team-chat thread has no messages yet.
class TeamChatThreadEmpty extends StatelessWidget {
  const TeamChatThreadEmpty({
    super.key,
    required this.isCompanyGroup,
  });

  final bool isCompanyGroup;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String tr(String key) => loc?.translate(key) ?? key;
    return ChatThreadEmpty(
      icon: isCompanyGroup
          ? Icons.groups_rounded
          : Icons.chat_bubble_outline_rounded,
      title: tr('teamChatEmptyTitle'),
      subtitle: tr(
        isCompanyGroup ? 'teamChatEmptyGroupHint' : 'teamChatEmptyDirectHint',
      ),
    );
  }
}
