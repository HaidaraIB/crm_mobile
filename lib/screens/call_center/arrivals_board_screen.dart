import 'package:flutter/material.dart';
// intl exports its own TextDirection, which would shadow dart:ui's on the phone row.
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_locales.dart';
import '../../models/lead_arrival_model.dart';
import '../../services/api_service.dart';
import '../../widgets/app_switch.dart';

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

  /// Sheet-owned filters, mirroring the web board: day (null = today) and scope.
  DateTime? _date;
  bool _mineOnly = false;

  /// Committed search term. Client-side (the endpoint has no search param) and
  /// submit-gated: typing never re-filters the board under the user's finger.
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  bool get _hasSheetFilters => _date != null || _mineOnly;

  /// Anything narrowing the board, search bar included — decides which empty
  /// state to show.
  bool get _isNarrowed => _hasSheetFilters || _search.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        date: _date == null ? null : DateFormat('yyyy-MM-dd').format(_date!),
        mine: _mineOnly,
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

  /// Search runs on submit only, like the reception search screen — a walk-in
  /// board must not reshuffle while a name is half-typed.
  void _submitSearch() {
    final term = _searchController.text.trim();
    if (term == _search) return;
    FocusScope.of(context).unfocus();
    setState(() => _search = term);
  }

  void _clearSearch() {
    _searchController.clear();
    if (_search.isEmpty) return;
    setState(() => _search = '');
  }

  /// Name/phone match. Phones compare on digits only so "0770 12" still finds
  /// "+96477012…".
  bool _matchesSearch(LeadArrivalModel arrival) {
    final query = _search.toLowerCase();
    if (query.isEmpty) return true;
    if (arrival.clientName.toLowerCase().contains(query)) return true;
    final phone = arrival.clientPhone ?? '';
    if (phone.toLowerCase().contains(query)) return true;
    final queryDigits = query.replaceAll(RegExp(r'\D'), '');
    if (queryDigits.isEmpty) return false;
    return phone.replaceAll(RegExp(r'\D'), '').contains(queryDigits);
  }

  List<_GroupedArrival> get _grouped {
    final byClient = <int, List<LeadArrivalModel>>{};
    for (final arrival in _arrivals) {
      if (!_matchesSearch(arrival)) continue;
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
            icon: Badge(
              // Dot only for what the sheet owns — the status chips and the search
              // bar are already visible on screen and don't need an indicator.
              isLabelVisible: _hasSheetFilters,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: localizations?.translate('filterArrivals') ?? 'Filter arrivals',
            onPressed: () => _openFilterSheet(localizations),
          ),
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
          _buildSearchBar(localizations),
          _buildFilterBar(localizations),
          if (_hasSheetFilters) _buildActiveFilterSummary(localizations),
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

  /// Customer search, above the status chips and gated on submit. Mirrors the
  /// reception search screen so the two front-desk screens behave the same.
  Widget _buildSearchBar(AppLocalizations? localizations) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      // Rebuilds per keystroke so the clear/submit affordances track the field,
      // without a keystroke ever re-filtering the board.
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, _) {
          final draft = value.text.trim();
          final canSubmit = draft != _search;
          return Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitSearch(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText:
                        localizations?.translate('searchLeadByNameOrPhone') ??
                        'Search by name or phone',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            tooltip: localizations?.translate('clear') ?? 'Clear',
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                // Matches the dense field's height so the row doesn't read as two
                // mismatched controls.
                height: 48,
                child: ElevatedButton(
                  onPressed: canSubmit ? _submitSearch : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.45,
                    ),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(localizations?.translate('search') ?? 'Search'),
                ),
              ),
            ],
          );
        },
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

  /// Applied day/scope stay on screen: the board otherwise defaults to today, so
  /// an empty filtered result reads as "nobody arrived today".
  Widget _buildActiveFilterSummary(AppLocalizations? localizations) {
    final theme = Theme.of(context);
    final chips = <String>[
      if (_date != null)
        '${localizations?.translate('date') ?? 'Date'}: ${_formatDate(_date!)}',
      if (_mineOnly)
        localizations?.translate('arrivalScopeMine') ?? 'Mine',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final chip in chips)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(chip, style: theme.textTheme.bodySmall),
            ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _clearSheetFilters,
            child: Text(
              localizations?.translate('clearFilters') ?? 'Clear filters',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearSheetFilters() {
    setState(() {
      _date = null;
      _mineOnly = false;
    });
    _load(showSpinner: false);
  }

  String _formatDate(DateTime value) {
    final locale = Localizations.localeOf(context);
    return DateFormat.yMMMd(AppLocales.intlDateFormat(locale)).format(value);
  }

  /// Day and scope, with draft state discarded unless Apply is pressed — the same
  /// contract as the web filter drawer. Search lives in the bar on the board.
  Future<void> _openFilterSheet(AppLocalizations? localizations) async {
    DateTime? draftDate = _date;
    bool draftMine = _mineOnly;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations?.translate('filterArrivals') ?? 'Filter arrivals',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations?.translate('date') ?? 'Date',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: draftDate ?? now,
                        // The board is a daily log: future days are always empty.
                        firstDate: DateTime(now.year - 2),
                        lastDate: now,
                      );
                      if (picked != null) {
                        setSheetState(() => draftDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      draftDate == null
                          ? (localizations?.translate('today') ?? 'Today')
                          : _formatDate(draftDate!),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizations?.translate('arrivalDateFilterHint') ??
                              'Leave empty to show today.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                      if (draftDate != null)
                        TextButton(
                          onPressed: () => setSheetState(() => draftDate = null),
                          child: Text(
                            localizations?.translate('today') ?? 'Today',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizations?.translate('arrivalScope') ?? 'Scope',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  // Shared toggle: its own high-contrast track/thumb colors, so the
                  // switch stays readable on the dark sheet.
                  AppSwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: draftMine,
                    title: Text(
                      localizations?.translate('arrivalScopeMine') ??
                          'Mine (announced or notified)',
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      localizations?.translate('arrivalScopeMineHint') ??
                          'Only arrivals you announced or were notified about.',
                      style: theme.textTheme.bodySmall,
                    ),
                    onChanged: (value) => setSheetState(() => draftMine = value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              draftDate = null;
                              draftMine = false;
                            });
                          },
                          child: Text(
                            localizations?.translate('reset') ?? 'Reset',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          child: Text(
                            localizations?.translate('apply') ?? 'Apply',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (applied != true || !mounted) return;
    if (draftDate == _date && draftMine == _mineOnly) return;

    setState(() {
      _date = draftDate;
      _mineOnly = draftMine;
    });
    // Both axes are server-side, so an applied change always needs a reload.
    _load(showSpinner: false);
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
            _isNarrowed
                ? (localizations?.translate('noArrivalsMatchFilters') ??
                      'No arrivals match these filters.')
                : (localizations?.translate('noArrivalsToday') ??
                      'No arrivals today.'),
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
