import 'package:flutter/material.dart';
// intl exports its own TextDirection, which would shadow dart:ui's on the phone row.
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_locales.dart';
import '../../models/lead_arrival_model.dart';
import '../../services/api_service.dart';

class _GroupedArrival {
  final LeadArrivalModel latest;
  final int count;
  _GroupedArrival(this.latest, this.count);
}

/// Server-side status filter, mirroring the web board's chips.
enum _ArrivalFilter { all, waiting, acknowledged, escalated }

/// Today's walk-in arrivals board. Groups consecutive announcements for the
/// same lead into one row so a re-announce inside the cooldown window doesn't
/// clutter the board with duplicate entries.
class ArrivalsBoardScreen extends StatefulWidget {
  const ArrivalsBoardScreen({super.key});

  @override
  State<ArrivalsBoardScreen> createState() => _ArrivalsBoardScreenState();
}

class _ArrivalsBoardScreenState extends State<ArrivalsBoardScreen> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  bool _refreshing = false;
  List<LeadArrivalModel> _arrivals = const [];
  final Set<int> _acknowledgingIds = {};
  _ArrivalFilter _filter = _ArrivalFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [showSpinner] false keeps the current rows on screen (filter switch, pull to
  /// refresh, post-acknowledge reload) instead of flashing a full-screen spinner.
  Future<void> _load({bool showSpinner = true}) async {
    setState(() {
      if (showSpinner) {
        _loading = true;
      } else {
        _refreshing = true;
      }
    });
    try {
      final arrivals = await _apiService.getLeadArrivals(
        status: _filter == _ArrivalFilter.all ? null : _filter.name,
      );
      if (!mounted) return;
      setState(() {
        _arrivals = arrivals;
        _loading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _acknowledge(LeadArrivalModel arrival) async {
    setState(() => _acknowledgingIds.add(arrival.id));
    try {
      await _apiService.acknowledgeLeadArrival(arrival.id);
      await _load(showSpinner: false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _acknowledgingIds.remove(arrival.id));
    }
  }

  void _selectFilter(_ArrivalFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _load(showSpinner: false);
  }

  List<_GroupedArrival> get _grouped {
    final byClient = <int, List<LeadArrivalModel>>{};
    for (final arrival in _arrivals) {
      byClient.putIfAbsent(arrival.client, () => []).add(arrival);
    }
    final groups = byClient.values.map((list) {
      final sorted = [...list]
        ..sort((a, b) => b.announcedAt.compareTo(a.announcedAt));
      return _GroupedArrival(sorted.first, sorted.length);
    }).toList();
    groups.sort((a, b) => b.latest.announcedAt.compareTo(a.latest.announcedAt));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final groups = _grouped;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('arrivals') ?? 'Arrivals'),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: localizations?.translate('refresh') ?? 'Refresh',
            onPressed: _refreshing ? null : () => _load(showSpinner: false),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(localizations),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(showSpinner: false),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : groups.isEmpty
                  ? _buildEmptyState(localizations)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: groups.length,
                      itemBuilder: (context, index) =>
                          _buildArrivalCard(groups[index], localizations),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppLocalizations? localizations) {
    String label(_ArrivalFilter filter) {
      switch (filter) {
        case _ArrivalFilter.all:
          return localizations?.translate('all') ?? 'All';
        case _ArrivalFilter.waiting:
          return localizations?.translate('arrivalWaiting') ?? 'Waiting';
        case _ArrivalFilter.acknowledged:
          return localizations?.translate('arrivalAcknowledged') ??
              'Acknowledged';
        case _ArrivalFilter.escalated:
          return localizations?.translate('arrivalEscalated') ?? 'Escalated';
      }
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final filter in _ArrivalFilter.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(label(filter)),
                selected: _filter == filter,
                onSelected: (_) => _selectFilter(filter),
                // Brand purple for the active chip instead of the M3 seed's
                // secondaryContainer, which lands on the same pale lavender.
                selectedColor: AppTheme.primaryColor,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _filter == filter
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations? localizations) {
    final theme = Theme.of(context);
    // Scrollable so pull-to-refresh still works with nothing on the board.
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Icon(
            Icons.event_available_outlined,
            size: 56,
            color: theme.disabledColor,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            localizations?.translate('noArrivalsToday') ?? 'No arrivals today.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArrivalCard(
    _GroupedArrival group,
    AppLocalizations? localizations,
  ) {
    final theme = Theme.of(context);
    final arrival = group.latest;
    final isAcknowledging = _acknowledgingIds.contains(arrival.id);
    final accent = _statusColor(arrival);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );

    return Card(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      // Status stripe: scannable at a glance on a board that is mostly read from
      // across the front desk. A border rather than a stretched Row child — the
      // card's height is unbounded here, so stretch would force h=Infinity on it.
      // BorderDirectional keeps the stripe on the leading edge in both LTR and RTL.
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: accent, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      arrival.clientName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_formatTime(arrival.announcedAt), style: mutedStyle),
                ],
              ),
              if (arrival.clientPhone != null &&
                  arrival.clientPhone!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  arrival.clientPhone!,
                  // E.164 needs an explicit LTR run or the leading + jumps in RTL.
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: mutedStyle,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildBadge(_statusLabel(arrival, localizations), accent),
                  if (arrival.isAssigneeOffShift && !arrival.isAcknowledged)
                    _buildBadge(
                      localizations?.translate('arrivalAssigneeOffShift') ??
                          'Assignee off-shift',
                      Colors.orange,
                    ),
                  if (group.count > 1) _buildRepeatBadge(group.count),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _metaLine(arrival, localizations),
                style: mutedStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!arrival.isAcknowledged)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ElevatedButton.icon(
                      // Brand purple, not M3's pale-lavender FilledButton default.
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.primaryColor
                            .withValues(alpha: 0.45),
                        disabledForegroundColor: Colors.white70,
                      ),
                      onPressed: isAcknowledging
                          ? null
                          : () => _acknowledge(arrival),
                      icon: isAcknowledging
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      // No fixed width: "Understood" and its Arabic/longer
                      // translations wrapped mid-word inside the old 100px box.
                      label: Text(
                        localizations?.translate('understood') ?? 'Understood',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  /// Repeat announcements — the old bare "(6×)" next to the name read as noise.
  Widget _buildRepeatBadge(int count) {
    final theme = Theme.of(context);
    final color = theme.textTheme.bodySmall?.color ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final locale = Localizations.localeOf(context);
    return DateFormat(
      'h:mm a',
      AppLocales.intlDateFormat(locale),
    ).format(value.toLocal());
  }

  /// "Announced by X · Notified: Y, Z" — same provenance the web board shows.
  String _metaLine(LeadArrivalModel arrival, AppLocalizations? localizations) {
    final announcedBy =
        localizations?.translate('arrivalAnnouncedBy') ?? 'Announced by';
    final notifiedTo =
        localizations?.translate('arrivalNotifiedTo') ?? 'Notified';
    final by = arrival.announcedByName?.trim();
    final notified = arrival.notifiedUserNames.join(', ');
    return '$announcedBy: ${by == null || by.isEmpty ? '—' : by} · '
        '$notifiedTo: ${notified.isEmpty ? '—' : notified}';
  }

  /// Status only. Off-shift is a separate badge (as on the web board), so it must
  /// not also stand in for the status or the row shows the same word twice.
  Color _statusColor(LeadArrivalModel arrival) {
    if (arrival.isAcknowledged) return Colors.green;
    if (arrival.isEscalated) return Colors.red;
    return Colors.amber.shade700;
  }

  String _statusLabel(
    LeadArrivalModel arrival,
    AppLocalizations? localizations,
  ) {
    if (arrival.isAcknowledged) {
      return localizations?.translate('arrivalAcknowledged') ?? 'Acknowledged';
    }
    if (arrival.isEscalated) {
      return localizations?.translate('arrivalEscalated') ?? 'Escalated';
    }
    return localizations?.translate('arrivalWaiting') ?? 'Waiting';
  }
}
