import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../models/company_library_file_model.dart';
import '../../services/api_service.dart';
import 'whatsapp_chat_theme.dart';

/// Result of picking a Company Library file: the downloaded local path plus the
/// attachment kind the WhatsApp composer expects.
class CompanyLibraryPickResult {
  const CompanyLibraryPickResult({required this.path, required this.kind});

  final String path;

  /// `image` | `video` | `audio` | `document`.
  final String kind;
}

/// Bottom sheet listing the tenant's shared Company Library, so a file already
/// uploaded once can be sent without re-picking it from the device.
///
/// Native counterpart of the web `AttachmentSourceModal` library step
/// (`CRM-project/components/modals/AttachmentSourceModal.tsx`).
class CompanyLibraryPickerSheet extends StatefulWidget {
  const CompanyLibraryPickerSheet({super.key});

  /// Opens the sheet; resolves to null when dismissed without a pick.
  static Future<CompanyLibraryPickResult?> show(BuildContext context) {
    return showModalBottomSheet<CompanyLibraryPickResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CompanyLibraryPickerSheet(),
    );
  }

  @override
  State<CompanyLibraryPickerSheet> createState() =>
      _CompanyLibraryPickerSheetState();
}

class _CompanyLibraryPickerSheetState extends State<CompanyLibraryPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _api = ApiService();

  List<CompanyLibraryFileModel> _files = const [];
  bool _loading = true;
  String? _error;
  int? _downloadingId;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await _api.listCompanyLibrary(search: search);
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(search: q),
    );
  }

  Future<void> _pick(CompanyLibraryFileModel file) async {
    setState(() => _downloadingId = file.id);
    try {
      final path = await _api.downloadCompanyLibraryFile(
        file.id,
        file.originalFilename,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        CompanyLibraryPickResult(path: path, kind: file.kind),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _downloadingId = null);
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc?.translate('libraryDownloadFailed') ?? 'Download failed',
          ),
        ),
      );
    }
  }

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'audio':
        return Icons.audiotrack_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;
    final colors = WhatsAppChatColors.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.72;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.metaIn,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              title: Text(t('libraryPickerTitle')),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                tooltip: t('close'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  hintText: t('librarySearchHint'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(t, colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String Function(String) t, WhatsAppChatColors colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('libraryCouldNotLoad'), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _load(search: _searchCtrl.text),
              child: Text(t('retry')),
            ),
          ],
        ),
      );
    }
    if (_files.isEmpty) {
      return Center(child: Text(t('libraryEmpty')));
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final busy = _downloadingId == file.id;
        return ListTile(
          leading: busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_iconForKind(file.kind), color: colors.metaIn),
          title: Text(
            file.originalFilename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${t(file.kindLabelKey)} · ${file.formattedSize}'),
          enabled: _downloadingId == null,
          onTap: () => _pick(file),
        );
      },
    );
  }
}
