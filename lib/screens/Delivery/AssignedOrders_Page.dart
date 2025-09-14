import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';

class AssignedOrdersPage extends StatefulWidget {
  const AssignedOrdersPage({super.key});

  @override
  State<AssignedOrdersPage> createState() => _AssignedOrdersPageState();
}

class _AssignedOrdersPageState extends State<AssignedOrdersPage> with TickerProviderStateMixin {
  List<dynamic> assignedOrders = [];
  List<dynamic> filteredOrders = [];
  int? deliveryId;
  bool isLoading = true;
  String selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> filterOptions = ['All', 'Assigned', 'Delivered'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    loadDeliveryIdAndFetch();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadDeliveryIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    deliveryId = prefs.getInt('user_id');
    if (deliveryId != null) {
      fetchAssignedOrders();
    }
  }

  Future<void> fetchAssignedOrders() async {
    setState(() => isLoading = true);
    try {
      if (deliveryId == null) return;
      final orders = await ApiService.getAssignedOrders(deliveryId!);
      setState(() {
        assignedOrders = orders; // Include all orders (assigned and delivered)
        filteredOrders = orders;
        isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterOrders(String filter) {
    setState(() {
      selectedFilter = filter;
      if (filter == 'All') {
        filteredOrders = assignedOrders;
      } else if (filter == 'Assigned') {
        filteredOrders = assignedOrders.where((order) => 
          order['status'].toString().toLowerCase() != 'delivered'
        ).toList();
      } else if (filter == 'Delivered') {
        filteredOrders = assignedOrders.where((order) => 
          order['status'].toString().toLowerCase() == 'delivered'
        ).toList();
      } else {
        filteredOrders = assignedOrders.where((order) => 
          order['status'].toString().toLowerCase().contains(filter.toLowerCase())
        ).toList();
      }
    });
  }

  void _searchOrders(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredOrders = selectedFilter == 'All' ? assignedOrders : 
          assignedOrders.where((order) => 
            order['status'].toString().toLowerCase().contains(selectedFilter.toLowerCase())
          ).toList();
      } else {
        filteredOrders = assignedOrders.where((order) {
          final matchesSearch = order['id'].toString().contains(query) ||
                               order['status'].toString().toLowerCase().contains(query.toLowerCase());
          final matchesFilter = selectedFilter == 'All' || 
                               order['status'].toString().toLowerCase().contains(selectedFilter.toLowerCase());
          return matchesSearch && matchesFilter;
        }).toList();
      }
    });
  }

  Future<void> markDelivered(int orderId) async {
    if (deliveryId == null) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: Text('Mark Order #$orderId as delivered?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.updateDeliveryStatus(
        orderId: orderId,
        deliveryId: deliveryId!,
        status: 'delivered',
      );
      if (success) {
        fetchAssignedOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order marked as delivered successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update order status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'delivered':
        return Icons.check_circle;
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
          'Orders',
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
            onPressed: fetchAssignedOrders,
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
                    onChanged: _searchOrders,
                    decoration: const InputDecoration(
                      hintText: 'Search orders by ID or status...',
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
                          onSelected: (_) => _filterOrders(filter),
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
                          onRefresh: fetchAssignedOrders,
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
            'No orders assigned yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here when assigned to you',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: fetchAssignedOrders,
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
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action Button (QR Scanner for assigned, Details for delivered)
                  if (status.toLowerCase() != 'delivered')
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.qr_code_scanner,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/qrScanner');
                        },
                        tooltip: 'Scan QR Code',
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.green,
                          size: 24,
                        ),
                        onPressed: () {
                          _showOrderDetails(order);
                        },
                        tooltip: 'View Details',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Status and Amount Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  // Amount
                  Text(
                    '\$${double.tryParse(totalAmount)?.toStringAsFixed(2) ?? totalAmount}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action Buttons
              Row(
                children: [
                  if (status.toLowerCase() != 'delivered')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/qrScanner');
                        },
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scan QR'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showOrderDetails(order);
                        },
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('View Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
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
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? 'N/A';
    final status = order['status']?.toString() ?? 'Unknown';
    final totalAmount = order['total_amount']?.toString() ?? '0';
    final createdAt = order['created_at']?.toString();
    final deliveredAt = order['delivered_at']?.toString();
    final deliveryCode = order['delivery_code']?.toString() ?? 'N/A';
    
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
          title: Text('Order #$orderId Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Status', status.toUpperCase(), _getStatusColor(status)),
                const SizedBox(height: 12),
                _buildDetailRow('Total Amount', '\$${double.tryParse(totalAmount)?.toStringAsFixed(2) ?? totalAmount}', AppColors.primary),
                const SizedBox(height: 12),
                _buildDetailRow('Delivery Code', deliveryCode, Colors.grey.shade700),
                const SizedBox(height: 12),
                _buildDetailRow('Order Date', formattedCreatedDate, Colors.grey.shade700),
                if (status.toLowerCase() == 'delivered') ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Delivered Date', formattedDeliveredDate, Colors.green),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
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
