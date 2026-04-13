import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

import '../core/constants/app_constants.dart';
import '../models/mobile_app_version_policy.dart';
import 'api_service.dart';

enum AppVersionGateOutcome {
  /// Proceed with normal app flow.
  allowed,

  /// Installed build is below server minimum; user must update from the store.
  blockedNeedsUpdate,

  /// Policy could not be loaded (fail-closed).
  blockedCouldNotVerify,
}

/// Result of [AppVersionGate.evaluate] with resolved store URL when blocked for update.
class AppVersionGateResult {
  const AppVersionGateResult({
    required this.outcome,
    required this.storeUrl,
  });

  const AppVersionGateResult.allowed()
      : outcome = AppVersionGateOutcome.allowed,
        storeUrl = '';

  const AppVersionGateResult.blockedCouldNotVerify()
      : outcome = AppVersionGateOutcome.blockedCouldNotVerify,
        storeUrl = '';

  AppVersionGateResult.needsUpdate(String url)
      : outcome = AppVersionGateOutcome.blockedNeedsUpdate,
        storeUrl = url;

  final AppVersionGateOutcome outcome;
  final String storeUrl;
}

/// Startup / resume gate: compare [PackageInfo] to server minimums (fail-closed on fetch errors).
class AppVersionGate {
  AppVersionGate._();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Public policy fetch + local version comparison.
  static Future<AppVersionGateResult> evaluate() async {
    if (!_isAndroid && !_isIos) {
      return const AppVersionGateResult.allowed();
    }

    MobileAppVersionPolicy policy;
    try {
      policy = await ApiService().fetchMobileAppVersionPolicy();
    } catch (_) {
      return const AppVersionGateResult.blockedCouldNotVerify();
    }

    final info = await PackageInfo.fromPlatform();
    final minVersion = _isAndroid
        ? policy.minimumVersionAndroid
        : policy.minimumVersionIos;
    final minBuild =
        _isAndroid ? policy.minimumBuildAndroid : policy.minimumBuildIos;

    if (minVersion.isEmpty) {
      return const AppVersionGateResult.allowed();
    }

    if (!_meetsMinimumVersion(
      installedVersion: info.version,
      installedBuild: info.buildNumber,
      minimumVersion: minVersion,
      minimumBuild: minBuild,
    )) {
      final fromApi =
          _isAndroid ? policy.storeUrlAndroid : policy.storeUrlIos;
      final fallback = _isAndroid
          ? AppConstants.storeUrlAndroidFallback
          : AppConstants.storeUrlIosFallback;
      final url = (fromApi.isNotEmpty ? fromApi : fallback).trim();
      return AppVersionGateResult.needsUpdate(url);
    }

    return const AppVersionGateResult.allowed();
  }

  /// True if installed version/build satisfies minimum (semver for version).
  static bool _meetsMinimumVersion({
    required String installedVersion,
    required String installedBuild,
    required String minimumVersion,
    required int? minimumBuild,
  }) {
    Version installed;
    Version minimum;
    try {
      installed = Version.parse(_normalizeSemver(installedVersion));
      minimum = Version.parse(_normalizeSemver(minimumVersion));
    } on FormatException {
      return true;
    }

    if (installed < minimum) return false;
    if (installed > minimum) return true;

    if (minimumBuild == null) return true;
    final ib = int.tryParse(installedBuild.trim()) ?? 0;
    return ib >= minimumBuild;
  }

  /// Allows values like `1.2.1+6` by taking the part before `+` for semver parse.
  static String _normalizeSemver(String raw) {
    final s = raw.trim();
    final plus = s.indexOf('+');
    return plus >= 0 ? s.substring(0, plus) : s;
  }
}
