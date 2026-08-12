import 'package:flutter_test/flutter_test.dart';

import 'package:crm_mobile/models/whatsapp_template_model.dart';
import 'package:crm_mobile/utils/whatsapp_template_placeholders.dart';

void main() {
  group('named placeholders', () {
    test('fills customer, phone and employee by alias', () {
      final out = replaceWhatsAppTemplatePlaceholders(
        'مرحباً { اسم العميل } معك { اسم الموظف } على { رقم الهاتف }',
        customerName: 'سارة',
        phone: '+9647701112233',
        employeeName: 'علي حسن',
      );
      expect(out, 'مرحباً سارة معك علي حسن على +9647701112233');
    });

    test('accepts whatsapp_api channel templates', () {
      final tpl = WhatsAppTemplateModel.fromJson({
        'id': 1,
        'name': 'welcome',
        'channel_type': 'whatsapp_api',
        'content': 'hi',
        'meta_status': 'APPROVED',
      });
      expect(tpl.isWhatsApp, isTrue);
      expect(tpl.isApproved, isTrue);
    });

    test('unknown placeholder is left untouched', () {
      final out = replaceWhatsAppTemplatePlaceholders(
        'مرحباً { شيء غريب }',
        customerName: 'سارة',
      );
      expect(out, 'مرحباً { شيء غريب }');
    });
  });

  group('Meta positional {{n}}', () {
    test('uses the template variable map, not position', () {
      final out = replaceWhatsAppTemplatePlaceholders(
        'معك {{1}} مرحباً {{2}}',
        customerName: 'سارة',
        employeeName: 'علي حسن',
        bodyVariables: const ['employee_name', 'customer_name'],
      );
      expect(out, 'معك علي حسن مرحباً سارة');
    });

    test('empty mapped value keeps the token instead of another field', () {
      final out = replaceWhatsAppTemplatePlaceholders(
        'معك {{1}}',
        customerName: 'سارة',
        employeeName: '',
        bodyVariables: const ['employee_name'],
      );
      expect(out, 'معك {{1}}');
    });

    test('without a map falls back to customer name for {{1}}', () {
      final out = replaceWhatsAppTemplatePlaceholders(
        'مرحباً {{1}}',
        customerName: 'سارة',
      );
      expect(out, 'مرحباً سارة');
    });

    test('parses body variables from meta_variable_map', () {
      final tpl = WhatsAppTemplateModel.fromJson({
        'id': 2,
        'name': 'new_customer',
        'channel_type': 'whatsapp_api',
        'content': 'معك {{1}}',
        'meta_status': 'APPROVED',
        'meta_variable_map': {
          'body': ['employee_name'],
        },
      });
      expect(tpl.bodyVariables, ['employee_name']);
    });

    test('missing meta_variable_map yields no variables', () {
      final tpl = WhatsAppTemplateModel.fromJson({
        'id': 3,
        'name': 'x',
        'channel_type': 'whatsapp_api',
        'content': 'hi',
      });
      expect(tpl.bodyVariables, isEmpty);
    });
  });
}
