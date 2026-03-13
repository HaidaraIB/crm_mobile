import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/lead_model.dart';

/// Field keys for column mapping (empty = skip).
typedef LeadImportFieldKey = String;

/// Result of parsing Excel without requiring column match (for match-columns step).
class HeadersAndRowsResult {
  final List<String> headers;
  final List<Map<String, String>> rows;

  const HeadersAndRowsResult({required this.headers, required this.rows});
}

/// Service for parsing Excel files to leads and exporting leads to Excel.
class LeadsExcelService {
  static const List<String> _nameKeys = ['name', 'اسم', 'client name', 'اسم العميل', 'الاسم', 'full name', 'الاسم الكامل'];
  static const List<String> _phoneKeys = ['phone', 'هاتف', 'phone number', 'رقم الهاتف', 'tel', 'mobile', 'جوال', 'telephone'];
  static const List<String> _budgetKeys = ['budget', 'ميزانية', 'الميزانية'];
  static const List<String> _typeKeys = ['type', 'نوع', 'lead type', 'نوع العميل'];
  static const List<String> _priorityKeys = ['priority', 'أولوية', 'الأولوية'];
  static const List<String> _statusKeys = ['status', 'حالة', 'الحالة', 'state'];
  static const List<String> _channelKeys = ['channel', 'قناة', 'communication way', 'طريقة التواصل', 'contact method'];
  static const List<String> _assignedKeys = ['assigned to', 'مسند إلى', 'assigned_to', 'assignee', 'موظف'];
  static const List<String> _sourceKeys = ['source', 'مصدر', 'المصدر', 'origin'];
  static const List<String> _campaignKeys = ['campaign', 'حملة', 'الحملة'];
  static const List<String> _createdAtKeys = ['created at', 'تاريخ الإنشاء', 'creation date', 'date', 'تاريخ', 'created_at'];

  /// All mappable field keys (including empty for "skip"). Order matches display.
  static const List<LeadImportFieldKey> fieldKeys = [
    '', 'name', 'phone', 'budget', 'type', 'priority',
    'status', 'communicationWay', 'assignedTo', 'source', 'campaign', 'createdAt',
  ];

  /// Build initial column mapping from headers (auto-detect where possible).
  static Map<String, LeadImportFieldKey> getInitialColumnMapping(List<String> headers) {
    final mapping = <String, LeadImportFieldKey>{};
    for (final h in headers) {
      mapping[h] = '';
    }
    final nameIdx = _findColumnIndex(headers, _nameKeys);
    final phoneIdx = _findColumnIndex(headers, _phoneKeys);
    final budgetIdx = _findColumnIndex(headers, _budgetKeys);
    final typeIdx = _findColumnIndex(headers, _typeKeys);
    final priorityIdx = _findColumnIndex(headers, _priorityKeys);
    final statusIdx = _findColumnIndex(headers, _statusKeys);
    final channelIdx = _findColumnIndex(headers, _channelKeys);
    final assignedIdx = _findColumnIndex(headers, _assignedKeys);
    final sourceIdx = _findColumnIndex(headers, _sourceKeys);
    final campaignIdx = _findColumnIndex(headers, _campaignKeys);
    final createdAtIdx = _findColumnIndex(headers, _createdAtKeys);
    if (nameIdx >= 0) mapping[headers[nameIdx]] = 'name';
    if (phoneIdx >= 0) mapping[headers[phoneIdx]] = 'phone';
    if (budgetIdx >= 0) mapping[headers[budgetIdx]] = 'budget';
    if (typeIdx >= 0) mapping[headers[typeIdx]] = 'type';
    if (priorityIdx >= 0) mapping[headers[priorityIdx]] = 'priority';
    if (statusIdx >= 0) mapping[headers[statusIdx]] = 'status';
    if (channelIdx >= 0) mapping[headers[channelIdx]] = 'communicationWay';
    if (assignedIdx >= 0) mapping[headers[assignedIdx]] = 'assignedTo';
    if (sourceIdx >= 0) mapping[headers[sourceIdx]] = 'source';
    if (campaignIdx >= 0) mapping[headers[campaignIdx]] = 'campaign';
    if (createdAtIdx >= 0) mapping[headers[createdAtIdx]] = 'createdAt';
    return mapping;
  }

  /// Parse XLSX to headers and raw rows (no name/phone required). Use for match-columns step.
  static HeadersAndRowsResult? parseXlsxToHeadersAndRows(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return null;
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) return null;

    final headerRow = sheet.rows.first;
    final headers = <String>[];
    for (int c = 0; c < headerRow.length; c++) {
      final v = _cellValue(headerRow[c]);
      headers.add(v.isEmpty ? 'column_${c + 1}' : v);
    }
    if (headers.isEmpty || headers.every((h) => h.startsWith('column_'))) return null;

    final rows = <Map<String, String>>[];
    for (int r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      final map = <String, String>{};
      bool hasAny = false;
      for (int c = 0; c < headers.length; c++) {
        final val = c < row.length ? _cellValue(row[c]) : '';
        map[headers[c]] = val;
        if (val.isNotEmpty) hasAny = true;
      }
      if (!hasAny) break;
      rows.add(map);
    }
    return HeadersAndRowsResult(headers: headers, rows: rows);
  }

  /// Resolve status name to ID.
  static int? _resolveStatusId(String val, List<dynamic> statuses) {
    if (val.trim().isEmpty || statuses.isEmpty) return null;
    final v = val.trim().toLowerCase();
    for (final s in statuses) {
      final name = (s is Map ? s['name']?.toString() : s.name?.toString()) ?? '';
      if (name.toLowerCase() == v || name.toLowerCase().contains(v) || v.contains(name.toLowerCase())) {
        final id = s is Map ? s['id'] : s.id;
        if (id != null) return id is int ? id : int.tryParse(id.toString());
      }
    }
    return null;
  }

  /// Resolve channel name to ID.
  static int? _resolveChannelId(String val, List<dynamic> channels) {
    if (val.trim().isEmpty || channels.isEmpty) return null;
    final v = val.trim().toLowerCase();
    for (final c in channels) {
      final name = (c is Map ? c['name']?.toString() : c.name?.toString()) ?? '';
      if (name.toLowerCase() == v || name.toLowerCase().contains(v) || v.contains(name.toLowerCase())) {
        final id = c is Map ? c['id'] : c.id;
        if (id != null) return id is int ? id : int.tryParse(id.toString());
      }
    }
    return null;
  }

  /// Resolve user display name to ID.
  static int? _resolveUserId(String val, List<dynamic> users, String Function(dynamic) displayName) {
    if (val.trim().isEmpty || users.isEmpty) return null;
    final v = val.trim().toLowerCase();
    for (final u in users) {
      final dn = displayName(u);
      if (dn.toLowerCase() == v || dn.toLowerCase().contains(v) || v.contains(dn.toLowerCase())) {
        final id = u is Map ? u['id'] : u.id;
        if (id != null) return id is int ? id : int.tryParse(id.toString());
      }
    }
    return null;
  }

  /// Convert raw rows to lead row maps using column mapping (header -> field key).
  /// Optional [resolveContext] provides statuses, channels, users to resolve names to IDs.
  static List<Map<String, dynamic>> parseRowsWithMapping(
    List<Map<String, String>> rawRows,
    Map<String, LeadImportFieldKey> columnMapping, {
    List<dynamic>? statuses,
    List<dynamic>? channels,
    List<dynamic>? users,
    String Function(dynamic)? userDisplayName,
  }) {
    final headerByField = <String, String>{};
    columnMapping.forEach((header, field) {
      if (field.isNotEmpty) headerByField[field] = header;
    });
    final displayName = userDisplayName ?? (dynamic u) => u.toString();

    final result = <Map<String, dynamic>>[];
    for (final row in rawRows) {
      final name = (row[headerByField['name']] ?? '').trim();
      final phone = (row[headerByField['phone']] ?? '').trim();
      if (name.isEmpty && phone.isEmpty) continue;

      final budgetVal = row[headerByField['budget']] ?? '';
      final budget = budgetVal.isEmpty ? null : double.tryParse(budgetVal);
      var type = (row[headerByField['type']] ?? '').toLowerCase();
      if (type != 'fresh' && type != 'cold') type = 'fresh';
      if (type.isEmpty) type = 'fresh';
      var priority = (row[headerByField['priority']] ?? '').toLowerCase();
      if (!['low', 'medium', 'high'].contains(priority)) priority = 'medium';
      if (priority.isEmpty) priority = 'medium';

      final statusVal = row[headerByField['status']] ?? '';
      final channelVal = row[headerByField['communicationWay']] ?? '';
      final assignedVal = row[headerByField['assignedTo']] ?? '';
      final sourceVal = row[headerByField['source']] ?? '';
      final campaignVal = row[headerByField['campaign']] ?? '';
      final createdAtVal = row[headerByField['createdAt']] ?? '';

      final statusId = statuses != null ? _resolveStatusId(statusVal, statuses) : null;
      final channelId = channels != null ? _resolveChannelId(channelVal, channels) : null;
      final assignedId = users != null ? _resolveUserId(assignedVal, users, displayName) : null;

      result.add({
        'name': name,
        'phone': phone,
        'budget': budget,
        'type': type,
        'priority': priority,
        'status_id': statusId,
        'channel_id': channelId,
        'assigned_to': assignedId,
        'source': sourceVal.trim().isEmpty ? null : sourceVal.trim(),
        'campaign': campaignVal.trim().isEmpty ? null : campaignVal.trim(),
        'created_at': createdAtVal.trim().isEmpty ? null : createdAtVal.trim(),
      });
    }
    return result;
  }

  static String _cellValue(dynamic cell) {
    if (cell == null) return '';
    if (cell is TextCellValue) return cell.value.text ?? '';
    if (cell is IntCellValue) return cell.value.toString();
    if (cell is DoubleCellValue) return cell.value.toString();
    if (cell is BoolCellValue) return cell.value.toString();
    return cell.toString().trim();
  }

  static String _normalizeHeader(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static int _findColumnIndex(List<String> headers, List<String> keys) {
    for (int i = 0; i < headers.length; i++) {
      final h = _normalizeHeader(headers[i]);
      if (keys.any((k) => h == k || h.contains(k) || k.contains(h))) return i;
    }
    return -1;
  }

  /// Parse XLSX bytes into a list of row maps (name, phone, budget, type, priority).
  /// Returns empty list if required columns (name, phone) are missing.
  static List<Map<String, dynamic>> parseXlsxToRows(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) return [];

    final headerRow = sheet.rows.first;
    final headers = <String>[];
    for (int c = 0; c < headerRow.length; c++) {
      final v = _cellValue(headerRow[c]);
      headers.add(v.isEmpty ? 'column_${c + 1}' : v);
    }

    final nameIdx = _findColumnIndex(headers, _nameKeys);
    final phoneIdx = _findColumnIndex(headers, _phoneKeys);
    if (nameIdx < 0 || phoneIdx < 0) return [];

    final budgetIdx = _findColumnIndex(headers, _budgetKeys);
    final typeIdx = _findColumnIndex(headers, _typeKeys);
    final priorityIdx = _findColumnIndex(headers, _priorityKeys);

    final rows = <Map<String, dynamic>>[];
    for (int r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      final name = (nameIdx < row.length ? _cellValue(row[nameIdx]) : '').trim();
      final phone = (phoneIdx < row.length ? _cellValue(row[phoneIdx]) : '').trim();
      if (name.isEmpty && phone.isEmpty) continue;

      final budgetVal = budgetIdx >= 0 && budgetIdx < row.length ? _cellValue(row[budgetIdx]) : '';
      final budget = budgetVal.isEmpty ? null : (double.tryParse(budgetVal));
      var type = typeIdx >= 0 && typeIdx < row.length ? _cellValue(row[typeIdx]).toLowerCase() : 'fresh';
      if (type != 'fresh' && type != 'cold') type = 'fresh';
      var priority = priorityIdx >= 0 && priorityIdx < row.length ? _cellValue(row[priorityIdx]).toLowerCase() : 'medium';
      if (!['low', 'medium', 'high'].contains(priority)) priority = 'medium';

      rows.add({
        'name': name,
        'phone': phone,
        'budget': budget,
        'type': type,
        'priority': priority,
      });
    }
    return rows;
  }

  /// Export a list of leads to an XLSX file and share it.
  static Future<void> exportLeadsToExcelAndShare(List<LeadModel> leads) async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];
    final headers = ['Name', 'Phone', 'Budget', 'Type', 'Priority', 'Status', 'Channel'];
    for (int c = 0; c < headers.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value = TextCellValue(headers[c]);
    }
    for (int r = 0; r < leads.length; r++) {
      final lead = leads[r];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value = TextCellValue(lead.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value = TextCellValue(lead.phone);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value = DoubleCellValue(lead.budget);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1)).value = TextCellValue(lead.type);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r + 1)).value = TextCellValue(lead.priority ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r + 1)).value = TextCellValue(lead.statusName ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r + 1)).value = TextCellValue(lead.communicationWay ?? '');
    }
    final encoded = excel.encode();
    if (encoded == null || encoded.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/leads_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(path);
    await file.writeAsBytes(Uint8List.fromList(encoded));
    await Share.shareXFiles([XFile(path)], text: 'Leads export');
  }
}
