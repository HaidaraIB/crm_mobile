import '../../models/user_model.dart';
import '../../services/softphone_service.dart';

class PbxDialAvailability {
  final bool canPbxDial;
  final bool canSoftphoneDial;
  final bool showSoftphoneButton;
  final bool showPbxButton;

  const PbxDialAvailability({
    required this.canPbxDial,
    required this.canSoftphoneDial,
    required this.showSoftphoneButton,
    required this.showPbxButton,
  });

  static const unavailable = PbxDialAvailability(
    canPbxDial: false,
    canSoftphoneDial: false,
    showSoftphoneButton: false,
    showPbxButton: false,
  );

  static PbxDialAvailability fromSettings({
    required Map<String, dynamic>? settings,
    required List<Map<String, dynamic>> extensions,
    required UserModel? currentUser,
    SoftphoneRegState regState = SoftphoneRegState.idle,
  }) {
    if (settings == null || settings['is_enabled'] != true || currentUser == null) {
      return unavailable;
    }

    final userId = currentUser.id;
    final username = (currentUser.username ?? '').trim().toLowerCase();

    Map<String, dynamic>? userExtension;
    for (final row in extensions) {
      final rowUserId = row['user_id'];
      if (rowUserId != null && rowUserId == userId) {
        userExtension = row;
        break;
      }
      final rowUsername = (row['username'] as String?)?.trim().toLowerCase() ?? '';
      if (username.isNotEmpty && rowUsername == username) {
        userExtension = row;
        break;
      }
    }

    if (userExtension == null) {
      return unavailable;
    }

    final canPbx = true;
    final companySoftphoneOn = settings['softphone_enabled'] == true;
    final perUserSoftphoneOn = userExtension['softphone_enabled'] != false;
    final sipConfigured = userExtension['sip_password_masked'] != null &&
        (userExtension['sip_password_masked'] as String).isNotEmpty;
    final canSoftphone = companySoftphoneOn && perUserSoftphoneOn && sipConfigured;
    final showSoftphone =
        canSoftphone && regState == SoftphoneRegState.registered;

    return PbxDialAvailability(
      canPbxDial: canPbx,
      canSoftphoneDial: canSoftphone,
      showSoftphoneButton: showSoftphone,
      showPbxButton: canPbx && !showSoftphone,
    );
  }
}
