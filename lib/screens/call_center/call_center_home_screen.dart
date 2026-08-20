import 'dart:async';

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
  Timer? _debounce;

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
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final term = value.trim();
      if (term.isEmpty) {
        setState(() {
          _searched = false;
          _results = const [];
        });
        return;
      }
      _runSearch(term);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
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
            TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText:
                    localizations?.translate('searchLeadByNameOrPhone') ??
                    'Search by name or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searched = false;
                            _results = const [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
      return Center(
        child: Text(
          localizations?.translate('searchLeadByNameOrPhone') ??
              'Search by name or phone to find a lead.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              localizations?.translate('leadNotFoundCreateOne') ??
                  'No matching lead found.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openCreateLead,
              icon: const Icon(Icons.add),
              label: Text(localizations?.translate('createLead') ?? 'Create Lead'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final lead = _results[index];
        final assigned = lead.assignedTo != 0;
        final isAnnouncing = _announcingIds.contains(lead.id);
        final isAnnounced = _announcedIds.contains(lead.id);
        return ListTile(
          title: Text(lead.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lead.phone, textDirection: TextDirection.ltr),
              Text(
                assigned
                    ? (localizations?.translate('assigned') ?? 'Assigned')
                    : (localizations?.translate('unassigned') ?? 'Unassigned'),
                style: TextStyle(
                  color: assigned ? Colors.grey : Colors.orange,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          trailing: isAnnounced
              ? Text(
                  localizations?.translate('arrivalAnnouncedToast') ??
                      'Arrival announced',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                )
              : SizedBox(
                  width: 110,
                  child: ElevatedButton(
                    onPressed: isAnnouncing ? null : () => _announceArrival(lead),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: isAnnouncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            localizations?.translate('announceArrival') ??
                                'Customer arrived',
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                  ),
                ),
        );
      },
    );
  }
}
