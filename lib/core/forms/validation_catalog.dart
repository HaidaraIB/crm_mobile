import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class ValidationCatalog {
  ValidationCatalog(this.document);

  final Map<String, dynamic> document;

  Map<String, dynamic> form(String id) {
    final forms = document['forms'];
    if (forms is! Map || forms[id] is! Map) {
      throw StateError('Unknown validation form: $id');
    }
    return Map<String, dynamic>.from(forms[id] as Map);
  }

  Map<String, Object?> get context {
    final raw = document['context'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', value));
    }
    return const {};
  }
}

class ValidationCatalogRepository {
  ValidationCatalogRepository({this.token});

  final String? token;
  static const _etagKey = 'validationCatalogEtag';

  Future<ValidationCatalog> load() async {
    final raw = await rootBundle.loadString('assets/validation/catalog.json');
    final snapshot = ValidationCatalog(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    try {
      final prefs = await SharedPreferences.getInstance();
      final etag = prefs.getString(_etagKey);
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token!.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      if (etag != null && etag.isNotEmpty) headers['If-None-Match'] = etag;
      final base = AppConstants.baseUrl.endsWith('/')
          ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
          : AppConstants.baseUrl;
      final response = await http.get(Uri.parse('$base/validation/catalog/'), headers: headers);
      if (response.statusCode == 304 || response.statusCode >= 400) return snapshot;
      final body = jsonDecode(response.body);
      final document = body is Map && body['data'] is Map ? body['data'] : body;
      if (document is! Map || document['forms'] is! Map) return snapshot;
      final next = response.headers['etag'];
      if (next != null && next.isNotEmpty) await prefs.setString(_etagKey, next);
      return ValidationCatalog(Map<String, dynamic>.from(document));
    } catch (_) {
      return snapshot;
    }
  }
}
