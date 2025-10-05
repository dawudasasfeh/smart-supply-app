import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../widgets/rating_details_modal.dart';
import '../../models/cart_manager.dart';
import 'Cart_Page.dart';
import '../../widgets/supermarket_bottom_nav.dart';
import '../../l10n/app_localizations.dart';

class BrowseProductsPage extends StatefulWidget {
  final bool enableOffersFilter;
  final bool showBottomNav;
  final int currentNavIndex;

  const BrowseProductsPage({
    super.key,
    this.enableOffersFilter = false,
    this.showBottomNav = false,
    this.currentNavIndex = 0,
  });

  @override
  State<BrowseProductsPage> createState() => _BrowseProductsPageState();
}

class _BrowseProductsPageState extends State<BrowseProductsPage> 
    with TickerProviderStateMixin {
  
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  
  List<dynamic> products = [];
  List<dynamic> offers = [];
  List<Map<String, dynamic>> distributors = [];
  int? selectedDistributorId;
  bool isLoading = true;
  String searchQuery = '';
  String selectedCategory = 'All';
  bool showOffersOnly = false;
  bool showInStockOnly = false;
  String sortBy = 'name';
  double _minPrice = 0;
  double _maxPrice = 1000;
  RangeValues _priceRange = const RangeValues(0, 1000);
  bool _showFilters = false;
  
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<String> get categories {
    final locale = AppLocalizations.of(context);
    final isRTL = locale?.isRTL == true;
    return [
      isRTL ? 'الكل' : 'All',
      isRTL ? 'طعام ومشروبات' : 'Food & Beverages',
      isRTL ? 'إلكترونيات' : 'Electronics',
      isRTL ? 'ملابس وأزياء' : 'Clothing & Fashion',
      isRTL ? 'منزل وحديقة' : 'Home & Garden',
      isRTL ? 'صحة وجمال' : 'Health & Beauty',
      isRTL ? 'رياضة وهواء طلق' : 'Sports & Outdoors',
      isRTL ? 'كتب ووسائط' : 'Books & Media',
      isRTL ? 'ألعاب' : 'Toys & Games',
      isRTL ? 'سيارات' : 'Automotive',
      isRTL ? 'مستلزمات مكتبية' : 'Office Supplies',
      isRTL ? 'أخرى' : 'Other',
    ];
  }

  List<Map<String, dynamic>> get sortOptions {
    final locale = AppLocalizations.of(context);
    final isRTL = locale?.isRTL == true;
    return [
      {'value': 'name', 'label': isRTL ? 'الاسم (أ-ي)' : 'Name (A-Z)', 'icon': Icons.sort_by_alpha},
      {'value': 'price_low', 'label': isRTL ? 'السعر (من الأقل للأعلى)' : 'Price (Low to High)', 'icon': Icons.arrow_upward},
      {'value': 'price_high', 'label': isRTL ? 'السعر (من الأعلى للأقل)' : 'Price (High to Low)', 'icon': Icons.arrow_downward},
      {'value': 'rating', 'label': isRTL ? 'الأعلى تقييماً' : 'Highest Rated', 'icon': Icons.star},
    ];
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    if (widget.enableOffersFilter) {
      showOffersOnly = true;
    }
    fetchDistributors();
    fetchData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOutCubic),
    );
    
    _animationController?.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchDistributors() async {
    final result = await ApiService.getAllDistributors();
    if (mounted) {
      setState(() => distributors = result);
    }
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      List<dynamic> fetchedProducts = [];
      List<dynamic> fetchedOffers = [];

      if (widget.enableOffersFilter || showOffersOnly) {
        fetchedOffers = await ApiService.getOffers();
        fetchedProducts = fetchedOffers;
      } else {
        fetchedProducts = await ApiService.getProducts(token);
        fetchedOffers = await ApiService.getOffers();
      }

      // Apply filters
      List<dynamic> filteredProducts = fetchedProducts.where((product) {
        // Search filter
        if (searchQuery.isNotEmpty) {
          final name = (product['name'] ?? '').toString().toLowerCase();
          if (!name.contains(searchQuery.toLowerCase())) return false;
        }

        // Category filter
        if (selectedCategory != 'All') {
          final category = (product['category'] ?? '').toString();
          if (category != selectedCategory) return false;
        }

        // Distributor filter
        if (selectedDistributorId != null) {
          final distributorId = product['distributor_id'] ?? product['user_id'];
          if (distributorId != selectedDistributorId) return false;
        }

        // Price filter
        final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;
        if (price < _minPrice || price > _maxPrice) return false;

        // Stock filter
        if (showInStockOnly) {
          final stock = int.tryParse(product['stock']?.toString() ?? '0') ?? 0;
          if (stock <= 0) return false;
        }

        return true;
      }).toList();

      // Apply sorting
      filteredProducts.sort((a, b) {
        switch (sortBy) {
          case 'name':
            return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
          case 'price_low':
            final priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
            final priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
            return priceA.compareTo(priceB);
          case 'price_high':
            final priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
            final priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
            return priceB.compareTo(priceA);
          case 'rating':
            final ratingA = double.tryParse(a['rating']?.toString() ?? '0') ?? 0;
            final ratingB = double.tryParse(b['rating']?.toString() ?? '0') ?? 0;
            return ratingB.compareTo(ratingA);
          default:
            return 0;
        }
      });

      if (mounted) {
        setState(() {
          products = filteredProducts;
          offers = fetchedOffers;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  void _clearAllFilters() {
    setState(() {
      searchQuery = '';
      selectedCategory = 'All';
      selectedDistributorId = null;
      _priceRange = const RangeValues(0, 1000);
      _minPrice = 0;
      _maxPrice = 1000;
      showInStockOnly = false;
      if (!widget.enableOffersFilter) {
        showOffersOnly = false;
      }
      sortBy = 'name';
    });
    _searchController.clear();
    fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
    
    return Scaffold(
      backgroundColor: bgColor,
      extendBody: false, // Prevent body from extending behind bottom nav
      body: isLoading 
        ? _buildLoadingScreen()
        : _fadeAnimation != null 
          ? FadeTransition(
              opacity: _fadeAnimation!,
              child: _buildBrowseProducts(),
            )
          : _buildBrowseProducts(),
      bottomNavigationBar: widget.showBottomNav 
        ? SuperMarketBottomNav(
            currentIndex: widget.currentNavIndex,
            onTap: (index) {
              HapticFeedback.lightImpact();
              Navigator.pushReplacementNamed(
                context,
                '/supermarket',
                arguments: {'initialIndex': index},
              );
            },
          )
        : null,
    );
  }

  Widget _buildLoadingScreen() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF000000), const Color(0xFF0A0A0A)]
              : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
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
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
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
              locale?.translate('loading') ?? 'Loading Products',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finding the best products for you...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: subtextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseProducts() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),
              _buildSearchSection(),
              const SizedBox(height: 24),
              _buildProductsSection(),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: bgColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF000000), const Color(0xFF0A0A0A)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
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
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
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
                              widget.enableOffersFilter 
                                  ? (locale?.translate('special_offers') ?? 'Special Offers')
                                  : (locale?.translate('browse_products') ?? 'Browse Products'),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.enableOffersFilter 
                                  ? (locale?.translate('exclusive_deals') ?? 'Exclusive Deals')
                                  : (locale?.translate('discover_products') ?? 'Discover Products'),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: subtextColor,
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
                          color: isDark ? const Color(0xFF0A0A0A) : Colors.black,
                          borderRadius: BorderRadius.circular(10),
                          border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CartPage(),
                              ),
                            );
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

  Widget _buildSearchSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final hintColor = isDark ? const Color(0xFF6B7280) : const Color(0xFF94A3B8);
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
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
                      fetchData();
                    });
                  },
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: locale?.translate('search') ?? 'Search products...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: hintColor,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: subtextColor,
                      size: 20,
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: subtextColor,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                              fetchData();
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
                color: isDark ? const Color(0xFF0A0A0A) : Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
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
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
        if (_showFilters) ...[
          const SizedBox(height: 16),
          _buildFiltersSection(),
        ],
        const SizedBox(height: 16),
        _buildActiveFiltersChips(),
      ],
    );
  }

  Widget _buildFiltersSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final bgColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale?.isRTL == true ? 'الفلاتر' : 'Filters',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              TextButton(
                onPressed: _clearAllFilters,
                child: Text(
                  locale?.isRTL == true ? 'مسح الكل' : 'Clear All',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Categories
          Text(
            locale?.isRTL == true ? 'الفئات' : 'Categories',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
              final isSelected = selectedCategory == category;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    selectedCategory = category;
                  });
                  fetchData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF3B82F6) 
                        : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF3B82F6) : borderColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    category,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : subtextColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Distributors
          Text(
            locale?.isRTL == true ? 'موردين' : 'Distributors',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: selectedDistributorId,
                hint: Text(
                  locale?.isRTL == true ? 'كل الموردين' : 'All Distributors',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: subtextColor,
                  size: 20,
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      locale?.isRTL == true ? 'كل الموردين' : 'All Distributors',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ),
                  ...distributors.map<DropdownMenuItem<int?>>((distributor) {
                    return DropdownMenuItem<int?>(
                      value: distributor['id'],
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              distributor['name'] ?? 'Unknown Distributor',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (int? value) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    selectedDistributorId = value;
                  });
                  fetchData();
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Toggle Filters
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      showOffersOnly = !showOffersOnly;
                    });
                    fetchData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: showOffersOnly 
                          ? const Color(0xFFEF4444) 
                          : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: showOffersOnly ? const Color(0xFFEF4444) : borderColor,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_offer,
                          size: 14,
                          color: showOffersOnly ? Colors.white : subtextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          locale?.isRTL == true ? 'العروض فقط' : 'Offers Only',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: showOffersOnly ? Colors.white : subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      showInStockOnly = !showInStockOnly;
                    });
                    fetchData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: showInStockOnly 
                          ? const Color(0xFF10B981) 
                          : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: showInStockOnly ? const Color(0xFF10B981) : borderColor,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 14,
                          color: showInStockOnly ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          locale?.isRTL == true ? 'متوفر' : 'In Stock',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: showInStockOnly ? Colors.white : subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Sort Options
          Text(
            locale?.isRTL == true ? 'ترتيب حسب' : 'Sort By',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortOptions.map((option) {
              final isSelected = sortBy == option['value'];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    sortBy = option['value'];
                  });
                  fetchData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF3B82F6) 
                        : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    option['label'],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : subtextColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Price Range
          Text(
            locale?.isRTL == true 
                ? 'نطاق السعر: \$${_priceRange.start.round()} - \$${_priceRange.end.round()}'
                : 'Price Range: \$${_priceRange.start.round()} - \$${_priceRange.end.round()}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000,
            divisions: 20,
            activeColor: const Color(0xFF3B82F6),
            inactiveColor: const Color(0xFFE2E8F0),
            onChanged: (values) {
              setState(() {
                _priceRange = values;
                _minPrice = values.start;
                _maxPrice = values.end;
              });
            },
            onChangeEnd: (values) {
              fetchData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    final locale = AppLocalizations.of(context);
    List<Widget> activeFilters = [];
    
    // Category filter
    if (selectedCategory != 'All') {
      activeFilters.add(_buildFilterChip(
        label: selectedCategory,
        onRemove: () {
          setState(() {
            selectedCategory = 'All';
          });
          fetchData();
        },
      ));
    }
    
    // Distributor filter
    if (selectedDistributorId != null) {
      final distributor = distributors.firstWhere(
        (d) => d['id'] == selectedDistributorId,
        orElse: () => {'name': 'Unknown'},
      );
      activeFilters.add(_buildFilterChip(
        label: distributor['name'] ?? 'Unknown',
        onRemove: () {
          setState(() {
            selectedDistributorId = null;
          });
          fetchData();
        },
      ));
    }
    
    // Offers filter
    if (showOffersOnly) {
      final locale = AppLocalizations.of(context);
      activeFilters.add(_buildFilterChip(
        label: locale?.isRTL == true ? 'العروض فقط' : 'Offers Only',
        onRemove: () {
          setState(() {
            showOffersOnly = false;
          });
          fetchData();
        },
      ));
    }
    
    // In Stock filter
    if (showInStockOnly) {
      final locale = AppLocalizations.of(context);
      activeFilters.add(_buildFilterChip(
        label: locale?.isRTL == true ? 'متوفر' : 'In Stock',
        onRemove: () {
          setState(() {
            showInStockOnly = false;
          });
          fetchData();
        },
      ));
    }
    
    // Price range filter
    if (_priceRange.start > 0 || _priceRange.end < 1000) {
      activeFilters.add(_buildFilterChip(
        label: '\$${_priceRange.start.round()}-\$${_priceRange.end.round()}',
        onRemove: () {
          setState(() {
            _priceRange = const RangeValues(0, 1000);
            _minPrice = 0;
            _maxPrice = 1000;
          });
          fetchData();
        },
      ));
    }
    
    if (activeFilters.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              locale?.isRTL == true ? 'الفلاتر النشطة' : 'Active Filters',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _clearAllFilters,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                locale?.isRTL == true ? 'مسح الكل' : 'Clear All',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: activeFilters,
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onRemove();
            },
            child: const Icon(
              Icons.close,
              size: 14,
              color: Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.enableOffersFilter 
                  ? '${locale?.translate('special_offers') ?? 'Special Offers'} (${products.length})'
                  : '${locale?.translate('products') ?? 'Products'} (${products.length})',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (products.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
                    color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: subtextColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  locale?.translate('no_products_found') ?? 'No products found',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try adjusting your search or filters',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: subtextColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.62,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product);
            },
          ),
      ],
    );
  }

  Widget _buildProductCard(dynamic product) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    final productName = product['name'] ?? product['product_name'] ?? 'Unknown Product';
    final productImage = product['image_url'] ?? product['image'] ?? product['product_image'];
    
    // Handle price for both products and offers
    double price = 0.0;
    if (product['discount_price'] != null) {
      // This is an offer, use discount_price
      price = double.tryParse(product['discount_price']?.toString() ?? '0') ?? 0.0;
    } else if (product['price'] != null) {
      // This is a regular product, use price
      price = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    } else if (product['original_price'] != null) {
      // Fallback to original_price if available
      price = double.tryParse(product['original_price']?.toString() ?? '0') ?? 0.0;
    }
    
    final rating = double.tryParse(product['rating']?.toString() ?? '0') ?? 0.0;
    final stock = int.tryParse(product['stock']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showProductDetailsModal(product);
      },
      child: Container(
        decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: productImage != null && productImage.toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: productImage.toString(),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64748B)),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.shopping_bag_rounded,
                          color: Color(0xFF64748B),
                          size: 32,
                        ),
                      )
                    : const Icon(
                        Icons.shopping_bag_rounded,
                        color: Color(0xFF64748B),
                        size: 32,
                      ),
              ),
            ),
          ),
          
          // Product Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    productName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (rating > 0) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: stock > 0 ? () async {
                        HapticFeedback.lightImpact();
                        await _addToCart(product, context);
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: stock > 0 ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        stock > 0 
                            ? (locale?.translate('add_to_cart') ?? 'Add to Cart')
                            : (locale?.translate('out_of_stock') ?? 'Out of Stock'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
     ),
    );
  }

  Future<void> _showProductDetailsModal(dynamic product) async {
    // Find the offer for this product if it exists
    dynamic productOffer;
    try {
      productOffer = offers.firstWhere(
        (offer) => offer['product_id'] == product['id'],
      );
    } catch (e) {
      productOffer = null;
    }
    
    // Find the distributor for this product
    final distributorId = product['distributor_id'] ?? product['user_id'];
    Map<String, dynamic>? distributor;
    try {
      distributor = distributors.firstWhere(
        (dist) => dist['id'] == distributorId,
      );
    } catch (e) {
      distributor = null;
    }

    // Get distributor rating if available
    double avgRating = 0.0;
    int reviewCount = 0;
    if (distributor != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token') ?? '';
        final summary = await ApiService.getRatingSummary(token, distributor['id'], 'distributor');
        if (summary.isNotEmpty) {
          final supplierRating = summary.firstWhere(
            (s) => s['rating_type'] == 'supplier_rating',
            orElse: () => null,
          );
          if (supplierRating != null) {
            avgRating = double.tryParse(supplierRating['average_rating']?.toString() ?? '0') ?? 0.0;
            reviewCount = int.tryParse(supplierRating['total_ratings']?.toString() ?? '0') ?? 0;
          }
        }
      } catch (e) {
        print('Error fetching distributor rating: $e');
      }
    }
    
    // Show comprehensive product details modal
    _showProductModal(product, productOffer, distributor, avgRating, reviewCount);
  }

  void _showProductModal(dynamic product, dynamic productOffer, Map<String, dynamic>? distributor, double avgRating, int reviewCount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final currentLocale = Localizations.localeOf(context);
    final isRTL = currentLocale.languageCode == 'ar';
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.grey[100]!;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, (1 - value) * 100),
              child: Opacity(
                opacity: value,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [const Color(0xFF0A0A0A), const Color(0xFF000000)]
                          : [Colors.white, Colors.grey[50]!],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Enhanced Handle bar with gradient
                      Container(
                        width: 60,
                        height: 6,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark 
                                ? [const Color(0xFF6B7280), const Color(0xFF9CA3AF)]
                                : [Colors.grey[400]!, Colors.grey[300]!],
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Product Image with Hero Animation and Staggered Effects
                      TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 800 + (value * 200).round()),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.elasticOut,
                        builder: (context, imageValue, _) {
                          return Transform.scale(
                            scale: 0.8 + (imageValue * 0.2),
                            child: Center(
                              child: Hero(
                                tag: 'product_${(product['id'] ?? 0).toString()}',
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isDark
                                          ? [const Color(0xFF1F2937), const Color(0xFF111827)]
                                          : [Colors.white, Colors.grey[100]!],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.2),
                                        blurRadius: 25,
                                        offset: const Offset(0, 15),
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: product['image_url'] != null && product['image_url'].toString().isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: product['image_url'].startsWith('http')
                                                ? product['image_url']
                                                : '${ApiService.imageBaseUrl}${(product['image_url'] ?? '').toString()}',
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: isDark
                                                      ? [const Color(0xFF1F2937), const Color(0xFF374151)]
                                                      : [Colors.grey[100]!, Colors.grey[200]!],
                                                ),
                                              ),
                                              child: Center(
                                                child: TweenAnimationBuilder<double>(
                                                  duration: const Duration(milliseconds: 1000),
                                                  tween: Tween(begin: 0.0, end: 1.0),
                                                  builder: (context, pulseValue, _) {
                                                    return Transform.scale(
                                                      scale: 0.8 + (pulseValue * 0.2),
                                                      child: const CircularProgressIndicator(
                                                        strokeWidth: 3,
                                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: isDark
                                                      ? [const Color(0xFF1F2937), const Color(0xFF374151)]
                                                      : [Colors.grey[100]!, Colors.grey[200]!],
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.image_not_supported, size: 70, color: subtextColor),
                                                  const SizedBox(height: 12),
                                                  Text(locale?.translate('no_image') ?? 'No Image Available', 
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isDark 
                                                    ? [const Color(0xFF000000), const Color(0xFF0A0A0A)]
                                                    : [Colors.blue[50]!, Colors.blue[100]!],
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.shopping_basket, size: 80, color: isDark ? subtextColor : Colors.blue.withOpacity(0.7)),
                                                const SizedBox(height: 12),
                                                Text(locale?.translate('product_image') ?? 'Product Image', 
                                                  style: TextStyle(
                                                    color: subtextColor,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Product Name and Brand
                      Text(
                        product['name'] ?? 'Unknown Product',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: textColor,
                        ),
                      ),
                      if (product['brand'] != null && product['brand'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product['brand'],
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      
                      // Distributor Info with Rating
                      if (distributor != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF000000) : cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF1F1F1F) : Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFF3B82F6).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.store, color: isDark ? subtextColor : const Color(0xFF3B82F6), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          distributor['name'] ?? 'Unknown Distributor',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () {
                                            showModalBottomSheet(
                                              context: context,
                                              builder: (context) => RatingDetailsModal(
                                                avgRating: avgRating,
                                                reviewCount: reviewCount,
                                                recentComments: const ['Great service!', 'Fast delivery', 'Quality products'],
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              gradient: avgRating > 0 
                                                  ? LinearGradient(
                                                      colors: [
                                                        Colors.amber.withOpacity(0.9),
                                                        Colors.orange.withOpacity(0.8),
                                                      ],
                                                    )
                                                  : LinearGradient(
                                                      colors: [
                                                        Colors.grey[300]!,
                                                        Colors.grey[200]!,
                                                      ],
                                                    ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: avgRating > 0 
                                                      ? Colors.amber.withOpacity(0.3)
                                                      : Colors.grey.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.star_rounded,
                                                  size: 18,
                                                  color: avgRating > 0 ? Colors.white : Colors.grey[500],
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  avgRating > 0 ? avgRating.toStringAsFixed(1) : (locale?.translate('no_rating') ?? 'No rating'),
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: avgRating > 0 ? Colors.white : subtextColor,
                                                  ),
                                                ),
                                                if (reviewCount > 0) ... [
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '$reviewCount',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  size: 16,
                                                  color: avgRating > 0 ? Colors.white : Colors.grey[500],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (distributor['email'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.email, size: 16, color: subtextColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      distributor['email'],
                                      style: TextStyle(color: subtextColor, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                              if (distributor['phone'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.phone, size: 16, color: subtextColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      distributor['phone'],
                                      style: TextStyle(color: subtextColor, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Product Description
                      if (product['description'] != null && product['description'].toString().isNotEmpty) ...[
                        Text(
                          isRTL ? 'الوصف' : 'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product['description'],
                          style: TextStyle(
                            fontSize: 15,
                            color: subtextColor,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Product Details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF000000) : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(isRTL ? 'الفئة' : 'Category', product['category'] ?? (isRTL ? 'غير محدد' : 'Not specified'), labelColor: subtextColor, valueColor: textColor),
                            _buildDetailRow('SKU', product['sku'] ?? (isRTL ? 'غير محدد' : 'Not specified'), labelColor: subtextColor, valueColor: textColor),
                            _buildDetailRow(isRTL ? 'المخزون المتاح' : 'Stock Available', '${(product['stock'] ?? 0).toString()} ${isRTL ? 'وحدة' : 'units'}', labelColor: subtextColor, valueColor: textColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Price and Offer Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF000000), const Color(0xFF000000)]
                                : [
                                    Colors.blue.withOpacity(0.1),
                                    Colors.blue.withOpacity(0.05),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (productOffer != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.orange, Colors.deepOrange],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_offer, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      () {
                                        final originalPrice = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
                                        final discountPrice = double.tryParse(productOffer['discount_price']?.toString() ?? '0') ?? 0.0;
                                        if (originalPrice > 0) {
                                          final percentage = ((originalPrice - discountPrice) / originalPrice * 100).round();
                                          return isRTL ? '\u062e\u0635\u0645 $percentage%' : '$percentage% OFF';
                                        }
                                        return isRTL ? '\u062a\u062e\u0641\u064a\u0636' : 'SALE';
                                      }(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    '\$${(double.tryParse(product['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '\$${(double.tryParse(productOffer['discount_price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                '\$${(double.tryParse(product['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              
              // Add to Cart Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (product['stock'] ?? 0) <= 0 
                        ? null 
                        : () async {
                            await _addToCart(product, context);
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (product['stock'] ?? 0) <= 0 ? Colors.grey : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: (product['stock'] ?? 0) <= 0 ? 0 : 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          (product['stock'] ?? 0) <= 0 ? Icons.block : Icons.add_shopping_cart,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (product['stock'] ?? 0) <= 0 
                              ? (isRTL ? '\u063a\u064a\u0631 \u0645\u062a\u0648\u0641\u0631' : 'Out of Stock')
                              : (isRTL ? '\u0623\u0636\u0641 \u0644\u0644\u0633\u0644\u0629' : 'Add to Cart'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                    ],
                  ),
                )));
              },
            );
          },
        );
      }
  }

  Widget _buildDetailRow(String label, String value, {Color? labelColor, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: labelColor ?? const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(dynamic product, BuildContext context) async {
    final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    final distributorId = product['distributor_id'] ?? product['user_id'];

    if (distributorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Distributor ID not found. Cannot add to cart.")),
      );
      return;
    }

    final cartItem = {
      'id': product['id'],
      'name': product['name'],
      'price': price,
      'image': product['image_url'] ?? product['image'],
      'image_url': product['image_url'],
      'distributor_id': distributorId,
      'stock': product['stock'] ?? 1,
    };
    
    // Use CartManager instance instead of static method
    final cartManager = CartManager();
    cartManager.addItem(cartItem, 1);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${(product['name'] ?? 'Product').toString()} added to cart'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'VIEW CART',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CartPage(),
              ),
            );
          },
        ),
      ),
    );
  }
  