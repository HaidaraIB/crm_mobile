/// Connected WhatsApp Cloud account state, as far as the chat composer cares.
///
/// Mirrors the web dashboard's account normalization in
/// `CRM-project/pages/ChatsPage.tsx` (`hasConnectedWhatsApp`,
/// `currentWhatsAppPhoneNumberId`, `displayNameBlockedHint`).
class WhatsAppAccountStatus {
  const WhatsAppAccountStatus({
    required this.connected,
    required this.displayNameBlocked,
    this.phoneNumberId,
  });

  /// Account is connected AND active — free-form sending is possible.
  final bool connected;

  /// Meta has not approved the business display name, so sends will be
  /// rejected with error 131037.
  final bool displayNameBlocked;

  /// Business phone number id, used for the "via previous number" badge.
  final String? phoneNumberId;

  static const Set<String> _blockedDisplayNameStatuses = {
    'PENDING',
    'PENDING_REVIEW',
    'DECLINED',
    'EXPIRED',
  };

  factory WhatsAppAccountStatus.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const <String, dynamic>{};
    final extra = json['extra_data'] is Map
        ? Map<String, dynamic>.from(json['extra_data'] as Map)
        : const <String, dynamic>{};

    final connected = (json['is_connected'] == true ||
            json['connected'] == true ||
            json['status']?.toString().toLowerCase() == 'connected') &&
        json['is_active'] != false;

    final rawStatus = (metadata['display_name_status'] ??
            metadata['name_status'] ??
            '')
        .toString()
        .toUpperCase();
    final displayNameBlocked = connected &&
        (_blockedDisplayNameStatuses.contains(rawStatus) ||
            metadata['display_name_approved'] == false);

    final pnid = json['phone_number_id']?.toString() ??
        metadata['phone_number_id']?.toString() ??
        extra['phone_number_id']?.toString();

    return WhatsAppAccountStatus(
      connected: connected,
      displayNameBlocked: displayNameBlocked,
      phoneNumberId: (pnid != null && pnid.isNotEmpty) ? pnid : null,
    );
  }
}
