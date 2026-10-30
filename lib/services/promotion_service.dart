import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../models/promotion_model.dart';

/// Reads the public promotion bar endpoint. No auth: it is the same public
/// content shown on the web pricing pages.
class PromotionService {
  PromotionService._();
  static final PromotionService instance = PromotionService._();

  Future<ActivePromotion> fetchActive({String audience = 'mobile'}) async {
    final base = AppConstants.baseUrl.endsWith('/')
        ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
        : AppConstants.baseUrl;
    final url = Uri.parse('$base/public/promotions/active/?audience=$audience');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Client-Platform': 'mobile',
      if (AppConstants.apiKey.isNotEmpty) 'X-API-Key': AppConstants.apiKey,
    };
    final fetchedAt = DateTime.now();
    final response = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Failed to load promotion (${response.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded is Map && decoded['data'] is Map
        ? decoded['data'] as Map
        : decoded as Map;
    final serverTime = data['server_time'] != null
        ? DateTime.tryParse(data['server_time'].toString())
        : null;
    final promo = data['promotion'];
    return ActivePromotion(
      promotion: promo is Map<String, dynamic>
          ? PromotionModel.fromJson(promo)
          : null,
      serverOffset: serverTime != null
          ? serverTime.difference(fetchedAt)
          : Duration.zero,
    );
  }
}
