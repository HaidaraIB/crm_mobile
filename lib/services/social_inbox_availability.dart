import 'package:flutter/foundation.dart';

/// Whether this tenant may open Omni-Channel Inbox.
///
/// `null` until the first digest. `false` when `social_inbox_unread` is null
/// (plan or admin policy) — hide the entry and do not call the inbox API.
class SocialInboxAvailability {
  SocialInboxAvailability._();

  static final ValueNotifier<bool?> available = ValueNotifier<bool?>(null);

  static void setAvailable(bool value) {
    if (available.value != value) available.value = value;
  }

  static void reset() {
    available.value = null;
  }
}
