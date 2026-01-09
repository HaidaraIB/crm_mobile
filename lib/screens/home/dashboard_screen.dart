import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../models/lead_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../leads/all_leads_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  
  int _allLeadsCount = 0;
  int _freshLeadsCount = 0;
  int _coldLeadsCount = 0;
  int _untouchedCount = 0;
  int _touchedCount = 0;
  int _followingCount = 0;
  
  UserModel? _currentUser;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _loadLeads();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh user data when app comes back to foreground
      _loadUser();
    }
  }

  // This method will be called when returning from profile screen
  void refreshUserData() {
    _loadUser();
  }
  
  // This method will be called to refresh all dashboard data
  void refreshDashboardData() {
    _loadLeads();
  }
  
  Future<void> _loadUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      // Silently fail - user name is not critical
      debugPrint('Failed to load user: $e');
    }
  }
  
  Future<void> _loadLeads({bool retry = false, bool reloadUser = false}) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        // Reset counts when retrying to ensure fresh state
        if (retry) {
          _allLeadsCount = 0;
          _freshLeadsCount = 0;
          _coldLeadsCount = 0;
          _untouchedCount = 0;
          _touchedCount = 0;
          _followingCount = 0;
        }
      });
      
      // Reload user data when retrying, refreshing, or if not loaded
      if (retry || reloadUser || _currentUser == null) {
        await _loadUser();
      }
      
      final result = await _apiService.getLeads();
      final leads = (result['results'] as List).cast<LeadModel>();
      
      setState(() {
        _allLeadsCount = leads.length;
        // Type filtering - case insensitive
        _freshLeadsCount = leads.where((l) => 
          l.type.toLowerCase() == 'fresh'
        ).length;
        _coldLeadsCount = leads.where((l) => 
          l.type.toLowerCase() == 'cold'
        ).length;
        // Status filtering - case insensitive, check both status and statusName
        _untouchedCount = leads.where((l) {
          final status = (l.statusName ?? l.status ?? '').toLowerCase();
          return status == 'untouched';
        }).length;
        _touchedCount = leads.where((l) {
          final status = (l.statusName ?? l.status ?? '').toLowerCase();
          return status == 'touched';
        }).length;
        _followingCount = leads.where((l) {
          final status = (l.statusName ?? l.status ?? '').toLowerCase();
          return status == 'following';
        }).length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
        _isLoading = false;
      });
    }
  }
  
  Future<void> _retryLoad() async {
    await _loadLeads(retry: true, reloadUser: true);
  }
  
  Future<void> _refreshAll() async {
    await _loadLeads(retry: true, reloadUser: true);
  }
  
  String _getErrorMessage(dynamic error) {
    // Check for TimeoutException directly
    if (error is TimeoutException) {
      return 'CONNECTION_TIMEOUT';
    }
    
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out')) {
      return 'NO_INTERNET';
    }
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'CONNECTION_TIMEOUT';
    }
    return error.toString();
  }

  Widget _buildErrorWidget(
    BuildContext context,
    AppLocalizations? localizations,
    ThemeData theme,
  ) {
    final isNoInternet = _errorMessage == 'NO_INTERNET';
    final isTimeout = _errorMessage == 'CONNECTION_TIMEOUT';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNoInternet ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isNoInternet
                  ? (localizations?.translate('noInternetConnection') ?? 'No Internet Connection')
                  : isTimeout
                      ? (localizations?.translate('connectionError') ?? 'Connection Error')
                      : (localizations?.translate('errorOccurred') ?? 'An error occurred'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isNoInternet
                  ? (localizations?.translate('noInternetMessage') ?? 'Please check your internet connection and try again')
                  : isTimeout
                      ? (localizations?.translate('connectionErrorMessage') ?? 'Unable to connect to the server. Please try again later')
                      : _errorMessage!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retryLoad,
              icon: const Icon(Icons.refresh),
              label: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getProgress(int count, int total) {
    if (total == 0) return 0.0;
    return count / total;
  }
  
  Widget _buildProfileAvatar() {
    final profilePhotoUrl = _currentUser?.profilePhoto ?? _currentUser?.avatar;
    final hasImage = profilePhotoUrl != null && profilePhotoUrl.isNotEmpty;
    final imageUrl = profilePhotoUrl;
    
    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.white,
      backgroundImage: hasImage && imageUrl != null
          ? NetworkImage(imageUrl)
          : null,
      onBackgroundImageError: hasImage && imageUrl != null
          ? (exception, stackTrace) {
              // Handle image loading errors silently
              debugPrint('Error loading profile image: $exception');
            }
          : null,
      child: hasImage
          ? null
          : Text(
              _currentUser?.displayName.isNotEmpty == true
                  ? (_currentUser?.displayName ?? 'U')[0].toUpperCase()
                  : 'U',
              style: TextStyle(
                fontSize: 32,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return _buildErrorWidget(context, localizations, theme);
    }
    
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Avatar
                  _buildProfileAvatar(),
                  const SizedBox(height: 12),
                  Text(
                    localizations?.translate('goodMorning') ?? 'Good Morning',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser?.displayName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations?.translate('readyForWork') ?? 'Ready for Work, Make customers happy!',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Lead Categories Grid
            Text(
              localizations?.translate('leads') ?? 'Leads',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _buildLeadCategoryCard(
                  context,
                  localizations?.translate('allLeads') ?? 'All Leads',
                  _allLeadsCount,
                  _getProgress(_allLeadsCount, _allLeadsCount),
                  localizations,
                  type: null,
                  status: null,
                ),
                _buildLeadCategoryCard(
                  context,
                  localizations?.translate('freshLeads') ?? 'Fresh Leads',
                  _freshLeadsCount,
                  _getProgress(_freshLeadsCount, _allLeadsCount),
                  localizations,
                  type: 'fresh',
                  status: null,
                ),
                _buildLeadCategoryCard(
                  context,
                  localizations?.translate('coldLeads') ?? 'Cold Leads',
                  _coldLeadsCount,
                  _getProgress(_coldLeadsCount, _allLeadsCount),
                  localizations,
                  type: 'cold',
                  status: null,
                ),
                _buildLeadCategoryCard(
                  context,
                  localizations?.translate('untouched') ?? 'Untouched',
                  _untouchedCount,
                  _getProgress(_untouchedCount, _allLeadsCount),
                  localizations,
                  type: null,
                  status: 'untouched',
                ),
                _buildLeadCategoryCard(
                  context,
                  localizations?.translate('touched') ?? 'Touched',
                  _touchedCount,
                  _getProgress(_touchedCount, _allLeadsCount),
                  localizations,
                  type: null,
                  status: 'touched',
                ),
                _buildLeadCategoryCard(
                  context,
                  localizations?.translate('following') ?? 'Following',
                  _followingCount,
                  _getProgress(_followingCount, _allLeadsCount),
                  localizations,
                  type: null,
                  status: 'following',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLeadCategoryCard(
    BuildContext context,
    String title,
    int count,
    double progress,
    AppLocalizations? localizations, {
    String? type,
    String? status,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AllLeadsScreen(
                type: type,
                status: status,
              ),
            ),
          );
          // Refresh leads data when returning from AllLeadsScreen
          if (result == true || mounted) {
            _loadLeads();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      NumberFormatter.formatNumber(count),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

