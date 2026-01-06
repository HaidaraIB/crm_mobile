import 'package:flutter/material.dart';

/// Utility class for handling keyboard-related UI adjustments
class KeyboardHandler {
  /// Gets the bottom padding needed to avoid keyboard overlap
  static double getBottomPadding(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return viewInsets > 0 ? viewInsets : 0;
  }

  /// Checks if keyboard is currently visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }
}

/// A widget that wraps content and automatically adjusts for keyboard
class KeyboardAwareWidget extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool enablePadding;

  const KeyboardAwareWidget({
    super.key,
    required this.child,
    this.padding,
    this.enablePadding = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enablePadding) {
      return child;
    }

    return Padding(
      padding: padding ?? EdgeInsets.only(
        bottom: KeyboardHandler.getBottomPadding(context),
      ),
      child: child,
    );
  }
}

