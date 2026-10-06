import 'package:shared_preferences/shared_preferences.dart';

const _prefix = 'tab:';

/// Last selected [TabController] index for a screen. Clamped to `[0, maxIndex]`.
Future<int> loadTabIndex(String key, {required int maxIndex}) async {
  final prefs = await SharedPreferences.getInstance();
  final v = prefs.getInt('$_prefix$key') ?? 0;
  if (v < 0 || v > maxIndex) return 0;
  return v;
}

Future<void> saveTabIndex(String key, int index) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('$_prefix$key', index);
}
