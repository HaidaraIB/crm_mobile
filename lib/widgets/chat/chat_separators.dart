import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/app_locales.dart';
import 'chat_palette.dart';

/// Day chip label: Today / Yesterday / short date.
String chatDayChipLabel(
  DateTime dayStart, {
  required String language,
  required String Function(String key) t,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final day = DateTime(dayStart.year, dayStart.month, dayStart.day);
  if (day == today) return t('teamChatDayToday');
  if (day == yesterday) return t('teamChatDayYesterday');
  final locale = AppLocales.intlDateFormat(AppLocales.fromLanguageCode(language));
  return withLatinDigits(DateFormat('d MMM y', locale).format(day));
}

/// Centered pill for a day separator row.
class ChatDaySeparatorChip extends StatelessWidget {
  const ChatDaySeparatorChip({
    super.key,
    required this.label,
    required this.palette,
  });

  final String label;
  final ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: palette.statusChipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.statusChipFg,
            ),
          ),
        ),
      ),
    );
  }
}

/// Unread divider label.
class ChatUnreadSeparatorChip extends StatelessWidget {
  const ChatUnreadSeparatorChip({
    super.key,
    required this.label,
    required this.palette,
  });

  final String label;
  final ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: palette.statusChipBg)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.statusChipFg,
              ),
            ),
          ),
          Expanded(child: Divider(color: palette.statusChipBg)),
        ],
      ),
    );
  }
}
