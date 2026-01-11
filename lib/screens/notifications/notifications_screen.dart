import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/notification_model.dart';
import '../../services/api_service.dart';
import '../../services/notification_router.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;
  int _unreadCount = 0;
  String? _filter; // 'all', 'unread', 'read'

  @override
  void initState() {
    super.initState();
    _filter = 'all';
    _loadNotifications();
    _loadUnreadCount();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      bool? readFilter;
      if (_filter == 'unread') {
        readFilter = false;
      } else if (_filter == 'read') {
        readFilter = true;
      }

      final notifications = await _apiService.getNotifications(
        read: readFilter,
      );

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });

      // تحديث عدد غير المقروءة بعد تحميل الإشعارات
      _loadUnreadCount();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _apiService.getUnreadNotificationsCount();
      setState(() {
        _unreadCount = count;
      });
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  Future<void> _refreshNotifications() async {
    await Future.wait([
      _loadNotifications(),
      _loadUnreadCount(),
    ]);
  }

  Future<void> _markAsRead(int notificationId, int index) async {
    try {
      await _apiService.markNotificationAsRead(notificationId);
      
      setState(() {
        _notifications[index]['read'] = true;
        _notifications[index]['read_at'] = DateTime.now().toIso8601String();
        if (_unreadCount > 0) {
          _unreadCount--;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('notificationMarkedAsRead') ?? 
              'Notification marked as read',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('failedToMarkAsRead') ?? 
              'Failed to mark as read',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsAsRead();
      
      // تحديث جميع الإشعارات في القائمة
      setState(() {
        for (var notification in _notifications) {
          if (!(notification['read'] as bool? ?? false)) {
            notification['read'] = true;
            notification['read_at'] = DateTime.now().toIso8601String();
          }
        }
        _unreadCount = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('allNotificationsMarkedAsRead') ?? 
              'All notifications marked as read',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('failedToMarkAllAsRead') ?? 
              'Failed to mark all as read',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteAllRead() async {
    final readCount = _notifications.where((n) => n['read'] == true).length;
    
    if (readCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('noReadNotifications') ?? 
              'No read notifications to delete',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.translate('deleteReadNotifications') ?? 
          'Delete Read Notifications',
        ),
        content: Text(
          AppLocalizations.of(context)?.translate('deleteReadNotificationsConfirm') ?? 
          'Are you sure you want to delete all read notifications?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)?.translate('delete') ?? 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.deleteAllReadNotifications();
      
      setState(() {
        _notifications = _notifications.where((n) => n['read'] != true).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('readNotificationsDeleted') ?? 
              'Read notifications deleted',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('failedToDeleteReadNotifications') ?? 
              'Failed to delete read notifications',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onNotificationTap(Map<String, dynamic> notification) {
    // تحديد كمقروء إذا لم يكن مقروءاً
    final isRead = notification['read'] as bool? ?? false;
    final notificationId = notification['id'] as int?;
    
    if (!isRead && notificationId != null) {
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _markAsRead(notificationId, index);
      }
    }

    // التنقل إلى الشاشة المناسبة
    final typeString = notification['type'] as String? ?? 'unknown';
    final type = NotificationType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => NotificationType.unknown,
    );

    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final title = notification['title'] as String? ?? '';
    final body = notification['body'] as String? ?? '';
    
    final payload = NotificationPayload(
      type: type,
      title: title,
      body: body,
      data: data,
      notificationId: notificationId,
    );
    
    NotificationRouter.navigateFromNotification(
      context,
      payload,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations?.translate('notifications') ?? 'Notifications',
        ),
        actions: [
          // Filter button
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
              _loadNotifications();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.list,
                      size: 20,
                      color: _filter == 'all' ? AppTheme.primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      localizations?.translate('all') ?? 'All',
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unread',
                child: Row(
                  children: [
                    Icon(
                      Icons.mark_email_unread,
                      size: 20,
                      color: _filter == 'unread' ? AppTheme.primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      localizations?.translate('unread') ?? 'Unread',
                    ),
                    if (_unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'read',
                child: Row(
                  children: [
                    Icon(
                      Icons.mark_email_read,
                      size: 20,
                      color: _filter == 'read' ? AppTheme.primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      localizations?.translate('read') ?? 'Read',
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Mark all as read
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: localizations?.translate('markAllAsRead') ?? 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
          // Delete all read
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: localizations?.translate('deleteReadNotifications') ?? 'Delete read notifications',
            onPressed: _deleteAllRead,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadNotifications,
                          child: Text(
                            localizations?.translate('retry') ?? 'Retry',
                          ),
                        ),
                      ],
                    ),
                  )
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              localizations?.translate('noNotifications') ?? 'No notifications',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final isRead = notification['read'] as bool? ?? false;
                          final notificationId = notification['id'] as int?;
                          final title = notification['title'] as String? ?? '';
                          final body = notification['body'] as String? ?? '';
                          final typeString = notification['type'] as String? ?? 'unknown';
                          final sentAt = notification['sent_at'] as String?;
                          
                          DateTime? sentDate;
                          if (sentAt != null) {
                            sentDate = DateTime.tryParse(sentAt);
                          }

                          final type = NotificationType.values.firstWhere(
                            (e) => e.name == typeString,
                            orElse: () => NotificationType.unknown,
                          );

                          return Dismissible(
                            key: Key('notification_${notificationId ?? index}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (direction) {
                              if (notificationId != null) {
                                _markAsRead(notificationId, index);
                              }
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              color: isRead
                                  ? null
                                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isRead
                                      ? theme.colorScheme.surfaceContainerHighest
                                      : AppTheme.primaryColor.withValues(alpha: 0.2),
                                  child: Icon(
                                    NotificationRouter.getIconForType(type),
                                    color: isRead
                                        ? theme.colorScheme.onSurfaceVariant
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                                title: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(body),
                                    if (sentDate != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(sentDate, localizations?.locale.languageCode ?? 'en'),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: isRead
                                    ? null
                                    : Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                onTap: () => _onNotificationTap(notification),
                                onLongPress: () {
                                  if (notificationId != null && !isRead) {
                                    _markAsRead(notificationId, index);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  String _formatDate(DateTime date, String languageCode) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return AppLocalizations.of(context)?.translate('justNow') ?? 'Just now';
        }
        return '${difference.inMinutes} ${AppLocalizations.of(context)?.translate('minutesAgo') ?? 'minutes ago'}';
      }
      return '${difference.inHours} ${AppLocalizations.of(context)?.translate('hoursAgo') ?? 'hours ago'}';
    } else if (difference.inDays == 1) {
      return AppLocalizations.of(context)?.translate('yesterday') ?? 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${AppLocalizations.of(context)?.translate('daysAgo') ?? 'days ago'}';
    } else {
      return DateFormat('MMM d, yyyy', languageCode).format(date);
    }
  }
}
