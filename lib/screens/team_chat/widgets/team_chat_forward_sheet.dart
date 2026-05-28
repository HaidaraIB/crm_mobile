import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../models/tenant_chat_models.dart';
import '../team_chat_common.dart';

class TeamChatForwardSheet extends StatelessWidget {
  const TeamChatForwardSheet({
    super.key,
    required this.conversations,
    required this.captionController,
    required this.onSend,
  });

  final List<TenantChatConversation> conversations;
  final TextEditingController captionController;
  final Future<void> Function(int targetId) onSend;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              t('teamChatForwardTo'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: captionController,
              decoration: InputDecoration(
                labelText: t('teamChatForwardCaption'),
                hintText: t('teamChatForwardCaptionPlaceholder'),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 280,
            child: conversations.isEmpty
                ? Center(child: Text(t('teamChatNoEligiblePeers')))
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (ctx, i) {
                      final c = conversations[i];
                      return ListTile(
                        title: Text(
                          c.isCompanyGroup
                              ? tenantChatConversationTitle(
                                  c,
                                  t('teamChatCompanyRoom'),
                                )
                              : (c.otherUser != null
                                  ? tenantChatPeerName(c.otherUser!)
                                  : ''),
                        ),
                        onTap: () => onSend(c.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
