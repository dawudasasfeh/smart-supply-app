import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final int? deliveryId;
  final int? orderId;
  
  const DeliveryTrackingPage({
    super.key,
    this.deliveryId,
    this.orderId,
  });

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  Map<String, dynamic>? deliveryData;
  List<Map<String, dynamic>> trackingHistory = [];
  bool isLoading = true;
  Timer? _trackingTimer;
  String currentStatus = 'pending';

  final List<Map<String, String>> deliveryStatuses = [
    {'status': 'pending', 'label': 'Order Pending', 'icon': 'pending_actions'},
    {'status': 'assigned', 'label': 'Assigned to Delivery', 'icon': 'assignment_ind'},
    {'status': 'picked_up', 'label': 'Order Picked Up', 'icon': 'inventory'},
    {'status': 'in_transit', 'label': 'In Transit', 'icon': 'local_shipping'},
    {'status': 'out_for_delivery', 'label': 'Out for Delivery', 'icon': 'delivery_dining'},
    {'status': 'delivered', 'label': 'Delivered', 'icon': 'check_circle'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDeliveryData();
    _startRealTimeTracking();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDeliveryData() async {
    setState(() => isLoading = true);
    
    try {
      Map<String, dynamic>? data;
      List<Map<String, dynamic>> history = [];
      
      if (widget.deliveryId != null) {
        // Load by delivery man ID
        data = await ApiService.getEnhancedDeliveryManPerformance(widget.deliveryId!);
        history = await _getDeliveryHistory(widget.deliveryId!);
      } else if (widget.orderId != null) {
        // Load by order ID
        data = await _getOrderDeliveryData(widget.orderId!);
        history = await _getOrderTrackingHistory(widget.orderId!);
      }

      setState(() {
        deliveryData = data;
        trackingHistory = history;
        currentStatus = data?['current_status'] ?? 'pending';
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to load delivery data');
    }
  }

  void _startRealTimeTracking() {
    // Start with a shorter interval for more responsive updates
    _trackingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && currentStatus != 'delivered') {
        _updateTrackingData();
      } else if (currentStatus == 'delivered') {
        // Stop tracking once delivered
        timer.cancel();
      }
    });
  }

  Future<void> _updateTrackingData() async {
    try {
      if (widget.orderId != null) {
        final updatedData = await _getOrderDeliveryData(widget.orderId!);
        if (updatedData != null && mounted) {
          setState(() {
            deliveryData = updatedData;
            currentStatus = updatedData['current_status'] ?? currentStatus;
          });
        }
      }
    } catch (e) {
      // Silently handle tracking update errors
    }
  }

  Future<Map<String, dynamic>?> _getOrderDeliveryData(int orderId) async {
    try {
      // First try to get from active deliveries
      final activeDeliveries = await ApiService.getActiveDeliveryOrders();
      final activeDelivery = activeDeliveries.firstWhere(
        (delivery) => delivery['id'] == orderId || delivery['order_id'] == orderId,
        orElse: () => {},
      );
      
      if (activeDelivery.isNotEmpty) {
        return activeDelivery;
      }
      
      // Fallback to enhanced API method for order delivery tracking
      final data = await ApiService.getOrderDeliveryTracking(orderId);
      if (data.isNotEmpty) {
        return data;
      }
      
      // Final fallback to general order data
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final userId = prefs.getInt('user_id') ?? 0;
      
      if (token.isNotEmpty && userId > 0) {
        final orders = await ApiService.getDistributorOrders(token, userId);
        final order = orders.firstWhere(
          (o) => o['id'] == orderId,
          orElse: () => {},
        );
        
        if (order.isNotEmpty) {
          return _formatOrderAsDeliveryData(order);
        }
      }
      
      throw Exception('Order not found');
    } catch (e) {
      print('Error fetching order delivery data: $e');
      throw e; // No fallback - force real backend integration
    }
  }
  
  Map<String, dynamic> _formatOrderAsDeliveryData(Map<String, dynamic> order) {
    return {
      'order_id': order['id'],
      'order_number': order['order_number'] ?? 'ORD-${order['id'].toString().padLeft(3, '0')}',
      'customer_name': order['buyer']?['name'] ?? order['customer_name'] ?? 'Unknown Customer',
      'customer_phone': order['buyer']?['phone'] ?? order['customer_phone'] ?? 'N/A',
      'delivery_address': order['shipping_address']?['full_address'] ?? order['delivery_address'] ?? 'Address not available',
      'current_status': order['status'] ?? 'pending',
      'delivery_man': order['delivery_man'] ?? {
        'name': 'Unassigned',
        'phone': 'N/A',
        'rating': 0.0,
      },
      'current_location': order['current_location'] ?? {
        'latitude': 31.9539,
        'longitude': 35.9106,
        'address': 'Location updating...',
      },
      'destination': {
        'latitude': 31.9639,
        'longitude': 35.9206,
        'address': order['shipping_address']?['full_address'] ?? order['delivery_address'] ?? 'Destination',
      },
      'estimated_arrival': order['estimated_arrival'] ?? DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
      'total_amount': order['total_amount'] ?? 0.0,
      'items': order['items'] ?? [],
    };
  }
  

  Future<List<Map<String, dynamic>>> _getDeliveryHistory(int deliveryId) async {
    try {
      // Try to get real delivery history from API
      final response = await ApiService.getDeliveryHistory(deliveryId);
      return response;
    } catch (e) {
      print('Error fetching delivery history: $e');
      throw e; // No fallback - force real backend integration
    }
  }

  Future<List<Map<String, dynamic>>> _getOrderTrackingHistory(int orderId) async {
    try {
      // Try to get real tracking history from API
      final response = await ApiService.getDeliveryHistory(orderId);
      if (response.isNotEmpty) {
        return response;
      }
      
      // Try to get from active deliveries for recent history
      final activeDeliveries = await ApiService.getActiveDeliveryOrders();
      final delivery = activeDeliveries.firstWhere(
        (d) => d['id'] == orderId || d['order_id'] == orderId,
        orElse: () => {},
      );
      
      if (delivery.isNotEmpty && delivery['tracking_history'] != null) {
        return List<Map<String, dynamic>>.from(delivery['tracking_history']);
      }
      
      throw Exception('No tracking history found');
    } catch (e) {
      print('Error fetching order tracking history: $e');
      throw e; // No fallback - force real backend integration
    }
  }
  

  Future<void> _updateDeliveryStatus(String newStatus) async {
    try {
      if (widget.orderId != null) {
        final success = await ApiService.updateDeliveryStatusWithLocationData(
          widget.orderId!,
          newStatus,
          locationData: deliveryData?['current_location'],
        );
        
        if (success) {
          setState(() => currentStatus = newStatus);
          _showSuccessSnackBar('Status updated successfully');
          _loadDeliveryData(); // Refresh data
        } else {
          _showErrorSnackBar('Failed to update status');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error updating status: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(50.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: [
                      _buildDeliveryOverview(),
                      _buildStatusTimeline(),
                      _buildLocationCard(),
                      _buildOrderDetails(),
                      _buildActionButtons(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Delivery Tracking #${widget.orderId ?? widget.deliveryId ?? "N/A"}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadDeliveryData,
        ),
        IconButton(
          icon: const Icon(Icons.call, color: Colors.white),
          onPressed: () {
            // Call delivery person
            final phone = deliveryData?['delivery_man_phone'];
            if (phone != null) {
              // Implement phone call functionality
            }
          },
        ),
      ],
    );
  }

  Widget _buildDeliveryOverview() {
    if (deliveryData == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.blue.shade100,
                child: Icon(Icons.delivery_dining, color: Colors.blue.shade700, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deliveryData!['delivery_man_name'] ?? 'Unknown Driver',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      deliveryData!['delivery_man_phone'] ?? 'No phone',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(currentStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusLabel(currentStatus),
                  style: TextStyle(
                    color: _getStatusColor(currentStatus),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'ETA',
                  _formatETA(deliveryData!['estimated_delivery']),
                  Icons.schedule,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Distance',
                  '${deliveryData!['distance_remaining'] ?? 0} km',
                  Icons.location_on,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...deliveryStatuses.map((status) => _buildTimelineItem(status)).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, String> status) {
    final isCompleted = _isStatusCompleted(status['status']!);
    final isCurrent = status['status'] == currentStatus;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted 
                  ? Colors.green 
                  : isCurrent 
                      ? Colors.blue 
                      : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(status['icon']!),
              color: isCompleted || isCurrent ? Colors.white : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status['label']!,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted 
                        ? Colors.green 
                        : isCurrent 
                            ? Colors.blue 
                            : Colors.grey,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Current Status',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isCompleted)
            Icon(Icons.check, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    if (deliveryData == null) return const SizedBox.shrink();

    final currentLocation = deliveryData!['current_location'];
    final destination = deliveryData!['destination'];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildLocationItem(
            'Current Location',
            currentLocation?['address'] ?? 'Unknown',
            Icons.my_location,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildLocationItem(
            'Destination',
            destination?['address'] ?? 'Unknown',
            Icons.location_on,
            Colors.red,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _openMapView();
              },
              icon: const Icon(Icons.map),
              label: const Text('View on Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem(String label, String address, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetails() {
    if (deliveryData == null || deliveryData!['items'] == null) {
      return const SizedBox.shrink();
    }

    final items = deliveryData!['items'] as List;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildOrderItem(item)).toList(),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Unknown Item',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Qty: ${item['quantity'] ?? 0}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (currentStatus != 'delivered') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showStatusUpdateDialog(),
                icon: const Icon(Icons.update),
                label: const Text('Update Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _contactCustomer();
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _callCustomer();
                  },
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Delivery Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: deliveryStatuses
                .where((status) => !_isStatusCompleted(status['status']!))
                .map((status) => ListTile(
                      leading: Icon(_getStatusIcon(status['icon']!)),
                      title: Text(status['label']!),
                      onTap: () {
                        Navigator.pop(context);
                        _updateDeliveryStatus(status['status']!);
                      },
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  bool _isStatusCompleted(String status) {
    final currentIndex = deliveryStatuses.indexWhere((s) => s['status'] == currentStatus);
    final statusIndex = deliveryStatuses.indexWhere((s) => s['status'] == status);
    return statusIndex <= currentIndex;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'assigned':
        return Colors.blue;
      case 'picked_up':
        return Colors.orange;
      case 'in_transit':
        return Colors.purple;
      case 'out_for_delivery':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    final statusData = deliveryStatuses.firstWhere(
      (s) => s['status'] == status,
      orElse: () => {'label': 'Unknown'},
    );
    return statusData['label']!;
  }

  IconData _getStatusIcon(String iconName) {
    switch (iconName) {
      case 'pending_actions':
        return Icons.pending_actions;
      case 'assignment_ind':
        return Icons.assignment_ind;
      case 'inventory':
        return Icons.inventory;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'delivery_dining':
        return Icons.delivery_dining;
      case 'check_circle':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  String _formatETA(String? eta) {
    if (eta == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(eta);
      final now = DateTime.now();
      final difference = dateTime.difference(now);
      
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min';
      } else {
        return '${difference.inHours}h ${difference.inMinutes % 60}m';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Helper method to open map view
  void _openMapView() {
    if (deliveryData != null) {
      final currentLat = deliveryData!['current_location']?['latitude'];
      final currentLng = deliveryData!['current_location']?['longitude'];
      final destLat = deliveryData!['destination']?['latitude'];
      final destLng = deliveryData!['destination']?['longitude'];
      
      if (currentLat != null && currentLng != null && destLat != null && destLng != null) {
        // In a real app, you would open a map application or navigate to a map page
        _showSnackBar('Map view would open here. Current: $currentLat,$currentLng → Destination: $destLat,$destLng', Colors.blue);
      } else {
        _showErrorSnackBar('Location data not available');
      }
    }
  }

  // Helper method to contact customer
  void _contactCustomer() {
    if (deliveryData != null) {
      // In a real app, you would navigate to chat or messaging
      _showSnackBar('Opening customer chat...', Colors.blue);
    } else {
      _showErrorSnackBar('Customer contact information not available');
    }
  }

  // Helper method to call customer
  void _callCustomer() {
    if (deliveryData != null) {
      final phone = deliveryData!['customer_phone'] ?? deliveryData!['delivery_man_phone'];
      if (phone != null) {
        // In a real app, you would use url_launcher to make a phone call
        _showSnackBar('Calling $phone...', Colors.green);
      } else {
        _showErrorSnackBar('Phone number not available');
      }
    } else {
      _showErrorSnackBar('Contact information not available');
    }
  }

  // Helper method to show info snackbar
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
