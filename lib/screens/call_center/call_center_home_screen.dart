import 'package:flutter/material.dart' hide NavigationDrawer;
import '../../core/api/api_envelope.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lead_model.dart';
import '../../services/api_service.dart';
import '../../widgets/navigation_drawer.dart';
import '../leads/create_lead_screen.dart';
import '../notifications/notifications_screen.dart';

/// Front-desk lead search for the CALL_CENTER role: search all company leads by
/// name/phone, announce a walk-in's arrival, or jump to Create Lead when nobody
/// is found.
class CallCenterHomeScreen extends StatefulWidget {
  const CallCenterHomeScreen({super.key, this.isRoot = false});

  /// True when this is the landing screen for a CALL_CENTER user (pushed from
  /// [HomeScreen] instead of the tab shell). Adds the app drawer, which is the
  /// role's only route to profile, support and logout.
  final bool isRoot;

  @override
  State<CallCenterHomeScreen> createState() => _CallCenterHomeScreenState();
}

class _CallCenterHomeScreenState extends State<CallCenterHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _loading = false;
  bool _searched = false;
  List<LeadModel> _results = const [];
  final Set<int> _announcingIds = {};
  final Set<int> _announcedIds = {};
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isRoot) _loadUnreadCount();
  }

  Future<void> _loadUnreadCount({bool forceRefresh = false}) async {
    try {
      final count = await _apiService.getUnreadNotificationsCount(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() => _unreadNotificationsCount = count);
    } catch (e) {
      debugPrint('Warning: Failed to load unread notifications count: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Search runs on submit only — the old keystroke debounce fired a request per
  /// pause while typing a name or a 13-digit phone number.
  void _submitSearch() {
    final term = _searchController.text.trim();
    if (term.isEmpty) {
      setState(() {
        _searched = false;
        _results = const [];
      });
      return;
    }
    FocusScope.of(context).unfocus();
    _runSearch(term);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searched = false;
      _results = const [];
    });
  }

  Future<void> _runSearch(String term) async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final data = await _apiService.getLeads(search: term, forceRefresh: true);
      final results = (data['results'] as List<LeadModel>?) ?? const [];
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  Future<void> _announceArrival(LeadModel lead) async {
    setState(() => _announcingIds.add(lead.id));
    final localizations = AppLocalizations.of(context);
    try {
      await _apiService.announceLeadArrival(clientId: lead.id);
      if (!mounted) return;
      setState(() {
        _announcingIds.remove(lead.id);
        _announcedIds.add(lead.id);
      });
    } on ApiEnvelopeException catch (e) {
      if (!mounted) return;
      setState(() => _announcingIds.remove(lead.id));
      if (e.code == 'arrival_cooldown_active') {
        setState(() => _announcedIds.add(lead.id));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _announcingIds.remove(lead.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.translate('error') ?? 'Something went wrong',
          ),
        ),
      );
    }
  }

  void _openCreateLead() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateLeadScreen()),
    );
  }

  Widget _notificationsAppBarAction(AppLocalizations? localizations) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: localizations?.translate('notifications') ?? 'Notifications',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            if (mounted) _loadUnreadCount(forceRefresh: true);
          },
        ),
        if (_unreadNotificationsCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadNotificationsCount > 99
                    ? '99+'
                    : '$_unreadNotificationsCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      drawer: widget.isRoot ? const NavigationDrawer() : null,
      appBar: AppBar(
        title: Text(localizations?.translate('callCenter') ?? 'Call Center'),
        actions: [
          // Arrivals lives in the drawer (like the web sidebar). This slot keeps the
          // notifications bell every other role has in the same place — landing here
          // is otherwise a call-center user's only screen, with no route to them.
          if (widget.isRoot) _notificationsAppBarAction(localizations),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Rebuilds on every keystroke so the clear/submit affordances track the
            // field, without a keystroke ever triggering a request.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _submitSearch(),
                        decoration: InputDecoration(
                          hintText:
                              localizations?.translate(
                                'searchLeadByNameOrPhone',
                              ) ??
                              'Search by name or phone',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip:
                                      localizations?.translate('clear') ??
                                      'Clear',
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
                      // Matches the outlined field's default height so the row
                      // doesn't read as two mismatched controls.
                      height: 56,
                      child: ElevatedButton(
                        onPressed: hasText && !_loading ? _submitSearch : null,
                        style: _primaryButtonStyle.copyWith(
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 16),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                localizations?.translate('search') ?? 'Search',
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody(localizations)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations? localizations) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_searched) {
      return _buildPlaceholder(
        icon: Icons.person_search_outlined,
        message:
            localizations?.translate('searchLeadByNameOrPhone') ??
            'Search by name or phone to find a lead.',
      );
    }
    if (_results.isEmpty) {
      return _buildPlaceholder(
        icon: Icons.search_off,
        message:
            localizations?.translate('leadNotFoundCreateOne') ??
            'No matching lead found.',
        action: ElevatedButton.icon(
          style: _primaryButtonStyle,
          onPressed: _openCreateLead,
          icon: const Icon(Icons.add),
          label: Text(localizations?.translate('createLead') ?? 'Create Lead'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) =>
          _buildResultCard(_results[index], localizations),
    );
  }

  Widget _buildPlaceholder({
    required IconData icon,
    required String message,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: theme.disabledColor),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }

  /// Solid brand purple with white text — the convention across this app. M3's
  /// FilledButton default resolves the seed to a pale lavender on the dark theme,
  /// which reads as disabled next to everything else.
  ButtonStyle get _primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primaryColor,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.45),
    disabledForegroundColor: Colors.white70,
  );

  Widget _buildResultCard(LeadModel lead, AppLocalizations? localizations) {
    final theme = Theme.of(context);
    final assigned = lead.assignedTo != 0;
    final isAnnouncing = _announcingIds.contains(lead.id);
    final isAnnounced = _announcedIds.contains(lead.id);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  // Solid brand purple with a white glyph — the 15%-alpha tint on
                  // top of a dark card left the initial barely legible.
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    _initial(lead.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lead.phone.isNotEmpty)
                        Text(
                          lead.phone,
                          // E.164 needs an explicit LTR run or the leading + jumps in RTL.
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.start,
                          style: mutedStyle,
                        ),
                      const SizedBox(height: 6),
                      // Who the walk-in belongs to, by name — the web board shows
                      // assigned_to_username here, and "Assigned" alone doesn't tell
                      // the desk which colleague to go and fetch.
                      if (assigned)
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: mutedStyle?.color,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lead.assignedToName?.trim().isNotEmpty == true
                                    ? lead.assignedToName!
                                    : (localizations?.translate('assigned') ??
                                          'Assigned'),
                                style: mutedStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      else
                        _buildBadge(
                          localizations?.translate('unassigned') ??
                              'Unassigned',
                          Colors.orange,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: isAnnounced
                  // Confirmation stays on the row so the agent can see at a glance
                  // which of several look-alike results they already announced.
                  ? _buildBadge(
                      localizations?.translate('arrivalAnnouncedToast') ??
                          'Arrival announced',
                      Colors.green,
                      icon: Icons.check_circle,
                    )
                  : ElevatedButton.icon(
                      style: _primaryButtonStyle,
                      onPressed: isAnnouncing
                          ? null
                          : () => _announceArrival(lead),
                      icon: isAnnouncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.campaign_outlined, size: 18),
                      // No fixed width: the label and its Arabic translation were
                      // wrapping mid-word inside the old 110px box.
                      label: Text(
                        localizations?.translate('announceArrival') ??
                            'Customer arrived',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
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

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
