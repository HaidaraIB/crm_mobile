import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/settings_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/leads_excel_service.dart';

class ImportLeadsScreen extends StatefulWidget {
  final VoidCallback? onImportDone;

  const ImportLeadsScreen({super.key, this.onImportDone});

  @override
  State<ImportLeadsScreen> createState() => _ImportLeadsScreenState();
}

enum _ImportStep { upload, match, preview }

class _ImportLeadsScreenState extends State<ImportLeadsScreen> {
  final ApiService _apiService = ApiService();
  _ImportStep _step = _ImportStep.upload;
  List<Map<String, dynamic>> _rows = [];
  List<String> _headers = [];
  List<Map<String, String>> _rawRows = [];
  Map<String, LeadImportFieldKey> _columnMapping = {};
  List<UserModel> _users = [];
  List<ChannelModel> _channels = [];
  List<StatusModel> _statuses = [];
  bool _isLoading = false;
  bool _isImporting = false;
  String? _errorMessage;
  int? _defaultAssignedTo;
  int? _defaultStatusId;
  int? _defaultChannelId;
  final List<Map<String, dynamic>> _overrides = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final usersData = await _apiService.getUsers();
      final channels = await _apiService.getChannels();
      final statuses = await _apiService.getStatuses();
      final currentUser = await _apiService.getCurrentUser();
      if (!mounted) return;
      final users = (usersData['results'] as List).cast<UserModel>();
      StatusModel? defaultStatus;
      if (statuses.isNotEmpty) {
        try {
          defaultStatus = statuses.firstWhere((s) => s.isDefault == true && !s.isHidden);
        } catch (_) {
          defaultStatus = statuses.first;
        }
      }
      ChannelModel? defaultChannel;
      if (channels.isNotEmpty) {
        try {
          defaultChannel = channels.firstWhere((c) => c.isDefault == true);
        } catch (_) {
          defaultChannel = channels.first;
        }
      }
      setState(() {
        _users = users;
        _channels = channels;
        _statuses = statuses.where((s) => !s.isHidden).toList();
        _defaultAssignedTo = currentUser.id;
        _defaultStatusId = defaultStatus?.id;
        _defaultChannelId = defaultChannel?.id;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final bytes = Uint8List.fromList(result.files.single.bytes!);
    final parsed = LeadsExcelService.parseXlsxToHeadersAndRows(bytes);
    if (parsed == null || parsed.headers.isEmpty || parsed.rows.isEmpty) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        AppLocalizations.of(context)?.translate('importLeadsMissingColumns') ?? 'No headers or data found in file.',
      );
      return;
    }
    setState(() {
      _headers = parsed.headers;
      _rawRows = parsed.rows;
      _columnMapping = LeadsExcelService.getInitialColumnMapping(parsed.headers);
      _rows = [];
      _overrides.clear();
      _errorMessage = null;
      _step = _ImportStep.match;
    });
  }

  void _applyMappingAndGoToPreview() {
    final hasName = _columnMapping.values.any((v) => v == 'name');
    final hasPhone = _columnMapping.values.any((v) => v == 'phone');
    if (!hasName || !hasPhone) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)?.translate('importLeadsMatchRequired') ?? 'Please map at least one column to Name and one to Phone.';
      });
      return;
    }
    final rows = LeadsExcelService.parseRowsWithMapping(
      _rawRows,
      _columnMapping,
      statuses: _statuses,
      channels: _channels,
      users: _users,
      userDisplayName: (u) => (u as UserModel).displayName,
    );
    setState(() {
      _errorMessage = null;
      _rows = rows;
      _overrides.clear();
      for (int i = 0; i < rows.length; i++) {
        _overrides.add({
          'assigned_to': _defaultAssignedTo,
          'status_id': _defaultStatusId,
          'channel_id': _defaultChannelId,
        });
      }
      _step = _ImportStep.preview;
    });
  }

  void _reupload() {
    setState(() {
      _step = _ImportStep.upload;
      _headers = [];
      _rawRows = [];
      _columnMapping = {};
      _rows = [];
      _overrides.clear();
      _errorMessage = null;
    });
  }

  void _applyToAll(String key, int? value) {
    setState(() {
      for (var o in _overrides) {
        o[key] = value;
      }
    });
  }

  Future<void> _import() async {
    if (_rows.isEmpty) return;
    setState(() => _isImporting = true);
    int ok = 0;
    int fail = 0;
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final name = (row['name'] as String? ?? '').trim();
      final phone = (row['phone'] as String? ?? '').trim();
      if (name.isEmpty || phone.isEmpty) {
        fail++;
        continue;
      }
      final override = i < _overrides.length ? _overrides[i] : <String, dynamic>{};
      final assignedTo = row['assigned_to'] as int? ?? override['assigned_to'] as int?;
      final statusId = row['status_id'] as int? ?? override['status_id'] as int?;
      final channelId = row['channel_id'] as int? ?? override['channel_id'] as int?;
      try {
        await _apiService.createLead(
          name: name,
          phone: phone,
          budget: row['budget'] as double?,
          type: row['type'] as String? ?? 'fresh',
          priority: row['priority'] as String? ?? 'medium',
          assignedTo: assignedTo,
          statusId: statusId,
          communicationWayId: channelId,
        );
        ok++;
      } catch (e) {
        fail++;
      }
    }
    if (!mounted) return;
    setState(() => _isImporting = false);
    SnackbarHelper.showSuccess(
      context,
      '${AppLocalizations.of(context)?.translate('importLeadsComplete') ?? 'Import complete'}: $ok ${AppLocalizations.of(context)?.translate('importLeadsImported') ?? 'imported'}, $fail ${AppLocalizations.of(context)?.translate('importLeadsFailed') ?? 'failed'}.',
    );
    widget.onImportDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('importLeads') ?? 'Import from Excel'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: Text(localizations?.translate('retry') ?? 'Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_step == _ImportStep.upload) ...[
                        Text(
                          localizations?.translate('importLeadsDescription') ?? 'Upload an Excel file (.xlsx) with columns: Name and Phone. Optional: Budget, Type (fresh/cold), Priority (low/medium/high).',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.upload_file),
                          label: Text(localizations?.translate('chooseFiles') ?? 'Choose file'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                      if (_step == _ImportStep.match) ...[
                        Text(
                          '${localizations?.translate('importLeadsStep2Match') ?? 'Step 2: Match columns'}. ${localizations?.translate('importLeadsMatchDescription') ?? 'Match columns to system fields. If headers were mistyped, choose the correct field for each column.'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations?.translate('importLeadsDataExample') ?? 'Data example',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: _rawRows.take(2).map((row) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            _headers.map((h) => (row[h] ?? '').toString()).join(', '),
                                            style: Theme.of(context).textTheme.bodySmall,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${localizations?.translate('importLeadsColumnNames') ?? 'Column names'} → ${localizations?.translate('importLeadsCustomFields') ?? 'System field'}',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  ..._headers.map((header) {
                                    final currentValue = _columnMapping[header] ?? '';
                                    bool usedByOtherColumn(LeadImportFieldKey fieldValue) =>
                                        fieldValue.isNotEmpty &&
                                        _headers.any((h) => h != header && (_columnMapping[h] ?? '') == fieldValue);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(header.isEmpty ? ' ' : header, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: DropdownButtonFormField<LeadImportFieldKey>(
                                              initialValue: currentValue,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                labelText: localizations?.translate('importLeadsChooseField') ?? 'Choose field',
                                              ),
                                              items: LeadsExcelService.fieldKeys.map((key) {
                                                String label;
                                                if (key.isEmpty) {
                                                  label = localizations?.translate('importLeadsChooseField') ?? 'Choose field';
                                                } else {
                                                  label = localizations?.translate(key) ?? key;
                                                }
                                                final alreadyMapped = key.isNotEmpty && usedByOtherColumn(key);
                                                return DropdownMenuItem<LeadImportFieldKey>(
                                                  value: key,
                                                  enabled: !alreadyMapped,
                                                  child: Text(alreadyMapped ? '$label (${localizations?.translate('importLeadsAlreadyMapped') ?? 'already mapped'})' : label),
                                                );
                                              }).toList(),
                                              onChanged: (v) {
                                                setState(() {
                                                  _columnMapping = Map.from(_columnMapping);
                                                  _columnMapping[header] = v ?? '';
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _reupload,
                              child: Text(localizations?.translate('importLeadsReupload') ?? 'Reupload'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(localizations?.translate('cancel') ?? 'Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _applyMappingAndGoToPreview,
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                              child: Text(localizations?.translate('save') ?? 'Save'),
                            ),
                          ],
                        ),
                      ],
                      if (_step == _ImportStep.preview && _rows.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '${localizations?.translate('importLeadsPreview') ?? 'Found'} ${_rows.length} ${localizations?.translate('importLeadsRows') ?? 'rows'}.',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(_rows.length, (i) {
                          final row = _rows[i];
                          final override = i < _overrides.length ? _overrides[i] : <String, dynamic>{};
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${row['name']} • ${row['phone']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (row['budget'] != null) Text('Budget: ${row['budget']}'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int?>(
                                          key: ValueKey('assign_${i}_${override['assigned_to']}'),
                                          initialValue: override['assigned_to'] as int?,
                                          decoration: const InputDecoration(labelText: 'Assigned to', isDense: true),
                                          items: [
                                            const DropdownMenuItem(value: null, child: Text('-')),
                                            ..._users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName))),
                                          ],
                                          onChanged: (v) {
                                            setState(() {
                                              if (i < _overrides.length) _overrides[i]['assigned_to'] = v;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: DropdownButtonFormField<int?>(
                                          key: ValueKey('status_${i}_${override['status_id']}'),
                                          initialValue: override['status_id'] as int?,
                                          decoration: const InputDecoration(labelText: 'Status', isDense: true),
                                          items: [
                                            const DropdownMenuItem(value: null, child: Text('-')),
                                            ..._statuses.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                                          ],
                                          onChanged: (v) {
                                            setState(() {
                                              if (i < _overrides.length) _overrides[i]['status_id'] = v;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: DropdownButtonFormField<int?>(
                                          key: ValueKey('channel_${i}_${override['channel_id']}'),
                                          initialValue: override['channel_id'] as int?,
                                          decoration: const InputDecoration(labelText: 'Channel', isDense: true),
                                          items: [
                                            const DropdownMenuItem(value: null, child: Text('-')),
                                            ..._channels.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                                          ],
                                          onChanged: (v) {
                                            setState(() {
                                              if (i < _overrides.length) _overrides[i]['channel_id'] = v;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _isImporting ? null : () => setState(() => _step = _ImportStep.match),
                              child: Text(localizations?.translate('back') ?? 'Back'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _isImporting ? null : () => _applyToAll('assigned_to', _defaultAssignedTo),
                              child: Text(localizations?.translate('applyToAll') ?? 'Apply to all'),
                            ),
                            TextButton(
                              onPressed: _isImporting ? null : () => _applyToAll('status_id', _defaultStatusId),
                              child: Text(localizations?.translate('applyToAll') ?? 'Apply to all'),
                            ),
                            TextButton(
                              onPressed: _isImporting ? null : () => _applyToAll('channel_id', _defaultChannelId),
                              child: Text(localizations?.translate('applyToAll') ?? 'Apply to all'),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _isImporting ? null : _import,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                          child: _isImporting
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(localizations?.translate('import') ?? 'Import'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
