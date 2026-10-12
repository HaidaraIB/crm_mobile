import 'package:flutter_test/flutter_test.dart';

import 'package:crm_mobile/models/deal_model.dart';
import 'package:crm_mobile/models/deal_pipeline_model.dart';

Map<String, dynamic> _stage(
  int id,
  String name, {
  String type = 'open',
  String? systemKey,
  int order = 0,
  bool active = true,
}) =>
    {
      'id': id,
      'pipeline': 1,
      'name': name,
      'color': '#3B82F6',
      'order': order,
      'stage_type': type,
      'probability': 50,
      'system_key': systemKey,
      'is_active': active,
    };

void main() {
  group('dealColorFromHex', () {
    test('parses #RRGGBB as opaque', () {
      expect(dealColorFromHex('#3B82F6')?.toARGB32(), 0xFF3B82F6);
    });

    test('returns null for missing or malformed values', () {
      expect(dealColorFromHex(null), isNull);
      expect(dealColorFromHex(''), isNull);
      expect(dealColorFromHex('#FFF'), isNull);
      expect(dealColorFromHex('#GGGGGG'), isNull);
    });
  });

  group('DealStageModel.legacyStage', () {
    DealStageModel parse(Map<String, dynamic> json) =>
        DealStageModel.fromJson(json);

    test('prefers a recognised system key', () {
      expect(parse(_stage(1, 'Hold', systemKey: 'on_hold')).legacyStage, 'on_hold');
    });

    test('falls back to the stage type for custom stages', () {
      expect(parse(_stage(2, 'Signed', type: 'won')).legacyStage, 'won');
      expect(parse(_stage(3, 'Declined', type: 'lost')).legacyStage, 'lost');
      expect(parse(_stage(4, 'Negotiation')).legacyStage, 'in_progress');
    });

    test('ignores an unknown system key', () {
      expect(
        parse(_stage(5, 'Custom', systemKey: 'something_else')).legacyStage,
        'in_progress',
      );
    });
  });

  group('DealPipelineModel', () {
    DealPipelineModel pipeline(List<Map<String, dynamic>> stages) =>
        DealPipelineModel.fromJson({
          'id': 1,
          'name': 'Sales',
          'order': 0,
          'is_default': true,
          'is_active': true,
          'stages': stages,
        });

    test('activeStages drops inactive stages and sorts by order', () {
      final p = pipeline([
        _stage(1, 'Late', order: 3),
        _stage(2, 'Hidden', order: 1, active: false),
        _stage(3, 'Early', order: 2),
      ]);
      expect(p.activeStages.map((s) => s.name), ['Early', 'Late']);
    });

    test('initialStage prefers the in_progress system stage', () {
      final p = pipeline([
        _stage(1, 'Lead in', order: 0),
        _stage(2, 'In progress', order: 1, systemKey: 'in_progress'),
      ]);
      expect(p.initialStage?.id, 2);
    });

    test('initialStage skips won/lost stages when no system key matches', () {
      final p = pipeline([
        _stage(1, 'Won', type: 'won', order: 0),
        _stage(2, 'Qualified', order: 1),
      ]);
      expect(p.initialStage?.id, 2);
    });

    test('initialStage is null for a pipeline with no active stages', () {
      final p = pipeline([_stage(1, 'Off', active: false)]);
      expect(p.initialStage, isNull);
    });
  });

  group('DealModel pipeline fields', () {
    final base = <String, dynamic>{
      'id': 7,
      'client_name': 'Sara',
      'payment_method': 'cash',
      'status': 'reservation',
      'stage': 'lost',
      'value': '1500.00',
    };

    test('parses stage + lost reason from the API payload', () {
      final deal = DealModel.fromJson({
        ...base,
        'pipeline': 1,
        'pipeline_name': 'Sales',
        'pipeline_stage': 12,
        'pipeline_stage_name': 'Declined',
        'pipeline_stage_color': '#EF4444',
        'stage_type': 'lost',
        'lost_reason': 3,
        'lost_reason_name': 'Too expensive',
        'lost_note': 'Went elsewhere',
      });
      expect(deal.pipelineStage, 12);
      expect(deal.pipelineStageName, 'Declined');
      expect(deal.lostReasonName, 'Too expensive');
      expect(deal.isLost, isTrue);
    });

    test('legacy payload without pipeline fields still parses', () {
      final deal = DealModel.fromJson(base);
      expect(deal.pipelineStage, isNull);
      expect(deal.pipelineStageName, isNull);
      expect(deal.isLost, isTrue, reason: 'falls back to legacy stage == lost');
    });

    test('isLost follows stage_type over the legacy stage', () {
      final deal = DealModel.fromJson({
        ...base,
        'stage': 'lost',
        'stage_type': 'open',
      });
      expect(deal.isLost, isFalse);
    });
  });
}
