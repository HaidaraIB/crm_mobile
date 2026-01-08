import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../widgets/inventory_card.dart';
import '../../widgets/modals/add_owner_modal.dart';
import '../../widgets/modals/edit_owner_modal.dart';

class OwnersScreen extends StatefulWidget {
  const OwnersScreen({super.key});

  @override
  State<OwnersScreen> createState() => _OwnersScreenState();
}

class _OwnersScreenState extends State<OwnersScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Owner> _owners = [];
  List<Owner> _filteredOwners = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadOwners();
    _searchController.addListener(_filterOwners);
  }
  
  Future<void> _loadUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      setState(() {
        _isAdmin = user.isAdmin;
      });
    } catch (e) {
      // User not loaded, but continue
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOwners() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final owners = await _apiService.getOwners();
      setState(() {
        _owners = owners;
        _filteredOwners = owners;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterOwners() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredOwners = _owners.where((owner) {
        return owner.code.toLowerCase().contains(query) ||
               owner.name.toLowerCase().contains(query) ||
               owner.phone.toLowerCase().contains(query) ||
               (owner.city?.toLowerCase().contains(query) ?? false) ||
               (owner.district?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _callOwner(String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('cannotMakeCall') ?? 'Cannot make call',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('cannotMakeCall') ?? 'Cannot make call',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('owners') ?? 'Owners'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: localizations?.translate('typeToSearch') ?? 'Type to search...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Owners list
          Expanded(
            child: _buildContent(localizations, theme),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () {
                _showAddOwnerDialog(context, localizations, theme);
              },
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildContent(AppLocalizations? localizations, ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              localizations?.translate('failedToLoadData') ?? 'Failed to load data',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOwners,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredOwners.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noOwnersFound') ?? 'No owners found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadOwners,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredOwners.length,
        itemBuilder: (context, index) {
          final owner = _filteredOwners[index];
          return InventoryCard(
            onTap: () => _callOwner(owner.phone),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with name and call button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            owner.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            owner.code,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.phone,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () => _callOwner(owner.phone),
                        tooltip: localizations?.translate('call') ?? 'Call',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Location info
                if (owner.city != null)
                  InfoRow(
                    icon: Icons.location_city,
                    label: localizations?.translate('city') ?? 'City',
                    value: owner.city!,
                  ),
                if (owner.district != null)
                  InfoRow(
                    icon: Icons.location_on,
                    label: localizations?.translate('district') ?? 'District',
                    value: owner.district!,
                  ),
                const SizedBox(height: 8),
                // Phone number with call action
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          owner.phone,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Admin actions
                if (_isAdmin) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditOwnerDialog(context, localizations, theme, owner),
                        color: theme.colorScheme.primary,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _showDeleteOwnerDialog(context, localizations, theme, owner),
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
  
  void _showAddOwnerDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AddOwnerModal(
        onOwnerCreated: (owner) {
          _loadOwners();
        },
      ),
    );
  }
  
  void _showEditOwnerDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, Owner owner) {
    showDialog(
      context: context,
      builder: (context) => EditOwnerModal(
        owner: owner,
        onOwnerUpdated: (updatedOwner) {
          _loadOwners();
        },
      ),
    );
  }
  
  void _showDeleteOwnerDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, Owner owner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteOwner') ?? 'Delete Owner'),
        content: Text('${localizations?.translate('confirmDeleteOwner') ?? 'Are you sure you want to delete'} ${owner.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              navigator.pop();
              try {
                await _apiService.deleteOwner(owner.id);
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(localizations?.translate('ownerDeleted') ?? 'Owner deleted')),
                  );
                  _loadOwners();
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('${localizations?.translate('error') ?? 'Error'}: $e')),
                  );
                }
              }
            },
            child: Text(localizations?.translate('delete') ?? 'Delete', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

