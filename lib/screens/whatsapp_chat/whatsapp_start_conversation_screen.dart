import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../features/whatsapp_chat/whatsapp_chat_repository.dart';
import '../../models/lead_model.dart';
import '../../services/api_service.dart';
import '../../utils/whatsapp_manual_chats_storage.dart';
import '../../widgets/whatsapp_chat/whatsapp_phone_text.dart';

class WhatsAppStartConversationResult {
  const WhatsAppStartConversationResult({
    this.clientId,
    required this.name,
    required this.phone,
    this.isManual = false,
  });

  final int? clientId;
  final String name;
  final String phone;
  final bool isManual;
}

class WhatsAppStartConversationScreen extends StatefulWidget {
  const WhatsAppStartConversationScreen({super.key, this.allowManual = false});

  final bool allowManual;

  @override
  State<WhatsAppStartConversationScreen> createState() =>
      _WhatsAppStartConversationScreenState();
}

class _WhatsAppStartConversationScreenState
    extends State<WhatsAppStartConversationScreen> {
  final _phoneCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _repo = ApiWhatsAppChatRepository();
  final _api = ApiService();

  bool _resolving = false;
  bool _searching = false;
  String? _error;
  List<Map<String, dynamic>> _leads = [];
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _phoneCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Debounced so typing a name does not fire one request per keystroke.
  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _leads = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchLeads(q),
    );
  }

  Future<void> _searchLeads(String q) async {
    if (q.trim().length < 2) {
      setState(() => _leads = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await _api.getLeads(search: q.trim());
      final results = (res['results'] as List?) ?? [];
      final list = <Map<String, dynamic>>[];
      for (final lead in results) {
        if (lead is! LeadModel) continue;
        list.add({
          'id': lead.id,
          'name': lead.name,
          'phone': lead.phone,
        });
      }
      if (mounted) setState(() => _leads = list);
    } catch (_) {
      if (mounted) setState(() => _leads = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _resolvePhone() async {
    final loc = AppLocalizations.of(context);
    final phone = _phoneCtrl.text.trim();
    if (phone.replaceAll(RegExp(r'\D'), '').length < 7) {
      setState(() => _error = loc?.translate('enterPhoneNumber') ?? 'Enter phone');
      return;
    }
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      final contact = await _repo.getContactByPhone(phone);
      if (!mounted) return;
      if (contact != null && contact['id'] != null) {
        Navigator.pop(
          context,
          WhatsAppStartConversationResult(
            clientId: (contact['id'] as num).toInt(),
            name: (contact['name'] as String?)?.isNotEmpty == true
                ? contact['name'] as String
                : phone,
            phone: (contact['phone_number'] as String?) ?? phone,
          ),
        );
        return;
      }
      // null contact with 200 → owner may start manual
      if (widget.allowManual) {
        await WhatsAppManualChatsStorage.upsert(
          WhatsAppManualChatEntry(phoneNumber: phone, name: phone),
        );
        if (!mounted) return;
        Navigator.pop(
          context,
          WhatsAppStartConversationResult(
            name: phone,
            phone: phone,
            isManual: true,
          ),
        );
        return;
      }
      setState(() => _error = loc?.translate('whatsappContactNotFound') ?? 'Not found');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('whatsapp_contact_not_found')) {
        setState(
          () => _error = loc?.translate('whatsappContactNotFound') ?? 'Contact not found',
        );
      } else if (widget.allowManual) {
        await WhatsAppManualChatsStorage.upsert(
          WhatsAppManualChatEntry(phoneNumber: phone, name: phone),
        );
        if (!mounted) return;
        Navigator.pop(
          context,
          WhatsAppStartConversationResult(
            name: phone,
            phone: phone,
            isManual: true,
          ),
        );
      } else {
        setState(
          () => _error = loc?.translate('whatsappContactNotFound') ?? 'Contact not found',
        );
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;

    return Scaffold(
      appBar: AppBar(title: Text(t('startNewConversation'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('enterPhoneNumber'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: '+964…',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _resolving ? null : _resolvePhone,
            child: _resolving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(t('startNewConversation')),
          ),
          const SizedBox(height: 24),
          Text(t('chooseClientFromDb'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              hintText: t('searchConversations'),
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          for (final lead in _leads)
            ListTile(
              title: Text(lead['name']?.toString() ?? ''),
              subtitle: WhatsAppPhoneText(lead['phone']?.toString() ?? ''),
              onTap: () {
                Navigator.pop(
                  context,
                  WhatsAppStartConversationResult(
                    clientId: (lead['id'] as num?)?.toInt(),
                    name: lead['name']?.toString() ?? '',
                    phone: lead['phone']?.toString() ?? '',
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
