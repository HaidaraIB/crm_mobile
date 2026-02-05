import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/specialization_helper.dart';
import '../screens/leads/all_leads_screen.dart';
import '../screens/leads/fresh_leads_screen.dart';
import '../screens/leads/cold_leads_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/inventory/properties_inventory_screen.dart';
import '../screens/inventory/owners_screen.dart';
import '../screens/inventory/services_inventory_screen.dart';
import '../screens/inventory/products_inventory_screen.dart';
import '../screens/deals/deals_screen.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationDrawer extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  
  const NavigationDrawer({super.key, this.onProfileUpdated});

  @override
  State<NavigationDrawer> createState() => _NavigationDrawerState();
}

class _NavigationDrawerState extends State<NavigationDrawer> {
  bool _inventoryExpanded = false;
  bool _leadsExpanded = false;
  UserModel? _currentUser;
  bool _isLoadingUser = true;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
      debugPrint('Failed to load user in drawer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return Drawer(
      child: Column(
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
            ),
            child: Column(
              children: [
                // Profile Avatar - Clickable
                GestureDetector(
                  onTap: _navigateToProfile,
                  child: _buildProfileAvatar(),
                ),
                const SizedBox(height: 16),
                // User Name - Clickable
                GestureDetector(
                  onTap: _navigateToProfile,
                  child: Text(
                    _isLoadingUser
                        ? localizations?.translate('loading') ?? 'Loading...'
                        : _currentUser?.displayName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                // User Email
                if (!_isLoadingUser && _currentUser?.email != null)
                  Text(
                    _currentUser!.email!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                // Tap to view profile hint - Clickable
                GestureDetector(
                  onTap: _navigateToProfile,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        localizations?.translate('tapToEditProfile') ?? 'Tap to edit profile',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.track_changes,
                  title: localizations?.translate('leads') ?? 'Leads',
                  hasSubItems: true,
                  isExpanded: _leadsExpanded,
                  onTap: () {
                    setState(() {
                      _leadsExpanded = !_leadsExpanded;
                    });
                  },
                ),
                // Sub-items for Leads
                if (_leadsExpanded) ...[
                  _buildSubMenuItem(
                    context,
                    title: localizations?.translate('allLeads') ?? 'All Leads',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllLeadsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSubMenuItem(
                    context,
                    title: localizations?.translate('freshLeads') ?? 'Fresh Leads',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FreshLeadsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSubMenuItem(
                    context,
                    title: localizations?.translate('coldLeads') ?? 'Cold Leads',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ColdLeadsScreen(),
                        ),
                      );
                    },
                  ),
                ],
                // Inventory menu - only show if user has a company with specialization
                if (_currentUser?.company != null) ...[
                  _buildMenuItem(
                    context,
                    icon: Icons.inventory,
                    title: localizations?.translate('inventory') ?? 'Inventory',
                    hasSubItems: true,
                    isExpanded: _inventoryExpanded,
                    onTap: () {
                      setState(() {
                        _inventoryExpanded = !_inventoryExpanded;
                      });
                    },
                  ),
                  // Sub-items for Inventory - based on specialization
                  if (_inventoryExpanded) ...[
                    // Real Estate specialization items
                    if (SpecializationHelper.isRealEstate(_currentUser)) ...[
                      _buildSubMenuItem(
                        context,
                        title: localizations?.translate('properties') ?? 'Properties',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PropertiesInventoryScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSubMenuItem(
                        context,
                        title: localizations?.translate('owners') ?? 'Owners',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OwnersScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                    // Services specialization items
                    if (SpecializationHelper.isServices(_currentUser)) ...[
                      _buildSubMenuItem(
                        context,
                        title: localizations?.translate('services') ?? 'Services',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ServicesInventoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                    // Products specialization items
                    if (SpecializationHelper.isProducts(_currentUser)) ...[
                      _buildSubMenuItem(
                        context,
                        title: localizations?.translate('products') ?? 'Products',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProductsInventoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
                _buildMenuItem(
                  context,
                  icon: Icons.handshake,
                  title: localizations?.translate('deals') ?? 'Deals',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DealsScreen(),
                      ),
                    );
                  },
                ),
                // Settings (accessible to all users)
                _buildMenuItem(
                  context,
                  icon: Icons.settings,
                  title: localizations?.translate('settings') ?? 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                // Admin-only menu items
                if (_currentUser?.isAdmin == true) ...[
                  // Note: Add Users, Reports, Employees, Integrations here when implemented
                  // For now, these features are not yet implemented in mobile app
                ],
              ],
            ),
          ),
          
          // Divider before logout
          const Divider(height: 1),
          
          // Logout Button at Bottom
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              localizations?.translate('logout') ?? 'Logout',
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () => _showLogoutConfirmation(context, localizations),
          ),
          
          // Version
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${localizations?.translate('version') ?? 'Version'} ${AppConstants.appVersion}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showLogoutConfirmation(
    BuildContext context,
    AppLocalizations? localizations,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            localizations?.translate('logoutConfirmTitle') ?? 'Confirm Logout',
            textAlign: TextAlign.center,
          ),
          content: Text(
            localizations?.translate('logoutConfirmMessage') ?? 
            'Are you sure you want to logout?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                localizations?.translate('cancel') ?? 'Cancel',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text(
                localizations?.translate('logout') ?? 'Logout',
              ),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true && context.mounted) {
      await _performLogout();
    }
  }
  
  Future<void> _performLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.currentUserKey);
    await prefs.setBool(AppConstants.isLoggedInKey, false);
    
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }
  
  Future<void> _navigateToProfile() async {
    Navigator.pop(context);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
    // Refresh user data in drawer after returning from profile
    _loadUser();
    // If profile was updated, notify parent to refresh dashboard
    if (result == true) {
      widget.onProfileUpdated?.call();
    }
  }
  
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool hasSubItems = false,
    bool isExpanded = false,
  }) {
    IconData? trailingIcon;
    if (hasSubItems) {
      trailingIcon = isExpanded 
          ? Icons.expand_less 
          : Icons.expand_more;
    }
    
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: trailingIcon != null ? Icon(trailingIcon) : null,
      onTap: onTap,
    );
  }
  
  Widget _buildSubMenuItem(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
  }) {
    final localizations = AppLocalizations.of(context);
    final isRTL = localizations?.isRTL ?? false;
    final theme = Theme.of(context);
    
    return Padding(
      padding: EdgeInsets.only(left: isRTL ? 0 : 56, right: isRTL ? 56 : 0),
      child: ListTile(
        leading: Icon(
          isRTL ? Icons.arrow_left : Icons.arrow_right,
          size: 20,
          color: theme.iconTheme.color?.withValues(alpha: 0.6),
        ),
        title: Text(title),
        onTap: onTap,
        contentPadding: EdgeInsets.only(
          left: isRTL ? 16 : 8,
          right: isRTL ? 8 : 16,
        ),
      ),
    );
  }
  
  Widget _buildProfileAvatar() {
    final profilePhotoUrl = _currentUser?.profilePhoto ?? _currentUser?.avatar;
    final hasImage = profilePhotoUrl != null && profilePhotoUrl.isNotEmpty;
    final shouldShowImage = !_isLoadingUser && hasImage;
    final String? imageUrl = shouldShowImage ? profilePhotoUrl : null;
    
    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.white,
      backgroundImage: imageUrl != null
          ? NetworkImage(imageUrl)
          : null,
      onBackgroundImageError: imageUrl != null
          ? (exception, stackTrace) {
              debugPrint('Error loading profile image in drawer: $exception');
            }
          : null,
      child: _isLoadingUser
          ? const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            )
          : !hasImage
              ? Text(
                  _currentUser?.displayName.isNotEmpty == true
                      ? (_currentUser?.displayName ?? 'U')[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 32,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
    );
  }
}


