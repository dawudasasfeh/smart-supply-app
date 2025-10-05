import 'package:flutter/material.dart';
import '../../services/delivery_api_service.dart';
import '../../services/delivery_socket_service.dart';
import '../../theme/app_colors.dart';

class EnhancedDeliveryDashboard extends StatefulWidget {
  final int userId;
  final String userRole;

  const EnhancedDeliveryDashboard({
    Key? key,
    required this.userId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<EnhancedDeliveryDashboard> createState() => _EnhancedDeliveryDashboardState();
}

class _EnhancedDeliveryDashboardState extends State<EnhancedDeliveryDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Data variables
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _analytics;
  List<dynamic> _pendingOrders = [];
  List<dynamic> _activeDeliveries = [];
  List<dynamic> _completedDeliveries = [];
  List<dynamic> _deliveryMen = [];
  
  // Loading states
  bool _isLoading = true;
  bool _isAssigning = false;
  
  // Selected items for bulk operations
  Set<int> _selectedOrders = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeDeliverySystem();
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    DeliverySocketService.dispose();
    super.dispose();
  }

  void _initializeDeliverySystem() {
    // Initialize Socket.IO for real-time updates
    DeliverySocketService.initializeDeliverySocket(
      userId: widget.userId,
      userName: 'User', // You can pass actual user name
      userRole: widget.userRole,
    );

    // Listen to delivery events
    DeliverySocketService.listenToDeliveryEvents(
      onDeliveryAssigned: (data) {
        if (mounted) {
          _showNotification('Order #${data['order_id']} assigned to ${data['delivery_man_name']}');
          _refreshData();
        }
      },
      onStatusUpdate: (data) {
        if (mounted) {
          _showNotification('Order #${data['order_id']} status: ${data['status']}');
          _refreshData();
        }
      },
      onLocationUpdate: (data) {
        if (mounted) {
          print('📍 Location update received: ${data['order_id']}');
          // Update UI with new location if needed
        }
      },
    );
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load all data in parallel
      final results = await Future.wait([
        DeliveryApiService.getDeliveryStats(),
        DeliveryApiService.getEnhancedAnalytics(),
        DeliveryApiService.getPendingOrders(),
        DeliveryApiService.getActiveDeliveries(),
        DeliveryApiService.getCompletedDeliveries(),
        DeliveryApiService.getDeliveryMen(),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0];
          _analytics = results[1];
          _pendingOrders = results[2]['orders'] ?? [];
          _activeDeliveries = results[3]['deliveries'] ?? [];
          _completedDeliveries = results[4]['deliveries'] ?? [];
          _deliveryMen = results[5]['deliveryMen'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading initial data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load delivery data: $e');
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading ? _buildLoadingWidget() : _buildMainContent(),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading delivery system...'),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildStatsHeader(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPendingOrdersTab(),
              _buildActiveDeliveriesTab(),
              _buildCompletedDeliveriesTab(),
              _buildAnalyticsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    final stats = _stats?['stats'] ?? {};
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Delivery Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard('Pending', '${stats['pending_orders'] ?? 0}', Icons.pending_actions, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Active', '${stats['active_deliveries'] ?? 0}', Icons.local_shipping, Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Completed', '${stats['completed_deliveries'] ?? 0}', Icons.check_circle, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Available', '${stats['available_delivery_men'] ?? 0}', Icons.person, Colors.purple)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: 'Pending', icon: Icon(Icons.pending_actions, size: 20)),
          Tab(text: 'Active', icon: Icon(Icons.local_shipping, size: 20)),
          Tab(text: 'Completed', icon: Icon(Icons.check_circle, size: 20)),
          Tab(text: 'Analytics', icon: Icon(Icons.analytics, size: 20)),
        ],
      ),
    );
  }

  Widget _buildPendingOrdersTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          if (_pendingOrders.isNotEmpty) _buildBulkActionBar(),
          Expanded(
            child: _pendingOrders.isEmpty
                ? _buildEmptyState('No pending orders', Icons.pending_actions)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingOrders.length,
                    itemBuilder: (context, index) {
                      final order = _pendingOrders[index];
                      return _buildOrderCard(order, isPending: true);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveriesTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: _activeDeliveries.isEmpty
          ? _buildEmptyState('No active deliveries', Icons.local_shipping)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activeDeliveries.length,
              itemBuilder: (context, index) {
                final delivery = _activeDeliveries[index];
                return _buildDeliveryCard(delivery);
              },
            ),
    );
  }

  Widget _buildCompletedDeliveriesTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: _completedDeliveries.isEmpty
          ? _buildEmptyState('No completed deliveries', Icons.check_circle)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _completedDeliveries.length,
              itemBuilder: (context, index) {
                final delivery = _completedDeliveries[index];
                return _buildDeliveryCard(delivery, isCompleted: true);
              },
            ),
    );
  }

  Widget _buildAnalyticsTab() {
    final analytics = _analytics?['analytics'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAnalyticsCard('Performance Metrics', [
            _buildMetricRow('Average Delivery Time', '${analytics['average_delivery_time'] ?? 0} min'),
            _buildMetricRow('On-Time Rate', '${((analytics['on_time_rate'] ?? 0) * 100).toInt()}%'),
            _buildMetricRow('Efficiency Score', '${((analytics['efficiency_score'] ?? 0) * 100).toInt()}%'),
            _buildMetricRow('Success Rate', '${((analytics['delivery_success_rate'] ?? 0) * 100).toInt()}%'),
          ]),
          const SizedBox(height: 16),
          _buildAnalyticsCard('Delivery Statistics', [
            _buildMetricRow('Total Assignments', '${analytics['total_assignments'] ?? 0}'),
            _buildMetricRow('Total Deliveries', '${analytics['total_deliveries'] ?? 0}'),
            _buildMetricRow('Completed Today', '${analytics['completed_today'] ?? 0}'),
            _buildMetricRow('Average Rating', '${analytics['average_rating'] ?? 0}/5'),
          ]),
        ],
      ),
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Row(
        children: [
          Text('${_selectedOrders.length} selected'),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _selectedOrders.isNotEmpty ? _performSmartAssignment : null,
            icon: const Icon(Icons.smart_toy, size: 16),
            label: const Text('Smart Assign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _selectedOrders.clear()),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {bool isPending = false}) {
    final orderId = order['id'] ?? 0;
    final isSelected = _selectedOrders.contains(orderId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: isPending
            ? Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedOrders.add(orderId);
                    } else {
                      _selectedOrders.remove(orderId);
                    }
                  });
                },
              )
            : const Icon(Icons.local_shipping, color: Colors.blue),
        title: Text('Order #${order['id']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order['customer_name'] ?? 'Unknown'}'),
            Text('Amount: \$${order['total_amount'] ?? 0}'),
            if (order['delivery_address'] != null)
              Text('Address: ${order['delivery_address']}'),
          ],
        ),
        trailing: isPending
            ? PopupMenuButton<String>(
                onSelected: (value) => _handleOrderAction(value, order),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'assign', child: Text('Assign')),
                  const PopupMenuItem(value: 'details', child: Text('Details')),
                ],
              )
            : Text(
                DeliveryApiService.formatDeliveryStatus(order['status'] ?? ''),
                style: TextStyle(
                  color: Color(int.parse(
                    DeliveryApiService.getStatusColor(order['status'] ?? '').substring(1),
                    radix: 16,
                  ) + 0xFF000000),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery, {bool isCompleted = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.local_shipping,
          color: isCompleted ? Colors.green : Colors.blue,
        ),
        title: Text('Order #${delivery['id']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${delivery['customer_name'] ?? 'Unknown'}'),
            Text('Delivery: ${delivery['delivery_man_name'] ?? 'Unassigned'}'),
            if (delivery['assigned_at'] != null)
              Text('Assigned: ${DeliveryApiService.formatTimeAgo(delivery['assigned_at'])}'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Order ID', '${delivery['id']}'),
                _buildDetailRow('Status', DeliveryApiService.formatDeliveryStatus(delivery['status'] ?? '')),
                _buildDetailRow('Amount', '\$${delivery['total_amount'] ?? 0}'),
                if (delivery['delivery_address'] != null)
                  _buildDetailRow('Address', delivery['delivery_address']),
                if (delivery['delivery_man_phone'] != null)
                  _buildDetailRow('Delivery Contact', delivery['delivery_man_phone']),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _viewDeliveryHistory(delivery['id']),
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('History'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isCompleted)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateDeliveryStatus(delivery),
                          icon: const Icon(Icons.update, size: 16),
                          label: const Text('Update'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'smart_assign',
          onPressed: _isAssigning ? null : _performSmartAssignment,
          backgroundColor: AppColors.primary,
          child: _isAssigning
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.smart_toy),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'refresh',
          onPressed: _refreshData,
          backgroundColor: Colors.grey[600],
          child: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  // Action handlers
  void _handleOrderAction(String action, Map<String, dynamic> order) {
    switch (action) {
      case 'assign':
        _showAssignmentDialog(order);
        break;
      case 'details':
        _showOrderDetails(order);
        break;
    }
  }

  void _showAssignmentDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Order #${order['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a delivery man for this order:'),
            const SizedBox(height: 16),
            ..._deliveryMen.map((deliveryMan) => ListTile(
              title: Text(deliveryMan['name'] ?? 'Unknown'),
              subtitle: Text('${deliveryMan['vehicle_type'] ?? 'Vehicle'} - Rating: ${deliveryMan['rating'] ?? 0}/5'),
              onTap: () {
                Navigator.pop(context);
                _assignOrder(order['id'], deliveryMan['id']);
              },
            )).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${order['id']} Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Customer', order['customer_name'] ?? 'Unknown'),
            _buildDetailRow('Phone', order['customer_phone'] ?? 'N/A'),
            _buildDetailRow('Amount', '\$${order['total_amount'] ?? 0}'),
            _buildDetailRow('Status', order['status'] ?? 'Unknown'),
            if (order['delivery_address'] != null)
              _buildDetailRow('Address', order['delivery_address']),
            _buildDetailRow('Created', DeliveryApiService.formatTimeAgo(order['created_at'] ?? '')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignOrder(int orderId, int deliveryManId) async {
    try {
      setState(() => _isAssigning = true);
      
      await DeliveryApiService.assignOrder(
        orderId: orderId,
        deliveryManId: deliveryManId,
      );
      
      _showNotification('Order #$orderId assigned successfully!');
      await _refreshData();
    } catch (e) {
      _showErrorSnackBar('Failed to assign order: $e');
    } finally {
      if (mounted) {
        setState(() => _isAssigning = false);
      }
    }
  }

  Future<void> _performSmartAssignment() async {
    try {
      setState(() => _isAssigning = true);
      
      final result = await DeliveryApiService.performSmartAssignment();
      final assignedCount = result['count'] ?? 0;
      
      _showNotification('Smart assignment completed! $assignedCount orders assigned.');
      setState(() => _selectedOrders.clear());
      await _refreshData();
    } catch (e) {
      _showErrorSnackBar('Smart assignment failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isAssigning = false);
      }
    }
  }

  void _updateDeliveryStatus(Map<String, dynamic> delivery) {
    // Implementation for updating delivery status
    // This would show a dialog with status options
    print('Update status for delivery: ${delivery['id']}');
  }

  void _viewDeliveryHistory(int orderId) {
    // Implementation for viewing delivery history
    // This would navigate to a detailed history page
    print('View history for order: $orderId');
  }
}
