import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import '../models/settings_model.dart';
import 'lead_tag_chips.dart';

/// Tag picker built as a chip field rather than a select box: selected tags read
/// as removable chips and an "add" pill opens the picker sheet. Mirrors the web
/// TagMultiSelect.
class TagMultiSelectField extends StatelessWidget {
  const TagMultiSelectField({
    super.key,
    required this.tags,
    required this.selectedIds,
    required this.onChanged,
    this.enabled = true,
  });

  final List<TagModel> tags;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = tags.where((tag) => selectedIds.contains(tag.id)).toList();
    final allSelected = selected.length == tags.length && tags.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.translate('tags') ?? 'Tags',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.45),
            ),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in selected)
                _RemovableTagChip(
                  tag: tag,
                  enabled: enabled,
                  onRemove: () => onChanged(
                    selectedIds.where((id) => id != tag.id).toList(),
                  ),
                ),
              if (!allSelected)
                InkWell(
                  onTap: enabled ? () => _openPicker(context) : null,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: theme.colorScheme.outline
                            .withValues(alpha: isDark ? 0.6 : 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 14,
                          color: enabled
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.disabledColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          selected.isEmpty
                              ? (localizations?.translate('addTags') ??
                                  'Add tags')
                              : (localizations?.translate('add') ?? 'Add'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: enabled
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final draft = List<int>.from(selectedIds);

    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            localizations?.translate('tags') ?? 'Tags',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        if (draft.isNotEmpty)
                          TextButton(
                            onPressed: () => setSheetState(() => draft.clear()),
                            child: Text(
                              localizations?.translate('clearAll') ??
                                  'Clear all',
                            ),
                          ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, draft),
                          child: Text(
                            localizations?.translate('done') ?? 'Done',
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: tags.length,
                      itemBuilder: (context, index) {
                        final tag = tags[index];
                        final checked = draft.contains(tag.id);
                        return ListTile(
                          onTap: () {
                            setSheetState(() {
                              if (checked) {
                                draft.remove(tag.id);
                              } else {
                                draft.add(tag.id);
                              }
                            });
                          },
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: parseTagHexColor(tag.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            tag.name,
                            style: TextStyle(
                              fontWeight:
                                  checked ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: (tag.description ?? '').isEmpty
                              ? null
                              : Text(
                                  tag.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: checked
                              ? Icon(Icons.check, color: theme.colorScheme.primary)
                              : null,
                          selected: checked,
                          selectedTileColor:
                              theme.colorScheme.primary.withValues(alpha: 0.08),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != null) onChanged(result);
  }
}

class _RemovableTagChip extends StatelessWidget {
  const _RemovableTagChip({
    required this.tag,
    required this.enabled,
    required this.onRemove,
  });

  final TagModel tag;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = parseTagHexColor(tag.color);

    return Container(
      padding: const EdgeInsetsDirectional.only(start: 8, end: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: isDark ? 0.16 : 0.12),
          theme.cardColor,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.42 : 0.38),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              tag.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (enabled)
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}
