import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'SupermarketOrderDetailsPage.dart';

class OrdersPageNew extends StatefulWidget {
  const OrdersPageNew({super.key});

  @override
  State<OrdersPageNew> createState() => _OrdersPageNewState();
}

class _OrdersPageNewState extends State<OrdersPageNew> with TickerProviderStateMixin {
  List<dynamic> orders = [];
  List<dynamic> filteredOrders = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fabAnimation;
  String supermarketId = '';
  String supermarketName = '';
  Map<int, bool> orderRatingStatus = {};
  Set<int> dismissedRatingCards = {};
  bool _showFilters = false;

  final List<Map<String, dynamic>> filterOptions = [
    {'label': 'All', 'icon': Icons.list_alt, 'color': Colors.grey},
    {'label': 'Pending', 'icon': Icons.schedule, 'color': Colors.orange},
    {'label': 'Accepted', 'icon': Icons.check_circle_outline, 'color': Colors.blue},
    {'label': 'Delivered', 'icon': Icons.check_circle, 'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );
    
    fetchOrders();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchOrders() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final buyerId = prefs.getInt('user_id');
      
      supermarketId = prefs.getInt('user_id')?.toString() ?? '1';
      supermarketName = prefs.getString('name') ?? 'SuperMarket';
      
      if (buyerId != null) {
        final result = await ApiService.getBuyerOrders(token, buyerId);
        
        setState(() {
          orders = result;
          filteredOrders = result;
          isLoading = false;
        });
        
        _animationController.forward();
        _fabAnimationController.forward();
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        _showErrorSnackBar('Error loading orders: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _filterOrders(String filter) {
    HapticFeedback.lightImpact();
    setState(() {
      selectedFilter = filter;
      if (filter == 'All') {
        filteredOrders = orders;
      } else {
        filteredOrders = orders.where((order) => 
          order['status'].toString().toLowerCase() == filter.toLowerCase()
        ).toList();
      }
    });
  }

  void _searchOrders(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredOrders = selectedFilter == 'All' ? orders : 
          orders.where((order) => 
            order['status'].toString().toLowerCase() == selectedFilter.toLowerCase()
          ).toList();
      } else {
        filteredOrders = orders.where((order) {
          final matchesSearch = order['id'].toString().contains(query) ||
                               order['status'].toString().toLowerCase().contains(query.toLowerCase());
          final matchesFilter = selectedFilter == 'All' || 
                               order['status'].toString().toLowerCase() == selectedFilter.toLowerCase();
          return matchesSearch && matchesFilter;
        }).toList();
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'delivered': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Icons.schedule;
      case 'accepted': return Icons.local_shipping;
      case 'delivered': return Icons.check_circle;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildSearchAndFilters(),
          _buildOrdersList(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue[50]!,
                Colors.teal[50]!,
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            fetchOrders();
          },
          tooltip: 'Refresh Orders',
        ),
        IconButton(
          icon: AnimatedRotation(
            turns: _showFilters ? 0.5 : 0,
            duration: const Duration(milliseconds: 300),
            child: const Icon(Icons.tune_rounded),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() => _showFilters = !_showFilters);
          },
          tooltip: 'Toggle Filters',
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return SliverToBoxAdapter(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildSearchBar(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showFilters ? 60 : 0,
              child: _showFilters ? _buildFilterChips() : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[100]!, Colors.grey[50]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _searchOrders,
        decoration: InputDecoration(
          hintText: 'Search orders by ID or status...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey[600]),
                  onPressed: () {
                    _searchController.clear();
                    _searchOrders('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: filterOptions.length,
          itemBuilder: (context, index) {
            final filter = filterOptions[index];
            final isSelected = selectedFilter == filter['label'];
            
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 100)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: FilterChip(
                      avatar: Icon(
                        filter['icon'],
                        size: 18,
                        color: isSelected ? Colors.white : filter['color'],
                      ),
                      label: Text(
                        filter['label'],
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) => _filterOrders(filter['label']),
                      backgroundColor: Colors.grey[100],
                      selectedColor: filter['color'],
                      checkmarkColor: Colors.white,
                      elevation: isSelected ? 4 : 0,
                      shadowColor: filter['color'].withOpacity(0.3),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    if (isLoading) {
      return SliverFillRemaining(
        child: _buildLoadingState(),
      );
    }

    if (filteredOrders.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 600 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - value) * 50),
                  child: Opacity(
                    opacity: value,
                    child: _buildEnhancedOrderCard(filteredOrders[index], index),
                  ),
                );
              },
            );
          },
          childCount: filteredOrders.length,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (value * 0.2),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your orders...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.teal[50]!],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            selectedFilter == 'All' ? 'No orders yet' : 'No $selectedFilter orders',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedFilter == 'All' 
                ? 'Start shopping to see your orders here'
                : 'Try selecting a different filter',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: fetchOrders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedOrderCard(Map<String, dynamic> order, int index) {
    final status = order['status']?.toString() ?? 'Unknown';
    final orderId = order['id']?.toString() ?? 'N/A';
    final createdAt = order['created_at']?.toString();
    final totalAmount = order['total_amount']?.toString() ?? '0';
    
    String formattedDate = 'Unknown date';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
      } catch (e) {
        formattedDate = createdAt;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 4,
        shadowColor: _getStatusColor(status).withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            _showOrderDetails(order);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  _getStatusColor(status).withOpacity(0.02),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderHeader(orderId, formattedDate, status, order),
                  const SizedBox(height: 16),
                  _buildOrderStatus(status, totalAmount),
                  const SizedBox(height: 16),
                  _buildOrderActions(order),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader(String orderId, String formattedDate, String status, Map<String, dynamic> order) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getStatusColor(status).withOpacity(0.1),
                _getStatusColor(status).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #$orderId',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (status.toLowerCase() != 'delivered')
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.1), Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.qr_code_2_rounded),
              color: AppColors.primary,
              onPressed: () {
                HapticFeedback.lightImpact();
                _showQRCodeDialog(order);
              },
              tooltip: 'View QR Code',
            ),
          ),
      ],
    );
  }

  Widget _buildOrderStatus(String status, String totalAmount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getStatusColor(status).withOpacity(0.15),
                _getStatusColor(status).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: _getStatusColor(status).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[50]!, Colors.green[25]!],
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            '\$${double.tryParse(totalAmount)?.toStringAsFixed(2) ?? totalAmount}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderActions(Map<String, dynamic> order) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showOrderDetails(order),
            icon: const Icon(Icons.visibility_rounded, size: 18),
            label: const Text('View Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          fetchOrders();
        },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  String _generateQRData(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '0';
    final deliveryCode = 'DEL${orderId.padLeft(3, '0')}';
    
    final qrContent = {
      'type': 'delivery_verification',
      'supermarket_id': supermarketId,
      'supermarket_name': supermarketName,
      'order_id': int.tryParse(orderId) ?? 0,
      'delivery_code': deliveryCode,
      'verification_key': deliveryCode,
    };
    
    return jsonEncode(qrContent);
  }

  void _showQRCodeDialog(Map<String, dynamic> order) {
    final deliveryCode = (order['delivery_code'] ?? 'DEL${(order['id'] ?? 0).toString()}').toString();
    final qrData = _generateQRData(order);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.blue[50]!],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary.withOpacity(0.1), Colors.transparent],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery QR Code',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Order #${(order['id'] ?? 0).toString()}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.blue[25]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Delivery Code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deliveryCode,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Show this QR code to the delivery person to verify your order delivery.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
