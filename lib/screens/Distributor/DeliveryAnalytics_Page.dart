import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/smart_delivery_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class DeliveryAnalyticsPage extends StatefulWidget {
  const DeliveryAnalyticsPage({super.key});

  @override
  State<DeliveryAnalyticsPage> createState() => _DeliveryAnalyticsPageState();
}

class _DeliveryAnalyticsPageState extends State<DeliveryAnalyticsPage> with TickerProviderStateMixin {
  bool isLoading = true;
  Map<String, dynamic> analyticsData = {};
  List<Map<String, dynamic>> deliveryMenPerformance = [];
  List<Map<String, dynamic>> dailyStats = [];
  String selectedPeriod = 'week';
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => isLoading = true);
    
    try {
      final analytics = await SmartDeliveryService.getDeliveryAnalytics();
      final performance = await _getDeliveryMenPerformance();
      final daily = await _getDailyStats();
      
      // Calculate average rating from delivery men performance
      double averageRating = 0.0;
      if (performance.isNotEmpty) {
        final totalRating = performance.fold<double>(0.0, (sum, deliveryMan) {
          final rating = deliveryMan['rating'] as double? ?? 0.0;
          return sum + rating;
        });
        averageRating = totalRating / performance.length;
      }
      
      // Add calculated average rating to analytics data
      final updatedAnalytics = Map<String, dynamic>.from(analytics);
      updatedAnalytics['average_rating'] = averageRating;
      
      setState(() {
        analyticsData = updatedAnalytics;
        deliveryMenPerformance = performance;
        dailyStats = daily;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to load analytics data');
    }
  }

  Future<List<Map<String, dynamic>>> _getDeliveryMenPerformance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }
      
      // Fetch actual delivery men data from API
      final deliveryMen = await ApiService.getAvailableDeliveryMen();
      
      if (deliveryMen.isNotEmpty) {
        
        // Fetch rating data for each delivery man
        final List<Map<String, dynamic>> performanceData = [];
        
        for (final deliveryMan in deliveryMen) {
          try {
            // Get rating summary for this delivery man
            final ratingSummary = await ApiService.getRatingSummary(token, deliveryMan['id'], 'delivery');
            double averageRating = 0.0;
            
            if (ratingSummary.isNotEmpty) {
              final deliveryRating = ratingSummary.firstWhere(
                (s) => s['rating_type'] == 'delivery_rating',
                orElse: () => null,
              );
              if (deliveryRating != null) {
                averageRating = double.tryParse(deliveryRating['average_rating']?.toString() ?? '0') ?? 0.0;
              }
            }
            
            performanceData.add({
              'id': deliveryMan['id'],
              'name': deliveryMan['name'] ?? 'Unknown',
              'deliveries_completed': deliveryMan['deliveries_completed'] ?? 0,
              'average_time': deliveryMan['average_delivery_time'] ?? 0,
              'on_time_rate': deliveryMan['on_time_rate'] ?? 0.0,
              'distance_covered': deliveryMan['total_distance_covered'] ?? 0.0,
              'rating': averageRating,
              'efficiency_score': deliveryMan['efficiency_score'] ?? 0.0,
            });
          } catch (e) {
            print('Error fetching rating for delivery man ${deliveryMan['id']}: $e');
            // Add delivery man with 0 rating if rating fetch fails
            performanceData.add({
              'id': deliveryMan['id'],
              'name': deliveryMan['name'] ?? 'Unknown',
              'deliveries_completed': deliveryMan['deliveries_completed'] ?? 0,
              'average_time': deliveryMan['average_delivery_time'] ?? 0,
              'on_time_rate': deliveryMan['on_time_rate'] ?? 0.0,
              'distance_covered': deliveryMan['total_distance_covered'] ?? 0.0,
              'rating': 0.0,
              'efficiency_score': deliveryMan['efficiency_score'] ?? 0.0,
            });
          }
        }
        
        return performanceData;
      } else {
        throw Exception('Failed to fetch delivery men data');
      }
    } catch (e) {
      print('Error fetching delivery men performance: $e');
      _showErrorSnackBar('Failed to load delivery men performance data');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getDailyStats() async {
    // Mock data for the last 7 days
    return List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      return {
        'date': date.toIso8601String().split('T')[0],
        'deliveries': 15 + math.Random().nextInt(20),
        'on_time': 12 + math.Random().nextInt(8),
        'delayed': 2 + math.Random().nextInt(3),
        'average_time': 25 + math.Random().nextInt(15),
      };
    });
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
                      _buildKPICards(),
                      _buildPeriodSelector(),
                      _buildTabContent(),
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
        title: const Text(
          'Delivery Analytics',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple,
                Colors.purple.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadAnalyticsData,
        ),
        IconButton(
          icon: const Icon(Icons.download, color: Colors.white),
          onPressed: () {
            // Export analytics report
          },
        ),
      ],
    );
  }

  Widget _buildKPICards() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _buildKPICard(
            'Total Deliveries',
            analyticsData['total_deliveries_today']?.toString() ?? '0',
            Icons.local_shipping,
            Colors.blue,
            '+12% from yesterday',
          ),
          _buildKPICard(
            'Avg Delivery Time',
            '${analyticsData['average_delivery_time'] ?? 0} min',
            Icons.timer,
            Colors.orange,
            '-5 min from last week',
          ),
          _buildKPICard(
            'On-Time Rate',
            '${(analyticsData['on_time_percentage'] ?? 0.0).toStringAsFixed(1)}%',
            Icons.schedule,
            Colors.green,
            '+2.3% improvement',
          ),
          _buildKPICard(
            'Efficiency Score',
            '${(analyticsData['efficiency_score'] ?? 0.0).toStringAsFixed(1)}%',
            Icons.trending_up,
            Colors.purple,
            'Excellent performance',
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color, String trend) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.trending_up, color: Colors.green, size: 16),
            ],
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trend,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Period: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          ...['day', 'week', 'month'].map((period) => 
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(period.toUpperCase()),
                selected: selectedPeriod == period,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => selectedPeriod = period);
                    _loadAnalyticsData();
                  }
                },
                selectedColor: AppColors.primary.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: selectedPeriod == period ? AppColors.primary : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ).toList(),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return Container(
      margin: const EdgeInsets.all(16),
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
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Performance'),
              Tab(text: 'Trends'),
              Tab(text: 'Delivery Men'),
            ],
          ),
          SizedBox(
            height: 500,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPerformanceTab(),
                _buildTrendsTab(),
                _buildDeliveryMenTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildPerformanceChart(),
          const SizedBox(height: 20),
          _buildPerformanceMetrics(),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Delivery Performance Over Time',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: dailyStats.map((stat) => _buildChartBar(stat)).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: dailyStats.map((stat) => 
              Text(
                DateTime.parse(stat['date']).day.toString(),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(Map<String, dynamic> stat) {
    final deliveries = stat['deliveries'] as int;
    final maxHeight = 120.0;
    final height = (deliveries / 35) * maxHeight;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          deliveries.toString(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          width: 20,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.6)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics() {
    return Column(
      children: [
        _buildMetricRow('Total Distance Covered', '${analyticsData['total_distance_covered'] ?? 0.0} km'),
        _buildMetricRow('Active Delivery Men', '${analyticsData['active_delivery_men'] ?? 0}'),
        _buildMetricRow('Completed Orders', '${analyticsData['completed_orders'] ?? 0}'),
        _buildMetricRow('Average Rating', '${analyticsData['average_rating']?.toStringAsFixed(1) ?? '0.0'} ⭐'),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Trends',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildTrendCard('Peak Hours', '2:00 PM - 4:00 PM', Icons.schedule, Colors.orange),
          _buildTrendCard('Busiest Day', 'Thursday', Icons.calendar_today, Colors.blue),
          _buildTrendCard('Average Distance', '12.5 km per delivery', Icons.location_on, Colors.red),
          _buildTrendCard('Success Rate', '94.2% deliveries completed', Icons.check_circle, Colors.green),
        ],
      ),
    );
  }

  Widget _buildTrendCard(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMenTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Personnel Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: deliveryMenPerformance.length,
              itemBuilder: (context, index) {
                final performer = deliveryMenPerformance[index];
                return _buildDeliveryManCard(performer);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryManCard(Map<String, dynamic> performer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  performer['name'].toString().substring(0, 2).toUpperCase(),
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      performer['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${performer['rating']}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getEfficiencyColor(performer['efficiency_score']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${performer['efficiency_score'].toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _getEfficiencyColor(performer['efficiency_score']),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceMetric(
                  'Deliveries',
                  performer['deliveries_completed'].toString(),
                  Icons.local_shipping,
                ),
              ),
              Expanded(
                child: _buildPerformanceMetric(
                  'Avg Time',
                  '${performer['average_time']} min',
                  Icons.timer,
                ),
              ),
              Expanded(
                child: _buildPerformanceMetric(
                  'On-Time',
                  '${performer['on_time_rate'].toStringAsFixed(1)}%',
                  Icons.schedule,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Color _getEfficiencyColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.orange;
    return Colors.red;
  }
}
