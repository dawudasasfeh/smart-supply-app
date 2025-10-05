import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/delivery_bottom_navigation.dart';
import 'OrderDetailsPage.dart';

class AssignedOrdersPage extends StatefulWidget {
  const AssignedOrdersPage({super.key});

  @override
  State<AssignedOrdersPage> createState() => _AssignedOrdersPageState();
}

class _AssignedOrdersPageState extends State<AssignedOrdersPage>
    with SingleTickerProviderStateMixin {
  // Data Management
  List<dynamic> assignedOrders = [];
  List<dynamic> filteredOrders = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  int? deliveryId;

  // Animation Controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Controllers
  late TextEditingController _searchController;

  // Filter Options
  final List<String> filterOptions = ['All', 'Active', 'Delivered'];

  @override
  void initState() {
    super.initState();
    _initializeComponents();
    _loadDeliveryData();
  }

  void _initializeComponents() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _filterOrders();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Data Loading Methods
  Future<void> _loadDeliveryData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDeliveryId = prefs.getInt('delivery_man_id');
    final storedUserId = prefs.getInt('user_id') ?? prefs.getInt('userId');
    final storedName = prefs.getString('username');
    final storedEmail = prefs.getString('user_email');

    deliveryId = cachedDeliveryId;

    if (deliveryId == null) {
      try {
        final deliveryMen = await ApiService.getAvailableDeliveryMen();
        Map<String, dynamic> match = {};

        if (storedEmail != null && storedEmail.isNotEmpty) {
          match = deliveryMen.firstWhere(
            (dm) => (dm['email'] ?? '').toString() == storedEmail,
            orElse: () => {},
          );
        }

        if (match.isEmpty && storedName != null && storedName.isNotEmpty) {
          match = deliveryMen.firstWhere(
            (dm) => (dm['name'] ?? '').toString() == storedName,
            orElse: () => {},
          );
        }

        if (match.isEmpty && storedUserId != null) {
          match = deliveryMen.firstWhere((dm) {
            final dmId = dm['id'];
            final dmUserId = dm['user_id'];
            return (dmId == storedUserId) || (dmUserId == storedUserId);
          }, orElse: () => {});
        }

        if (match.isNotEmpty && match.containsKey('id')) {
          final idVal = match['id'];
          if (idVal is int) {
            deliveryId = idVal;
            await prefs.setInt('delivery_man_id', deliveryId!);
          }
        }
      } catch (e) {
        print('Error resolving delivery_man_id: $e');
      }
    }

    if (deliveryId != null) {
      await _fetchAssignedOrders();
    }
  }

  Future<void> _fetchAssignedOrders() async {
    if (!mounted) return;
    
    setState(() => isLoading = true);
    
    try {
      if (deliveryId == null) return;
      
      final orders = await ApiService.getAssignedOrders(deliveryId!);
      
      if (mounted) {
        setState(() {
          assignedOrders = orders;
          filteredOrders = orders;
          isLoading = false;
        });
        
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading orders: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Filter and Search Methods
  void _filterOrders() {
    if (!mounted) return;
    
    setState(() {
      String query = _searchController.text.toLowerCase();
      
      List<dynamic> filtered = assignedOrders.where((order) {
        // Search filter
        bool matchesSearch = query.isEmpty ||
            order['id'].toString().contains(query) ||
            (order['customer_name'] ?? '').toString().toLowerCase().contains(query);
        
        // Status filter
        bool matchesStatus = true;
        if (selectedFilter != 'All') {
          final status = (order['status'] ?? order['delivery_status'] ?? '').toString().toLowerCase();
          if (selectedFilter == 'Active') {
            matchesStatus = status != 'delivered' && status != 'completed';
          } else if (selectedFilter == 'Delivered') {
            matchesStatus = status == 'delivered' || status == 'completed';
          }
        }
        
        return matchesSearch && matchesStatus;
      }).toList();
      
      filteredOrders = filtered;
    });
  }

  void _onFilterSelected(String filter) {
    setState(() {
      selectedFilter = filter;
    });
    _filterOrders();
  }

  // Status Helper Methods
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.info;
      case 'assigned':
        return AppColors.primary;
      case 'picked_up':
        return Colors.purple;
      case 'in_transit':
        return Colors.blue;
      case 'out_for_delivery':
        return Colors.indigo;
      case 'delivered':
        return AppColors.success;
      case 'completed':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_outlined;
      case 'accepted':
        return Icons.assignment_turned_in_outlined;
      case 'assigned':
        return Icons.assignment_outlined;
      case 'picked_up':
        return Icons.inventory_2_outlined;
      case 'in_transit':
        return Icons.local_shipping_outlined;
      case 'out_for_delivery':
        return Icons.delivery_dining_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.verified_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Assigned Orders',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            onPressed: () => Navigator.pushNamed(context, '/qrScanner'),
            tooltip: 'Scan QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _fetchAssignedOrders,
            tooltip: 'Refresh Orders',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
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
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search orders by ID or customer...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filterOptions.length,
                    itemBuilder: (context, index) {
                      final filter = filterOptions[index];
                      final isSelected = selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) => _onFilterSelected(filter),
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Orders List
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Loading assigned orders...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: RefreshIndicator(
                          onRefresh: _fetchAssignedOrders,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredOrders.length,
                            itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              return _buildOrderCard(order, index);
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const DeliveryBottomNavigation(
        currentRoute: '/assignedOrders',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedFilter == 'All' 
                ? 'No orders assigned yet'
                : 'No ${selectedFilter.toLowerCase()} orders found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchAssignedOrders,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final statusRaw = order['status'] ?? order['delivery_status'] ?? order['deliveryStatus'] ?? 'Unknown';
    final status = statusRaw.toString();
    final orderId = order['id']?.toString() ?? 'N/A';
    final createdAt = order['created_at']?.toString();
    final totalAmount = order['total_amount']?.toString() ?? '0';
    final supermarketName = order['supermarket_name']?.toString() ?? order['customer_name']?.toString() ?? order['buyer_name']?.toString() ?? 'Unknown Supermarket';
    final deliveryAddress = order['delivery_address']?.toString() ?? 'No address provided';
    
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
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () => _navigateToOrderDetails(order),
                child: Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.grey.shade50,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #$orderId',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Status Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(status).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStatusIcon(status),
                                    size: 16,
                                    color: _getStatusColor(status),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Customer Info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    supermarketName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      deliveryAddress,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Amount and Actions Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${double.tryParse(totalAmount)?.toStringAsFixed(2) ?? totalAmount}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Action Buttons
                            Row(
                              children: [
                                if (status.toLowerCase() != 'delivered' && status.toLowerCase() != 'completed')
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final result = await Navigator.pushNamed(context, '/qrScanner');
                                      if (result == true) {
                                        await _fetchAssignedOrders();
                                      }
                                    },
                                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                                    label: const Text('Scan QR'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      _showOrderDetails(order);
                                    },
                                    icon: const Icon(Icons.info_outline, size: 18),
                                    label: const Text('Details'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.success,
                                      side: const BorderSide(color: AppColors.success),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      },
    );
  }

  void _navigateToOrderDetails(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsPage(order: order),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? 'N/A';
    final status = order['status']?.toString() ?? 'Unknown';
    final totalAmount = order['total_amount']?.toString() ?? '0';
    final createdAt = order['created_at']?.toString();
    final deliveredAt = order['delivered_at']?.toString();
    final customerName = order['customer_name']?.toString() ?? 'Unknown Customer';
    final deliveryAddress = order['delivery_address']?.toString() ?? 'No address provided';
    
    String formattedCreatedDate = 'Unknown date';
    String formattedDeliveredDate = 'Not delivered';
    
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        formattedCreatedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
      } catch (e) {
        formattedCreatedDate = createdAt;
      }
    }
    
    if (deliveredAt != null) {
      try {
        final date = DateTime.parse(deliveredAt);
        formattedDeliveredDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
      } catch (e) {
        formattedDeliveredDate = deliveredAt;
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Order #$orderId Details',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Status', status.toUpperCase(), _getStatusColor(status)),
                const SizedBox(height: 12),
                _buildDetailRow('Customer', customerName, AppColors.textPrimary),
                const SizedBox(height: 12),
                _buildDetailRow('Total Amount', '\$${double.tryParse(totalAmount)?.toStringAsFixed(2) ?? totalAmount}', AppColors.primary),
                const SizedBox(height: 12),
                _buildDetailRow('Address', deliveryAddress, Colors.grey.shade700),
                const SizedBox(height: 12),
                _buildDetailRow('Order Date', formattedCreatedDate, Colors.grey.shade700),
                if (status.toLowerCase() == 'delivered' || status.toLowerCase() == 'completed') ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Delivered Date', formattedDeliveredDate, AppColors.success),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
