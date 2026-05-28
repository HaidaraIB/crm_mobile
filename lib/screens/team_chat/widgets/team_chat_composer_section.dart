import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../features/team_chat/cubit/team_chat_composer_cubit.dart';
import '../../../features/team_chat/cubit/team_chat_composer_state.dart';
import '../../../models/tenant_chat_models.dart';
import '../team_chat_composer.dart';
import '../team_chat_common.dart';

class TeamChatComposerSection extends StatefulWidget {
  const TeamChatComposerSection({
    super.key,
    required this.draft,
    required this.onScrollToBottom,
    required this.onToggleVoice,
  });

  final TextEditingController draft;
  final Future<void> Function({bool animated}) onScrollToBottom;
  final Future<void> Function() onToggleVoice;

  @override
  State<TeamChatComposerSection> createState() => _TeamChatComposerSectionState();
}

class _TeamChatComposerSectionState extends State<TeamChatComposerSection> {
  @override
  void initState() {
    super.initState();
    widget.draft.addListener(_onDraftChanged);
  }

  @override
  void dispose() {
    widget.draft.removeListener(_onDraftChanged);
    super.dispose();
  }

  void _onDraftChanged() {
    context.read<TeamChatComposerCubit>().onDraftChanged(
          hasText: widget.draft.text.trim().isNotEmpty,
        );
  }

  String _t(String key) {
    final loc = AppLocalizations.of(context);
    return loc?.translate(key) ?? key;
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    context.read<TeamChatComposerCubit>().setPendingAttachment(x.path);
    await widget.onScrollToBottom(animated: true);
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(withData: false);
    if (r == null || r.files.single.path == null || !mounted) return;
    context.read<TeamChatComposerCubit>().setPendingAttachment(r.files.single.path);
    await widget.onScrollToBottom(animated: true);
  }

  Widget _replyDockBanner(TenantChatMessage r) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 40,
              margin: const EdgeInsetsDirectional.only(start: 6, end: 8),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_t('teamChatReplyingTo')} ${tenantChatPeerName(r.sender)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.body.isNotEmpty ? r.body : (r.attachmentKind ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
              onPressed: () {
                context.read<TeamChatComposerCubit>().setReplyTo(null);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TeamChatComposerCubit, TeamChatComposerState>(
      listenWhen: (prev, next) =>
          prev.sendErrorKey != next.sendErrorKey ||
          prev.pinErrorKey != next.pinErrorKey,
      listener: (context, state) {
        if (state.sendErrorKey != null) {
          SnackbarHelper.showError(context, _t(state.sendErrorKey!));
          context.read<TeamChatComposerCubit>().clearSendError();
        }
        if (state.pinErrorKey != null) {
          SnackbarHelper.showError(context, _t(state.pinErrorKey!));
          context.read<TeamChatComposerCubit>().clearPinError();
        }
      },
      buildWhen: (prev, next) =>
          prev.sending != next.sending ||
          prev.compressing != next.compressing ||
          prev.pendingAttachmentPath != next.pendingAttachmentPath ||
          prev.voiceRecording != next.voiceRecording ||
          prev.replyTo != next.replyTo,
      builder: (context, state) {
        final hasAttach = state.pendingAttachmentPath != null;
        return TeamChatComposer(
          draft: widget.draft,
          compressing: state.compressing,
          hasAttach: hasAttach,
          sending: state.sending,
          voiceRecording: state.voiceRecording,
          compressLabel: _t('teamChatCompressing'),
          hintText: _t('teamChatMessagePlaceholder'),
          attachFileName: hasAttach
              ? state.pendingAttachmentPath!.split(Platform.pathSeparator).last
              : '',
          onPickImage: () => _pickImage(),
          onPickFile: () => _pickFile(),
          onVoice: widget.onToggleVoice,
          onClearAttach: () {
            context.read<TeamChatComposerCubit>().setPendingAttachment(null);
          },
          onSend: () async {
            final text = widget.draft.text;
            await context.read<TeamChatComposerCubit>().send(draftText: text);
            if (!context.mounted) return;
            if (context.read<TeamChatComposerCubit>().state.sendErrorKey == null) {
              widget.draft.clear();
            }
          },
          attachPhotoLabel: _t('teamChatMediaPhoto'),
          attachFileLabel: _t('teamChatAttach'),
          replyBanner:
              state.replyTo != null ? _replyDockBanner(state.replyTo!) : null,
        );
      },
    );
  }
}
