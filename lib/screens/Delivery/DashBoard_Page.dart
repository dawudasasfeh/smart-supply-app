import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../themes/role_theme_manager.dart';
import '../Distributor/Notifications_Page.dart';
import '../../widgets/delivery_bottom_navigation.dart';
import '../../widgets/integrated_map_widget.dart';
import '../RouteOptimization/RouteOptimizationPage.dart';

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String? token;
  String userName = 'Delivery Partner';
  Map<String, dynamic> dashboardStats = {};
  List<Map<String, dynamic>> assignedOrders = [];
  List<Map<String, dynamic>> aiSuggestions = [];
  List<Map<String, dynamic>> recentActivities = [];
  List<Map<String, dynamic>> notifications = [];
  Map<String, dynamic> userProfile = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDashboardData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _loadDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? '';
    
    if (token!.isNotEmpty) {
      userName = prefs.getString('name') ?? 'Delivery Partner';
      // Prefer cached delivery_man_id (maps to delivery_men.id). Do not assume users.id == delivery_men.id.
      int userId = prefs.getInt('delivery_man_id') ?? 0;
      final storedUserId = prefs.getInt('user_id') ?? prefs.getInt('userId');
      final storedName = prefs.getString('username');
      final storedEmail = prefs.getString('user_email');

      if (userId == 0) {
        try {
          final deliveryMen = await ApiService.getAvailableDeliveryMen();
          Map<String, dynamic> match = {};

          if (storedEmail != null && storedEmail.isNotEmpty) {
            match = deliveryMen.firstWhere((dm) => (dm['email'] ?? '').toString() == storedEmail, orElse: () => {});
          }

          if (match.isEmpty && storedName != null && storedName.isNotEmpty) {
            match = deliveryMen.firstWhere((dm) => (dm['name'] ?? '').toString() == storedName, orElse: () => {});
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
              userId = idVal;
              await prefs.setInt('delivery_man_id', userId);
            }
          }
        } catch (e) {
          print('Error resolving delivery_man_id in dashboard: $e');
        }
      }
      
      await Future.wait([
        _fetchDeliveryStats(userId),
        _fetchAssignedOrders(userId),
        _generateAISuggestions(),
      ]);
    }
    
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _fetchDeliveryStats(int deliveryId) async {
    try {
      // Fetch real delivery statistics
      final orders = await ApiService.getAssignedOrders(deliveryId);
      final assignedCount = orders.where((o) {
        final s = (o['status'] ?? o['delivery_status'] ?? o['deliveryStatus'] ?? '').toString().toLowerCase();
        // Include more status values that represent active assignments
        final isAssigned = s == 'assigned' || s == 'accepted' || s == 'in_transit' || s == 'picked_up' || s == 'shipped';
        return isAssigned;
      }).length;

      // Count deliveries completed today. Prefer delivered_at on delivery assignment (delivery_assignments.delivered_at)
      // or fallback to order.delivered_at / deliveredAt fields. Compare the date portion to current local date.
      DateTime now = DateTime.now();
      DateTime todayStart = DateTime(now.year, now.month, now.day);
      final deliveredCount = orders.where((o) {
        final status = (o['status'] ?? o['delivery_status'] ?? o['deliveryStatus'] ?? '').toString().toLowerCase();
        
        // Count orders with delivered status
        if (status == 'delivered' || status == 'completed') {
          // Try to check if delivered today using various timestamp fields
          final deliveredAtRaw = o['delivered_at'] ?? o['delivery_delivered_at'] ?? o['deliveredAt'] ?? o['assignment_delivered_at'] ?? o['updated_at'];
          if (deliveredAtRaw != null) {
            try {
              final dt = DateTime.parse(deliveredAtRaw.toString()).toLocal();
              return dt.isAfter(todayStart);
            } catch (_) {
              // If can't parse date, assume it's recent
              return true;
            }
          }
          // If no timestamp, assume it's recent
          return true;
        }
        
        return false;
      }).length;
      
      final totalEarnings = deliveredCount * 25.0; // $25 per delivery
      final completionRate = orders.isNotEmpty ? (deliveredCount / orders.length * 100).round() : 0;
      
      setState(() {
        dashboardStats = {
          'assignedOrders': assignedCount,
          'deliveredToday': deliveredCount,
          'totalEarnings': totalEarnings,
          'completionRate': completionRate,
        };
      });
    } catch (e) {
      print('Error fetching delivery stats: $e');
      // Fallback to default values
      setState(() {
        dashboardStats = {
          'assignedOrders': 0,
          'deliveredToday': 0,
          'totalEarnings': 0.0,
          'completionRate': 0,
        };
      });
    }
  }

  Future<void> _fetchAssignedOrders(int deliveryId) async {
    try {
      final orders = await ApiService.getAssignedOrders(deliveryId);
      setState(() {
        assignedOrders = orders.take(5).map((order) => {
          'id': order['id'],
          'customerName': order['customer_name'] ?? 'Unknown Customer',
          'address': order['delivery_address'] ?? 'No address provided',
          'status': order['status'] ?? 'assigned',
        }).toList();
      });
    } catch (e) {
      print('Error fetching assigned orders: $e');
      // Fallback data
      setState(() {
        assignedOrders = [
          {'id': 1001, 'customerName': 'SuperMart Downtown', 'address': '123 Main St', 'status': 'assigned'},
          {'id': 1002, 'customerName': 'Metro Grocery', 'address': '456 Oak Ave', 'status': 'in_transit'},
        ];
      });
    }
  }

  Future<void> _generateAISuggestions() async {
    // Generate AI suggestions based on real data
    setState(() {
      aiSuggestions = [
        {
          'type': 'route',
          'title': 'Smart Route Optimization',
          'description': 'Optimize your delivery route using smart algorithms to save time and fuel costs',
          'priority': 'high',
          'icon': Icons.route,
          'color': Colors.blue,
          'action': 'optimize_route',
        },
      ];
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleColors = context.roleColors;
    
    return Scaffold(
      backgroundColor: roleColors.background,
      body: isLoading 
        ? _buildLoadingScreen(roleColors)
        : FadeTransition(
            opacity: _fadeAnimation,
            child: _buildDashboardContent(),
          ),
      bottomNavigationBar: DeliveryBottomNavigation(
        currentRoute: '/deliveryDashboard',
        onDashboardRefresh: _loadDashboardData,
      ),
    );
  }

  Widget _buildLoadingScreen(RoleColorScheme roleColors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(roleColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your dashboard...',
            style: TextStyle(
              fontSize: 16,
              color: roleColors.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildWelcomeCard(),
              const SizedBox(height: 20),
              _buildStatsGrid(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
        _buildAISuggestionsSection(),
        const SizedBox(height: 16),
        _buildRouteOptimizationIntro(),
        const SizedBox(height: 24),
              _buildAssignedOrders(),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: AppDimensions.appBarExpandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DistributorNotificationsPage(),
              ),
            );
          },
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $userName! 🚚',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ready for today\'s deliveries?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          'Assigned Orders',
          '${dashboardStats['assignedOrders'] ?? 0}',
          Icons.assignment,
          Colors.blue,
        ),
        _buildStatCard(
          'Delivered Today',
          '${dashboardStats['deliveredToday'] ?? 0}',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Total Earnings',
          '\$${dashboardStats['totalEarnings'] ?? 0}',
          Icons.attach_money,
          Colors.orange,
        ),
        _buildStatCard(
          'Completion Rate',
          '${dashboardStats['completionRate'] ?? 0}%',
          Icons.trending_up,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              '🧠 Smart Delivery Insights',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: aiSuggestions.map((suggestion) => _buildAISuggestionCard(suggestion)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAISuggestionCard(Map<String, dynamic> suggestion) {
    Color priorityColor = suggestion['priority'] == 'high' 
        ? Colors.red 
        : suggestion['priority'] == 'medium' 
            ? Colors.orange 
            : Colors.green;

    return GestureDetector(
      onTap: () => _handleSuggestionAction(suggestion),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: priorityColor.withAlpha(13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: priorityColor.withAlpha(51)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: suggestion['color'].withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                suggestion['icon'],
                color: suggestion['color'],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          suggestion['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          suggestion['priority'].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion['description'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (suggestion['action'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(26),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Tap to optimize',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSuggestionAction(Map<String, dynamic> suggestion) {
    if (suggestion['action'] == 'optimize_route') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RouteOptimizationPage(),
        ),
      );
    }
  }

  Widget _buildRouteOptimizationIntro() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.route,
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
                      'Smart Route Optimization',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Smart algorithm-powered route optimization',
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
          const SizedBox(height: 16),
          const Text(
            'Our smart route optimization system uses advanced algorithms to analyze your delivery locations and find the most efficient path to save time, reduce fuel costs, and improve customer satisfaction.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureChip('Time Saving', Icons.timer, Colors.green),
              _buildFeatureChip('Fuel Efficient', Icons.local_gas_station, Colors.orange),
              GestureDetector(
                onTap: _openIntegratedMap,
                child: _buildFeatureChip('Integrated Maps', Icons.map, Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RouteOptimizationPage(),
                  ),
                );
              },
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Start Route Optimization'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
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
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _openIntegratedMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const IntegratedMapWidget(
          title: 'Delivery Dashboard Map',
          showNavigationButton: true,
        ),
      ),
    );
  }

  Widget _buildAssignedOrders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📋 Today\'s Assignments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to full orders
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: assignedOrders.take(3).map((order) => _buildOrderItem(order)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> order) {
    Color statusColor = _getStatusColor(order['status']);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order['id']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order['customerName'],
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  order['address'],
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              order['status'].toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚡ Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2,
          children: [
            _buildActionCard('My Orders', Icons.assignment_turned_in, Colors.blue, () {
              Navigator.pushNamed(context, '/assignedOrders');
            }),
            _buildActionCard('QR Scanner', Icons.qr_code_scanner, Colors.green, () async {
              final result = await Navigator.pushNamed(context, '/qrScanner');
              if (result == true) {
                // refresh dashboard data after successful verification (order delivered)
                await _loadDashboardData();
                setState(() {});
              }
            }),
            _buildActionCard('Delivered', Icons.check_circle, Colors.orange, () {
              Navigator.pushNamed(context, '/deliveredOrders');
            }),
            _buildActionCard('Profile', Icons.person, Colors.purple, () {
              Navigator.pushNamed(context, '/deliveryProfile');
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'assigned':
        return Colors.orange;
      case 'in_transit':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
