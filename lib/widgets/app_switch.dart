import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// High-contrast toggle used across the app.
///
/// Prefer this over [Switch], [Switch.adaptive], and raw [SwitchListTile]
/// so dark-mode tracks stay visible against navy cards.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: Theme.of(context).copyWith(
        switchTheme: AppTheme.switchThemeFor(brightness),
      ),
      child: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// [SwitchListTile] wired to the same high-contrast [AppSwitch] colors.
class AppSwitchListTile extends StatelessWidget {
  const AppSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: Theme.of(context).copyWith(
        switchTheme: AppTheme.switchThemeFor(brightness),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        contentPadding: contentPadding,
        dense: dense,
      ),
    );
  }
}
