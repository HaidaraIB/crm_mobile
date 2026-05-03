import '../../models/user_model.dart';

/// Users shown in manual “assign lead” / edit-lead assignee UI.
/// Data-entry accounts are intake-only (server auto-assign); exclude from pickers.
List<UserModel> usersForLeadAssigneePicker(Iterable<UserModel> all) {
  return all.where((u) => !u.isDataEntry).toList();
}
