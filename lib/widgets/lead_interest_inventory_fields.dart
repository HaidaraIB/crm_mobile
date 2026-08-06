import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../models/inventory_model.dart';
import '../services/api_service.dart';

/// Cascading developer → project → unit pickers for real-estate lead interest.
class LeadInterestInventoryFields extends StatefulWidget {
  const LeadInterestInventoryFields({
    super.key,
    required this.interestedDeveloper,
    required this.interestedProject,
    required this.interestedUnit,
    required this.onChanged,
  });

  final int? interestedDeveloper;
  final int? interestedProject;
  final int? interestedUnit;
  final void Function({
    int? developer,
    int? project,
    int? unit,
  }) onChanged;

  @override
  State<LeadInterestInventoryFields> createState() =>
      _LeadInterestInventoryFieldsState();
}

class _LeadInterestInventoryFieldsState
    extends State<LeadInterestInventoryFields> {
  final _api = ApiService();
  List<Developer> _developers = [];
  List<Project> _projects = [];
  List<Unit> _units = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final developers = await _api.getDevelopers();
      final projects = await _api.getProjects();
      final units = await _api.getUnits();
      if (!mounted) return;
      setState(() {
        _developers = developers;
        _projects = projects;
        _units = units;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Project> get _filteredProjects {
    final devId = widget.interestedDeveloper;
    if (devId == null) return const [];
    return _projects.where((p) => p.developerId == devId).toList();
  }

  List<Unit> get _filteredUnits {
    final projId = widget.interestedProject;
    if (projId == null) return const [];
    return _units.where((u) => u.projectId == projId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final none =
        localizations?.translate('noneOptional') ?? '— (optional)';

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations?.translate('leadInventoryInterest') ??
              'Property interest (optional)',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          key: ValueKey('dev-${widget.interestedDeveloper}'),
          initialValue: widget.interestedDeveloper,
          decoration: InputDecoration(
            labelText:
                localizations?.translate('interestedDeveloper') ?? 'Developer',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(none)),
            ..._developers.map(
              (d) => DropdownMenuItem<int?>(
                value: d.id,
                child: Text(d.name),
              ),
            ),
          ],
          onChanged: (v) {
            widget.onChanged(developer: v, project: null, unit: null);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          key: ValueKey(
            'proj-${widget.interestedDeveloper}-${widget.interestedProject}',
          ),
          initialValue: widget.interestedProject,
          decoration: InputDecoration(
            labelText:
                localizations?.translate('interestedProject') ?? 'Project',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(none)),
            ..._filteredProjects.map(
              (p) => DropdownMenuItem<int?>(
                value: p.id,
                child: Text(p.name),
              ),
            ),
          ],
          onChanged: widget.interestedDeveloper == null
              ? null
              : (v) {
                  widget.onChanged(
                    developer: widget.interestedDeveloper,
                    project: v,
                    unit: null,
                  );
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          key: ValueKey(
            'unit-${widget.interestedProject}-${widget.interestedUnit}',
          ),
          initialValue: widget.interestedUnit,
          decoration: InputDecoration(
            labelText: localizations?.translate('interestedUnit') ?? 'Unit',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(none)),
            ..._filteredUnits.map(
              (u) => DropdownMenuItem<int?>(
                value: u.id,
                child: Text(
                  u.code.isNotEmpty ? '${u.name} (${u.code})' : u.name,
                ),
              ),
            ),
          ],
          onChanged: widget.interestedProject == null
              ? null
              : (v) {
                  widget.onChanged(
                    developer: widget.interestedDeveloper,
                    project: widget.interestedProject,
                    unit: v,
                  );
                },
        ),
      ],
    );
  }
}
