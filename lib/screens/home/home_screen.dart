import 'package:flutter/material.dart' hide NavigationDrawer;
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/app_locales.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../services/api_service.dart';
import '../../widgets/navigation_drawer.dart';
import '../../widgets/bottom_navigation.dart';
import '../calendar/calendar_screen.dart';
import '../leads/all_leads_screen.dart';
import '../notifications/notifications_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  bool get _isDataEntry => _sessionUser?.isDataEntry ?? false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _loadSessionUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _sessionUser = user;
        if (user.isDataEntry) {
          _currentIndex = 1;
        }
      });
    } catch (e) {
      debugPrint('Failed to load session user: $e');
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
                if (_currentIndex == 0)
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
            ),
      drawer: NavigationDrawer(
        onProfileUpdated: () {
          // Refresh dashboard when profile is updated
          _dashboardKey.currentState?.refreshUserData();
        },
      ),
      body: _isDataEntry
          ? _allLeadsScreen
          : IndexedStack(
              index: _currentIndex,
              children: [
                _dashboardScreen,
                _allLeadsScreen,
                _calendarScreen,
              ],
            ),
      bottomNavigationBar: _isDataEntry
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
