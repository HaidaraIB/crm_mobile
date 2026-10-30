/// Platform promotion bar (Super Admin → Subscriptions → Promotions).
/// Mirrors `GET /api/v1/public/promotions/active/` → `promotion`.
class PromotionMessage {
  final String en;
  final String ar;

  const PromotionMessage({required this.en, required this.ar});

  String textFor(String languageCode) => languageCode == 'ar'
      ? (ar.isNotEmpty ? ar : en)
      : (en.isNotEmpty ? en : ar);
}

class PromotionModel {
  final int id;
  final List<PromotionMessage> messages;
  final String ctaLabel;
  final String ctaLabelAr;
  final String ctaUrl;

  /// sale | brand | dark | amber
  final String theme;
  final DateTime? endsAt;
  final bool showCountdown;
  final bool dismissible;
  final String updatedAt;

  const PromotionModel({
    required this.id,
    required this.messages,
    required this.ctaLabel,
    required this.ctaLabelAr,
    required this.ctaUrl,
    required this.theme,
    required this.endsAt,
    required this.showCountdown,
    required this.dismissible,
    required this.updatedAt,
  });

  /// Dismissal key: editing the promotion (new `updated_at`) shows it again.
  String get dismissKey => 'promo-dismissed:$id:$updatedAt';

  String ctaLabelFor(String languageCode) => languageCode == 'ar'
      ? (ctaLabelAr.isNotEmpty ? ctaLabelAr : ctaLabel)
      : (ctaLabel.isNotEmpty ? ctaLabel : ctaLabelAr);

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return PromotionModel(
      id: (json['id'] as num).toInt(),
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map>()
                .map(
                  (m) => PromotionMessage(
                    en: (m['en'] ?? '').toString(),
                    ar: (m['ar'] ?? '').toString(),
                  ),
                )
                .toList()
          : const [],
      ctaLabel: (json['cta_label'] ?? '').toString(),
      ctaLabelAr: (json['cta_label_ar'] ?? '').toString(),
      ctaUrl: (json['cta_url'] ?? '').toString(),
      theme: (json['theme'] ?? 'sale').toString(),
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())
          : null,
      showCountdown: json['show_countdown'] == true,
      dismissible: json['dismissible'] != false,
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }
}

/// The active promotion plus the server clock offset (server − device), so
/// countdowns stay correct on a device with a wrong clock.
class ActivePromotion {
  final PromotionModel? promotion;
  final Duration serverOffset;

  const ActivePromotion({required this.promotion, required this.serverOffset});
}
