import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../widgets/inventory_card.dart';
import '../../widgets/modals/add_developer_modal.dart';
import '../../widgets/modals/edit_developer_modal.dart';
import '../../widgets/modals/add_project_modal.dart';
import '../../widgets/modals/edit_project_modal.dart';
import '../../widgets/modals/add_unit_modal.dart';
import '../../widgets/modals/edit_unit_modal.dart';

class PropertiesInventoryScreen extends StatefulWidget {
  const PropertiesInventoryScreen({super.key});

  @override
  State<PropertiesInventoryScreen> createState() => _PropertiesInventoryScreenState();
}

class _PropertiesInventoryScreenState extends State<PropertiesInventoryScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // User
  bool _isAdmin = false;
  
  // Units
  List<Unit> _units = [];
  List<Unit> _filteredUnits = [];
  bool _isLoadingUnits = true;
  String? _errorUnits;
  
  // Projects
  List<Project> _projects = [];
  List<Project> _filteredProjects = [];
  bool _isLoadingProjects = true;
  String? _errorProjects;
  
  // Developers
  List<Developer> _developers = [];
  List<Developer> _filteredDevelopers = [];
  bool _isLoadingDevelopers = true;
  String? _errorDevelopers;

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
      _loadUnits(),
      _loadProjects(),
      _loadDevelopers(),
    ]);
  }

  Future<void> _loadUnits() async {
    setState(() {
      _isLoadingUnits = true;
      _errorUnits = null;
    });
    
    try {
      final units = await _apiService.getUnits();
      setState(() {
        _units = units;
        _filteredUnits = units;
        _isLoadingUnits = false;
      });
    } catch (e) {
      setState(() {
        _errorUnits = e.toString();
        _isLoadingUnits = false;
      });
    }
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _errorProjects = null;
    });
    
    try {
      final projects = await _apiService.getProjects();
      setState(() {
        _projects = projects;
        _filteredProjects = projects;
        _isLoadingProjects = false;
      });
    } catch (e) {
      setState(() {
        _errorProjects = e.toString();
        _isLoadingProjects = false;
      });
    }
  }

  Future<void> _loadDevelopers() async {
    setState(() {
      _isLoadingDevelopers = true;
      _errorDevelopers = null;
    });
    
    try {
      final developers = await _apiService.getDevelopers();
      setState(() {
        _developers = developers;
        _filteredDevelopers = developers;
        _isLoadingDevelopers = false;
      });
    } catch (e) {
      setState(() {
        _errorDevelopers = e.toString();
        _isLoadingDevelopers = false;
      });
    }
  }

  void _filterData() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredUnits = _units.where((unit) {
        return unit.code.toLowerCase().contains(query) ||
               unit.project.toLowerCase().contains(query) ||
               (unit.city?.toLowerCase().contains(query) ?? false) ||
               (unit.district?.toLowerCase().contains(query) ?? false);
      }).toList();
      
      _filteredProjects = _projects.where((project) {
        return project.code.toLowerCase().contains(query) ||
               project.name.toLowerCase().contains(query) ||
               project.developer.toLowerCase().contains(query) ||
               (project.city?.toLowerCase().contains(query) ?? false);
      }).toList();
      
      _filteredDevelopers = _developers.where((developer) {
        return developer.code.toLowerCase().contains(query) ||
               developer.name.toLowerCase().contains(query);
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
            Tab(text: localizations?.translate('units') ?? 'Units'),
            Tab(text: localizations?.translate('projects') ?? 'Projects'),
            Tab(text: localizations?.translate('developers') ?? 'Developers'),
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
                _buildUnitsTab(localizations, theme),
                _buildProjectsTab(localizations, theme),
                _buildDevelopersTab(localizations, theme),
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

  Widget _buildUnitsTab(AppLocalizations? localizations, ThemeData theme) {
    if (_isLoadingUnits) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorUnits != null) {
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
              _errorUnits!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUnits,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredUnits.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noUnitsFound') ?? 'No units found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredUnits.length,
      itemBuilder: (context, index) {
        final unit = _filteredUnits[index];
        return InventoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with code and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.code,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        if (unit.project.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            unit.project,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  StatusBadge(
                    text: unit.isSold 
                        ? (localizations?.translate('sold') ?? 'Sold')
                        : (localizations?.translate('available') ?? 'Available'),
                    color: unit.isSold ? Colors.red : Colors.green,
                    icon: unit.isSold ? Icons.check_circle : Icons.home,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Location info
              if (unit.city != null || unit.district != null) ...[
                if (unit.city != null)
                  InfoRow(
                    icon: Icons.location_city,
                    label: localizations?.translate('city') ?? 'City',
                    value: unit.city!,
                  ),
                if (unit.district != null)
                  InfoRow(
                    icon: Icons.location_on,
                    label: localizations?.translate('district') ?? 'District',
                    value: unit.district!,
                  ),
              ],
              // Property details in a row
              Row(
                children: [
                  Expanded(
                    child: InfoRow(
                      icon: Icons.bed,
                      label: localizations?.translate('bedrooms') ?? 'Bedrooms',
                      value: unit.bedrooms.toString(),
                    ),
                  ),
                  Expanded(
                    child: InfoRow(
                      icon: Icons.bathtub,
                      label: localizations?.translate('bathrooms') ?? 'Bathrooms',
                      value: unit.bathrooms.toString(),
                    ),
                  ),
                ],
              ),
              if (unit.type != null)
                InfoRow(
                  icon: Icons.category,
                  label: localizations?.translate('type') ?? 'Type',
                  value: unit.type!,
                ),
              if (unit.finishing != null)
                InfoRow(
                  icon: Icons.build,
                  label: localizations?.translate('finishing') ?? 'Finishing',
                  value: unit.finishing!,
                ),
              const SizedBox(height: 8),
              // Price display
              Align(
                alignment: Alignment.centerRight,
                child: PriceDisplay(price: unit.price),
              ),
              // Admin actions
              if (_isAdmin) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditUnitDialog(context, localizations, theme, unit),
                      color: theme.colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _showDeleteUnitDialog(context, localizations, theme, unit),
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

  Widget _buildProjectsTab(AppLocalizations? localizations, ThemeData theme) {
    if (_isLoadingProjects) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorProjects != null) {
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
              _errorProjects!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProjects,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredProjects.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noProjectsFound') ?? 'No projects found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProjects.length,
      itemBuilder: (context, index) {
        final project = _filteredProjects[index];
        return InventoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                project.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                project.code,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              // Details
              if (project.developer.isNotEmpty)
                InfoRow(
                  icon: Icons.business,
                  label: localizations?.translate('developer') ?? 'Developer',
                  value: project.developer,
                ),
              if (project.type != null)
                InfoRow(
                  icon: Icons.category,
                  label: localizations?.translate('type') ?? 'Type',
                  value: project.type!,
                ),
              if (project.city != null)
                InfoRow(
                  icon: Icons.location_city,
                  label: localizations?.translate('city') ?? 'City',
                  value: project.city!,
                ),
              if (project.paymentMethod != null)
                InfoRow(
                  icon: Icons.payment,
                  label: localizations?.translate('paymentMethod') ?? 'Payment Method',
                  value: project.paymentMethod!,
                ),
              // Admin actions
              if (_isAdmin) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditProjectDialog(context, localizations, theme, project),
                      color: theme.colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _showDeleteProjectDialog(context, localizations, theme, project),
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

  Widget _buildDevelopersTab(AppLocalizations? localizations, ThemeData theme) {
    if (_isLoadingDevelopers) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorDevelopers != null) {
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
              _errorDevelopers!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDevelopers,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredDevelopers.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noDevelopersFound') ?? 'No developers found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDevelopers.length,
      itemBuilder: (context, index) {
        final developer = _filteredDevelopers[index];
        return InventoryCard(
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      developer.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      developer.code,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Admin actions
              if (_isAdmin) ...[
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditDeveloperDialog(context, localizations, theme, developer),
                      color: theme.colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _showDeleteDeveloperDialog(context, localizations, theme, developer),
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
      _showAddUnitDialog(context, localizations, theme);
    } else if (currentTab == 1) {
      _showAddProjectDialog(context, localizations, theme);
    } else if (currentTab == 2) {
      _showAddDeveloperDialog(context, localizations, theme);
    }
  }
  
  void _showAddUnitDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AddUnitModal(
        onUnitCreated: (unit) {
          _loadUnits();
        },
      ),
    );
  }
  
  void _showAddProjectDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AddProjectModal(
        onProjectCreated: (project) {
          _loadProjects();
        },
      ),
    );
  }
  
  void _showAddDeveloperDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AddDeveloperModal(
        onDeveloperCreated: (developer) {
          _loadDevelopers();
        },
      ),
    );
  }
  
  void _showEditUnitDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, Unit unit) {
    showDialog(
      context: context,
      builder: (context) => EditUnitModal(
        unit: unit,
        onUnitUpdated: (updatedUnit) {
          _loadUnits();
        },
      ),
    );
  }
  
  void _showDeleteUnitDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, Unit unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteUnit') ?? 'Delete Unit'),
        content: Text('${localizations?.translate('confirmDeleteUnit') ?? 'Are you sure you want to delete'} ${unit.code}?'),
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
                await _apiService.deleteUnit(unit.id);
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(localizations?.translate('unitDeleted') ?? 'Unit deleted')),
                  );
                  _loadUnits();
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
  
  void _showEditProjectDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, Project project) {
    showDialog(
      context: context,
      builder: (context) => EditProjectModal(
        project: project,
        onProjectUpdated: (updatedProject) {
          _loadProjects();
        },
      ),
    );
  }
  
  void _showDeleteProjectDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteProject') ?? 'Delete Project'),
        content: Text('${localizations?.translate('confirmDeleteProject') ?? 'Are you sure you want to delete'} ${project.name}?'),
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
                await _apiService.deleteProject(project.id);
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(localizations?.translate('projectDeleted') ?? 'Project deleted')),
                  );
                  // Reload projects and units since deleting a project cascades to units
                  await Future.wait([
                    _loadProjects(),
                    _loadUnits(),
                  ]);
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
  
  void _showEditDeveloperDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, Developer developer) {
    showDialog(
      context: context,
      builder: (context) => EditDeveloperModal(
        developer: developer,
        onDeveloperUpdated: (updatedDeveloper) {
          _loadDevelopers();
        },
      ),
    );
  }
  
  void _showDeleteDeveloperDialog(BuildContext context, AppLocalizations? localizations, ThemeData theme, Developer developer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('deleteDeveloper') ?? 'Delete Developer'),
        content: Text('${localizations?.translate('confirmDeleteDeveloper') ?? 'Are you sure you want to delete'} ${developer.name}?'),
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
                await _apiService.deleteDeveloper(developer.id);
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(localizations?.translate('developerDeleted') ?? 'Developer deleted')),
                  );
                  // Reload all related data since deleting a developer cascades to projects and units
                  await Future.wait([
                    _loadDevelopers(),
                    _loadProjects(),
                    _loadUnits(),
                  ]);
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

