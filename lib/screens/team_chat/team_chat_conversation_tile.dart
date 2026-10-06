import 'package:flutter/material.dart';

import '../../models/tenant_chat_models.dart';
import '../../widgets/app_avatar.dart';
import 'team_chat_common.dart';
import 'team_chat_text_direction.dart';

class TeamChatConversationRow extends StatelessWidget {
  const TeamChatConversationRow({
    super.key,
    required this.conversation,
    required this.selected,
    required this.previewText,
    required this.timeLabel,
    required this.titleText,
    required this.avatarLetters,
    required this.showOnlineDot,
    required this.onTap,
  });

  final TenantChatConversation conversation;
  final bool selected;
  final String previewText;
  final String timeLabel;
  final String titleText;
  final String avatarLetters;
  final bool showOnlineDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = conversation.unreadCount;

    return Material(
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    radius: 26,
                    initials: conversation.isCompanyGroup ? null : avatarLetters,
                    icon: conversation.isCompanyGroup
                        ? Icons.groups_rounded
                        : null,
                  ),
                  if (showOnlineDot)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TeamChatIsolatedText(
                            titleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TeamChatIsolatedText(
                            previewText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.25,
                              color: unread > 0
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                              fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeamChatThreadAppBarTitle extends StatelessWidget {
  const TeamChatThreadAppBarTitle({
    super.key,
    required this.peer,
    this.subtitle,
    this.onPrimaryBackground = true,
  });

  final TenantChatPeer peer;
  final String? subtitle;
  /// When false (e.g. tablet split pane), use [ColorScheme] surface colors.
  final bool onPrimaryBackground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor = onPrimaryBackground ? Colors.white : scheme.onSurface;
    final subColor = onPrimaryBackground
        ? Colors.white.withValues(alpha: 0.88)
        : scheme.onSurfaceVariant;
    return Row(
      children: [
        AppAvatar(
          radius: 18,
          onPrimaryBackground: onPrimaryBackground,
          initials: tenantChatPeerInitials(peer),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TeamChatIsolatedText(
                tenantChatPeerName(peer),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: titleColor,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                TeamChatIsolatedText(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class TeamChatGroupThreadAppBarTitle extends StatelessWidget {
  const TeamChatGroupThreadAppBarTitle({
    super.key,
    required this.title,
    required this.avatarLetters,
    this.subtitle,
    this.onPrimaryBackground = true,
  });

  final String title;
  final String avatarLetters;
  final String? subtitle;
  final bool onPrimaryBackground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor = onPrimaryBackground ? Colors.white : scheme.onSurface;
    final subColor = onPrimaryBackground
        ? Colors.white.withValues(alpha: 0.88)
        : scheme.onSurfaceVariant;
    return Row(
      children: [
        AppAvatar(
          radius: 18,
          onPrimaryBackground: onPrimaryBackground,
          initials: avatarLetters,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TeamChatIsolatedText(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: titleColor,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                TeamChatIsolatedText(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
