import '../../models/user_model.dart';

class PbxDialAvailability {
  final bool canPbxDial;
  final bool showPbxButton;

  const PbxDialAvailability({
    required this.canPbxDial,
    required this.showPbxButton,
  });

  static const unavailable = PbxDialAvailability(
    canPbxDial: false,
    showPbxButton: false,
  );

  static PbxDialAvailability fromSettings({
    required Map<String, dynamic>? settings,
    required List<Map<String, dynamic>> extensions,
    required UserModel? currentUser,
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

    return const PbxDialAvailability(
      canPbxDial: true,
      showPbxButton: true,
    );
  }
}
