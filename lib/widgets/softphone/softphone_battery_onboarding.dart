import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time OEM battery / autostart guidance for reliable softphone wake-up.
class SoftphoneBatteryOnboarding {
  SoftphoneBatteryOnboarding._();
  static const _prefKey = 'softphone_battery_onboarding_shown';

  static Future<void> maybeShow(BuildContext context) async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) return;

    final manufacturer = (await _deviceManufacturer()).toLowerCase();
    final isAggressiveOem = manufacturer.contains('samsung') ||
        manufacturer.contains('xiaomi') ||
        manufacturer.contains('redmi') ||
        manufacturer.contains('huawei') ||
        manufacturer.contains('honor') ||
        manufacturer.contains('oppo') ||
        manufacturer.contains('vivo');

    if (!isAggressiveOem) {
      await prefs.setBool(_prefKey, true);
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reliable incoming calls'),
        content: const Text(
          'On this device, disable battery optimization and enable autostart for LOOP CRM '
          'so incoming calls can wake the app when it is closed.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool(_prefKey, true);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () async {
              await prefs.setBool(_prefKey, true);
              await openAppSettings();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  static Future<String> _deviceManufacturer() async {
    try {
      // package_info doesn't expose manufacturer; use a coarse Android heuristic.
      return Platform.operatingSystemVersion;
    } catch (_) {
      return '';
    }
  }
}
