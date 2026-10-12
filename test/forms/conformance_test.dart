import 'dart:convert';
import 'dart:io';

import 'package:crm_mobile/core/forms/form_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog conformance matches backend vectors', () {
    final catalog = jsonDecode(File('assets/validation/catalog.json').readAsStringSync()) as Map;
    final vectors = (jsonDecode(File('test/forms/vectors.json').readAsStringSync()) as Map)['vectors'] as List;
    final forms = catalog['forms'] as Map;
    final failures = <String>[];

    for (final raw in vectors) {
      final vector = Map<String, dynamic>.from(raw as Map);
      final form = forms[vector['form']];
      final data = vector['data'] is Map ? Map<String, dynamic>.from(vector['data'] as Map) : <String, dynamic>{};
      final context = vector['context'] is Map
          ? Map<String, Object?>.from(vector['context'] as Map)
          : <String, Object?>{};
      final issues = evaluateForm(form as Map, data, context: context, partial: vector['partial'] == true);
      final actual = <String, List<String>>{};
      issues.forEach((key, list) {
        actual[key] = list.map((issue) => issue.code).toList();
      });
      final expectedRaw = vector['expect'];
      final expected = <String, List<String>>{};
      if (expectedRaw is Map) {
        expectedRaw.forEach((key, value) {
          expected['$key'] = (value as List).map((item) => '$item').toList();
        });
      }
      if (!_same(actual, expected)) {
        failures.add('${vector['form']} expected=$expected actual=$actual');
      }
    }

    expect(failures, isEmpty);
  });
}

bool _same(Map<String, List<String>> actual, Map<String, List<String>> expected) {
  if (actual.length != expected.length) return false;
  for (final entry in expected.entries) {
    final got = actual[entry.key];
    if (got == null || got.length != entry.value.length) return false;
    for (var i = 0; i < got.length; i++) {
      if (got[i] != entry.value[i]) return false;
    }
  }
  return true;
}
