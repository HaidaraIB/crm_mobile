import 'package:flutter/material.dart';
import '../../core/forms/catalog_form_binding.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/seed_labels.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import 'package:crm_mobile/widgets/auto_dir_text_field.dart';

class AddVisitModal extends StatefulWidget {
  final int leadId;
  final void Function(int visitTypeId, String summary, DateTime? upcoming)? onSave;

  const AddVisitModal({
    super.key,
    required this.leadId,
    this.onSave,
  });

  @override
  State<AddVisitModal> createState() => _AddVisitModalState();
}

class _AddVisitModalState extends State<AddVisitModal> {
  final ApiService _apiService = ApiService();
  final _catalog = CatalogFormBinding('lead_visit.create');
  final _summaryFocus = FocusNode();
  int? _selectedVisitTypeId;
  final TextEditingController _summaryController = TextEditingController();
  final Map<String, String> _errors = {};
  DateTime? _visitDatetime;
  bool _hasUpcomingVisit = false;
  DateTime? _upcomingVisitDate;
  List<VisitTypeModel> _visitTypes = [];
  bool _isLoadingVisitTypes = true;
  String? _visitTypesError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _catalog.load();
    _catalog.watch(_summaryFocus, 'notes', () async {
      await _catalog.validate(context, _visitValues(), only: 'notes');
      if (mounted) setState(() => _errors..clear()..addAll(_catalog.errors));
    });
    _loadVisitTypes();
  }

  Map<String, dynamic> _visitValues() => {
        'visitType': _selectedVisitTypeId,
        'notes': _summaryController.text,
        'visitDate': _visitDatetime?.toIso8601String() ?? '',
      };

  Future<void> _loadVisitTypes() async {
    try {
      setState(() {
        _isLoadingVisitTypes = true;
        _visitTypesError = null;
      });
      final list = await _apiService.getVisitTypes();
      if (!mounted) return;
      setState(() {
        _visitTypes = list;
        if (_selectedVisitTypeId == null && list.isNotEmpty) {
          VisitTypeModel? def;
          for (final v in list) {
            if (v.isDefault) {
              def = v;
              break;
            }
          }
          _selectedVisitTypeId = (def ?? list.first).id;
        }
        _isLoadingVisitTypes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _visitTypesError = e.toString();
        _isLoadingVisitTypes = false;
      });
    }
  }

  @override
  void dispose() {
    _summaryFocus.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _selectVisitDatetime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDatetime ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (!mounted) return;
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _visitDatetime != null
            ? TimeOfDay.fromDateTime(_visitDatetime!)
            : TimeOfDay.now(),
      );
      if (!mounted) return;
      if (time != null) {
        setState(() {
          _visitDatetime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _setVisitDatetimeToNow() {
    setState(() {
      _visitDatetime = DateTime.now();
    });
  }

  Future<void> _selectUpcomingVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _upcomingVisitDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (!mounted) return;
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _upcomingVisitDate != null
            ? TimeOfDay.fromDateTime(_upcomingVisitDate!)
            : TimeOfDay.now(),
      );
      if (!mounted) return;
      if (time != null) {
        setState(() {
          _upcomingVisitDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    final localizations = AppLocalizations.of(context);
    final valid = await _catalog.validate(context, _visitValues());
    if (!valid) {
      if (mounted) {
        setState(() {
          _errors
            ..clear()
            ..addAll(_catalog.errors);
        });
      }
      return;
    }
    if (_hasUpcomingVisit && _upcomingVisitDate == null) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        localizations?.translate('upcomingVisitDateRequired') ??
            'Please select an upcoming visit date',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _apiService.addVisitToLead(
        leadId: widget.leadId,
        visitType: _selectedVisitTypeId!,
        summary: _summaryController.text.trim(),
        visitDatetime: _visitDatetime!,
        upcomingVisitDate: _hasUpcomingVisit ? _upcomingVisitDate : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      SnackbarHelper.showSuccess(
        context,
        localizations?.translate('visitAdded') ?? 'Visit added successfully',
      );
      widget.onSave?.call(
        _selectedVisitTypeId!,
        _summaryController.text.trim(),
        _hasUpcomingVisit ? _upcomingVisitDate : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (e is ApiFieldException && _catalog.applyApiError(localizations, e)) {
        setState(() {
          _errors
            ..clear()
            ..addAll(_catalog.errors);
        });
        return;
      }
      SnackbarHelper.showError(
        context,
        '${localizations?.translate('failedToAddVisit') ?? 'Failed to add visit'}: ${e.toString()}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      localizations?.translate('addVisit') ?? 'Add Visit',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localizations?.translate('visitType') ?? 'Visit type',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingVisitTypes)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_visitTypesError != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _visitTypesError!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                          TextButton.icon(
                            onPressed: _loadVisitTypes,
                            icon: const Icon(Icons.refresh),
                            label: Text(localizations?.translate('retry') ?? 'Retry'),
                          ),
                        ],
                      )
                    else if (_visitTypes.isEmpty)
                      Text(
                        localizations?.translate('noVisitTypesFound') ?? 'No visit types found',
                        style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _selectedVisitTypeId,
                        decoration: InputDecoration(
                          hintText: localizations?.translate('selectItem') ?? 'Select',
                          errorText: _errors['visitType'],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _visitTypes
                            .map(
                              (v) => DropdownMenuItem<int>(
                                value: v.id,
                                child: Text(seedLabel(v.name, localizations?.locale.languageCode)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedVisitTypeId = v),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      localizations?.translate('visitSummary') ?? 'Summary',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    AutoDirTextField(
                      controller: _summaryController,
                      focusNode: _summaryFocus,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            localizations?.translate('visitSummaryHint') ?? 'Describe the visit…',
                        errorText: _errors['notes'],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      localizations?.translate('visitDay') ?? 'Visit day',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectVisitDatetime,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _visitDatetime != null
                                  ? _visitDatetime!.toString().substring(0, 16)
                                  : localizations?.translate('selectVisitDay') ?? 'Select visit day',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _setVisitDatetimeToNow,
                          icon: const Icon(Icons.access_time),
                          label: Text(localizations?.translate('now') ?? 'Now'),
                        ),
                      ],
                    ),
                    if (_errors['visitDate'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _errors['visitDate']!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        localizations?.translate('hasUpcomingVisit') ?? 'Schedule an upcoming visit',
                      ),
                      value: _hasUpcomingVisit,
                      onChanged: (v) {
                        setState(() {
                          _hasUpcomingVisit = v ?? false;
                          if (!_hasUpcomingVisit) _upcomingVisitDate = null;
                        });
                      },
                    ),
                    if (_hasUpcomingVisit) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _selectUpcomingVisitDate,
                          icon: const Icon(Icons.event_available),
                          label: Text(
                            _upcomingVisitDate != null
                                ? _upcomingVisitDate!.toString().substring(0, 16)
                                : localizations?.translate('selectUpcomingVisitDate') ??
                                    'Select upcoming visit date',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(localizations?.translate('save') ?? 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
