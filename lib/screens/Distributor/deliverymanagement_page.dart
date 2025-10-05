import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/tracking_service.dart';
import '../Delivery/smart_assignment_dashboard.dart';
import '../tracking/order_tracking_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DeliveryManagementPage extends StatefulWidget {
  const DeliveryManagementPage({super.key});

  @override
  State<DeliveryManagementPage> createState() => _DeliveryManagementPageState();
}

class _DeliveryManagementPageState extends State<DeliveryManagementPage>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String? token;
  int? userId;
  String? userRole;
  bool isLoading = true;
  bool isRefreshing = false;
  String? errorMessage;
  
  // Real data from backend
  List<Map<String, dynamic>> pendingOrders = [];
  List<Map<String, dynamic>> activeDeliveries = [];
  List<Map<String, dynamic>> completedDeliveries = [];
  List<Map<String, dynamic>> deliveryMen = [];
  Map<String, dynamic> deliveryStats = {};
  Map<String, dynamic> performanceMetrics = {};
  Map<String, dynamic> personnelStats = {};
  List<Map<String, dynamic>> filteredPersonnel = [];
  
  // UI State
  int selectedTabIndex = 0;
  String searchQuery = '';
  final TextEditingController _trackingController = TextEditingController();
  String personnelFilter = 'all'; // all, available, busy, off_duty
  String personnelSortBy = 'name'; // name, rating, performance, deliveries

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserData();
  }

  void _initializeControllers() {
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          selectedTabIndex = _tabController.index;
        });
      }
    });
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token') ?? '';
      userId = prefs.getInt('userId') ?? prefs.getInt('user_id'); // Try both keys
      userRole = prefs.getString('userRole') ?? prefs.getString('role') ?? 'distributor';

      print('🔍 Debug - Token: ${token?.isNotEmpty == true ? "Found" : "Missing"}');
      print('🔍 Debug - UserId: $userId');
      print('🔍 Debug - UserRole: $userRole');

      if (token?.isEmpty == true) {
        print('❌ Token is empty, but continuing with fallback data...');
        // Don't fail completely, just use fallback data
        _setError('Limited functionality - authentication token missing');
        return;
      }

      _animationController.forward();
      await _loadAllData();
    } catch (e) {
      print('❌ Error loading user data: $e');
      _setError('Failed to load user data: ${e.toString()}');
    }
  }

  void _setError(String message) {
    setState(() {
      errorMessage = message;
      isLoading = false;
    });
  }

  Future<void> _debugAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    print('🔍 All SharedPreferences keys: $allKeys');
    
    for (String key in allKeys) {
      final value = prefs.get(key);
      print('🔍 $key: $value (${value.runtimeType})');
    }
    
    // Show in UI as well
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debug info logged to console. Keys found: ${allKeys.length}'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadAllData() async {
    print('🚀 _loadAllData() called');
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      print('📊 Starting to fetch all data...');
      await Future.wait([
        _fetchPendingOrders(),
        _fetchActiveDeliveries(),
        _fetchCompletedDeliveries(),
        _fetchDeliveryMen(),
        _fetchDeliveryStats(),
        _fetchPerformanceMetrics(),
        _fetchPersonnelStats(),
      ]);
      print('📊 All data fetched successfully');

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading delivery data: $e');
      _setError('Failed to load delivery data: ${e.toString()}');
    }
  }

  Future<void> _fetchPendingOrders() async {
    try {
      // Build URL with distributor filter
      String url = 'http://10.0.2.2:5000/api/delivery/pending';
      if (userId != null) {
        url += '?distributorId=$userId';
      }
      
      print('🔗 Fetching pending orders from: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      print('📊 Pending orders response: ${response.statusCode} - ${response.body.length} bytes');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orders = List<Map<String, dynamic>>.from(data['data'] ?? []);
        print('✅ Found ${orders.length} pending orders');
        setState(() {
          pendingOrders = orders;
        });
        return;
      }

      // Fallback to existing API
      if (token?.isNotEmpty == true && userId != null) {
        final orders = await ApiService.getDistributorOrders(token!, userId!);
        setState(() {
          pendingOrders = orders.where((order) => 
            order['delivery_status'] == null || 
            order['delivery_status'] == 'pending'
          ).toList().cast<Map<String, dynamic>>();
        });
      } else {
        // Mock data for demo purposes
        setState(() {
          pendingOrders = [
            {
              'id': 1,
              'customer_name': 'Demo Customer',
              'total_amount': 150.0,
              'delivery_address': 'Demo Address',
              'status': 'pending',
            }
          ];
        });
      }
    } catch (e) {
      print('❌ Error fetching pending orders: $e');
      setState(() {
        pendingOrders = [];
      });
    }
  }

  Future<void> _fetchActiveDeliveries() async {
    try {
      // Build URL with distributor filter
      String url = 'http://10.0.2.2:5000/api/delivery/active';
      if (userId != null) {
        url += '?distributorId=$userId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          activeDeliveries = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      } else {
        // Fallback to existing API
        final orders = await ApiService.getDistributorOrders(token!, userId!);
        setState(() {
          activeDeliveries = orders.where((order) => 
            order['delivery_status'] == 'assigned' || 
            order['delivery_status'] == 'shipped' ||
            order['delivery_status'] == 'in_transit'
          ).toList().cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('❌ Error fetching active deliveries: $e');
      setState(() {
        activeDeliveries = [];
      });
    }
  }

  Future<void> _fetchCompletedDeliveries() async {
    try {
      // Build URL with distributor filter
      String url = 'http://10.0.2.2:5000/api/delivery/completed';
      if (userId != null) {
        url += '?distributorId=$userId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          completedDeliveries = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      } else {
        // Fallback to existing API
        final orders = await ApiService.getDistributorOrders(token!, userId!);
        setState(() {
          completedDeliveries = orders.where((order) => 
            order['delivery_status'] == 'delivered'
          ).toList().cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('❌ Error fetching completed deliveries: $e');
      setState(() {
        completedDeliveries = [];
      });
    }
  }

  Future<void> _fetchDeliveryMen() async {
    try {
      print('👥 Fetching delivery personnel...');
      final personnel = await ApiService.getAllPersonnel();
      setState(() {
        deliveryMen = personnel;
        _filterAndSortPersonnel();
      });
      print('👥 Fetched ${personnel.length} delivery personnel');
    } catch (e) {
      print('❌ Error fetching delivery personnel: $e');
      setState(() {
        deliveryMen = [];
        filteredPersonnel = [];
      });
    }
  }

  Future<void> _fetchPersonnelStats() async {
    try {
      print('📊 Fetching personnel statistics...');
      final stats = await ApiService.getPersonnelStats();
      setState(() {
        personnelStats = stats;
      });
      print('📊 Personnel stats received: $stats');
    } catch (e) {
      print('❌ Error fetching personnel stats: $e');
      setState(() {
        personnelStats = {};
      });
    }
  }

  void _filterAndSortPersonnel() {
    List<Map<String, dynamic>> filtered = List.from(deliveryMen);
    
    // Apply filter
    if (personnelFilter != 'all') {
      filtered = filtered.where((person) {
        switch (personnelFilter) {
          case 'available':
            return person['status'] == 'available';
          case 'busy':
            return person['status'] == 'busy';
          case 'off_duty':
            return person['status'] == 'off_duty';
          default:
            return true;
        }
      }).toList();
    }
    
    // Apply search
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((person) {
        final name = person['name']?.toString().toLowerCase() ?? '';
        final phone = person['phone']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    }
    
    // Apply sorting
    filtered.sort((a, b) {
      switch (personnelSortBy) {
        case 'rating':
          return (b['rating'] ?? 0).compareTo(a['rating'] ?? 0);
        case 'performance':
          return (b['efficiency_score'] ?? 0).compareTo(a['efficiency_score'] ?? 0);
        case 'deliveries':
          return (b['month_deliveries'] ?? 0).compareTo(a['month_deliveries'] ?? 0);
        case 'name':
        default:
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
      }
    });
    
    setState(() {
      filteredPersonnel = filtered;
    });
  }

  Future<void> _fetchDeliveryStats() async {
    try {
      // Use delivery API endpoint from memory
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl.replaceAll('/api', '')}/api/delivery/analytics'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          deliveryStats = data['data'] ?? {};
        });
      } else {
        // Fallback to existing distributor stats API
        final stats = await ApiService.getDistributorStats(token!);
        setState(() {
          deliveryStats = stats;
        });
      }
    } catch (e) {
      print('❌ Error fetching delivery stats: $e');
      setState(() {
        deliveryStats = {};
      });
    }
  }

  Future<void> _fetchPerformanceMetrics() async {
    print('🚀 _fetchPerformanceMetrics() called');
    try {
      if (userId == null) {
        print('❌ User ID is null, cannot fetch performance metrics');
        return;
      }

      print('📊 Fetching performance metrics for authenticated distributor');
      print('📊 User ID: $userId');
      print('📊 User Role: $userRole');
      
      final metrics = await ApiService.getDeliveryPerformanceMetrics();
      print('📊 Performance metrics received: $metrics');
      print('📊 Performance metrics type: ${metrics.runtimeType}');
      print('📊 Performance metrics keys: ${metrics.keys.toList()}');
      
      if (mounted) {
        setState(() {
          performanceMetrics = metrics;
        });
        print('📊 Performance metrics set in state: $performanceMetrics');
      } else {
        print('❌ Widget not mounted, cannot set state');
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching performance metrics: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          performanceMetrics = {};
        });
      }
    }
  }

  Future<void> _navigateToSmartAssignmentSystem() async {
    try {
      if (userId == null || userRole == null) {
        _showSnackBar('❌ User authentication required', Colors.red);
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SmartAssignmentDashboard(
            userId: userId!,
            userRole: 'distributor',
          ),
        ),
      );
    } catch (e) {
      print('❌ Error navigating to smart assignment system: $e');
      _showSnackBar('❌ Error opening smart assignment system: ${e.toString()}', Colors.red);
    }
  }

  void _navigateToTracking(int orderId) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingPage(
            orderId: orderId,
          ),
        ),
      );
    } catch (e) {
      print('❌ Error navigating to tracking: $e');
      _showSnackBar('❌ Error opening tracking: ${e.toString()}', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isRefreshing = true;
    });
    await _loadAllData();
    setState(() {
      isRefreshing = false;
    });
  }

  // ============================================================================
  // PERSONNEL MANAGEMENT METHODS
  // ============================================================================

  void _showPersonnelManagement() {
    setState(() {
      selectedTabIndex = 3; // Personnel tab
    });
  }

  void _showPersonnelDetails(Map<String, dynamic> person) {
    showDialog(
      context: context,
      builder: (context) => _buildPersonnelDetailsDialog(person),
    );
  }

  Widget _buildPersonnelDetailsDialog(Map<String, dynamic> person) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    (person['name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        person['phone'] ?? 'No phone',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        person['email'] ?? 'No email',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Performance metrics
            const Text(
              'Performance Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDetailMetric(
                    'Rating',
                    '${double.tryParse(person['rating']?.toString() ?? '0.0')?.toStringAsFixed(1) ?? '0.0'}',
                    Icons.star,
                    Colors.amber[600]!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailMetric(
                    'This Month',
                    '${person['month_deliveries'] ?? 0}',
                    Icons.local_shipping,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailMetric(
                    'Efficiency',
                    '${double.tryParse(person['efficiency_score']?.toString() ?? '0.0')?.toStringAsFixed(1) ?? '0.0'}',
                    Icons.speed,
                    const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Additional details
            const Text(
              'Additional Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Vehicle Type', person['vehicle_type'] ?? 'Not specified'),
            _buildDetailRow('Vehicle Capacity', '${person['vehicle_capacity'] ?? 0} kg'),
            _buildDetailRow('Plate Number', person['plate_number'] ?? 'Not specified'),
            _buildDetailRow('Emergency Contact', person['emergency_contact'] ?? 'Not specified'),
            _buildDetailRow('Emergency Phone', person['emergency_phone'] ?? 'Not specified'),
            _buildDetailRow('Shift Time', '${person['shift_start'] ?? 'N/A'} - ${person['shift_end'] ?? 'N/A'}'),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callPersonnel(person),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _togglePersonnelAvailability(person),
                    icon: Icon(
                      person['is_available'] == true ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(person['is_available'] == true ? 'Pause' : 'Resume'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: person['is_available'] == true 
                          ? const Color(0xFFFF9800) 
                          : const Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _callPersonnel(Map<String, dynamic> person) {
    final phone = person['phone'];
    if (phone != null && phone.isNotEmpty) {
      // In a real app, you would use url_launcher to make the call
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calling ${person['name']} at $phone'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _togglePersonnelAvailability(Map<String, dynamic> person) async {
    try {
      final newAvailability = !(person['is_available'] ?? false);
      final success = await ApiService.togglePersonnelAvailability(
        person['id'], 
        newAvailability
      );
      
      if (success) {
        setState(() {
          person['is_available'] = newAvailability;
          _filterAndSortPersonnel();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${person['name']} ${newAvailability ? 'activated' : 'deactivated'} successfully'
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update availability'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error toggling availability: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating availability'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _trackingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: isLoading ? _buildLoadingScreen() : _buildContent(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToSmartAssignmentSystem,
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Smart Assignment'),
        tooltip: 'Open Smart Assignment System',
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadUserData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _debugAuthState,
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Debug'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.8),
                        AppColors.secondary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading Delivery Management...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fetching real-time delivery data',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildStatsOverview(),
              const SizedBox(height: 24),
              _buildDeliveryManagementSection(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Delivery Management',
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
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshData,
        ),
      ],
    );
  }

  Widget _buildStatsOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delivery Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  '${pendingOrders.length}',
                  Icons.schedule,
                  const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  '${activeDeliveries.length}',
                  Icons.local_shipping,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  '${completedDeliveries.length}',
                  Icons.check_circle,
                  const Color(0xFF2196F3),
                ),
              ),
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryManagementSection() {
    return Column(
      children: [
        // Smart Assignment Card
        _buildSmartAssignmentCard(),
        const SizedBox(height: 24),
        
        // Delivery Performance Metrics
        _buildPerformanceMetrics(),
        const SizedBox(height: 24),
        
        // Active Deliveries Map/Tracking
        _buildActiveDeliveriesTracking(),
        const SizedBox(height: 24),
        
        // Delivery Personnel Management
        _buildDeliveryPersonnelSection(),
        const SizedBox(height: 24),
        
        // Quick Actions
        _buildQuickActionsSection(),
        const SizedBox(height: 24),
        
        // Order Tracking Search
        _buildTrackingSearchSection(),
      ],
    );
  }

  Widget _buildSmartAssignmentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Smart Assignment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Optimize delivery routes with AI',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${pendingOrders.length} Pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _navigateToSmartAssignmentSystem,
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text('Start Smart Assignment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF667eea),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delivery Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Avg. Delivery Time',
                  _getAvgDeliveryTime(),
                  Icons.timer,
                  const Color(0xFF2196F3),
                  _getDeliveryTimeTrend(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'On-Time Rate',
                  _getOnTimeRate(),
                  Icons.check_circle,
                  const Color(0xFF4CAF50),
                  _getOnTimeTrend(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Efficiency Score',
                  _getEfficiencyScore(),
                  Icons.star,
                  const Color(0xFFFF9800),
                  _getEfficiencyTrend(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Cost per Delivery',
                  _getCostPerDelivery(),
                  Icons.attach_money,
                  const Color(0xFF9C27B0),
                  _getCostTrend(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String trend) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveriesTracking() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5722).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: Color(0xFFFF5722),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Live Delivery Tracking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Navigate to full tracking view
                },
                icon: const Icon(Icons.map, size: 16),
                label: const Text('View Map'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5722),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activeDeliveries.isNotEmpty) ...[
            ...activeDeliveries.take(3).map((delivery) => _buildActiveDeliveryItem(delivery)),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              child: const Column(
                children: [
                  Icon(
                    Icons.delivery_dining,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No active deliveries',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveDeliveryItem(Map<String, dynamic> delivery) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.delivery_dining,
              color: Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${delivery['id'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'To: ${delivery['buyer']?['name'] ?? delivery['customer_name'] ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'In Transit',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'ETA: 45 min',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _navigateToTracking(delivery['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Track',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPersonnelSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people,
                  color: Color(0xFF9C27B0),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delivery Personnel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showPersonnelManagement,
                icon: const Icon(Icons.manage_accounts, size: 16),
                label: const Text('Manage'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9C27B0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPersonnelStat(
                  'Available', 
                  '${personnelStats['available'] ?? 0}', 
                  const Color(0xFF4CAF50)
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPersonnelStat(
                  'Busy', 
                  '${personnelStats['busy'] ?? 0}', 
                  const Color(0xFFFF9800)
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPersonnelStat(
                  'Off Duty', 
                  '${personnelStats['off_duty'] ?? 0}', 
                  const Color(0xFF757575)
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter and search controls
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: personnelFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Personnel')),
                    DropdownMenuItem(value: 'available', child: Text('Available')),
                    DropdownMenuItem(value: 'busy', child: Text('Busy')),
                    DropdownMenuItem(value: 'off_duty', child: Text('Off Duty')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      personnelFilter = value ?? 'all';
                      _filterAndSortPersonnel();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: personnelSortBy,
                  decoration: const InputDecoration(
                    labelText: 'Sort By',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'rating', child: Text('Rating')),
                    DropdownMenuItem(value: 'performance', child: Text('Performance')),
                    DropdownMenuItem(value: 'deliveries', child: Text('Deliveries')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      personnelSortBy = value ?? 'name';
                      _filterAndSortPersonnel();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Personnel list preview
          if (filteredPersonnel.isNotEmpty) ...[
            ...filteredPersonnel.take(3).map((person) => _buildPersonnelCardPreview(person)),
            if (filteredPersonnel.length > 3)
              Center(
                child: TextButton(
                  onPressed: _showPersonnelManagement,
                  child: Text('View All ${filteredPersonnel.length} Personnel'),
                ),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              child: const Column(
                children: [
                  Icon(
                    Icons.person_search,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No personnel found',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonnelStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
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
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Bulk Assign',
                  Icons.assignment_turned_in,
                  const Color(0xFF2196F3),
                  () => _navigateToSmartAssignmentSystem(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Route Optimizer',
                  Icons.route,
                  const Color(0xFF4CAF50),
                  () {
                    // Navigate to route optimizer
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Performance Report',
                  Icons.assessment,
                  const Color(0xFFFF9800),
                  () {
                    // Navigate to performance report
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Emergency Support',
                  Icons.support_agent,
                  const Color(0xFFE91E63),
                  () {
                    // Open emergency support
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (pendingOrders.isEmpty) {
      return _buildEmptyState('No pending orders', Icons.inbox);
    }

    return ListView.builder(
      itemCount: pendingOrders.length,
      itemBuilder: (context, index) {
        final order = pendingOrders[index];
        return _buildOrderCard(order, 'pending');
      },
    );
  }

  Widget _buildActiveTab() {
    if (activeDeliveries.isEmpty) {
      return _buildEmptyState('No active deliveries', Icons.local_shipping);
    }

    return ListView.builder(
      itemCount: activeDeliveries.length,
      itemBuilder: (context, index) {
        final delivery = activeDeliveries[index];
        return _buildOrderCard(delivery, 'active');
      },
    );
  }

  Widget _buildCompletedTab() {
    if (completedDeliveries.isEmpty) {
      return _buildEmptyState('No completed deliveries', Icons.check_circle);
    }

    return ListView.builder(
      itemCount: completedDeliveries.length,
      itemBuilder: (context, index) {
        final order = completedDeliveries[index];
        return _buildOrderCard(order, 'completed');
      },
    );
  }

  Widget _buildPersonnelTab() {
    if (filteredPersonnel.isEmpty) {
      return _buildEmptyState('No delivery personnel found', Icons.person_search);
    }

    return Column(
      children: [
        // Search and filter controls
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search personnel...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      _filterAndSortPersonnel();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: personnelFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'available', child: Text('Available')),
                  DropdownMenuItem(value: 'busy', child: Text('Busy')),
                  DropdownMenuItem(value: 'off_duty', child: Text('Off Duty')),
                ],
                onChanged: (value) {
                  setState(() {
                    personnelFilter = value ?? 'all';
                    _filterAndSortPersonnel();
                  });
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: personnelSortBy,
                items: const [
                  DropdownMenuItem(value: 'name', child: Text('Name')),
                  DropdownMenuItem(value: 'rating', child: Text('Rating')),
                  DropdownMenuItem(value: 'performance', child: Text('Performance')),
                  DropdownMenuItem(value: 'deliveries', child: Text('Deliveries')),
                ],
                onChanged: (value) {
                  setState(() {
                    personnelSortBy = value ?? 'name';
                    _filterAndSortPersonnel();
                  });
                },
              ),
            ],
          ),
        ),
        // Personnel list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredPersonnel.length,
            itemBuilder: (context, index) {
              final person = filteredPersonnel[index];
              return _buildPersonnelCard(person);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String type) {
    Color statusColor;
    switch (type) {
      case 'pending':
        statusColor = const Color(0xFFFF9800);
        break;
      case 'active':
        statusColor = const Color(0xFF4CAF50);
        break;
      case 'completed':
        statusColor = const Color(0xFF2196F3);
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order['id'] ?? 'N/A'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Customer: ${order['buyer']?['name'] ?? order['customer_name'] ?? 'Unknown'}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total: \$${order['total_amount'] ?? '0.00'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (type == 'pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToSmartAssignmentSystem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Assign Delivery'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonnelCardPreview(Map<String, dynamic> person) {
    Color statusColor;
    String statusText;
    switch (person['status']) {
      case 'available':
        statusColor = const Color(0xFF4CAF50);
        statusText = 'Available';
        break;
      case 'busy':
        statusColor = const Color(0xFFFF9800);
        statusText = 'Busy';
        break;
      case 'off_duty':
        statusColor = const Color(0xFF757575);
        statusText = 'Off Duty';
        break;
      default:
        statusColor = const Color(0xFF757575);
        statusText = 'Unknown';
    }

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
      child: InkWell(
        onTap: () => _showPersonnelDetails(person),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: statusColor.withOpacity(0.1),
              child: Text(
                (person['name'] ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person['name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    person['phone'] ?? 'No phone',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 14,
                        color: Colors.amber[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${double.tryParse(person['rating']?.toString() ?? '0.0')?.toStringAsFixed(1) ?? '0.0'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.local_shipping,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${person['month_deliveries'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonnelCard(Map<String, dynamic> person) {
    Color statusColor;
    String statusText;
    switch (person['status']) {
      case 'available':
        statusColor = const Color(0xFF4CAF50);
        statusText = 'Available';
        break;
      case 'busy':
        statusColor = const Color(0xFFFF9800);
        statusText = 'Busy';
        break;
      case 'off_duty':
        statusColor = const Color(0xFF757575);
        statusText = 'Off Duty';
        break;
      default:
        statusColor = const Color(0xFF757575);
        statusText = 'Unknown';
    }

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
      child: InkWell(
        onTap: () => _showPersonnelDetails(person),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Text(
                    (person['name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        person['phone'] ?? 'No phone',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Performance metrics
            Row(
              children: [
                Expanded(
                  child: _buildPersonnelMetric(
                    'Rating',
                    '${double.tryParse(person['rating']?.toString() ?? '0.0')?.toStringAsFixed(1) ?? '0.0'}',
                    Icons.star,
                    Colors.amber[600]!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPersonnelMetric(
                    'Deliveries',
                    '${person['month_deliveries'] ?? 0}',
                    Icons.local_shipping,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPersonnelMetric(
                    'Efficiency',
                    '${double.tryParse(person['efficiency_score']?.toString() ?? '0.0')?.toStringAsFixed(1) ?? '0.0'}',
                    Icons.speed,
                    const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Quick actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callPersonnel(person),
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _togglePersonnelAvailability(person),
                    icon: Icon(
                      person['is_available'] == true ? Icons.pause : Icons.play_arrow,
                      size: 16,
                    ),
                    label: Text(person['is_available'] == true ? 'Pause' : 'Resume'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: person['is_available'] == true 
                          ? const Color(0xFFFF9800) 
                          : const Color(0xFF4CAF50),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showPersonnelDetails(person),
                  icon: const Icon(Icons.info_outline),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonnelMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSearchSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF673AB7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.search,
                  color: Color(0xFF673AB7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Tracking',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Search for any order using Order ID or Tracking Number',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _trackingController,
                  decoration: InputDecoration(
                    hintText: 'Enter Order ID or Tracking Number',
                    prefixIcon: const Icon(Icons.track_changes),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onSubmitted: (value) => _searchAndTrackOrder(value),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _searchAndTrackOrder(_trackingController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF673AB7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Track'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickTrackButton(
                  'Recent Orders',
                  Icons.history,
                  const Color(0xFF2196F3),
                  () => _showRecentOrders(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickTrackButton(
                  'Scan QR Code',
                  Icons.qr_code_scanner,
                  const Color(0xFF4CAF50),
                  () => _scanQRCode(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTrackButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _searchAndTrackOrder(String query) {
    if (query.trim().isEmpty) {
      _showSnackBar('Please enter an Order ID or Tracking Number', Colors.orange);
      return;
    }

    try {
      // Check if it's a number (Order ID) or string (Tracking Number)
      final orderId = int.tryParse(query.trim());
      
      if (orderId != null) {
        // Navigate with Order ID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingPage(orderId: orderId),
          ),
        );
      } else {
        // Navigate with Tracking Number
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingPage(trackingNumber: query.trim()),
          ),
        );
      }
    } catch (e) {
      print('❌ Error searching order: $e');
      _showSnackBar('❌ Error searching order: ${e.toString()}', Colors.red);
    }
  }

  void _showRecentOrders() async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch recent orders for the logged-in distributor
      final recentOrders = await TrackingService.getRecentOrders(
        limit: 15,
        distributorId: userId, // Pass the logged-in distributor's ID
      );
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show recent orders dialog
      showDialog(
        context: context,
        builder: (context) => _buildRecentOrdersDialog(recentOrders),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      
      // Show error
      _showSnackBar('Failed to load recent orders: $e', Colors.red);
    }
  }

  Widget _buildRecentOrdersDialog(List<Map<String, dynamic>> orders) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Color(0xFF2196F3),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'My Recent Orders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Color(0xFF2196F3),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap on any order to start tracking',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Orders list
            Expanded(
              child: orders.isEmpty
                  ? _buildEmptyRecentOrders()
                  : ListView.separated(
                      itemCount: orders.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _buildRecentOrderItem(order);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecentOrders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Recent Orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent orders will appear here for quick tracking',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrderItem(Map<String, dynamic> order) {
    final status = order['delivery_status'] ?? order['status'] ?? 'pending';
    final statusColor = TrackingService.getStatusColor(status);
    final createdAt = DateTime.parse(order['created_at']);
    
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close dialog
        _navigateToTracking(order['id']);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order['id']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (order['tracking_number'] != null)
                        Text(
                          order['tracking_number'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(int.parse('0xFF${statusColor.substring(1)}')).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    TrackingService.formatTrackingStatus(status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(int.parse('0xFF${statusColor.substring(1)}')),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Details row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order['customer_name'] != null)
                        Text(
                          order['customer_name'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      Text(
                        '\$${order['total_amount']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      TrackingService.formatTimeAgo(createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _scanQRCode() {
    // Implement QR code scanning for tracking
    _showSnackBar('QR Code scanning feature coming soon', Colors.blue);
  }

  // Helper methods to extract real performance data
  String _getAvgDeliveryTime() {
    print('🔍 _getAvgDeliveryTime called - performanceMetrics: $performanceMetrics');
    if (performanceMetrics.isEmpty) {
      print('🔍 _getAvgDeliveryTime - performanceMetrics is empty, returning N/A');
      return 'N/A';
    }
    
    final avgTime = performanceMetrics['avgDeliveryTime'];
    print('🔍 _getAvgDeliveryTime - avgTime: $avgTime');
    if (avgTime != null && avgTime['hours'] != null) {
      final result = '${avgTime['hours']} hrs';
      print('🔍 _getAvgDeliveryTime - returning: $result');
      return result;
    }
    print('🔍 _getAvgDeliveryTime - avgTime is null or hours is null, returning N/A');
    return 'N/A';
  }

  String _getDeliveryTimeTrend() {
    if (performanceMetrics.isEmpty) return 'No data';
    
    final avgTime = performanceMetrics['avgDeliveryTime'];
    if (avgTime != null && avgTime['trend'] != null) {
      final trend = avgTime['trend'];
      if (trend > 0) {
        return '+${trend.toStringAsFixed(1)}% slower';
      } else if (trend < 0) {
        return '${trend.toStringAsFixed(1)}% faster';
      } else {
        return 'No change';
      }
    }
    return 'No data';
  }

  String _getOnTimeRate() {
    if (performanceMetrics.isEmpty) return 'N/A';
    
    final onTimeRate = performanceMetrics['onTimeRate'];
    if (onTimeRate != null && onTimeRate['percentage'] != null) {
      return '${onTimeRate['percentage']}%';
    }
    return 'N/A';
  }

  String _getOnTimeTrend() {
    if (performanceMetrics.isEmpty) return 'No data';
    
    final onTimeRate = performanceMetrics['onTimeRate'];
    if (onTimeRate != null && onTimeRate['trend'] != null) {
      final trend = onTimeRate['trend'];
      if (trend > 0) {
        return '+${trend.toStringAsFixed(1)}% better';
      } else if (trend < 0) {
        return '${trend.toStringAsFixed(1)}% worse';
      } else {
        return 'No change';
      }
    }
    return 'No data';
  }

  String _getEfficiencyScore() {
    if (performanceMetrics.isEmpty) return 'N/A';
    
    final efficiency = performanceMetrics['efficiencyScore'];
    if (efficiency != null && efficiency['score'] != null) {
      return '${efficiency['score']}/10';
    }
    return 'N/A';
  }

  String _getEfficiencyTrend() {
    if (performanceMetrics.isEmpty) return 'No data';
    
    final efficiency = performanceMetrics['efficiencyScore'];
    if (efficiency != null && efficiency['trend'] != null) {
      final trend = efficiency['trend'];
      if (trend > 0) {
        return '+${trend.toStringAsFixed(1)}% better';
      } else if (trend < 0) {
        return '${trend.toStringAsFixed(1)}% worse';
      } else {
        return 'No change';
      }
    }
    return 'No data';
  }

  String _getCostPerDelivery() {
    if (performanceMetrics.isEmpty) return 'N/A';
    
    final cost = performanceMetrics['costPerDelivery'];
    if (cost != null && cost['cost'] != null) {
      return '\$${cost['cost'].toStringAsFixed(2)}';
    }
    return 'N/A';
  }

  String _getCostTrend() {
    if (performanceMetrics.isEmpty) return 'No data';
    
    final cost = performanceMetrics['costPerDelivery'];
    if (cost != null && cost['trend'] != null) {
      final trend = cost['trend'];
      if (trend > 0) {
        return '+${trend.toStringAsFixed(1)}% higher';
      } else if (trend < 0) {
        return '${trend.toStringAsFixed(1)}% lower';
      } else {
        return 'No change';
      }
    }
    return 'No data';
  }
}
