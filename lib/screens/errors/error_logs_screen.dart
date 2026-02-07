import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/error_logger.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/theme/app_theme.dart';

class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  final ErrorLogger _errorLogger = ErrorLogger();
  String _selectedLogText = '';

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final logs = _errorLogger.getLogs();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('errorLogs') ?? 'Error Logs'),
        actions: [
          if (logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(localizations?.translate('clearLogs') ?? 'Clear Logs'),
                    content: Text(
                      localizations?.translate('clearLogsConfirm') ?? 
                      'Are you sure you want to clear all error logs?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(localizations?.translate('cancel') ?? 'Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          _errorLogger.clearLogs();
                          Navigator.pop(context);
                          setState(() {});
                        },
                        child: Text(
                          localizations?.translate('clear') ?? 'Clear',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all),
              onPressed: () {
                final allLogs = _errorLogger.getAllLogsAsString();
                Clipboard.setData(ClipboardData(text: allLogs));
                SnackbarHelper.showSuccess(
                  context,
                  localizations?.translate('logsCopied') ?? 'All logs copied to clipboard',
                );
              },
            ),
        ],
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations?.translate('noErrors') ?? 'No errors logged yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Summary Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${logs.length} ${localizations?.translate('errors') ?? 'error(s)'}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations?.translate('tapToViewDetails') ?? 
                        'Tap on any error to view details and copy',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),

                // Error List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isSelected = _selectedLogText == log.toFormattedString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedLogText = isSelected 
                                  ? '' 
                                  : log.toFormattedString();
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.error,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        log.error.split('\n').first,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      isSelected 
                                          ? Icons.expand_less 
                                          : Icons.expand_more,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTimestamp(log.timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (log.endpoint != null) ...[
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.link,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${log.method ?? 'GET'} ${log.endpoint}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                
                                // Expanded Details
                                if (isSelected) ...[
                                  const Divider(height: 24),
                                  SelectableText(
                                    log.toFormattedString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: log.toFormattedString()),
                                          );
                                          SnackbarHelper.showSuccess(
                                            context,
                                            localizations?.translate('logCopied') ?? 
                                                'Error log copied to clipboard',
                                          );
                                        },
                                        icon: const Icon(Icons.copy, size: 16),
                                        label: Text(
                                          localizations?.translate('copy') ?? 'Copy',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

