import 'package:crm_mobile/utils/telephony_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not query before authentication or while policy is loading', () {
    expect(
      shouldQueryTelephonyMe(
        authenticated: false,
        policyStatus: TelephonyPolicyQueryStatus.success,
        telephonyEnabled: true,
      ),
      isFalse,
    );
    expect(
      shouldQueryTelephonyMe(
        authenticated: true,
        policyStatus: TelephonyPolicyQueryStatus.pending,
        telephonyEnabled: null,
      ),
      isFalse,
    );
  });

  test('does not query when policy explicitly denies telephony', () {
    for (final enabled in <bool?>[false, null]) {
      expect(
        shouldQueryTelephonyMe(
          authenticated: true,
          policyStatus: TelephonyPolicyQueryStatus.success,
          telephonyEnabled: enabled,
        ),
        isFalse,
      );
    }
  });

  test('queries for an approved pilot', () {
    expect(
      shouldQueryTelephonyMe(
        authenticated: true,
        policyStatus: TelephonyPolicyQueryStatus.success,
        telephonyEnabled: true,
      ),
      isTrue,
    );
  });

  test('falls back to telephony when the policy lookup fails', () {
    expect(
      shouldQueryTelephonyMe(
        authenticated: true,
        policyStatus: TelephonyPolicyQueryStatus.error,
        telephonyEnabled: null,
      ),
      isTrue,
    );
  });
}
