import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Owner/admin manual phone threads (mirrors web `whatsappManualChatsStorage`).
class WhatsAppManualChatEntry {
  const WhatsAppManualChatEntry({
    required this.phoneNumber,
    required this.name,
    this.lastMessageAt,
  });

  final String phoneNumber;
  final String name;
  final DateTime? lastMessageAt;

  Map<String, dynamic> toJson() => {
        'phone_number': phoneNumber,
        'name': name,
        if (lastMessageAt != null) 'last_message_at': lastMessageAt!.toIso8601String(),
      };

  factory WhatsAppManualChatEntry.fromJson(Map<String, dynamic> json) {
    return WhatsAppManualChatEntry(
      phoneNumber: json['phone_number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastMessageAt: (json['last_message_at'] as String?) != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
    );
  }
}

class WhatsAppManualChatsStorage {
  WhatsAppManualChatsStorage._();

  static const _key = 'whatsapp_manual_chats_v1';

  static Future<List<WhatsAppManualChatEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => WhatsAppManualChatEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.phoneNumber.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<WhatsAppManualChatEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> upsert(WhatsAppManualChatEntry entry) async {
    final list = await load();
    final digits = _digits(entry.phoneNumber);
    list.removeWhere((e) => _digits(e.phoneNumber) == digits);
    list.insert(0, entry);
    await save(list);
  }

  static Future<void> remove(String phone) async {
    final digits = _digits(phone);
    final list = await load();
    list.removeWhere((e) => _digits(e.phoneNumber) == digits);
    await save(list);
  }

  static String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');
}
