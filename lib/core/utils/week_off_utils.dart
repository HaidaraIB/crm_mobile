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
