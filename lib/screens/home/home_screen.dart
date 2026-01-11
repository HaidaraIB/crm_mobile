import 'package:flutter/material.dart' hide NavigationDrawer;
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
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
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _allLeadsKey = GlobalKey();
  VoidCallback? _showAllLeadsFilterCallback;
  bool Function()? _checkAllLeadsFiltersCallback;
  final ApiService _apiService = ApiService();
  int _unreadNotificationsCount = 0;
  
  @override
  void initState() {
    super.initState();
    // إرسال FCM token للمستخدمين المسجلين دخول بالفعل
    _sendFCMTokenIfLoggedIn();
    // تحميل عدد الإشعارات غير المقروءة
    _loadUnreadCount();
  }
  
  /// تحميل عدد الإشعارات غير المقروءة
  Future<void> _loadUnreadCount() async {
    try {
      final count = await _apiService.getUnreadNotificationsCount();
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
    
    Widget getBody() {
      switch (_currentIndex) {
        case 0:
          return DashboardScreen(key: _dashboardKey);
        case 1:
          return AllLeadsScreen(
            key: _allLeadsKey,
            showAppBar: false,
            onFilterRequested: (callback) {
              _showAllLeadsFilterCallback = callback;
            },
            onHasActiveFiltersRequested: (callback) {
              _checkAllLeadsFiltersCallback = callback;
            },
          );
        case 2:
          return CalendarScreen(
            key: _calendarKey,
            initialDate: _selectedCalendarDate,
          );
        default:
          return DashboardScreen(key: _dashboardKey);
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
                    DateFormat('MMMM yyyy', localizations?.locale.languageCode ?? 'en').format(_selectedCalendarDate),
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
                          _loadUnreadCount();
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
                            _unreadNotificationsCount > 99 ? '99+' : '$_unreadNotificationsCount',
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
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(getAppBarTitle()),
              actions: [
                // Filter button for All Leads page
                if (_currentIndex == 1)
                  Builder(
                    builder: (context) {
                      // Check if filters are active
                      final hasActiveFilters = _checkAllLeadsFiltersCallback?.call() ?? false;
                      
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
                                    color: Theme.of(context).colorScheme.primary,
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
                          _loadUnreadCount();
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
                            _unreadNotificationsCount > 99 ? '99+' : '$_unreadNotificationsCount',
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
      body: getBody(),
      bottomNavigationBar: BottomNavigation(
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
            // Switching to calendar - refresh calendar events
            (_calendarKey.currentState as dynamic)?.refreshEvents();
          }
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}


