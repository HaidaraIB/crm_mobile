import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../core/localization/app_localizations.dart';
import '../models/pbx_call_model.dart';
import '../utils/telephony_eligibility.dart';
import 'api_service.dart';

/// Calling a lead from the app (Phase 6).
///
/// With the company's phone system available to this user (an extension and
/// click-to-call allowed), the user chooses between the phone system — the node
/// rings their own extension first (desk phone or browser; the app has no
/// softphone), then the lead, with the company's verified caller id — and this
/// phone's dialer. Without it, the dialer opens straight away, as before.
class PbxCallLauncher {
  PbxCallLauncher._();

  static PbxMe? _me;
  static DateTime? _meAt;
  static Future<PbxMe?>? _meInFlight;
  static int _requestGeneration = 0;
  static const _meTtl = Duration(minutes: 5);

  /// Resolve PBX discovery with the same policy-first behavior as tenant web.
  ///
  /// The fetchers are arguments so the policy/telephony boundary can be tested
  /// without network calls.
  static Future<PbxMe?> resolveMe({
    required Future<bool> Function() fetchPolicyEnabled,
    required Future<PbxMe?> Function() fetchTelephonyMe,
    bool authenticated = true,
  }) async {
    if (!authenticated) return null;

    var status = TelephonyPolicyQueryStatus.pending;
    bool? enabled;
    try {
      enabled = await fetchPolicyEnabled();
      status = TelephonyPolicyQueryStatus.success;
    } catch (_) {
      status = TelephonyPolicyQueryStatus.error;
    }

    if (!shouldQueryTelephonyMe(
      authenticated: authenticated,
      policyStatus: status,
      telephonyEnabled: enabled,
    )) {
      return null;
    }
    return fetchTelephonyMe();
  }

  /// The phone-system context, cached for a few minutes (null = not available).
  static Future<PbxMe?> me({bool force = false}) async {
    final at = _meAt;
    if (!force && at != null && DateTime.now().difference(at) < _meTtl) {
      return _me;
    }
    if (!force && _meInFlight != null) return _meInFlight!;

    final api = ApiService();
    final request = resolveMe(
      fetchPolicyEnabled: api.getTelephonyPolicyEnabled,
      fetchTelephonyMe: api.getTelephonyMe,
    );
    final generation = ++_requestGeneration;
    _meInFlight = request;
    try {
      final resolved = await request;
      // Logout/reset or a newer forced refresh invalidates this result.
      if (generation != _requestGeneration) return null;
      _me = resolved;
      _meAt = DateTime.now();
      return resolved;
    } finally {
      if (identical(_meInFlight, request)) _meInFlight = null;
    }
  }

  /// Forget the cached context (logout, company switch).
  static void reset() {
    _me = null;
    _meAt = null;
    _meInFlight = null;
    _requestGeneration++;
  }

  /// Call history is only an app entry point once the pilot is provisioned.
  static bool canAccessCallHistory(PbxMe? me) => me?.provisioned == true;

  static Future<bool> canOpenCallHistory() async =>
      canAccessCallHistory(await me());

  /// Whether the phone system can place this user's calls.
  static bool canClickToCall(PbxMe? me) =>
      me != null && me.canClickToCall && me.hasExtension;

  /// Localized message for a refused click-to-call (`POST /telephony/calls/`).
  static String refusalMessage(
    String? code,
    PbxMe? me,
    String Function(String) t,
  ) {
    switch (code) {
      case 'concurrency_limit':
      case 'cps_limit':
      case 'phone_not_registered':
      case 'outbound_suspended':
      case 'pbx_unavailable':
      case 'destination_not_allowed':
      case 'invalid_destination':
      case 'no_extension':
      case 'not_provisioned':
      case 'monthly_pbx_minutes':
      case 'emergency_unroutable':
        return t(
          'pbxCallError_$code',
        ).replaceAll('{ext}', me?.extensionNumber ?? '');
      default:
        return t('pbxCallError_generic');
    }
  }

  static String deviceLabel(PbxMe? me, String Function(String) t) {
    switch (me?.deviceType) {
      case 'desk_phone':
        return t('pbxDevice_desk_phone');
      case 'webrtc':
        return t('pbxDevice_webrtc');
      default:
        return t('pbxDevice_softphone');
    }
  }

  /// Call [phone] (optionally for lead [leadId]). [dialer] opens this phone's
  /// dialer (default [dial]); screens pass their own to keep their error message.
  static Future<void> call(
    BuildContext context, {
    required String phone,
    int? leadId,
    Future<void> Function(String phone)? dialer,
  }) async {
    final openDialer = dialer ?? dial;
    final number = phone.trim();
    if (number.isEmpty) return;
    final loc = AppLocalizations.of(context);
    String t(String key) => loc?.translate(key) ?? key;
    final pbx = await me();
    if (!context.mounted) return;
    if (!canClickToCall(pbx)) {
      await openDialer(number);
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(number, style: Theme.of(ctx).textTheme.titleMedium),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: Text(t('pbxCallThroughSystem')),
              subtitle: Text(
                t('pbxCallThroughSystemHint')
                    .replaceAll('{device}', deviceLabel(pbx, t))
                    .replaceAll('{ext}', pbx!.extensionNumber ?? ''),
              ),
              onTap: () => Navigator.pop(ctx, 'pbx'),
            ),
            ListTile(
              leading: const Icon(Icons.phone_iphone),
              title: Text(t('callFromThisPhone')),
              onTap: () => Navigator.pop(ctx, 'dial'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'dial') {
      await openDialer(number);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await ApiService().placePbxCall(
      destination: number,
      crmContactId: leadId,
      idempotencyKey: const Uuid().v4(),
    );
    if (result.ok) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            t('pbxCallStarted').replaceAll('{device}', deviceLabel(pbx, t)),
          ),
        ),
      );
    } else {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(refusalMessage(result.code, pbx, t)),
          action: SnackBarAction(
            label: t('callFromThisPhone'),
            onPressed: () => openDialer(number),
          ),
        ),
      );
    }
  }

  /// This phone's own dialer.
  static Future<void> dial(String phone) async {
    try {
      await launchUrl(
        Uri.parse('tel:${phone.trim()}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // No dialer (tablet, emulator): nothing else to do.
    }
  }
}
