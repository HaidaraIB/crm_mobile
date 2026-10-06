import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Full-body placeholder while a chat thread verifies session / window /
/// messages. Prevents locked banners and composers from flashing unverified
/// defaults (e.g. a closed Meta reply window before the API answers).
class ChatThreadOpening extends StatelessWidget {
  const ChatThreadOpening({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryAccent(theme.brightness),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
