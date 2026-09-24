import '../models/user_model.dart';

// Omni-Channel Inbox access rules, mirroring the backend
// (`integrations/social_inbox_access.py`) and the web dashboard.
//
// Deliberately the mirror image of whatsapp_access.dart on one axis: CALL_CENTER
// is the primary audience here — triaging Instagram/Messenger DMs and converting
// the interested ones is the role's job — whereas WhatsApp denies it outright.
// Both rules are live at once; do not "harmonize" them.

/// Can the user open the Inbox at all?
///
/// Admin/owner and call-center always; supervisors need `can_manage_social_inbox`;
/// reception and data entry never; employee/doctor may open it but the backend
/// scopes them to conversations tied to their own converted leads.
bool canAccessSocialInbox(UserModel? user) {
  if (user == null) return false;
  if (user.isAdmin || user.isCallCenter) return true;
  if (user.isSupervisor) {
    return user.hasSupervisorPermission('can_manage_social_inbox');
  }
  if (user.isReception || user.isDataEntry) return false;
  return user.isAssignedClinicalStaff;
}

/// Company-wide visibility across every conversation, converted or not.
bool userSeesAllSocialConversations(UserModel? user) {
  if (user == null) return false;
  if (user.isAdmin || user.isCallCenter) return true;
  if (user.isSupervisor) {
    return user.hasSupervisorPermission('can_manage_social_inbox');
  }
  return false;
}

/// Employee/Doctor: limited to conversations tied to their own converted leads.
bool isSocialInboxStaffScoped(UserModel? user) {
  return user != null && user.isAssignedClinicalStaff;
}

/// Who may turn a conversation into a CRM lead and pick its assignee.
bool canConvertSocialConversation(UserModel? user) {
  if (user == null) return false;
  if (user.isAdmin || user.isCallCenter) return true;
  if (user.isSupervisor) {
    return user.hasSupervisorPermission('can_manage_social_inbox') ||
        user.hasSupervisorPermission('can_manage_leads');
  }
  return false;
}

/// Empty-list copy: triage roles see every DM; staff only see assigned converted leads.
String socialInboxEmptyHintKey(UserModel? user) {
  if (isSocialInboxStaffScoped(user)) {
    return 'noSocialConversationsHintAssigned';
  }
  return 'noSocialConversationsHint';
}

/// Localization key for an inbox-unavailable API 403.
///
/// These are not retryable load failures — the drawer entry should hide and the
/// screen should explain rather than offering "Retry".
String socialInboxUnavailableMessageKey(String? code) {
  switch (code) {
    case 'integration_disabled':
      return 'socialInboxUnavailablePolicy';
    case 'plan_integration_disabled':
      return 'socialInboxUnavailablePlan';
    case 'social_inbox_access_disabled':
      return 'socialInboxAccessDisabled';
    default:
      return 'socialInboxUnavailable';
  }
}

/// Maps a send/convert `error_key` to a localization key.
String socialSendErrorMessageKey(String? code) {
  switch (code) {
    case 'social_outside_window':
      return 'socialOutsideWindow';
    case 'social_user_unavailable':
      return 'socialUserUnavailable';
    case 'social_permission_denied':
      return 'socialPermissionDenied';
    case 'social_token_invalid':
      return 'socialTokenInvalid';
    case 'social_rate_limited':
      return 'socialRateLimited';
    case 'social_temporarily_blocked':
      return 'socialTemporarilyBlocked';
    case 'social_contact_unsubscribed':
      return 'socialContactUnsubscribed';
    case 'social_media_too_large':
      return 'socialMediaTooLarge';
    case 'social_media_type_not_allowed':
      return 'socialMediaTypeNotAllowed';
    case 'social_already_converted':
      return 'socialAlreadyConverted';
    case 'plan_quota_max_clients_exceeded':
      return 'socialLeadQuotaReached';
    case 'social_phone_required':
      return 'social_phone_required';
    case 'social_phone_invalid':
      return 'social_phone_invalid';
    default:
      return 'socialInboxCouldNotSend';
  }
}
