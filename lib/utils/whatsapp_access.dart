import '../models/user_model.dart';

/// WhatsApp Chats access rules, mirroring the backend (`integrations/whatsapp_access.py`)
/// and the web dashboard (`CRM-project/hooks/useWhatsAppChatsAllowed.ts`).
///
/// Kept in one place so the app bar icon, the drawer entry, the lead profile
/// shortcuts and the notification deep links all deny in exactly the same way.

/// Can the user open the WhatsApp Chats feature at all?
///
/// Admin/owner always; supervisors need `can_manage_whatsapp_chats`;
/// data entry and reception never; everyone else follows the per-user
/// `whatsapp_chat_enabled` toggle (defaults true).
bool canAccessWhatsAppChats(UserModel? user) {
  if (user == null) return false;
  if (user.isAdmin) return true;
  if (user.isSupervisor) {
    return user.hasSupervisorPermission('can_manage_whatsapp_chats');
  }
  if (user.isDataEntry || user.isReception) return false;
  return user.whatsappChatEnabled;
}

/// Can the user open a chat with a number that has no CRM lead?
///
/// Staff scoped to their own assignments (employee/doctor) only ever see leads
/// assigned to them, so the backend answers `whatsapp_contact_not_found` for
/// unknown numbers rather than leaking ownership. Everyone else who can reach
/// Chats — owners, admins and permitted supervisors — may keep manual threads.
bool canOpenManualWhatsAppChats(UserModel? user) {
  if (!canAccessWhatsAppChats(user)) return false;
  return !user!.isAssignedClinicalStaff;
}
