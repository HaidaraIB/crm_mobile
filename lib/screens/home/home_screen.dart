import 'package:flutter/material.dart' hide NavigationDrawer;
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/navigation_drawer.dart';
import '../../widgets/bottom_navigation.dart';
import '../calendar/calendar_screen.dart';
import '../leads/all_leads_screen.dart';
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
          return const AllLeadsScreen(showAppBar: false);
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
                    DateFormat('MMMM yyyy').format(_selectedCalendarDate),
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
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    // TODO: Open notifications - Show notifications screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          localizations?.translate('notificationsComingSoon') ?? 'Notifications feature coming soon',
                        ),
                      ),
                    );
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
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    // TODO: Open notifications - Show notifications screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          localizations?.translate('notificationsComingSoon') ?? 'Notifications feature coming soon',
                        ),
                      ),
                    );
                  },
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
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}


