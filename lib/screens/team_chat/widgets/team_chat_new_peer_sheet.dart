import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../features/team_chat/cubit/team_chat_new_peer_cubit.dart';
import '../../../models/tenant_chat_models.dart';
import '../team_chat_common.dart';

class TeamChatNewPeerSheet extends StatefulWidget {
  const TeamChatNewPeerSheet({
    super.key,
    required this.peers,
    required this.onPick,
  });

  final List<TenantChatPeer> peers;
  final Future<void> Function(TenantChatPeer peer) onPick;

  @override
  State<TeamChatNewPeerSheet> createState() => _TeamChatNewPeerSheetState();
}

class _TeamChatNewPeerSheetState extends State<TeamChatNewPeerSheet> {
  late final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      context.read<TeamChatNewPeerCubit>().setQuery(_search.text);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String tr(String k) => loc?.translate(k) ?? k;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final searchFill = Color.lerp(
      scheme.surfaceContainerHighest,
      scheme.surface,
      theme.brightness == Brightness.dark ? 0.45 : 0.2,
    )!;

    return BlocBuilder<TeamChatNewPeerCubit, TeamChatNewPeerState>(
      builder: (context, state) {
        final filtered = state.filtered;
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('teamChatNewConversation'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('cancel')),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: tr('teamChatSearchPeople'),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: searchFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: widget.peers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            tr('teamChatNoEligiblePeers'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                tr('teamChatNoMatchingPeers'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 1,
                              indent: 76,
                              color: scheme.outlineVariant.withValues(alpha: 0.35),
                            ),
                            itemBuilder: (ctx, i) {
                              final p = filtered[i];
                              final name = tenantChatPeerName(p);
                              final roleLine = tenantChatPeerRoleLabel(p.role, tr);
                              final photo = p.profilePhoto?.trim();
                              final ImageProvider<Object>? avatarImg =
                                  photo != null &&
                                          photo.isNotEmpty &&
                                          (photo.startsWith('http://') ||
                                              photo.startsWith('https://'))
                                      ? NetworkImage(photo)
                                      : null;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => widget.onPick(p),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            CircleAvatar(
                                              radius: 26,
                                              backgroundColor: scheme.primary
                                                  .withValues(alpha: 0.12),
                                              backgroundImage: avatarImg,
                                              child: avatarImg == null
                                                  ? Text(
                                                      tenantChatPeerInitials(p),
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                        color: scheme.primary,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            if (p.isOnline == true)
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: Colors
                                                        .greenAccent.shade400,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: scheme.surface,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (roleLine.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  roleLine,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
