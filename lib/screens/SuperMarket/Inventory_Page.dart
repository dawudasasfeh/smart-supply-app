import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/supermarket_bottom_nav.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  List<dynamic> inventory = [];
  List<dynamic> filteredInventory = [];
  bool isLoading = true;
  String token = '';
  String searchQuery = '';
  String selectedFilter = 'All';
  bool _showFilters = false;
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();
  final List<String> filterOptions = ['All', 'Low Stock', 'In Stock', 'High Value'];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchInventory();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchInventory() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? '';
    final data = await ApiService.getSupermarketInventory(token);
    setState(() {
      inventory = data;
      filteredInventory = data;
      isLoading = false;
    });
  }

  void _filterInventory() {
    setState(() {
      filteredInventory = inventory.where((item) {
        final productName = (item['product_name'] ?? item['name'] ?? '').toString().toLowerCase();
        final matchesSearch = searchQuery.isEmpty || productName.contains(searchQuery.toLowerCase());
        
        if (!matchesSearch) return false;
        
        switch (selectedFilter) {
          case 'Low Stock':
            final stock = item['total_quantity'] ?? item['stock'] ?? 0;
            final stockInt = stock is int ? stock : int.tryParse(stock.toString()) ?? 0;
            return stockInt < 10;
          case 'In Stock':
            final stock = item['total_quantity'] ?? item['stock'] ?? 0;
            final stockInt = stock is int ? stock : int.tryParse(stock.toString()) ?? 0;
            return stockInt >= 10;
          case 'High Value':
            final quantity = item['total_quantity'] ?? item['stock'] ?? 0;
            final price = item['price'] ?? 0;
            final qty = quantity is int ? quantity : int.tryParse(quantity.toString()) ?? 0;
            final prc = price is double ? price : double.tryParse(price.toString()) ?? 0;
            return (qty * prc) > 100;
          default:
            return true;
        }
      }).toList();
    });
  }

void _predictAndRestock(dynamic item) async {
  final productId = item['product_id'] ?? item['id'];
  final productName = item['product_name'] ?? item['name'] ?? 'Product';

  // Parse stockLevel safely to double
  double stockLevel = 0;
  final stockValue = item['total_quantity'] ?? item['stock'] ?? 0;
  if (stockValue is String) {
    stockLevel = double.tryParse(stockValue) ?? 0;
  } else if (stockValue is int) {
    stockLevel = stockValue.toDouble();
  } else if (stockValue is double) {
    stockLevel = stockValue;
  }

  // Same for previousOrders & activeOffers - parse as int
  int previousOrders = 0;
  final prevOrdersValue = item['previous_orders'] ?? 0;
  if (prevOrdersValue is String) {
    previousOrders = int.tryParse(prevOrdersValue) ?? 0;
  } else if (prevOrdersValue is int) {
    previousOrders = prevOrdersValue;
  }

  int activeOffers = 0;
  final activeOffersValue = item['active_offers'] ?? 0;
  if (activeOffersValue is String) {
    activeOffers = int.tryParse(activeOffersValue) ?? 0;
  } else if (activeOffersValue is int) {
    activeOffers = activeOffersValue;
  }

  final distributorId = item['distributor_id'] ?? 1;
  final date = DateTime.now().toIso8601String().split('T').first;

  print(
    'Calling predictRestock with: productId=$productId, distributorId=$distributorId, stockLevel=$stockLevel, previousOrders=$previousOrders, activeOffers=$activeOffers, date=$date'
  );

  try {
    final prediction = await ApiService.predictRestock(
      productId: productId,
      distributorId: distributorId,
      stockLevel: stockLevel,
      previousOrders: previousOrders,
      activeOffers: activeOffers,
      date: date,
    );

    if (prediction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to get restock prediction")),
      );
      return;
    }

    final suggestedQuantity = prediction['suggested_quantity'] ?? 0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("AI Suggestion for '$productName'"),
        content: Text("Restock $suggestedQuantity units?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final success = await ApiService.restockProduct(token, productId, suggestedQuantity);
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Product restocked successfully")),
                );
                fetchInventory();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to restock product")),
                );
              }
            },
            child: const Text("Restock Now"),
          ),
        ],
      ),
    );
  } catch (e) {
    print('Error during restock prediction: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${e.toString()}")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isLoading 
        ? _buildModernLoadingScreen()
        : FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildModernAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),
                      _buildModernSearchSection(),
                      const SizedBox(height: 24),
                      _buildModernStatsSection(),
                      const SizedBox(height: 24),
                      _buildModernInventorySection(),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          ),
      bottomNavigationBar: SuperMarketBottomNav(
        currentIndex: 2, // Inventory page index
        onTap: (index) {
          Navigator.pushReplacementNamed(
            context,
            '/supermarket',
            arguments: {'initialIndex': index},
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inventory Management',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Track and manage your stock',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: fetchInventory,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar with Filter Button Row
          Row(
            children: [
              // Search Bar
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search inventory, products, brands...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 24),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => searchQuery = '');
                                _filterInventory();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (value) {
                      setState(() => searchQuery = value);
                      _debounceTimer?.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                        if (mounted && searchQuery == value) {
                          _filterInventory();
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Animated Filter Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: _showFilters 
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        )
                      : LinearGradient(
                          colors: [Colors.grey[100]!, Colors.grey[50]!],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _showFilters 
                          ? AppColors.primary.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: _showFilters ? 12 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() => _showFilters = !_showFilters);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _showFilters ? Icons.filter_list_off : Icons.tune,
                          key: ValueKey(_showFilters),
                          color: _showFilters ? Colors.white : AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Animated Filter Options
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showFilters ? null : 0,
            child: _showFilters ? _buildFilterOptions() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Options',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filterOptions.map((filter) {
              final isSelected = selectedFilter == filter;
              return FilterChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    selectedFilter = filter;
                  });
                  _filterInventory();
                },
                backgroundColor: Colors.white,
                selectedColor: AppColors.primary.withOpacity(0.1),
                checkmarkColor: AppColors.primary,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final totalItems = filteredInventory.length;
    final lowStockItems = filteredInventory.where((item) {
      final stock = item['total_quantity'] ?? item['stock'] ?? 0;
      return (stock is int ? stock : int.tryParse(stock.toString()) ?? 0) < 10;
    }).length;
    final totalValue = filteredInventory.fold<double>(0, (sum, item) {
      final quantity = item['total_quantity'] ?? item['stock'] ?? 0;
      final price = item['price'] ?? 0;
      final qty = quantity is int ? quantity : int.tryParse(quantity.toString()) ?? 0;
      final prc = price is double ? price : double.tryParse(price.toString()) ?? 0;
      return sum + (qty * prc);
    });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Total Items', totalItems.toString(), Icons.inventory_2, AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Low Stock', lowStockItems.toString(), Icons.warning_amber, AppColors.warning)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Total Value', '\$${totalValue.toStringAsFixed(0)}', Icons.attach_money, AppColors.success)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryGrid() {
    if (isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Loading inventory...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredInventory.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                searchQuery.isNotEmpty || selectedFilter != 'All' 
                    ? 'No items match your search'
                    : 'No inventory items found',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
              if (searchQuery.isNotEmpty || selectedFilter != 'All')
                TextButton(
                  onPressed: () {
                    setState(() {
                      searchQuery = '';
                      selectedFilter = 'All';
                    });
                    _filterInventory();
                  },
                  child: const Text('Clear filters'),
                ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildInventoryCard(filteredInventory[index]),
          childCount: filteredInventory.length,
        ),
      ),
    );
  }

  Widget _buildInventoryCard(dynamic item) {
    final productName = item['product_name'] ?? item['name'] ?? 'Unknown Product';
    final stock = item['total_quantity'] ?? item['stock'] ?? 0;
    final stockInt = stock is int ? stock : int.tryParse(stock.toString()) ?? 0;
    final price = item['price'] ?? 0;
    final priceDouble = price is double ? price : double.tryParse(price.toString()) ?? 0;
    final isLowStock = stockInt < 10;
    final brand = item['brand'] ?? '';
    final totalValue = stockInt * priceDouble;
    final productImage = item['image_url'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLowStock 
            ? Border.all(color: AppColors.warning.withOpacity(0.3), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status indicator
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: 100,
                  width: double.infinity,
                  child: productImage.isNotEmpty
                      ? Image.network(
                          productImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isLowStock
                                      ? [AppColors.warning.withOpacity(0.1), AppColors.error.withOpacity(0.1)]
                                      : [AppColors.primary.withOpacity(0.1), AppColors.secondary.withOpacity(0.1)],
                                ),
                              ),
                              child: Icon(
                                isLowStock ? Icons.warning_amber : Icons.inventory_2,
                                size: 40,
                                color: isLowStock ? AppColors.warning : AppColors.primary,
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isLowStock
                                  ? [AppColors.warning.withOpacity(0.1), AppColors.error.withOpacity(0.1)]
                                  : [AppColors.primary.withOpacity(0.1), AppColors.secondary.withOpacity(0.1)],
                            ),
                          ),
                          child: Icon(
                            isLowStock ? Icons.warning_amber : Icons.inventory_2,
                            size: 40,
                            color: isLowStock ? AppColors.warning : AppColors.primary,
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLowStock ? AppColors.warning : AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isLowStock ? 'LOW STOCK' : 'IN STOCK',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Content
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (brand.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      brand,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Stock info
                  Row(
                    children: [
                      Icon(
                        Icons.inventory,
                        size: 12,
                        color: isLowStock ? AppColors.warning : AppColors.success,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '$stockInt units',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isLowStock ? AppColors.warning : AppColors.success,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (priceDouble > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '\$${totalValue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  // AI Restock button
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton.icon(
                      onPressed: () => _predictAndRestock(item),
                      icon: const Icon(Icons.auto_awesome, size: 12),
                      label: const Text(
                        'AI Restock',
                        style: TextStyle(fontSize: 10),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modern Loading Screen
  Widget _buildModernLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Loading Inventory',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fetching your products...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern AppBar
  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Inventory',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Manage Products',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            fetchInventory();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Modern Search Section
  Widget _buildModernSearchSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                      _filterInventory();
                    });
                  },
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF1E293B),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                              _filterInventory();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Icon(
                  _showFilters ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                  color: _showFilters ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
        if (_showFilters) ...[
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filterOptions.map((filter) {
                final isSelected = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        selectedFilter = filter;
                      });
                      _filterInventory();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  // Modern Stats Section
  Widget _buildModernStatsSection() {
    final totalProducts = filteredInventory.length;
    final lowStockCount = filteredInventory.where((item) {
      final stock = item['total_quantity'] ?? item['stock'] ?? 0;
      final stockInt = int.tryParse(stock.toString()) ?? 0;
      return stockInt < 10;
    }).length;
    final totalValue = filteredInventory.fold<double>(0, (sum, item) {
      final quantity = item['total_quantity'] ?? item['stock'] ?? 0;
      final price = item['price'] ?? 0;
      final qty = int.tryParse(quantity.toString()) ?? 0;
      final prc = double.tryParse(price.toString()) ?? 0;
      return sum + (qty * prc);
    });

    final stats = [
      {
        'title': 'Total Products',
        'value': totalProducts.toString(),
        'icon': Icons.inventory_2_rounded,
        'color': const Color(0xFF3B82F6),
        'bgColor': const Color(0xFFEFF6FF),
      },
      {
        'title': 'Low Stock',
        'value': lowStockCount.toString(),
        'icon': Icons.warning_rounded,
        'color': const Color(0xFFF59E0B),
        'bgColor': const Color(0xFFFEF3C7),
      },
      {
        'title': 'Total Value',
        'value': '\$${totalValue.toStringAsFixed(0)}',
        'icon': Icons.attach_money_rounded,
        'color': const Color(0xFF10B981),
        'bgColor': const Color(0xFFD1FAE5),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inventory Overview',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: stats.map((stat) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: stat['bgColor'] as Color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        stat['icon'] as IconData,
                        color: stat['color'] as Color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      stat['value'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat['title'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Modern Inventory Section
  Widget _buildModernInventorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Products (${filteredInventory.length})',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            if (filteredInventory.isNotEmpty)
              Text(
                selectedFilter != 'All' ? selectedFilter : 'All Items',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (filteredInventory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF64748B),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No products found',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try adjusting your search or filters',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredInventory.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = filteredInventory[index];
              return _buildModernProductCard(item);
            },
          ),
      ],
    );
  }

  // Modern Product Card
  Widget _buildModernProductCard(dynamic item) {
    final productName = item['product_name'] ?? item['name'] ?? 'Unknown Product';
    final productImage = item['image'] ?? item['image_url'] ?? item['product_image'];
    
    // Safe conversion for stock
    final stockRaw = item['total_quantity'] ?? item['stock'] ?? item['quantity'] ?? 0;
    final stockLevel = int.tryParse(stockRaw.toString()) ?? 0;
    
    // Safe conversion for price
    final priceRaw = item['price'] ?? item['unit_price'] ?? 0.0;
    final price = double.tryParse(priceRaw.toString()) ?? 0.0;
    
    final totalValue = stockLevel * price;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: productImage != null && productImage.toString().isNotEmpty
                  ? Image.network(
                      productImage.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.inventory_2_rounded,
                          color: Color(0xFF64748B),
                          size: 28,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64748B)),
                            ),
                          ),
                        );
                      },
                    )
                  : const Icon(
                      Icons.inventory_2_rounded,
                      color: Color(0xFF64748B),
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Stock: $stockLevel',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stockLevel > 10
                            ? const Color(0xFFD1FAE5)
                            : stockLevel > 0
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stockLevel > 10 
                            ? 'In Stock' 
                            : stockLevel > 0 
                                ? 'Low Stock' 
                                : 'Out of Stock',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: stockLevel > 10
                              ? const Color(0xFF10B981)
                              : stockLevel > 0
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit Price',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total Value',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          '\$${totalValue.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _predictAndRestock(item);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
