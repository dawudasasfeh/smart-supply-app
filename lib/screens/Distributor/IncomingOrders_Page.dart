import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/notification_service.dart';
import '../../themes/role_theme_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/loading_widget.dart';

class IncomingOrdersPage extends StatefulWidget {
  const IncomingOrdersPage({super.key});

  @override
  State<IncomingOrdersPage> createState() => _IncomingOrdersPageState();
}

class _IncomingOrdersPageState extends State<IncomingOrdersPage> with TickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pendingOrders = [];
  List<dynamic> _processingOrders = [];
  List<dynamic> _completedOrders = [];
  List<dynamic> _cancelledOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? token;
  int? userId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Stats (commented out as they're not currently used)
  // int _totalOrders = 0;
  // int _pendingCount = 0;
  // int _processingCount = 0;
  // int _completedCount = 0;
  // double _totalRevenue = 0.0;
  
  // Socket.IO
  final SocketService _socketService = SocketService.instance;
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<Map<String, dynamic>>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _orderSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
      userId = prefs.getInt('user_id');
      
      if (token != null && userId != null) {
        await _initializeSocketConnection();
        await _loadOrders();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadOrders() async {
    if (token == null || userId == null) return;
    
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('🔄 Loading orders for distributor ID: $userId');
      final orders = await ApiService.getDistributorOrders(token!, userId!);
      print('📦 Received ${orders.length} orders');
      print('📋 Orders data: $orders');
      
      if (!mounted) return;
      _categorizeOrders(orders);
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load orders. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _categorizeOrders(List<dynamic> orders) {
    print('🔄 Categorizing ${orders.length} orders');
    
    setState(() {
      List<dynamic> pending = [];
      List<dynamic> processing = [];
      List<dynamic> completed = [];
      List<dynamic> cancelled = [];

      for (final dynamic rawOrder in orders) {
        try {
          final Map<String, dynamic> order = Map<String, dynamic>.from(rawOrder as Map);
          final String status = (order['status']?.toString() ?? '').toLowerCase().trim();

          // Order Lifecycle: Order Created (pending) → Accepted → Delivered
          if (status == 'pending' || status == 'new' || status == 'awaiting' || status == 'awaiting_confirmation') {
            pending.add(order);
          } else if (status == 'accepted' || status == 'processing' || status == 'packed' || status == 'shipped' || status == 'out_for_delivery' || status == 'assigned') {
            processing.add(order);
          } else if (status == 'completed' || status == 'delivered') {
            completed.add(order);
          } else if (status == 'cancelled' || status == 'canceled' || status == 'rejected' || status == 'failed') {
            cancelled.add(order);
          } else {
            processing.add(order);
          }
        } catch (_) {
          // If structure unexpected, still show the order under processing
          processing.add(rawOrder);
        }
      }

      _pendingOrders = pending;
      _processingOrders = processing;
      _completedOrders = completed;
      _cancelledOrders = cancelled;
    });
    
    print('📊 Categorized orders:');
    print('   Pending: ${_pendingOrders.length}');
    print('   Processing: ${_processingOrders.length}');
    print('   Completed: ${_completedOrders.length}');
    print('   Cancelled: ${_cancelledOrders.length}');
  }
  
  // Commented out as these stats aren't currently used
  // void _calculateStats() {
  //   _totalOrders = _pendingOrders.length + _processingOrders.length + _completedOrders.length + _cancelledOrders.length;
  //   _pendingCount = _pendingOrders.length;
  //   _processingCount = _processingOrders.length;
  //   _completedCount = _completedOrders.length;
    
  //   _totalRevenue = _completedOrders.fold(0.0, (sum, order) {
  //     return sum + (double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0);
  //   });
  // }
  
  Future<void> _initializeSocketConnection() async {
    try {
      await _socketService.connect();
      
      _orderSubscription = _socketService.orderStream.listen((event) {
        if (event['type'] == 'new_order' || event['type'] == 'order_updated') {
          _loadOrders(); // Refresh orders when there's an update
          
          // Show notification for new orders
          if (event['type'] == 'new_order' && mounted) {
            final order = event['data'];
            _notificationService.showOrderStatusNotification(
              orderId: order['id'].toString(),
              status: 'New Order',
              message: 'New order #${order['id']} received',
            );
          }
        }
      });
    } catch (e) {
      print('Error initializing socket: $e');
    }
  }
  
  Future<void> _updateOrderStatus(String orderId, String status) async {
    if (token == null) return;
    
    try {
      final success = await ApiService.updateOrderStatus(token!, int.parse(orderId), status);
      if (success) {
        await _loadOrders(); // Refresh orders after status update
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order status updated to $status')),
          );
        }
      } else {
        throw Exception('Failed to update order status');
      }
    } catch (e) {
      print('Error updating order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update order status')),
        );
      }
    }
  }
  
  Future<void> _showOrderDetails(Map<String, dynamic> order) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => _buildOrderDetailsSheet(order, controller),
      ),
    );
  }

  Widget _buildOrderDetailsSheet(Map<String, dynamic> order, ScrollController controller) {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    final orderDate = order['created_at'] != null 
        ? DateTime.parse(order['created_at'])
        : DateTime.now();
    
    final items = order['items'] as List<dynamic>? ?? [];
    final totalAmount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Order header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order['id']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStatusChip(order['status']),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Order info
          Text(
            'Placed on ${dateFormat.format(orderDate)}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Customer info
          _buildDetailRow('Customer', order['buyer']?['name'] ?? 'N/A'),
          _buildDetailRow('Email', order['buyer']?['email'] ?? 'N/A'),
          _buildDetailRow('Phone', order['shipping_address']?['phone'] ?? 'N/A'),
          
          const SizedBox(height: 16),
          
          // Shipping address
          const Text(
            'Shipping Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (order['shipping_address'] != null)
            Text(
              '${order['shipping_address']['street'] ?? ''}\n'
              '${order['shipping_address']['city'] ?? ''}, ${order['shipping_address']['state'] ?? ''} ${order['shipping_address']['postal_code'] ?? ''}\n'
              '${order['shipping_address']['country'] ?? ''}',
              style: const TextStyle(fontSize: 14),
            ),
          
          const SizedBox(height: 16),
          
          // Order items
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final product = item['product'] ?? {};
                final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: product['image'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product['image'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                        ),
                  title: Text(
                    product['name'] ?? 'Product',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('Qty: $quantity'),
                  trailing: Text(
                    '\$${(price * quantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          
          // Order summary
          const Divider(height: 24),
          _buildSummaryRow('Subtotal', '\$${totalAmount.toStringAsFixed(2)}'),
          _buildSummaryRow('Shipping', '\$0.00'),
          _buildSummaryRow(
            'Tax',
            '\$${(totalAmount * 0.1).toStringAsFixed(2)}',
          ),
          const Divider(height: 24),
          _buildSummaryRow(
            'Total',
            '\$${(totalAmount * 1.1).toStringAsFixed(2)}',
            isTotal: true,
          ),
          
          // Action buttons
          const SizedBox(height: 16),
          if (order['status'] == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Accept Order'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _updateOrderStatus(order['id'].toString(), 'processing');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showRejectDialog(order['id'].toString());
                    },
                  ),
                ),
              ],
            )
          else if (order['status'] == 'processing' || order['status'] == 'shipped')
            ElevatedButton.icon(
              icon: const Icon(Icons.local_shipping, size: 18),
              label: Text(
                order['status'] == 'processing' 
                    ? 'Mark as Shipped' 
                    : 'Mark as Delivered',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.pop(context);
                _updateOrderStatus(
                  order['id'].toString(),
                  order['status'] == 'processing' ? 'shipped' : 'completed',
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal 
                ? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                : null,
          ),
          Text(
            value,
            style: isTotal 
                ? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignDeliveryDialog(String orderId) async {
    if (token == null) return;
    
    try {
      // Fetch available delivery men
      final deliveryMen = await ApiService.getAvailableDeliveryMen();
      
      if (deliveryMen.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No available delivery men found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final selectedDeliveryMan = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assign Delivery Man'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: deliveryMen.length,
              itemBuilder: (context, index) {
                final deliveryMan = deliveryMen[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFF9800).withOpacity(0.1),
                    child: Text(
                      (deliveryMan['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: const Color(0xFFFF9800)),
                    ),
                  ),
                  title: Text(deliveryMan['name'] ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Phone: ${(deliveryMan['phone'] ?? 'N/A').toString()}'),
                      Text('Rating: ${(deliveryMan['rating'] ?? 0.0).toString()}★'),
                      Text('Capacity: ${(deliveryMan['current_orders'] ?? 0).toString()}/${(deliveryMan['max_capacity'] ?? 5).toString()}'),
                    ],
                  ),
                  onTap: () => Navigator.pop(context, deliveryMan),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      
      if (selectedDeliveryMan != null) {
        // Assign the order to the selected delivery man
        final success = await ApiService.assignDeliveryToMan(
          int.parse(orderId),
          selectedDeliveryMan['id'],
        );
        
        if (success) {
          // Update order status to assigned
          await _updateOrderStatus(orderId, 'assigned');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Order assigned to ${(selectedDeliveryMan['name'] ?? 'Unknown').toString()}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to assign delivery'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error assigning delivery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(String orderId) async {
    final reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejecting this order:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _updateOrderStatus(orderId, 'rejected');
      
      // In a real app, you might want to notify the buyer about the rejection
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order has been rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusChip(String status) {
    final lower = status.toLowerCase();
    Color color;
    String label;
    switch (lower) {
      case 'pending':
      case 'new':
      case 'awaiting':
      case 'awaiting_confirmation':
        color = Colors.orange;
        label = 'PENDING';
        break;
      case 'processing':
      case 'accepted':
      case 'packed':
      case 'shipped':
      case 'out_for_delivery':
        color = Colors.blue;
        label = lower.toUpperCase();
        break;
      case 'completed':
      case 'delivered':
        color = Colors.green;
        label = lower == 'delivered' ? 'DELIVERED' : 'COMPLETED';
        break;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'failed':
        color = Colors.red;
        label = lower == 'rejected' ? 'REJECTED' : 'CANCELLED';
        break;
      default:
        color = Colors.grey;
        label = lower.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildOrderList(List<dynamic> orders, String status) {
    final filtered = _filterOrdersByQuery(orders);

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: filtered.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 48),
                Icon(
                  Icons.receipt_long_outlined,
                  size: 72,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'No $status orders yet' : 'No results match your search',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final order = filtered[index];
                return _buildOrderCard(order, status);
              },
            ),
    );
  }

  List<dynamic> _filterOrdersByQuery(List<dynamic> orders) {
    if (_searchQuery.trim().isEmpty) return orders;
    final q = _searchQuery.toLowerCase();
    return orders.where((o) {
      final id = o['id']?.toString() ?? '';
      final status = (o['status']?.toString() ?? '').toLowerCase();
      final buyer = (o['buyer']?['name']?.toString() ?? '').toLowerCase();
      return id.contains(q) || status.contains(q) || buyer.contains(q);
    }).toList();
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String status) {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    final orderDate = order['created_at'] != null 
        ? DateTime.parse(order['created_at'])
        : DateTime.now();
    
    // Safe data extraction with fallbacks
    final orderId = order['id']?.toString() ?? 'Unknown';
    final buyerName = order['buyer']?['name'] ?? 'Unknown Customer';
    final items = order['items'] as List<dynamic>? ?? [];
    final totalAmount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          // Navigate to order details
          _showOrderDetails(order);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F1E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$orderId',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 8),
              
              // Order Info
              Text(
                'Date: ${dateFormat.format(orderDate)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              
              // Customer Info
              Text(
                'Customer: $buyerName',
                style: const TextStyle(fontSize: 14),
              ),
              
              const SizedBox(height: 8),
              
              // Order Summary
              if (items.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${items.length} ${items.length == 1 ? 'item' : 'items'}:',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    ...items.take(2).map<Widget>((item) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 2),
                      child: Text(
                        '• ${item['quantity']}x ${item['product']?['name'] ?? 'Product'}',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    if (items.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 2),
                        child: Text(
                          '+ ${items.length - 2} more items',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              
              const SizedBox(height: 8),
              
              // Order Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '\$${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                ],
              ),
              
              // Action Buttons
              if (status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Accept'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _updateOrderStatus(orderId, 'processing'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.local_shipping, size: 18),
                          label: const Text('Assign'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF9800),
                            side: const BorderSide(color: const Color(0xFFFF9800)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _showAssignDeliveryDialog(orderId),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _showRejectDialog(orderId),
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (status == 'processing')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.local_shipping, size: 18),
                          label: const Text('Mark as Shipped'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9800),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _updateOrderStatus(orderId, 'shipped'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: LoadingWidget(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Incoming Orders')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadOrders,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text('Incoming Orders'),
        actions: [
          IconButton(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              _buildSummaryHeader(),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: const Color(0xFFFF9800),
                tabs: [
                  Tab(text: 'Pending (${_pendingOrders.length})'),
                  Tab(text: 'Processing (${_processingOrders.length})'),
                  Tab(text: 'Completed (${_completedOrders.length})'),
                  Tab(text: 'Cancelled (${_cancelledOrders.length})'),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(_pendingOrders, 'pending'),
                _buildOrderList(_processingOrders, 'processing'),
                _buildOrderList(_completedOrders, 'completed'),
                _buildOrderList(_cancelledOrders, 'cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final total = _pendingOrders.length + _processingOrders.length + _completedOrders.length + _cancelledOrders.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _buildStatChip('Total', total, Colors.blue),
          const SizedBox(width: 8),
          _buildStatChip('Pending', _pendingOrders.length, Colors.orange),
          const SizedBox(width: 8),
          _buildStatChip('Processing', _processingOrders.length, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $count',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search by order ID, customer, or status',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          filled: true,
          fillColor: const Color(0xFFF5F1E8),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFFF9800), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
