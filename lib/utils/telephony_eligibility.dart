/// State of the company integration-policy lookup used before PBX discovery.
enum TelephonyPolicyQueryStatus { pending, error, success }

/// Mirrors the tenant web's `shouldQueryTelephonyMe` decision.
///
/// An explicit policy denial (or a successful response without an enabled
/// telephony entry) must not probe the protected `/telephony/me/` endpoint.
/// When the policy lookup itself fails, the telephony endpoint remains the
/// fallback so a temporary policy outage does not hide an approved pilot.
bool shouldQueryTelephonyMe({
  required bool authenticated,
  required TelephonyPolicyQueryStatus policyStatus,
  required bool? telephonyEnabled,
}) {
  if (!authenticated) return false;
  if (policyStatus == TelephonyPolicyQueryStatus.error) return true;
  return policyStatus == TelephonyPolicyQueryStatus.success &&
      telephonyEnabled == true;
}
