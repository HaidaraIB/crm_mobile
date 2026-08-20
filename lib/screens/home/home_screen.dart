import 'package:flutter/material.dart' hide NavigationDrawer;
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_locales.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../services/api_service.dart';
import '../../services/team_chat_away_service.dart';
import '../../services/team_chat_unread_holder.dart';
import '../../services/whatsapp_chat_unread_holder.dart';
import '../../services/whatsapp_chat_unread_poller.dart';
import '../../utils/whatsapp_access.dart';
import '../../widgets/navigation_drawer.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/work_hours_chip.dart';
import '../calendar/calendar_screen.dart';
import '../call_center/call_center_home_screen.dart';
import '../leads/all_leads_screen.dart';
import '../notifications/notifications_screen.dart';
import '../team_chat/team_chat_screen.dart';
import '../whatsapp_chat/whatsapp_conversation_list_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime _selectedCalendarDate = DateTime.now();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _allLeadsKey = GlobalKey();
  VoidCallback? _showAllLeadsFilterCallback;
  bool Function()? _checkAllLeadsFiltersCallback;
  VoidCallback? _importLeadsCallback;
  VoidCallback? _exportLeadsCallback;
  final ApiService _apiService = ApiService();
  int _unreadNotificationsCount = 0;
  UserModel? _sessionUser;
  late final Widget _dashboardScreen;
  late final Widget _allLeadsScreen;
  late final Widget _calendarScreen;

  /// False until `_loadSessionUser` settles. The tab bodies stay unmounted until
  /// then: `IndexedStack` builds *every* child, so mounting it before the role is
  /// known fires dashboard/calendar requests that restricted roles (call center,
  /// data entry, reception) are forbidden from making.
  bool _sessionResolved = false;

  bool get _isDataEntry => _sessionUser?.isDataEntry ?? false;

  /// Gate the WhatsApp Chats app bar icon. See `utils/whatsapp_access.dart`.
  bool _canAccessWhatsAppChats(UserModel? user) => canAccessWhatsAppChats(user);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardScreen = DashboardScreen(key: _dashboardKey);
    _allLeadsScreen = AllLeadsScreen(
      key: _allLeadsKey,
      showAppBar: false,
      onFilterRequested: (callback) {
        _showAllLeadsFilterCallback = callback;
      },
      onHasActiveFiltersRequested: (callback) {
        _checkAllLeadsFiltersCallback = callback;
      },
      onImportRequested: (callback) {
        _importLeadsCallback = callback;
      },
      onExportRequested: (callback) {
        _exportLeadsCallback = callback;
      },
    );
    _calendarScreen = CalendarScreen(
      key: _calendarKey,
      initialDate: _selectedCalendarDate,
    );
    _loadSessionUser();
    // إرسال FCM token للمستخدمين المسجلين دخول بالفعل
    _sendFCMTokenIfLoggedIn();
    // على iOS قد يتأخر استلام FCM token؛ إعادة المحاولة بعد 3 و 8 ثوانٍ لضمان حفظ التوكن في الخادم
    _scheduleFCMTokenRetries();
    // تحميل عدد الإشعارات غير المقروءة
    _loadUnreadCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WhatsAppChatUnreadPoller.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    WhatsAppChatUnreadPoller.instance.setForeground(
      state == AppLifecycleState.resumed,
    );
  }

  Future<void> _loadSessionUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      if (!mounted) return;
      // Call center is a front-desk role with no dashboard/leads/calendar access —
      // send it to its own screen instead of mounting tabs it would only 403 on.
      if (user.isCallCenter) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const CallCenterHomeScreen(isRoot: true),
          ),
        );
        return;
      }
      setState(() {
        _sessionUser = user;
        _sessionResolved = true;
        if (user.isDataEntry || user.isReception) {
          _currentIndex = 1;
        }
      });
      TeamChatAwayService.instance.start();
      WhatsAppChatUnreadPoller.instance.reset();
      WhatsAppChatUnreadPoller.instance.start();
    } catch (e) {
      debugPrint('Failed to load session user: $e');
      // Fall back to the default tabs rather than stranding the user on a spinner.
      if (mounted) setState(() => _sessionResolved = true);
    }
  }

  /// جدولة إعادة إرسال FCM token (لمعالجة التأخر على iOS)
  void _scheduleFCMTokenRetries() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      NotificationService().sendTokenToServerIfLoggedIn();
    });
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      NotificationService().sendTokenToServerIfLoggedIn();
    });
  }

  /// تحميل عدد الإشعارات غير المقروءة
  Future<void> _loadUnreadCount({bool forceRefresh = false}) async {
    try {
      final count = await _apiService.getUnreadNotificationsCount(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    } catch (e) {
      debugPrint('Warning: Failed to load unread notifications count: $e');
    }
  }

  /// Team chat entry in the app bar (replaces drawer shortcut). Unread badge matches [TeamChatUnreadHolder].
  Widget _teamChatAppBarAction(AppLocalizations? localizations) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: localizations?.translate('teamChat') ?? 'Team Chat',
          onPressed: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'TeamChatScreen'),
                builder: (_) => const TeamChatScreen(),
              ),
            );
          },
        ),
        ValueListenableBuilder<int>(
          valueListenable: TeamChatUnreadHolder.totalUnread,
          builder: (context, count, _) {
            if (count <= 0) return const SizedBox.shrink();
            return Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// WhatsApp Chats entry in the app bar. Unread badge matches [WhatsAppChatUnreadHolder].
  Widget _whatsAppChatAppBarAction(AppLocalizations? localizations) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Image.asset(
            'assets/images/whatsapp_logo.png',
            width: 45,
            height: 45,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.chat_outlined);
            },
          ),
          tooltip:
              localizations?.translate('whatsappChats') ?? 'WhatsApp Chats',
          onPressed: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                settings: const RouteSettings(
                  name: 'WhatsAppConversationListScreen',
                ),
                builder: (_) => const WhatsAppConversationListScreen(),
              ),
            );
          },
        ),
        ValueListenableBuilder<int>(
          valueListenable: WhatsAppChatUnreadHolder.totalUnread,
          builder: (context, count, _) {
            if (count <= 0) return const SizedBox.shrink();
            return Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Shown on every cold start until the role is known — a bare
  /// [CircularProgressIndicator] on an empty page read as a broken screen.
  Widget _buildSessionLoadingState(AppLocalizations? localizations) {
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
            localizations?.translate('loading') ?? 'Loading...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  /// إرسال FCM token إذا كان المستخدم مسجل دخول
  Future<void> _sendFCMTokenIfLoggedIn() async {
    try {
      final notificationService = NotificationService();
      await notificationService.sendTokenToServerIfLoggedIn();
      debugPrint('FCM Token sent to server (for already logged in user)');
    } catch (e) {
      debugPrint('Warning: Failed to send FCM token for logged in user: $e');
      // لا نعرض خطأ للمستخدم لأن هذا ليس حرجاً
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    String getAppBarTitle() {
      if (_isDataEntry) {
        return localizations?.translate('allLeads') ?? 'All Leads';
      }
      switch (_currentIndex) {
        case 0:
          return localizations?.translate('home') ?? 'Home';
        case 1:
          return localizations?.translate('allLeads') ?? 'All Leads';
        case 2:
          return localizations?.translate('calendar') ?? 'Calendar';
        default:
          return localizations?.translate('home') ?? 'Home';
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: _currentIndex == 2
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Column(
                children: [
                  Text(getAppBarTitle()),
                  Text(
                    DateFormat(
                      'MMMM yyyy',
                      AppLocales.intlDateFormat(
                        localizations?.locale ?? AppLocales.english,
                      ),
                    ).format(_selectedCalendarDate),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedCalendarDate = DateTime(
                        _selectedCalendarDate.year,
                        _selectedCalendarDate.month - 1,
                      );
                    });
                    (_calendarKey.currentState as dynamic)?.navigateMonth(-1);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedCalendarDate = DateTime(
                        _selectedCalendarDate.year,
                        _selectedCalendarDate.month + 1,
                      );
                    });
                    (_calendarKey.currentState as dynamic)?.navigateMonth(1);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    (_calendarKey.currentState as dynamic)?.refreshEvents();
                  },
                ),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(getAppBarTitle()),
              actions: [
                // Import / Export for All Leads page
                if (_currentIndex == 1 || _isDataEntry) ...[
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined),
                    tooltip:
                        localizations?.translate('importLeads') ??
                        'Import from Excel',
                    onPressed: () => _importLeadsCallback?.call(),
                  ),
                  if (!_isDataEntry)
                    IconButton(
                      icon: const Icon(Icons.file_upload_outlined),
                      tooltip:
                          localizations?.translate('exportLeads') ??
                          'Export to Excel',
                      onPressed: () => _exportLeadsCallback?.call(),
                    ),
                  Builder(
                    builder: (context) {
                      // Check if filters are active
                      final hasActiveFilters =
                          _checkAllLeadsFiltersCallback?.call() ?? false;

                      return IconButton(
                        icon: Stack(
                          children: [
                            const Icon(Icons.filter_list),
                            if (hasActiveFilters)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () {
                          _showAllLeadsFilterCallback?.call();
                        },
                        tooltip: localizations?.translate('filter') ?? 'Filter',
                      );
                    },
                  ),
                ],
                if (_currentIndex == 0) ...[
                  const WorkHoursChip(),
                  if (_canAccessWhatsAppChats(_sessionUser))
                    _whatsAppChatAppBarAction(localizations),
                  _teamChatAppBarAction(localizations),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                          // تحديث عدد الإشعارات بعد العودة
                          if (mounted) {
                            _loadUnreadCount(forceRefresh: true);
                          }
                        },
                      ),
                      if (_unreadNotificationsCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              _unreadNotificationsCount > 99
                                  ? '99+'
                                  : '$_unreadNotificationsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
      drawer: NavigationDrawer(
        onProfileUpdated: () {
          // Refresh dashboard when profile is updated
          _dashboardKey.currentState?.refreshUserData();
        },
      ),
      body: !_sessionResolved
          ? _buildSessionLoadingState(localizations)
          : _isDataEntry
          ? _allLeadsScreen
          : IndexedStack(
              index: _currentIndex,
              children: [_dashboardScreen, _allLeadsScreen, _calendarScreen],
            ),
      bottomNavigationBar: (!_sessionResolved || _isDataEntry)
          ? null
          : BottomNavigation(
              currentIndex: _currentIndex,
              onTap: (index) {
                // Refresh data when switching tabs
                if (index == 0 && _currentIndex != 0) {
                  // Switching to dashboard - refresh dashboard data
                  _dashboardKey.currentState?.refreshDashboardData();
                } else if (index == 1 && _currentIndex != 1) {
                  // Switching to all leads - refresh leads data
                  // The AllLeadsScreen will handle its own refresh via PopScope
                } else if (index == 2 && _currentIndex != 2) {
                  // Switching to calendar should not force refresh; keep cache-friendly behavior.
                  // Manual refresh remains available via the calendar app bar button.
                }
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
    );
  }
}
