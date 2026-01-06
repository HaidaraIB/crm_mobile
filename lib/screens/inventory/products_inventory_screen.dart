import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/number_formatter.dart';
import '../../models/inventory_model.dart';
import '../../services/api_service.dart';
import '../../widgets/inventory_card.dart';

class ProductsInventoryScreen extends StatefulWidget {
  const ProductsInventoryScreen({super.key});

  @override
  State<ProductsInventoryScreen> createState() => _ProductsInventoryScreenState();
}

class _ProductsInventoryScreenState extends State<ProductsInventoryScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // Products
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoadingProducts = true;
  String? _errorProducts;
  
  // Product Categories
  List<ProductCategory> _categories = [];
  List<ProductCategory> _filteredCategories = [];
  bool _isLoadingCategories = true;
  String? _errorCategories;
  
  // Suppliers
  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];
  bool _isLoadingSuppliers = true;
  String? _errorSuppliers;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _searchController.addListener(_filterData);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadProducts(),
      _loadCategories(),
      _loadSuppliers(),
    ]);
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _errorProducts = null;
    });
    
    try {
      final products = await _apiService.getProducts();
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() {
        _errorProducts = e.toString();
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _errorCategories = null;
    });
    
    try {
      final categories = await _apiService.getProductCategories();
      setState(() {
        _categories = categories;
        _filteredCategories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _errorCategories = e.toString();
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoadingSuppliers = true;
      _errorSuppliers = null;
    });
    
    try {
      final suppliers = await _apiService.getSuppliers();
      setState(() {
        _suppliers = suppliers;
        _filteredSuppliers = suppliers;
        _isLoadingSuppliers = false;
      });
    } catch (e) {
      setState(() {
        _errorSuppliers = e.toString();
        _isLoadingSuppliers = false;
      });
    }
  }

  void _filterData() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredProducts = _products.where((product) {
        return product.code.toLowerCase().contains(query) ||
               product.name.toLowerCase().contains(query) ||
               product.category.toLowerCase().contains(query) ||
               (product.sku?.toLowerCase().contains(query) ?? false) ||
               (product.supplier?.toLowerCase().contains(query) ?? false);
      }).toList();
      
      _filteredCategories = _categories.where((category) {
        return category.code.toLowerCase().contains(query) ||
               category.name.toLowerCase().contains(query) ||
               (category.description?.toLowerCase().contains(query) ?? false);
      }).toList();
      
      _filteredSuppliers = _suppliers.where((supplier) {
        return supplier.code.toLowerCase().contains(query) ||
               supplier.name.toLowerCase().contains(query) ||
               supplier.phone.toLowerCase().contains(query) ||
               (supplier.email?.toLowerCase().contains(query) ?? false) ||
               (supplier.specialization?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Color _getStockColor(int stock) {
    if (stock > 10) return Colors.green;
    if (stock > 0) return Colors.orange;
    return Colors.red;
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
            Tab(text: localizations?.translate('products') ?? 'Products'),
            Tab(text: localizations?.translate('productCategories') ?? 'Product Categories'),
            Tab(text: localizations?.translate('suppliers') ?? 'Suppliers'),
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
                _buildProductsTab(localizations, theme),
                _buildCategoriesTab(localizations, theme),
                _buildSuppliersTab(localizations, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab(AppLocalizations? localizations, ThemeData theme) {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorProducts != null) {
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
              _errorProducts!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noProductsFound') ?? 'No products found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final stockColor = _getStockColor(product.stock);
        return InventoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and status badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.code,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    text: product.isActive 
                        ? (localizations?.translate('active') ?? 'Active')
                        : (localizations?.translate('inactive') ?? 'Inactive'),
                    color: product.isActive ? Colors.green : Colors.grey,
                    icon: product.isActive ? Icons.check_circle : Icons.cancel,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Details
              if (product.sku != null)
                InfoRow(
                  icon: Icons.qr_code,
                  label: localizations?.translate('sku') ?? 'SKU',
                  value: product.sku!,
                ),
              InfoRow(
                icon: Icons.category,
                label: localizations?.translate('category') ?? 'Category',
                value: product.category,
              ),
              if (product.supplier != null)
                InfoRow(
                  icon: Icons.local_shipping,
                  label: localizations?.translate('supplier') ?? 'Supplier',
                  value: product.supplier!,
                ),
              const SizedBox(height: 12),
              // Price and cost in a row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations?.translate('price') ?? 'Price',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormatter.formatCurrency(product.price),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations?.translate('cost') ?? 'Cost',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormatter.formatCurrency(product.cost),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stock badge
              StatusBadge(
                text: '${localizations?.translate('stock') ?? 'Stock'}: ${product.stock}',
                color: stockColor,
                icon: Icons.inventory_2,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab(AppLocalizations? localizations, ThemeData theme) {
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorCategories != null) {
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
              _errorCategories!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCategories,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredCategories.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noProductCategoriesFound') ?? 'No product categories found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        final category = _filteredCategories[index];
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
                  Icons.category,
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
                      category.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.code,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (category.description != null && category.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        category.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuppliersTab(AppLocalizations? localizations, ThemeData theme) {
    if (_isLoadingSuppliers) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorSuppliers != null) {
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
              _errorSuppliers!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSuppliers,
              child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredSuppliers.isEmpty) {
      return Center(
        child: Text(
          localizations?.translate('noSuppliersFound') ?? 'No suppliers found',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSuppliers.length,
      itemBuilder: (context, index) {
        final supplier = _filteredSuppliers[index];
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
                      Icons.local_shipping,
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
                          supplier.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          supplier.code,
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
                value: supplier.phone,
              ),
              if (supplier.email != null)
                InfoRow(
                  icon: Icons.email,
                  label: localizations?.translate('email') ?? 'Email',
                  value: supplier.email!,
                ),
              if (supplier.contactPerson != null)
                InfoRow(
                  icon: Icons.person,
                  label: localizations?.translate('contactPerson') ?? 'Contact Person',
                  value: supplier.contactPerson!,
                ),
              if (supplier.address != null)
                InfoRow(
                  icon: Icons.location_on,
                  label: localizations?.translate('address') ?? 'Address',
                  value: supplier.address!,
                ),
              if (supplier.specialization != null)
                InfoRow(
                  icon: Icons.work,
                  label: localizations?.translate('specialization') ?? 'Specialization',
                  value: supplier.specialization!,
                ),
            ],
          ),
        );
      },
    );
  }
}

