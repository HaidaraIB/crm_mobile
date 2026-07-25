import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/lead_location.dart';
import '../core/utils/media_url_utils.dart';
import '../models/timeline_entry.dart';
import 'media/open_app_media_viewer.dart';

const _timelineSortKey = 'leadTimelineSortOrder';

/// Accent readable on both light and dark surfaces (primary purple is too dark on dark UI).
Color _timelineAccentColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFFC4B5FD) : AppTheme.primaryColor;
}

Color _timelineMutedColor(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  if (isDark) return Colors.white.withValues(alpha: 0.75);
  return theme.colorScheme.onSurfaceVariant;
}

Color _timelineStrongColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurface;
}

class LeadTimeline extends StatefulWidget {
  final List<TimelineEntry> entries;
  final bool isLoading;
  final String? errorMessage;

  /// When true, the event list scrolls inside this widget (for sheets/modals).
  final bool scrollable;

  /// When false, hides the large "Timeline" title (useful when the sheet has its own title).
  final bool showSectionTitle;

  const LeadTimeline({
    super.key,
    required this.entries,
    this.isLoading = false,
    this.errorMessage,
    this.scrollable = false,
    this.showSectionTitle = true,
  });

  @override
  State<LeadTimeline> createState() => _LeadTimelineState();
}

class _LeadTimelineState extends State<LeadTimeline> {
  /// 'desc' = newest first, 'asc' = oldest first
  String _sortOrder = 'desc';
  bool _sortLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSortOrder();
  }

  Future<void> _loadSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_timelineSortKey);
    if (!mounted) return;
    setState(() {
      _sortOrder = stored == 'asc' ? 'asc' : 'desc';
      _sortLoaded = true;
    });
  }

  Future<void> _setSort(String order) async {
    setState(() => _sortOrder = order);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timelineSortKey, order);
  }

  List<TimelineEntry> get _sorted {
    final copy = List<TimelineEntry>.from(widget.entries);
    copy.sort((a, b) => _sortOrder == 'desc'
        ? b.timestamp.compareTo(a.timestamp)
        : a.timestamp.compareTo(b.timestamp));
    return copy;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final sorted = _sorted;
    final countLabel = (loc?.translate('timelineEventsCount') ?? '{count} events')
        .replaceAll('{count}', '${sorted.length}');

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: widget.showSectionTitle
            ? const BorderRadius.vertical(top: Radius.circular(12))
            : BorderRadius.zero,
        border: Border(
          top: widget.showSectionTitle
              ? BorderSide(color: theme.dividerColor.withValues(alpha: 0.6))
              : BorderSide.none,
          left: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
          right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (widget.showSectionTitle)
                  Flexible(
                    child: Text(
                      loc?.translate('timeline') ?? 'Timeline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.titleLarge?.color ??
                            theme.colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                if (widget.showSectionTitle && sorted.isNotEmpty)
                  const SizedBox(width: 8),
                if (sorted.isNotEmpty)
                  Text(
                    countLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _timelineMutedColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (_sortLoaded)
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.8),
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SortChip(
                    label: loc?.translate('timelineNewestFirst') ??
                        'Newest first',
                    selected: _sortOrder == 'desc',
                    onTap: () => _setSort('desc'),
                  ),
                  _SortChip(
                    label: loc?.translate('timelineOldestFirst') ??
                        'Oldest first',
                    selected: _sortOrder == 'asc',
                    onTap: () => _setSort('asc'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final body = _buildBody(theme, loc, sorted);

    if (widget.scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: body,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border(
              left: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
              right:
                  BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
              bottom:
                  BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
            ),
          ),
          child: body,
        ),
      ],
    );
  }

  Widget _buildBody(
    ThemeData theme,
    AppLocalizations? loc,
    List<TimelineEntry> sorted,
  ) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.errorMessage!,
          style: TextStyle(color: Colors.red[700]),
        ),
      );
    }
    if (sorted.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Text(
            loc?.translate('timelineEmpty') ?? 'No timeline events yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _timelineMutedColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final list = Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Column(
        children: [
          for (var i = 0; i < sorted.length; i++)
            _TimelineRow(
              entry: sorted[i],
              index: i,
              isLast: i == sorted.length - 1,
              onOpenUrl: _openUrl,
            ),
        ],
      ),
    );

    if (widget.scrollable) {
      return SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 12,
        ),
        child: Container(
          width: double.infinity,
          color: theme.cardColor,
          child: list,
        ),
      );
    }

    return list;
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primaryColor : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : _timelineMutedColor(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineEntry entry;
  final int index;
  final bool isLast;
  final Future<void> Function(String url) onOpenUrl;

  const _TimelineRow({
    required this.entry,
    required this.index,
    required this.isLast,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final chip = _typeChip(entry, loc);
    final showSubtitle = _showActionSubtitle(entry, chip.label);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.cardColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: theme.dividerColor.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _Chip(
                              icon: chip.icon,
                              label: chip.label,
                              foreground: chip.fg,
                              background: chip.bg,
                            ),
                            if (entry.stage != null && entry.stage!.isNotEmpty)
                              _StageChip(
                                label: entry.stage!,
                                colorHex: entry.color,
                                forceLtr: entry.type == TimelineEntryType.sms ||
                                    entry.type == TimelineEntryType.whatsapp,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: _timelineMutedColor(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.date,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _timelineMutedColor(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.user,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _timelineStrongColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.fieldLabel != null &&
                      entry.fieldLabel!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      entry.fieldLabel!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _timelineStrongColor(context),
                      ),
                    ),
                  ],
                  if (showSubtitle) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.action,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _timelineMutedColor(context),
                      ),
                    ),
                  ],
                  if (entry.type == TimelineEntryType.event &&
                      (entry.oldValue != null || entry.newValue != null))
                    _ValueChange(
                      oldValue: entry.oldValue,
                      newValue: entry.newValue,
                      loc: loc,
                    ),
                  if (entry.type == TimelineEntryType.locationUpdate)
                    _LocationBlock(
                      entry: entry,
                      loc: loc,
                      onOpenUrl: onOpenUrl,
                    ),
                  if (entry.details.isNotEmpty &&
                      entry.type != TimelineEntryType.locationUpdate) ...[
                    const SizedBox(height: 6),
                    Text(
                      entry.details,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _timelineMutedColor(context),
                      ),
                    ),
                  ],
                  _RecordingBlock(entry: entry, loc: loc, onOpenUrl: onOpenUrl),
                  if (entry.type == TimelineEntryType.fieldVisit &&
                      entry.locationPhotoUrl != null &&
                      entry.locationPhotoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final photoUrl =
                            resolveMediaUrl(entry.locationPhotoUrl!) ??
                                entry.locationPhotoUrl!;
                        return GestureDetector(
                          onTap: () => openAppImageViewer(
                            context,
                            imageUrl: photoUrl,
                            suggestedFilename:
                                mediaFilenameFromUrl(photoUrl),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              photoUrl,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if ((entry.type == TimelineEntryType.call ||
                          entry.type == TimelineEntryType.visit ||
                          entry.type == TimelineEntryType.fieldVisit) &&
                      ((entry.callDatetime != null &&
                              entry.callDatetime!.isNotEmpty) ||
                          (entry.followUpDate != null &&
                              entry.followUpDate!.isNotEmpty)))
                    _FromToDates(
                      entry: entry,
                      loc: loc,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipStyle {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  const _ChipStyle({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });
}

_ChipStyle _typeChip(TimelineEntry entry, AppLocalizations? loc) {
  String t(String key, String fallback) => loc?.translate(key) ?? fallback;

  switch (entry.type) {
    case TimelineEntryType.whatsapp:
      return _ChipStyle(
        icon: Icons.chat,
        label: t('whatsapp', 'WhatsApp'),
        fg: const Color(0xFF166534),
        bg: const Color(0xFFDCFCE7),
      );
    case TimelineEntryType.sms:
      return _ChipStyle(
        icon: Icons.sms_outlined,
        label: t('smsSentLabel', 'SMS sent'),
        fg: const Color(0xFF1E40AF),
        bg: const Color(0xFFDBEAFE),
      );
    case TimelineEntryType.call:
      return _ChipStyle(
        icon: Icons.phone,
        label: t('call', 'Call'),
        fg: const Color(0xFF3730A3),
        bg: const Color(0xFFE0E7FF),
      );
    case TimelineEntryType.visit:
      return _ChipStyle(
        icon: Icons.place_outlined,
        label: t('visit', 'Visit'),
        fg: const Color(0xFF92400E),
        bg: const Color(0xFFFEF3C7),
      );
    case TimelineEntryType.fieldVisit:
      return _ChipStyle(
        icon: Icons.map_outlined,
        label: t('fieldVisit', 'Field visit'),
        fg: const Color(0xFF065F46),
        bg: const Color(0xFFD1FAE5),
      );
    case TimelineEntryType.locationUpdate:
      return _ChipStyle(
        icon: Icons.place_outlined,
        label: entry.action.isNotEmpty
            ? entry.action
            : t('timeline', 'Timeline'),
        fg: const Color(0xFF065F46),
        bg: const Color(0xFFD1FAE5),
      );
    case TimelineEntryType.action:
      return _ChipStyle(
        icon: Icons.check_circle_outline,
        label: t('stageUpdated', 'Stage updated'),
        fg: const Color(0xFF5B21B6),
        bg: const Color(0xFFEDE9FE),
      );
    case TimelineEntryType.event:
      return _ChipStyle(
        icon: Icons.access_time,
        label: entry.fieldLabel != null
            ? t('leadEdited', 'Lead edited')
            : (entry.action.isNotEmpty
                ? entry.action
                : t('timeline', 'Timeline')),
        fg: const Color(0xFF92400E),
        bg: const Color(0xFFFEF3C7),
      );
  }
}

bool _showActionSubtitle(TimelineEntry entry, String chipLabel) {
  if (entry.action.trim().isEmpty) return false;
  if (entry.type == TimelineEntryType.whatsapp) return true;
  if (entry.type == TimelineEntryType.action) return false;
  if (entry.type == TimelineEntryType.event &&
      (entry.oldValue != null || entry.newValue != null)) {
    return false;
  }
  if (entry.type == TimelineEntryType.locationUpdate) return false;
  return entry.action != chipLabel;
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  const _Chip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == Icons.chat)
            Image.asset(
              'assets/images/whatsapp_logo.png',
              width: 12,
              height: 12,
              errorBuilder: (_, __, ___) =>
                  Icon(icon, size: 12, color: foreground),
            )
          else
            Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  final String label;
  final String? colorHex;
  final bool forceLtr;

  const _StageChip({
    required this.label,
    this.colorHex,
    this.forceLtr = false,
  });

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    return Color(int.tryParse(h, radix: 16) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parseColor(colorHex);
    final bg = parsed?.withValues(alpha: 0.12) ?? const Color(0xFFDBEAFE);
    final fg = parsed ?? const Color(0xFF1E40AF);
    final border = parsed?.withValues(alpha: 0.25) ??
        const Color(0xFF93C5FD);

    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: forceLtr ? TextDirection.ltr : null,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

class _ValueChange extends StatelessWidget {
  final String? oldValue;
  final String? newValue;
  final AppLocalizations? loc;

  const _ValueChange({
    this.oldValue,
    this.newValue,
    this.loc,
  });

  @override
  Widget build(BuildContext context) {
    if ((oldValue == null || oldValue!.isEmpty) &&
        (newValue == null || newValue!.isEmpty)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final muted = _timelineMutedColor(context);
    final accent = _timelineAccentColor(context);
    final strong = _timelineStrongColor(context);
    final hasOld = oldValue != null && oldValue!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasOld)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc?.translate('from') ?? 'From',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  oldValue!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: muted,
                    color: muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          if (newValue != null && newValue!.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc?.translate('to') ?? 'To',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  newValue!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hasOld ? accent : strong,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LocationBlock extends StatelessWidget {
  final TimelineEntry entry;
  final AppLocalizations? loc;
  final Future<void> Function(String url) onOpenUrl;

  const _LocationBlock({
    required this.entry,
    required this.loc,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final oldFmt = formatClientLocationPair(entry.oldValue);
    final newFmt = formatClientLocationPair(entry.newValue);
    final mapsUrl = clientLocationMapsUrl(entry.newValue);
    final linkColor =
        isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.4)
            : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (oldFmt != null || newFmt != null)
            _ValueChange(
              oldValue: oldFmt,
              newValue: newFmt,
              loc: loc,
            ),
          if (mapsUrl != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => onOpenUrl(mapsUrl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined, size: 14, color: linkColor),
                  const SizedBox(width: 4),
                  Text(
                    loc?.translate('openInMaps') ?? 'Open in maps',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: linkColor,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (oldFmt != null && newFmt == null) ...[
            const SizedBox(height: 4),
            Text(
              '${loc?.translate('previous') ?? 'Previous'}: $oldFmt',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _timelineMutedColor(context),
              ),
              textDirection: TextDirection.ltr,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordingBlock extends StatelessWidget {
  final TimelineEntry entry;
  final AppLocalizations? loc;
  final Future<void> Function(String url) onOpenUrl;

  const _RecordingBlock({
    required this.entry,
    required this.loc,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final status = entry.recordingStatus;
    if (status == null || status.isEmpty) return const SizedBox.shrink();

    if (status == 'ready' &&
        entry.recordingUrl != null &&
        entry.recordingUrl!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            spacing: 16,
            children: [
              InkWell(
                onTap: () => onOpenUrl(entry.recordingUrl!),
                child: Text(
                  loc?.translate('playRecording') ?? 'Play recording',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _timelineAccentColor(context),
                  ),
                ),
              ),
              InkWell(
                onTap: () => onOpenUrl(entry.recordingUrl!),
                child: Text(
                  loc?.translate('downloadRecording') ?? 'Download recording',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _timelineMutedColor(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    String? message;
    Color? color;
    if (status == 'pending' || status == 'processing') {
      message = loc?.translate('recordingProcessing') ??
          'Recording processing…';
      color = Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFBBF24)
          : const Color(0xFFB45309);
    } else if (status == 'failed') {
      message = loc?.translate('recordingUnavailable') ??
          'Recording unavailable';
    } else if (status == 'skipped') {
      message =
          loc?.translate('recordingSkipped') ?? 'No recording for this call';
    }
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          color: color ?? _timelineMutedColor(context),
        ),
      ),
    );
  }
}

class _FromToDates extends StatelessWidget {
  final TimelineEntry entry;
  final AppLocalizations? loc;

  const _FromToDates({required this.entry, required this.loc});

  @override
  Widget build(BuildContext context) {
    final from = entry.callDatetime;
    final to = entry.followUpDate;
    if ((from == null || from.isEmpty) && (to == null || to.isEmpty)) {
      return const SizedBox.shrink();
    }

    Color fromBg;
    Color fromFg;
    Color fromBorder;
    IconData fromIcon;
    switch (entry.type) {
      case TimelineEntryType.visit:
        fromBg = const Color(0xFFFFFBEB);
        fromFg = const Color(0xFF92400E);
        fromBorder = const Color(0xFFFDE68A);
        fromIcon = Icons.place_outlined;
        break;
      case TimelineEntryType.fieldVisit:
        fromBg = const Color(0xFFECFDF5);
        fromFg = const Color(0xFF065F46);
        fromBorder = const Color(0xFFA7F3D0);
        fromIcon = Icons.map_outlined;
        break;
      default:
        fromBg = const Color(0xFFEFF6FF);
        fromFg = const Color(0xFF1D4ED8);
        fromBorder = const Color(0xFFBFDBFE);
        fromIcon = Icons.phone;
    }

    final showFromToWords =
        from != null && from.isNotEmpty && to != null && to.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (from != null && from.isNotEmpty)
            _DatePill(
              label: from,
              prefix: showFromToWords
                  ? (loc?.translate('from') ?? 'From')
                  : null,
              bg: fromBg,
              fg: fromFg,
              border: fromBorder,
              icon: fromIcon,
            ),
          if (to != null && to.isNotEmpty)
            _DatePill(
              label: to,
              prefix: showFromToWords ? (loc?.translate('to') ?? 'To') : null,
              bg: const Color(0xFFF0FDF4),
              fg: const Color(0xFF15803D),
              border: const Color(0xFFBBF7D0),
              icon: Icons.access_time,
            ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  final String label;
  final String? prefix;
  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;

  const _DatePill({
    required this.label,
    this.prefix,
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefix != null) ...[
            Text(
              prefix!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
