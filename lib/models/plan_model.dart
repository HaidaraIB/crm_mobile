class PlanModel {
  final int id;
  final String name;
  final String? nameAr;
  final String description;
  final String? descriptionAr;
  final double priceMonthly;
  final double priceYearly;
  final int trialDays;
  final String users;
  final String clients;
  final int storage;

  PlanModel({
    required this.id,
    required this.name,
    this.nameAr,
    required this.description,
    this.descriptionAr,
    required this.priceMonthly,
    required this.priceYearly,
    required this.trialDays,
    required this.users,
    required this.clients,
    required this.storage,
  });

  /// Safely parse a JSON value to double (handles both String and num from API).
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Safely parse a JSON value to int (handles both String and num from API).
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String? _emptyToNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      nameAr: _emptyToNull(json['name_ar']),
      description: json['description']?.toString() ?? '',
      descriptionAr: _emptyToNull(json['description_ar']),
      priceMonthly: _toDouble(json['price_monthly']),
      priceYearly: _toDouble(json['price_yearly']),
      trialDays: _toInt(json['trial_days']),
      users: json['users']?.toString() ?? '0',
      clients: json['clients']?.toString() ?? '0',
      storage: _toInt(json['storage']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
      'description': description,
      'description_ar': descriptionAr,
      'price_monthly': priceMonthly,
      'price_yearly': priceYearly,
      'trial_days': trialDays,
      'users': users,
      'clients': clients,
      'storage': storage,
    };
  }

  /// Get price based on billing cycle
  double getPrice(String billingCycle) {
    return billingCycle == 'yearly' ? priceYearly : priceMonthly;
  }

  /// Get display name based on language
  String getDisplayName(String language) {
    if (language == 'ar' && nameAr != null && nameAr!.isNotEmpty) {
      return nameAr!;
    }
    return name;
  }

  /// Get display description based on language
  String getDisplayDescription(String language) {
    if (language == 'ar' && descriptionAr != null && descriptionAr!.isNotEmpty) {
      return descriptionAr!;
    }
    return description;
  }
}
