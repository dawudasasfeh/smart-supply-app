import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../../themes/role_theme_manager.dart';
import '../../constants/app_dimensions.dart';
import 'package:intl/intl.dart';
import 'SupermarketOrderDetailsPage.dart';
import '../../l10n/app_localizations.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  // Data
  List<dynamic> orders = [];
  List<dynamic> filteredOrders = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  
  
  // User Data
  String supermarketId = '';
  String supermarketName = '';
  Map<int, bool> orderRatingStatus = {};
  Set<int> dismissedRatingCards = {};
  
  // UI State
  bool _showFilters = false;

  final List<Map<String, dynamic>> filterOptions = [
    {'label': 'All', 'icon': Icons.apps_rounded},
    {'label': 'Pending', 'icon': Icons.access_time_rounded},
    {'label': 'Accepted', 'icon': Icons.local_shipping_rounded},
    {'label': 'Delivered', 'icon': Icons.check_circle_rounded},
  ];

  void initState() {
    super.initState();
    fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final userId = prefs.getInt('userId') ?? 0;
      final userEmail = prefs.getString('email') ?? '';
      final userRole = prefs.getString('role') ?? '';
      
      print('🔍 Fetching orders for user:');
      print('  - User ID: $userId');
      print('  - Email: $userEmail');
      print('  - Role: $userRole');
      print('  - Token available: ${token.isNotEmpty}');
      print('  - Token preview: ${token.isNotEmpty ? token.substring(0, 20) + "..." : "NO TOKEN"}');
      
      if (token.isEmpty) {
        print('❌ No token found, user might need to login again');
        return;
      }
      
      if (userId == 0) {
        print('❌ Invalid user ID, user might need to login again');
        return;
      }
      
      setState(() {
        isLoading = true;
        supermarketId = userId.toString();
        supermarketName = prefs.getString('name') ?? 'Supermarket';
      });

      print('🌐 Making API call to: getBuyerOrders($userId)');
      final result = await ApiService.getBuyerOrders(token, userId);
      print('📦 Orders fetched successfully: ${result.length} orders');
      
      if (result.isNotEmpty) {
        print('📋 Sample order: ${result[0]}');
      }
      
      if (mounted) {
        setState(() {
          orders = result;
          isLoading = false;
        });
        
        // Reapply the current filter after fetching new data
        _filterOrders(selectedFilter);
        
        // Animations are already started in initState
      }
    } catch (e) {
      print('❌ Error fetching orders: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: fetchOrders,
            ),
          ),
        );
      }
    }
  }

  void _searchOrders(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredOrders = orders;
      } else {
        filteredOrders = orders.where((order) {
          final orderId = order['id']?.toString().toLowerCase() ?? '';
          final status = order['status']?.toString().toLowerCase() ?? '';
          return orderId.contains(query.toLowerCase()) || 
                 status.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _filterOrders(String filter) {
    setState(() {
      selectedFilter = filter;
      if (filter == 'All') {
        filteredOrders = orders;
      } else {
        filteredOrders = orders.where((order) {
          final status = order['status']?.toString().toLowerCase() ?? '';
          return status == filter.toLowerCase();
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final supermarketColors = SupermarketColors(isDark: isDark);
    final locale = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(context, supermarketColors),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: _buildSearchAndFilterSection(context, isDark, supermarketColors),
            ),
          ),
          _buildSupermarketOrdersList(context, isDark, supermarketColors),
        ],
      ),
    );
  }

  // SUPERMARKET ROLE-SPECIFIC UI COMPONENTS
  // ============================================================================
  
  Widget _buildModernAppBar(BuildContext context, SupermarketColors colors) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final locale = AppLocalizations.of(context);
    
    return SliverAppBar(
      expandedHeight: AppDimensions.appBarExpandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                  ? [const Color(0xFF000000), const Color(0xFF000000)]
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
                      // Orders Icon
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
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Title and Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              locale?.isRTL == true ? 'طلباتي' : 'My Orders',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              locale?.isRTL == true ? 'تتبع مشترياتك' : 'Track your purchases',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: subtextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // Notification Button
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
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            // Navigate to notifications
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Refresh Button
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
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            fetchOrders();
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


  Widget _buildSearchAndFilterSection(BuildContext context, bool isDark, SupermarketColors colors) {
    final locale = AppLocalizations.of(context);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
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
                  onChanged: _searchOrders,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: locale?.isRTL == true 
                        ? 'ابحث عن الطلبات حسب الرقم أو الحالة...'
                        : 'Search orders by ID or status...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: subtextColor,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: subtextColor,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: subtextColor,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _searchOrders('');
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
          _buildFiltersSection(context, colors),
        ],
      ],
    );
  }

  Widget _buildFiltersSection(BuildContext context, SupermarketColors colors) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final locale = AppLocalizations.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
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
          Text(
            locale?.isRTL == true ? 'تصفية الطلبات' : 'Filter Orders',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filterOptions.map((filter) {
              final isSelected = selectedFilter == filter['label'];
              return GestureDetector(
                onTap: () => _filterOrders(filter['label']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF3B82F6)
                        : (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFF3B82F6)
                          : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0)),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter['icon'],
                        size: 16,
                        color: isSelected 
                            ? Colors.white
                            : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getLocalizedFilterLabel(filter['label'], locale),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected 
                              ? Colors.white
                              : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  Widget _buildSupermarketOrdersList(BuildContext context, bool isDark, SupermarketColors colors) {
    if (isLoading) {
      return SliverFillRemaining(
        child: _buildLoadingState(context, isDark, colors),
      );
    }

    if (filteredOrders.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(context, isDark, colors),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildOrderCard(context, filteredOrders[index], index, isDark, colors);
          },
          childCount: filteredOrders.length,
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, bool isDark, SupermarketColors colors) {
    final locale = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  colors.primary.withOpacity(0.9),
                  colors.primary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            locale?.translate('loading_orders') ?? 'Loading your orders...',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, SupermarketColors colors) {
    final locale = AppLocalizations.of(context);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1F1F1F), const Color(0xFF0A0A0A)]
                      : [
                          colors.primary.withOpacity(0.1),
                          colors.primary.withOpacity(0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A2A2A) : colors.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                selectedFilter == 'All' 
                    ? Icons.shopping_bag_outlined
                    : Icons.filter_list_off_rounded,
                size: 48,
                color: colors.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              selectedFilter == 'All' 
                  ? (locale?.translate('no_orders_yet') ?? 'No orders yet') 
                  : 'No ${selectedFilter.toLowerCase()} orders',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              selectedFilter == 'All' 
                  ? (locale?.translate('start_shopping_message') ?? 'Your orders will appear here when you place them.\nStart shopping to see your order history!')
                  : (locale?.translate('try_different_filter') ?? 'Try selecting a different filter or refresh to see more orders.'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: subtextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selectedFilter != 'All') ...[
                  OutlinedButton.icon(
                    onPressed: () => _filterOrders('All'),
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: Text(
                      'Clear Filter',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                ElevatedButton.icon(
                  onPressed: fetchOrders,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    'Refresh',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order, int index, bool isDark, SupermarketColors colors) {
    final status = order['status']?.toString() ?? 'Unknown';
    final orderId = order['id']?.toString() ?? 'N/A';
    final createdAt = order['created_at']?.toString();
    final totalAmount = order['total_amount']?.toString() ?? '0';
    final locale = AppLocalizations.of(context);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    String formattedDate = 'Unknown date';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
      } catch (e) {
        formattedDate = createdAt;
      }
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor(status).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showOrderDetails(order);
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getStatusColor(status),
                                  _getStatusColor(status).withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatusColor(status).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              _getStatusIcon(status),
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
                                  '${locale?.translate('order') ?? 'Order'} #$orderId',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: subtextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getStatusColor(status).withOpacity(0.3),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              _getLocalizedStatus(status, locale),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(status),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Amount Section
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    locale?.translate('total_amount') ?? 'Total Amount',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: subtextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '\$${(double.tryParse(totalAmount) ?? 0.0).toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showQRCode(order),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.qr_code_rounded,
                                  color: colors.primary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showOrderDetails(order),
                              icon: const Icon(Icons.visibility_outlined, size: 16),
                              label: Text(
                                locale?.translate('view_details') ?? 'View Details',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
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
      },
    );
  }


  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'accepted': return const Color(0xFF3B82F6);
      case 'delivered': return const Color(0xFF10B981);
      default: return const Color(0xFF64748B);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Icons.schedule_rounded;
      case 'accepted': return Icons.local_shipping_rounded;
      case 'delivered': return Icons.check_circle_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  String _getLocalizedStatus(String status, AppLocalizations? locale) {
    final isArabic = locale?.isRTL == true;
    switch (status.toLowerCase()) {
      case 'pending':
        return isArabic ? 'قيد الانتظار' : 'PENDING';
      case 'accepted':
        return isArabic ? 'مقبول' : 'ACCEPTED';
      case 'delivered':
        return isArabic ? 'تم التوصيل' : 'DELIVERED';
      default:
        return status.toUpperCase();
    }
  }

  String _getLocalizedFilterLabel(String label, AppLocalizations? locale) {
    final isArabic = locale?.isRTL == true;
    switch (label.toLowerCase()) {
      case 'all':
        return isArabic ? 'الكل' : 'All';
      case 'pending':
        return isArabic ? 'قيد الانتظار' : 'Pending';
      case 'accepted':
        return isArabic ? 'مقبول' : 'Accepted';
      case 'delivered':
        return isArabic ? 'تم التوصيل' : 'Delivered';
      default:
        return label;
    }
  }

  void _showQRCode(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? 'N/A';
    final deliveryCode = order['delivery_code']?.toString() ?? '';
    final trackingNumber = order['tracking_number']?.toString() ?? '';
    final status = order['status']?.toString() ?? 'Unknown';
    final totalAmount = order['total_amount']?.toString() ?? '0';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    // Create QR code data with order information
    final qrData = {
      'order_id': orderId,
      'delivery_code': deliveryCode,
      'tracking_number': trackingNumber,
      'status': status,
      'total_amount': totalAmount,
    };
    
    final qrString = qrData.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value.clamp(0.0, 1.0)),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF0A0A0A),
                                  const Color(0xFF000000),
                                ]
                              : [
                                  const Color(0xFFF8FAFC),
                                  const Color(0xFFE2E8F0),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                        border: Border.all(
                          color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          // Header Section
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                            child: Row(
                              children: [
                                // Animated QR Icon
                                TweenAnimationBuilder<double>(
                                  duration: Duration(milliseconds: 800 + (200)),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  curve: Curves.elasticOut,
                                  builder: (context, iconValue, child) {
                                    return Transform.scale(
                                      scale: iconValue,
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF3B82F6),
                                              Color(0xFF1D4ED8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.qr_code_2_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        locale?.isRTL == true ? 'رمز QR للطلب' : 'Order QR Code',
                                        style: GoogleFonts.inter(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        locale?.isRTL == true ? 'امسح للتتبع الفوري' : 'Scan for instant tracking',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: subtextColor,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Close Button
                                TweenAnimationBuilder<double>(
                                  duration: Duration(milliseconds: 600 + (300)),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  curve: Curves.easeOutBack,
                                  builder: (context, closeValue, child) {
                                    return Transform.scale(
                                      scale: closeValue,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
                                            width: 1,
                                          ),
                                        ),
                                        child: IconButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          icon: Icon(
                                            Icons.close_rounded,
                                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF64748B),
                                            size: 20,
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          constraints: const BoxConstraints(
                                            minWidth: 36,
                                            minHeight: 36,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // QR Code Section
                          TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 800 + (400)),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOutCubic,
                            builder: (context, qrValue, child) {
                              return Transform.scale(
                                scale: 0.9 + (0.1 * qrValue.clamp(0.0, 1.0)),
                                child: Opacity(
                                  opacity: qrValue.clamp(0.0, 1.0),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 24),
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF000000) : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
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
                                    child: Column(
                                      children: [
                                        // QR Code with animated border
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
                                              width: 2,
                                            ),
                                          ),
                                          child: QrImageView(
                                            data: qrString,
                                            version: QrVersions.auto,
                                            size: 180.0,
                                            backgroundColor: Colors.white,
                                            foregroundColor: const Color(0xFF000000),
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 20),
                                        
                                        // Order Info Cards
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      locale?.isRTL == true ? 'الطلب' : 'ORDER',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: subtextColor,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '#$orderId',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        color: textColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      locale?.isRTL == true ? 'المبلغ' : 'AMOUNT',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: subtextColor,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '\$${(double.tryParse(totalAmount) ?? 0.0).toStringAsFixed(2)}',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        color: textColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Footer Section
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Column(
                              children: [
                                // Instructions
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.info_outline_rounded,
                                          color: Color(0xFF3B82F6),
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          locale?.isRTL == true ? 'قدم رمز QR هذا للتحقق من الطلب والتتبع' : 'Present this QR code for order verification and tracking',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? subtextColor : const Color(0xFF64748B),
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: TweenAnimationBuilder<double>(
                                        duration: Duration(milliseconds: 800 + (500)),
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        curve: Curves.easeOutBack,
                                        builder: (context, buttonValue, child) {
                                          return Transform.translate(
                                            offset: Offset(0, 20 * (1 - buttonValue)),
                                            child: Opacity(
                                              opacity: buttonValue.clamp(0.0, 1.0),
                                              child: ElevatedButton(
                                                onPressed: () => Navigator.of(context).pop(),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF3B82F6),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  shadowColor: const Color(0xFF3B82F6).withOpacity(0.3),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.check_rounded,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Done',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
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
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _checkOrderRatingStatus(int orderId, int distributorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final hasRated = await ApiService.checkOrderRating(token, distributorId, orderId);
      setState(() {
        orderRatingStatus[orderId] = hasRated;
      });
    } catch (e) {
      print('Error checking rating status: $e');
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final orderId = order['id'] as int;
    final distributorId = order['distributor_id'] as int? ?? 0;
    final orderStatus = order['status']?.toString().toLowerCase() ?? '';
    
    if (orderStatus == 'delivered' && distributorId > 0) {
      _checkOrderRatingStatus(orderId, distributorId);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupermarketOrderDetailsPage(
          order: order,
          isRated: orderRatingStatus[orderId] ?? false,
          isDismissed: dismissedRatingCards.contains(orderId),
          onRatingSubmitted: (orderIdInt) {
            setState(() {
              orderRatingStatus[orderIdInt] = true;
            });
          },
          onRatingDismissed: (orderIdInt) {
            setState(() {
              dismissedRatingCards.add(orderIdInt);
            });
          },
        ),
      ),
    );
  }
}
