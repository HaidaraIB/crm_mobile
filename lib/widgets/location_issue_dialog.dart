import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/localization/app_localizations.dart';
import '../core/utils/device_location.dart';

Future<void> showDeviceLocationIssueDialog(
  BuildContext context,
  DeviceLocationFailure failure,
) async {
  final localizations = AppLocalizations.of(context);
  String t(String key, String fallback) =>
      localizations?.translate(key) ?? fallback;

  final isServicesDisabled =
      failure == DeviceLocationFailure.servicesDisabled;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        isServicesDisabled ? Icons.location_disabled : Icons.location_off,
        color: Colors.orange.shade700,
        size: 32,
      ),
      title: Text(
        isServicesDisabled
            ? t('locationServicesDisabledTitle', 'Location is turned off')
            : t('locationPermissionDeniedTitle', 'Location permission needed'),
      ),
      content: Text(
        isServicesDisabled
            ? t(
                'locationServicesDisabled',
                'Location services are disabled. Please enable them and try again.',
              )
            : t(
                'locationPermissionDenied',
                'Location permission denied. Please allow location access and try again.',
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(t('cancel', 'Cancel')),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            if (isServicesDisabled) {
              Geolocator.openLocationSettings();
            } else {
              Geolocator.openAppSettings();
            }
          },
          child: Text(
            isServicesDisabled
                ? t('openLocationSettings', 'Open location settings')
                : t('openAppSettings', 'Open app settings'),
          ),
        ),
      ],
    ),
  );
}
