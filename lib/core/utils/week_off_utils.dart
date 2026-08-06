import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _zonesLoaded = false;

void _ensureTimeZones() {
  if (_zonesLoaded) return;
  tzdata.initializeTimeZones();
  _zonesLoaded = true;
}

/// Monday = 0 .. Sunday = 6 in [iana] at instant [utc] (UTC).
int companyLocalWeekdayMonday0(String iana, DateTime utc) {
  final name = iana.trim().isEmpty ? 'UTC' : iana.trim();
  try {
    _ensureTimeZones();
    final loc = tz.getLocation(name);
    final z = tz.TZDateTime.from(utc.toUtc(), loc);
    return z.weekday - 1;
  } catch (_) {
    final w = utc.toUtc().weekday;
    return w - 1;
  }
}

bool isUserOnWeeklyDayOff(int? weeklyDayOff, String companyTimeZone) {
  if (weeklyDayOff == null) return false;
  final today = companyLocalWeekdayMonday0(companyTimeZone, DateTime.now());
  return weeklyDayOff == today;
}

/// HH:MM or HH:MM:SS → minutes since midnight, or null if invalid.
int? parseTimeToMinutes(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parts = value.trim().split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// Local time-of-day in minutes (company TZ).
int companyLocalMinutes(String iana, [DateTime? at]) {
  final utc = (at ?? DateTime.now()).toUtc();
  final name = iana.trim().isEmpty ? 'UTC' : iana.trim();
  try {
    _ensureTimeZones();
    final loc = tz.getLocation(name);
    final z = tz.TZDateTime.from(utc, loc);
    return z.hour * 60 + z.minute;
  } catch (_) {
    return utc.hour * 60 + utc.minute;
  }
}

bool _minutesInWindow(int nowMin, int startMin, int endMin) {
  if (startMin == endMin) return false;
  if (startMin < endMin) return nowMin >= startMin && nowMin <= endMin;
  return nowMin >= startMin || nowMin <= endMin;
}

bool isUserWithinWorkingHours({
  required String? workStartTime,
  required String? workEndTime,
  required String companyTimeZone,
  DateTime? at,
}) {
  final startMin = parseTimeToMinutes(workStartTime);
  final endMin = parseTimeToMinutes(workEndTime);
  if (startMin == null || endMin == null) return false;
  return _minutesInWindow(
    companyLocalMinutes(companyTimeZone, at),
    startMin,
    endMin,
  );
}

/// On-shift for urgent routing: not on day off + within working hours.
bool isUserOnShiftForUrgent({
  required int? weeklyDayOff,
  required String? workStartTime,
  required String? workEndTime,
  required String companyTimeZone,
  bool isActive = true,
  DateTime? at,
}) {
  if (!isActive) return false;
  if (isUserOnWeeklyDayOff(weeklyDayOff, companyTimeZone)) return false;
  return isUserWithinWorkingHours(
    workStartTime: workStartTime,
    workEndTime: workEndTime,
    companyTimeZone: companyTimeZone,
    at: at,
  );
}
