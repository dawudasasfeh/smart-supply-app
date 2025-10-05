import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/delivery_api_service.dart';
import '../../services/delivery_socket_service.dart';
import '../../theme/app_colors.dart';
import 'order_selection_page.dart';
import 'assignment_results_page.dart';
import 'assignment_analytics_page.dart';

class SmartAssignmentDashboard extends StatefulWidget {
  final int userId;
  final String userRole;

  const SmartAssignmentDashboard({
    Key? key,
    required this.userId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<SmartAssignmentDashboard> createState() => _SmartAssignmentDashboardState();
}

class _SmartAssignmentDashboardState extends State<SmartAssignmentDashboard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Data variables
  List<dynamic> _allOrders = [];
  List<dynamic> _activeDeliveries = [];
  List<dynamic> _deliveryMen = [];

  // Loading states
  bool _isLoading = true;
  bool _isAssigning = false;
  int _assignmentProgress = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSmartAssignment();
    _loadDashboardData();
  }

  // Add refresh method for real-time data updates
  Future<void> _refreshDashboard() async {
    await _loadDashboardData();
  }

  // Get pending orders for the logged-in distributor (only unassigned orders)
  Future<Map<String, dynamic>> _getPendingDistributorOrders() async {
    try {
      final response = await DeliveryApiService.getPendingOrders(distributorId: widget.userId);
      final pendingOrders = response['data'] ?? response['orders'] ?? [];
      
      print('📋 Pending orders API response: ${response['count']} orders');
      print('📋 Pending orders data: ${pendingOrders.length} orders');
      
      return {
        'data': pendingOrders,
        'count': pendingOrders.length
      };
    } catch (e) {
      print('❌ Error fetching pending distributor orders: $e');
      return {'data': [], 'count': 0};
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
  }

  void _initializeSmartAssignment() {
    DeliverySocketService.initializeDeliverySocket(
      userId: widget.userId,
      userName: 'Smart Assignment System',
      userRole: widget.userRole,
    );

    DeliverySocketService.listenToDeliveryEvents(
      onDeliveryAssigned: (data) {
        if (mounted) {
          _showAssignmentNotification(data);
          _loadDashboardData();
        }
      },
    );
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        DeliveryApiService.getEnhancedAnalytics(),
        // Get only pending orders for the logged-in distributor
        _getPendingDistributorOrders(),
        // Pass distributor ID to filter active deliveries for the logged-in distributor
        DeliveryApiService.getActiveDeliveries(distributorId: widget.userId),
        // Pass distributor ID to filter delivery men for the logged-in distributor
        DeliveryApiService.getDeliveryMen(distributorId: widget.userId),
      ]);

      if (mounted) {
        setState(() {
          // Enhanced analytics loaded but not stored (used for display only)
          _allOrders = results[1]['data'] ?? [];
          _activeDeliveries = results[2]['data'] ?? [];
          _deliveryMen = results[3]['deliveryMen'] ?? results[3]['delivery_men'] ?? [];
          _isLoading = false;
        });
        
        print('📊 Dashboard data loaded:');
        print('   Pending orders: ${_allOrders.length}');
        print('   Active deliveries: ${_activeDeliveries.length}');
        print('   Delivery men: ${_deliveryMen.length}');
      }
    } catch (e) {
      print('❌ Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load dashboard data');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading ? _buildLoadingScreen() : RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: _buildDashboardContent(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            Colors.white,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Smart Assignment System',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Loading intelligent delivery management...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SlideTransition(
      position: _slideAnimation,
      child: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickStatsCards(),
                  const SizedBox(height: 24),
                  _buildSmartAssignmentCard(),
                  const SizedBox(height: 24),
                  _buildActionCards(),
                  const SizedBox(height: 24),
                  _buildRecentActivity(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Smart Assignment',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
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
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              const Positioned(
                right: 20,
                bottom: 20,
                child: Icon(
                  Icons.smart_toy,
                  color: Colors.white24,
                  size: 80,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: _loadDashboardData,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AssignmentAnalyticsPage(
                userId: widget.userId,
                userRole: widget.userRole,
              ),
            ),
          ),
          icon: const Icon(Icons.analytics, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildQuickStatsCards() {
    // Use actual data instead of general stats for distributor-specific information
    final pendingOrdersCount = _allOrders.length;
    final availableCount = _deliveryMen.where((dm) => dm['is_available'] == true).length;
    final activeCount = _activeDeliveries.length; // Use actual active deliveries count
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pending Orders',
            '$pendingOrdersCount',
            Icons.pending_actions,
            Colors.orange,
            'Ready for assignment',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Available Delivery',
            '$availableCount',
            Icons.delivery_dining,
            Colors.green,
            'Ready to deliver',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Active Deliveries',
            '$activeCount',
            Icons.local_shipping,
            Colors.orange,
            'In progress',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartAssignmentCard() {
    final pendingCount = _allOrders.length;
    final availableCount = _deliveryMen.where((dm) => dm['is_available'] == true).length;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI-Powered Smart Assignment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Optimize delivery routes with machine learning',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildAssignmentMetric(
                  'Orders Ready',
                  pendingCount.toString(),
                  Icons.inventory_2,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAssignmentMetric(
                  'Available Delivery',
                  availableCount.toString(),
                  Icons.person,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isAssigning) _buildAssignmentProgress(),
          if (!_isAssigning) _buildAssignmentButtons(),
        ],
      ),
    );
  }

  Widget _buildAssignmentMetric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
       ],
      ),
    );
  }

  Widget _buildAssignmentProgress() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.orange),
            const SizedBox(width: 8),
            const Text(
              'Smart Assignment in Progress...',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Text(
              '$_assignmentProgress%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: _assignmentProgress / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildAssignmentButtons() {
    final canAssign = _allOrders.isNotEmpty && 
                     _deliveryMen.any((dm) => dm['is_available'] == true);
    
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canAssign ? _performQuickAssignment : null,
            icon: const Icon(Icons.flash_on, size: 20),
            label: const Text('Quick Assign'),
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
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderSelectionPage(
                    userId: widget.userId,
                    userRole: widget.userRole,
                  ),
                ),
              );
              // Refresh dashboard when returning from order selection
              if (result != null) {
                _refreshDashboard();
              }
            },
            icon: const Icon(Icons.tune, size: 20),
            label: const Text('Custom Assign'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Order Selection',
                'Choose specific orders to assign',
                Icons.checklist,
                Colors.blue,
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderSelectionPage(
                        userId: widget.userId,
                        userRole: widget.userRole,
                      ),
                    ),
                  );
                  // Refresh dashboard when returning from order selection
                  if (result != null) {
                    _refreshDashboard();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Assignment Results',
                'View recent assignment outcomes',
                Icons.assessment,
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AssignmentResultsPage(
                      userId: widget.userId,
                      userRole: widget.userRole,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssignmentResultsPage(
                    userId: widget.userId,
                    userRole: widget.userRole,
                  ),
                ),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildActivityList(),
      ],
    );
  }

  Widget _buildActivityList() {
    // Mock recent activity data
    final activities = [
      {
        'title': 'Smart Assignment Completed',
        'subtitle': '15 orders assigned to 8 delivery personnel',
        'time': '2 minutes ago',
        'icon': Icons.smart_toy,
        'color': Colors.green,
      },
      {
        'title': 'Bulk Assignment',
        'subtitle': '23 orders processed with 95% efficiency',
        'time': '1 hour ago',
        'icon': Icons.assignment_turned_in,
        'color': Colors.blue,
      },
      {
        'title': 'Route Optimization',
        'subtitle': 'Delivery routes optimized for Zone A',
        'time': '3 hours ago',
        'icon': Icons.route,
        'color': Colors.orange,
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (activity['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  activity['icon'] as IconData,
                  color: activity['color'] as Color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['title'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity['subtitle'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                activity['time'] as String,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Action handlers
  Future<void> _performQuickAssignment() async {
    setState(() {
      _isAssigning = true;
      _assignmentProgress = 0;
    });

    try {
      // Simulate assignment progress
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          setState(() => _assignmentProgress = i);
        }
      }

      final result = await DeliveryApiService.performSmartAssignment(distributorId: widget.userId);
      
      print('🤖 Smart assignment result: $result');
      
      if (mounted) {
        HapticFeedback.lightImpact();
        _showSuccessDialog(result);
        // Add a small delay to ensure database is updated
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadDashboardData();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Smart assignment failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isAssigning = false);
      }
    }
  }

  void _showAssignmentNotification(Map<String, dynamic> data) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Order #${data['order_id']} assigned to ${data['delivery_man_name']}'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green),
            ),
            const SizedBox(width: 12),
            const Text('Assignment Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully assigned ${result['count'] ?? 0} orders'),
            const SizedBox(height: 8),
            Text(
              'All assignments have been optimized for efficiency and delivery time.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Great!'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssignmentResultsPage(
                    userId: widget.userId,
                    userRole: widget.userRole,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('View Results'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
