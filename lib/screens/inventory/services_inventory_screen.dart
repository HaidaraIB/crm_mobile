import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../widgets/inventory_card.dart';
import '../../widgets/modals/add_service_modal.dart';
import '../../widgets/modals/edit_service_modal.dart';
import '../../widgets/modals/add_service_package_modal.dart';
import '../../widgets/modals/edit_service_package_modal.dart';
import '../../widgets/modals/add_service_provider_modal.dart';
import '../../widgets/modals/edit_service_provider_modal.dart';

class ServicesInventoryScreen extends StatefulWidget {
  const ServicesInventoryScreen({super.key});

  @override
  State<ServicesInventoryScreen> createState() => _ServicesInventoryScreenState();
}

class _ServicesInventoryScreenState extends State<ServicesInventoryScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // User
  bool _isAdmin = false;
  
  // Services
  List<Service> _services = [];
  List<Service> _filteredServices = [];
  bool _isLoadingServices = true;
  String? _errorServices;
  
  // Service Packages
  List<ServicePackage> _packages = [];
  List<ServicePackage> _filteredPackages = [];
  bool _isLoadingPackages = true;
  String? _errorPackages;
  
  // Service Providers
  List<ServiceProvider> _providers = [];
  List<ServiceProvider> _filteredProviders = [];
  bool _isLoadingProviders = true;
  String? _errorProviders;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUser();
    _loadData();
    _searchController.addListener(_filterData);
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
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadServices(),
      _loadPackages(),
      _loadProviders(),
    ]);
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoadingServices = true;
      _errorServices = null;
    });
    
    try {
      final services = await _apiService.getServices();
      setState(() {
        _services = services;
        _filteredServices = services;
        _isLoadingServices = false;
      });
    } catch (e) {
      setState(() {
        _errorServices = e.toString();
        _isLoadingServices = false;
      });
    }
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoadingPackages = true;
      _errorPackages = null;
    });
    
    try {
      final packages = await _apiService.getServicePackages();
      setState(() {
        _packages = packages;
        _filteredPackages = packages;
        _isLoadingPackages = false;
      });
    } catch (e) {
      setState(() {
        _errorPackages = e.toString();
        _isLoadingPackages = false;
      });
    }
  }

  Future<void> _loadProviders() async {
    setState(() {
      _isLoadingProviders = true;
      _errorProviders = null;
    });
    
    try {
      final providers = await _apiService.getServiceProviders();
      setState(() {
        _providers = providers;
        _filteredProviders = providers;
        _isLoadingProviders = false;
      });
    } catch (e) {
      setState(() {
        _errorProviders = e.toString();
        _isLoadingProviders = false;
      });
    }
  }

  void _filterData() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredServices = _services.where((service) {
        return service.code.toLowerCase().contains(query) ||
               service.name.toLowerCase().contains(query) ||
               service.category.toLowerCase().contains(query) ||
               (service.provider?.toLowerCase().contains(query) ?? false);
      }).toList();
      
      _filteredPackages = _packages.where((pkg) {
        return pkg.code.toLowerCase().contains(query) ||
               pkg.name.toLowerCase().contains(query) ||
               (pkg.description?.toLowerCase().contains(query) ?? false);
      }).toList();
      
      _filteredProviders = _providers.where((provider) {
        return provider.code.toLowerCase().contains(query) ||
               provider.name.toLowerCase().contains(query) ||
               provider.phone.toLowerCase().contains(query) ||
               (provider.email?.toLowerCase().contains(query) ?? false) ||
               (provider.specialization?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('inventory') ?? 'Inventory'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: localizations?.translate('services') ?? 'Services'),
            Tab(text: localizations?.translate('servicePackages') ?? 'Service Packages'),
            Tab(text: localizations?.translate('serviceProviders') ?? 'Service Providers'),
          ],
        ),
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
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildServicesTab(localizations, theme),
                _buildPackagesTab(localizations, theme),
                _buildProvidersTab(localizations, theme),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () {
                _showAddDialog(context, localizations, theme);
              },
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildServicesTab(AppLocalizations? localizations, ThemeData theme) {
    if (_isLoadingServices) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorServices != null) {
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
              _errorServices!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadServices,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredServices.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noServicesFound') ?? 'No services found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredServices.length,
      itemBuilder: (context, index) {
        final service = _filteredServices[index];
        return InventoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.code,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    text: service.isActive 
                        ? (localizations?.translate('active') ?? 'Active')
                        : (localizations?.translate('inactive') ?? 'Inactive'),
                    color: service.isActive ? Colors.green : Colors.grey,
                    icon: service.isActive ? Icons.check_circle : Icons.cancel,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Details
              InfoRow(
                icon: Icons.category,
                label: localizations?.translate('category') ?? 'Category',
                value: service.category,
              ),
              if (service.provider != null)
                InfoRow(
                  icon: Icons.person,
                  label: localizations?.translate('provider') ?? 'Provider',
                  value: service.provider!,
                ),
              if (service.duration != null)
                InfoRow(
                  icon: Icons.access_time,
                  label: localizations?.translate('duration') ?? 'Duration',
                  value: service.duration!,
                ),
              if (service.description != null && service.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  service.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              // Price display
              Align(
                alignment: Alignment.centerRight,
                child: PriceDisplay(price: service.price),
              ),
              // Admin actions
              if (_isAdmin) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditServiceDialog(context, localizations, theme, service),
                      color: theme.colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _showDeleteServiceDialog(context, localizations, theme, service),
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPackagesTab(AppLocalizations? localizations, ThemeData theme) {
    if (_isLoadingPackages) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorPackages != null) {
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
              _errorPackages!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPackages,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredPackages.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noServicePackagesFound') ?? 'No service packages found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPackages.length,
      itemBuilder: (context, index) {
        final pkg = _filteredPackages[index];
        return InventoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pkg.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pkg.code,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    text: pkg.isActive 
                        ? (localizations?.translate('active') ?? 'Active')
                        : (localizations?.translate('inactive') ?? 'Inactive'),
                    color: pkg.isActive ? Colors.green : Colors.grey,
                    icon: pkg.isActive ? Icons.check_circle : Icons.cancel,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Details
              if (pkg.description != null && pkg.description!.isNotEmpty) ...[
                Text(
                  pkg.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: InfoRow(
                      icon: Icons.access_time,
                      label: localizations?.translate('duration') ?? 'Duration',
                      value: pkg.duration ?? '-',
                    ),
                  ),
                  Expanded(
                    child: InfoRow(
                      icon: Icons.list,
                      label: localizations?.translate('services') ?? 'Services',
                      value: '${pkg.services.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Price display
              Align(
                alignment: Alignment.centerRight,
                child: PriceDisplay(price: pkg.price),
              ),
              // Admin actions
              if (_isAdmin) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditPackageDialog(context, localizations, theme, pkg),
                      color: theme.colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _showDeletePackageDialog(context, localizations, theme, pkg),
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProvidersTab(AppLocalizations? localizations, ThemeData theme) {
    if (_isLoadingProviders) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorProviders != null) {
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
              _errorProviders!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProviders,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredProviders.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noServiceProvidersFound') ?? 'No service providers found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProviders.length,
      itemBuilder: (context, index) {
        final provider = _filteredProviders[index];
        return InventoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.code,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Contact info
              InfoRow(
                icon: Icons.phone,
                label: localizations?.translate('phone') ?? 'Phone',
                value: provider.phone,
              ),
              if (provider.email != null)
                InfoRow(
                  icon: Icons.email,
                  label: localizations?.translate('email') ?? 'Email',
                  value: provider.email!,
                ),
              if (provider.specialization != null)
                InfoRow(
                  icon: Icons.work,
                  label: localizations?.translate('specialization') ?? 'Specialization',
                  value: provider.specialization!,
                ),
              if (provider.rating != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 18,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${localizations?.translate('rating') ?? 'Rating'}: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    ...List.generate(5, (i) {
                      return Icon(
                        i < provider.rating!.round() ? Icons.star : Icons.star_border,
                        size: 18,
                        color: Colors.amber,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      provider.rating!.toStringAsFixed(1),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              // Admin actions
              if (_isAdmin) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditProviderDialog(context, localizations, theme, provider),
                      color: theme.colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _showDeleteProviderDialog(context, localizations, theme, provider),
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  void _showAddDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
    final currentTab = _tabController.index;
    if (currentTab == 0) {
      _showAddServiceDialog(context, localizations, theme);
    } else if (currentTab == 1) {
      _showAddPackageDialog(context, localizations, theme);
    } else if (currentTab == 2) {
      _showAddProviderDialog(context, localizations, theme);
    }
  }
  
  void _showAddServiceDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AddServiceModal(
        onServiceCreated: (service) {
          _loadServices();
        },
      ),
    );
  }
  
  void _showAddPackageDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AddServicePackageModal(
        onPackageCreated: (package) {
          _loadPackages();
        },
      ),
    );
  }
  
  void _showAddProviderDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AddServiceProviderModal(
        onProviderCreated: (provider) {
          _loadProviders();
        },
      ),
    );
  }
  
  void _showEditServiceDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, Service service) {
    showDialog(
      context: context,
      builder: (context) => EditServiceModal(
        service: service,
        onServiceUpdated: (updatedService) {
          _loadServices();
        },
      ),
    );
  }
  
  void _showDeleteServiceDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, Service service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteService') ?? 'Delete Service'),
        content: Text('${localizations?.translate('confirmDeleteService') ?? 'Are you sure you want to delete'} ${service.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final brightness = Theme.of(context).brightness;
              navigator.pop();
              try {
                await _apiService.deleteService(service.id);
                if (mounted) {
                  SnackbarHelper.showSuccessWithMessenger(
                    scaffoldMessenger,
                    localizations?.translate('serviceDeleted') ?? 'Service deleted',
                    brightness: brightness,
                  );
                  _loadServices();
                }
              } catch (e) {
                if (mounted) {
                  SnackbarHelper.showErrorWithMessenger(
                    scaffoldMessenger,
                    '${localizations?.translate('error') ?? 'Error'}: $e',
                    brightness: brightness,
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
  
  void _showEditPackageDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, ServicePackage pkg) {
    showDialog(
      context: context,
      builder: (context) => EditServicePackageModal(
        package: pkg,
        onPackageUpdated: (updatedPackage) {
          _loadPackages();
        },
      ),
    );
  }
  
  void _showDeletePackageDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, ServicePackage pkg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteServicePackage') ?? 'Delete Service Package'),
        content: Text('${localizations?.translate('confirmDeleteServicePackage') ?? 'Are you sure you want to delete'} ${pkg.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final brightness = Theme.of(context).brightness;
              navigator.pop();
              try {
                await _apiService.deleteServicePackage(pkg.id);
                if (mounted) {
                  SnackbarHelper.showSuccessWithMessenger(
                    scaffoldMessenger,
                    localizations?.translate('packageDeleted') ?? 'Package deleted',
                    brightness: brightness,
                  );
                  _loadPackages();
                }
              } catch (e) {
                if (mounted) {
                  SnackbarHelper.showErrorWithMessenger(
                    scaffoldMessenger,
                    '${localizations?.translate('error') ?? 'Error'}: $e',
                    brightness: brightness,
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
  
  void _showEditProviderDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, ServiceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => EditServiceProviderModal(
        provider: provider,
        onProviderUpdated: (updatedProvider) {
          _loadProviders();
        },
      ),
    );
  }
  
  void _showDeleteProviderDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, ServiceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteServiceProvider') ?? 'Delete Service Provider'),
        content: Text('${localizations?.translate('confirmDeleteServiceProvider') ?? 'Are you sure you want to delete'} ${provider.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final brightness = Theme.of(context).brightness;
              navigator.pop();
              try {
                await _apiService.deleteServiceProvider(provider.id);
                if (mounted) {
                  SnackbarHelper.showSuccessWithMessenger(
                    scaffoldMessenger,
                    localizations?.translate('providerDeleted') ?? 'Provider deleted',
                    brightness: brightness,
                  );
                  _loadProviders();
                }
              } catch (e) {
                if (mounted) {
                  SnackbarHelper.showErrorWithMessenger(
                    scaffoldMessenger,
                    '${localizations?.translate('error') ?? 'Error'}: $e',
                    brightness: brightness,
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

