import '../models/user_model.dart';

/// True if [user] can access the Inventory section (Properties/Owners/Services/
/// Products): admin always; supervisor only if they have the permission matching
/// their company specialization; data entry/reception/call center never.
///
/// Shared by the drawer (which hides the Inventory entry point) and the
/// individual inventory screens (which must enforce the same rule at the
/// destination, since they're reachable via `Navigator.push` regardless of
/// which entry point rendered) so the two can never drift apart.
bool canAccessInventory(UserModel? user) {
  if (user == null || user.company == null) return false;
  if (user.isDataEntry || user.isReception || user.isCallCenter) return false;
  if (user.isAdmin) return true;
  if (user.isSupervisor) {
    final spec = user.company!.specialization;
    if (spec == 'real_estate') {
      return user.hasSupervisorPermission('can_manage_real_estate');
    }
    if (spec == 'products') {
      return user.hasSupervisorPermission('can_manage_products');
    }
    if (spec == 'services') {
      return user.hasSupervisorPermission('can_manage_services');
    }
    return false;
  }
  return true; // employees can see inventory (access controlled per screen)
}
