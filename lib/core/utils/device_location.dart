import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

enum DeviceLocationFailure {
  servicesDisabled,
  permissionDenied,
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.failure);

  final DeviceLocationFailure failure;
}

const _iosPreciseLocationPurposeKey = 'PreciseMapPin';

LocationSettings bestLocationSettings({
  Duration timeLimit = const Duration(seconds: 30),
}) {
  if (Platform.isAndroid) {
    return AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      timeLimit: timeLimit,
    );
  }
  if (Platform.isIOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.best,
      activityType: ActivityType.other,
      distanceFilter: 0,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: false,
      timeLimit: timeLimit,
    );
  }
  return LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
    timeLimit: timeLimit,
  );
}

Future<void> ensureDeviceLocationReady() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw const DeviceLocationException(DeviceLocationFailure.servicesDisabled);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const DeviceLocationException(DeviceLocationFailure.permissionDenied);
  }

  if (Platform.isIOS) {
    final accuracy = await Geolocator.getLocationAccuracy();
    if (accuracy == LocationAccuracyStatus.reduced) {
      await Geolocator.requestTemporaryFullAccuracy(
        purposeKey: _iosPreciseLocationPurposeKey,
      );
    }
  }
}

/// Waits for a fresh GPS fix, preferring readings within [targetAccuracyMeters].
Future<Position> getAccurateDevicePosition({
  double targetAccuracyMeters = 20,
  Duration timeout = const Duration(seconds: 30),
}) async {
  await ensureDeviceLocationReady();

  final settings = bestLocationSettings(timeLimit: timeout);
  Position? best;
  StreamSubscription<Position>? subscription;

  subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
    (position) {
      if (best == null || position.accuracy < best!.accuracy) {
        best = position;
      }
    },
  );

  try {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final current = best;
      if (current != null && current.accuracy <= targetAccuracyMeters) {
        return current;
      }
    }

    final fallback = best;
    if (fallback != null) {
      return fallback;
    }

    return Geolocator.getCurrentPosition(locationSettings: settings);
  } finally {
    await subscription.cancel();
  }
}
