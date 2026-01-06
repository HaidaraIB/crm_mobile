import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import 'channels_settings_screen.dart';
import 'general_settings_screen.dart';
import 'stages_settings_screen.dart';
import 'statuses_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  UserModel? _currentUser;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          // Initialize TabController after we know if user is admin
          final isAdmin = user.isAdmin;
          final tabCount = isAdmin ? 4 : 1; // General + 3 admin tabs or just General
          _tabController = TabController(length: tabCount, vsync: this);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Default to just General tab if we can't load user
          _tabController = TabController(length: 1, vsync: this);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isAdmin = _currentUser?.isAdmin == true;

    if (_tabController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('settings') ?? 'Settings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: localizations?.translate('general') ?? 'General'),
            if (isAdmin) Tab(text: localizations?.translate('channels') ?? 'Channels'),
            if (isAdmin) Tab(text: localizations?.translate('stages') ?? 'Stages'),
            if (isAdmin) Tab(text: localizations?.translate('statuses') ?? 'Statuses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const GeneralSettingsScreen(),
          if (isAdmin) const ChannelsSettingsScreen(),
          if (isAdmin) const StagesSettingsScreen(),
          if (isAdmin) const StatusesSettingsScreen(),
        ],
      ),
    );
  }
}

