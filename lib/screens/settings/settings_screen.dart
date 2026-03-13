import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import 'channels_settings_screen.dart';
import 'general_settings_screen.dart';
import 'stages_settings_screen.dart';
import 'statuses_settings_screen.dart';
import 'call_methods_settings_screen.dart';

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

  Widget _tabLabel(String text) {
    return Text(
      text,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
  }

  Future<void> _loadUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          // Initialize TabController after we know if user is admin
          final isAdmin = user.isAdmin;
          final hasSettingsPerm = user.hasSupervisorPermission('can_manage_settings');
          final tabCount = (isAdmin || hasSettingsPerm) ? 5 : 1; // General + 4 admin/supervisor tabs or just General
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
    final hasSettingsPerm = _currentUser?.hasSupervisorPermission('can_manage_settings') ?? false;
    final canManageSettings = isAdmin || hasSettingsPerm;

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
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(child: _tabLabel(localizations?.translate('general') ?? 'General')),
            if (canManageSettings) Tab(child: _tabLabel(localizations?.translate('channels') ?? 'Channels')),
            if (canManageSettings) Tab(child: _tabLabel(localizations?.translate('stages') ?? 'Stages')),
            if (canManageSettings) Tab(child: _tabLabel(localizations?.translate('statuses') ?? 'Statuses')),
            if (canManageSettings) Tab(child: _tabLabel(localizations?.translate('callMethods') ?? 'Call Methods')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const GeneralSettingsScreen(),
          if (canManageSettings) const ChannelsSettingsScreen(),
          if (canManageSettings) const StagesSettingsScreen(),
          if (canManageSettings) const StatusesSettingsScreen(),
          if (canManageSettings) const CallMethodsSettingsScreen(),
        ],
      ),
    );
  }
}

