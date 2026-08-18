import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/lead_arrival_model.dart';
import '../../services/api_service.dart';

class _GroupedArrival {
  final LeadArrivalModel latest;
  final int count;
  _GroupedArrival(this.latest, this.count);
}

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
  List<LeadArrivalModel> _arrivals = const [];
  final Set<int> _acknowledgingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final arrivals = await _apiService.getLeadArrivals();
      if (!mounted) return;
      setState(() {
        _arrivals = arrivals;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _acknowledge(LeadArrivalModel arrival) async {
    setState(() => _acknowledgingIds.add(arrival.id));
    try {
      await _apiService.acknowledgeLeadArrival(arrival.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _acknowledgingIds.remove(arrival.id));
    }
  }

  List<_GroupedArrival> get _grouped {
    final byClient = <int, List<LeadArrivalModel>>{};
    for (final arrival in _arrivals) {
      byClient.putIfAbsent(arrival.client, () => []).add(arrival);
    }
    final groups = byClient.values.map((list) {
      final sorted = [...list]..sort((a, b) => b.announcedAt.compareTo(a.announcedAt));
      return _GroupedArrival(sorted.first, sorted.length);
    }).toList();
    groups.sort((a, b) => b.latest.announcedAt.compareTo(a.latest.announcedAt));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('arrivals') ?? 'Arrivals'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _grouped.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      localizations?.translate('noArrivalsToday') ??
                          'No arrivals today.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                itemCount: _grouped.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final group = _grouped[index];
                  final arrival = group.latest;
                  final isAcknowledging = _acknowledgingIds.contains(arrival.id);
                  return ListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(arrival.clientName)),
                        if (group.count > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '(${group.count}×)',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (arrival.clientPhone != null)
                          Text(arrival.clientPhone!, textDirection: TextDirection.ltr),
                        Text(_statusLabel(arrival, localizations)),
                      ],
                    ),
                    trailing: arrival.isAcknowledged
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : SizedBox(
                            width: 100,
                            child: ElevatedButton(
                              onPressed: isAcknowledging
                                  ? null
                                  : () => _acknowledge(arrival),
                              child: isAcknowledging
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      localizations?.translate('understood') ?? 'Understood',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                            ),
                          ),
                  );
                },
              ),
      ),
    );
  }

  String _statusLabel(LeadArrivalModel arrival, AppLocalizations? localizations) {
    if (arrival.isAcknowledged) {
      return localizations?.translate('arrivalAcknowledged') ?? 'Acknowledged';
    }
    if (arrival.isEscalated) {
      return localizations?.translate('arrivalEscalated') ?? 'Escalated';
    }
    if (arrival.isAssigneeOffShift) {
      return localizations?.translate('arrivalAssigneeOffShift') ?? 'Assignee off-shift';
    }
    return localizations?.translate('arrivalWaiting') ?? 'Waiting';
  }
}
