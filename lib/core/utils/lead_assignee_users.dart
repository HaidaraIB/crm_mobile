import '../../models/user_model.dart';

/// Whether [role] may appear in manual lead/deal assignee pickers.
/// Matches web `showInLeadAssigneePicker`: data-entry, reception and call center are excluded.
bool showInLeadAssigneePicker(UserModel user) =>
    !user.isDataEntry && !user.isReception && !user.isCallCenter;

/// Users shown in manual “assign lead” / edit-lead assignee UI.
/// Mirrors web `buildLeadAssigneePickerOptions`: active users only, excludes
/// data-entry and reception, and includes [currentUser] when pickable.
List<UserModel> usersForLeadAssigneePicker(
  Iterable<UserModel> all, {
  UserModel? currentUser,
}) {
  final map = <int, UserModel>{};
  for (final u in all) {
    if (!u.isActive) continue;
    if (!showInLeadAssigneePicker(u)) continue;
    map[u.id] = u;
  }
  if (currentUser != null &&
      currentUser.isActive &&
      showInLeadAssigneePicker(currentUser) &&
      !map.containsKey(currentUser.id)) {
    map[currentUser.id] = currentUser;
  }
  return map.values.toList();
}
