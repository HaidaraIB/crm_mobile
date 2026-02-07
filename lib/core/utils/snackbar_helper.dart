import 'package:flutter/material.dart';

/// Snackbar text: white in dark mode, black in light mode.
/// Success: green background. Error: red background.
class SnackbarHelper {
  static Color _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: _textColor(context)),
        ),
        backgroundColor: Colors.green,
        duration: duration,
      ),
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: _textColor(context)),
        ),
        backgroundColor: Colors.red,
        duration: duration,
      ),
    );
  }

  /// Use when showing snackbar after Navigator.pop (e.g. in dialogs). Pass brightness from Theme.of(context) before pop.
  static void showSuccessWithMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    required Brightness brightness,
    Duration duration = const Duration(seconds: 2),
  }) {
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: textColor)),
        backgroundColor: Colors.green,
        duration: duration,
      ),
    );
  }

  static void showErrorWithMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    required Brightness brightness,
    Duration duration = const Duration(seconds: 4),
  }) {
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: textColor)),
        backgroundColor: Colors.red,
        duration: duration,
      ),
    );
  }
}
