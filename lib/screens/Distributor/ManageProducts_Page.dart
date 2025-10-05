import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../themes/role_theme_manager.dart';
import '../../l10n/app_localizations.dart';

class ManageProductsPage extends StatefulWidget {
  const ManageProductsPage({super.key});

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> with TickerProviderStateMixin {
  List<dynamic> myProducts = [];
  String token = '';
  bool isLoading = true;
  String searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    fetchMyProducts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchMyProducts() async {
    setState(() => isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token') ?? '';
      final userId = prefs.getInt('user_id');
      
      if (userId == null || userId == 0) {
        throw Exception('User ID not found');
      }
      
      final allProducts = await ApiService.getProducts(token, distributorId: userId);

      List<dynamic> filtered = allProducts; // No need to filter since we already fetched by distributor ID
      
      // Apply search filter
      if (searchQuery.isNotEmpty) {
        filtered = filtered.where((p) {
          return (p['name'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
                 (p['description'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
                 (p['brand'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();
      }
      
      // Sort by stock status (low stock first) then by name
      filtered.sort((a, b) {
        int stockA = a['stock'] ?? 0;
        int stockB = b['stock'] ?? 0;
        
        // Low stock products first
        if (stockA < 20 && stockB >= 20) return -1;
        if (stockA >= 20 && stockB < 20) return 1;
        
        // Then by name
        return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      });

      setState(() {
        myProducts = filtered;
        isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void deleteProduct(int id, String productName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            const Text('Delete Product'),
          ],
        ),
        content: Text('Are you sure you want to delete "$productName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final success = await ApiService.deleteProduct(token, id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$productName deleted successfully'),
            backgroundColor: const Color(0xFFFF9800),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        fetchMyProducts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete product'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void goToEdit(Map<String, dynamic> product) {
    Navigator.pushNamed(context, '/editProduct', arguments: product).then((_) => fetchMyProducts());
  }

  void goToAddOffer(Map<String, dynamic> product) {
    print('🔍 ManageProducts - Navigating to AddOffer with product: $product');
    print('📸 Product image_url: ${product['image_url']}');
    
    Navigator.pushNamed(context, '/addOffer', arguments: {
      'productId': product['id'],
      'productName': product['name'],
      'originalPrice': double.tryParse(product['price']?.toString() ?? '0'),
      'productImage': product['image_url'],
    });
  }

  void goToAddProduct() {
    Navigator.pushNamed(context, '/addProduct').then((_) => fetchMyProducts());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final distributorColors = DistributorColors(isDark: isDark);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 72,
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B),
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            // Orange gradient badge like dashboard
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A50), Color(0xFFFF6E40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.20 : 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    locale?.isRTL == true ? 'إدارة المنتجات' : 'Manage Products',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18,
                      color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    locale?.isRTL == true ? 'إدارة المخزون' : 'Inventory Management',
                    style: GoogleFonts.inter(fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Search rounded action (black in light, white in dark)
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.20 : 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: locale?.isRTL == true ? 'بحث' : 'Search',
              icon: Icon(Icons.search, size: 18, color: isDark ? Colors.black : Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
              },
            ),
          ),
          // Add product rounded action
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(left: 8, right: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.20 : 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: locale?.isRTL == true ? 'إضافة منتج' : 'Add Product',
              icon: Icon(Icons.add_rounded, size: 18, color: isDark ? Colors.black : Colors.white),
              onPressed: goToAddProduct,
            ),
          ),
        ],
        systemOverlayStyle: isDark
            ? const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)
            : const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      ),
      body: Container(
        color: isDark ? Colors.black : Colors.white,
        child: Column(
          children: [
            // Top spacing to match dashboard
            const SizedBox(height: 24),
            // Search Bar with dashboard-style margins
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: locale?.isRTL == true ? 'بحث عن المنتجات...' : 'Search products...',
                    hintStyle: GoogleFonts.inter(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                      fontSize: 14,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Icon(
                        Icons.search,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: textColor, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => searchQuery = '');
                              fetchMyProducts();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onChanged: (value) {
                    setState(() => searchQuery = value);
                    fetchMyProducts();
                  },
                ),
              ),
            ),
            // Spacing after search
            const SizedBox(height: 24),
            // Products Grid with dashboard-style margins
            Expanded(
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: distributorColors.primary),
                          const SizedBox(height: 16),
                          Text('Loading...', style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                          )),
                        ],
                      ),
                    )
                  : myProducts.isEmpty
                      ? _buildEmptyState(isDark, locale, distributorColors)
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.66,
                            ),
                            itemCount: myProducts.length,
                            itemBuilder: (context, index) => _buildProductCard(myProducts[index], isDark, distributorColors),
                          ),
                        ),
            ),
            // Bottom spacing
            const SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          goToAddProduct();
        },
        backgroundColor: distributorColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          locale?.isRTL == true ? 'إضافة منتج' : 'Add Product',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations? locale, DistributorColors distributorColors) {
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📦', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty 
                ? (locale?.isRTL == true ? 'لا توجد منتجات' : 'No products found')
                : (locale?.isRTL == true ? 'لم تضف أي منتجات بعد' : 'No products yet'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              searchQuery.isNotEmpty 
                  ? (locale?.isRTL == true ? 'جرب تعديل البحث' : 'Try adjusting your search')
                  : (locale?.isRTL == true ? 'ابدأ بإضافة منتجك الأول' : 'Start by adding your first product'),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: subtextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              goToAddProduct();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: distributorColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 18),
                const SizedBox(width: 6),
                Text(
                  locale?.isRTL == true ? 'إضافة منتج' : 'Add Product',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isDark, DistributorColors distributorColors) {
    final locale = AppLocalizations.of(context);
    final stock = product['stock'] ?? 0;
    final isLowStock = stock < 20;
    final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    final cardBg = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image on top
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1.4,
                child: product['image_url'] != null && product['image_url'].toString().isNotEmpty
                    ? Builder(
                        builder: (context) {
                          String imageUrl = product['image_url'];
                          if (!imageUrl.startsWith('http')) {
                            imageUrl = '${ApiService.imageBaseUrl}$imageUrl';
                          }
                          return CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: distributorColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[100],
                              child: const Center(child: Text('📦', style: TextStyle(fontSize: 24))),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: Icon(Icons.inventory_2, color: Colors.grey, size: 28),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // Name
            Text(
              product['name'] ?? 'Unknown Product',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (product['brand'] != null && product['brand'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  product['brand'],
                  style: GoogleFonts.inter(fontSize: 11, color: subtextColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const Spacer(),
            // Price + stock
            Row(
              children: [
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF9800),
                  ),
                ),
                const SizedBox(width: 8),
                if (isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Low',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.inventory_2, size: 14, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text('$stock', style: GoogleFonts.inter(fontSize: 11, color: subtextColor)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Actions row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => goToEdit(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(locale?.isRTL == true ? 'تعديل' : 'Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => goToAddOffer(product),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF9800),
                      side: const BorderSide(color: Color(0xFFFF9800)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(locale?.isRTL == true ? 'عرض' : 'Offer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
