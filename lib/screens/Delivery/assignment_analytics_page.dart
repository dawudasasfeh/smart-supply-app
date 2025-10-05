import 'package:flutter/material.dart';
import '../../services/delivery_api_service.dart';
import '../../theme/app_colors.dart';

class AssignmentAnalyticsPage extends StatefulWidget {
  final int userId;
  final String userRole;

  const AssignmentAnalyticsPage({
    Key? key,
    required this.userId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<AssignmentAnalyticsPage> createState() => _AssignmentAnalyticsPageState();
}

class _AssignmentAnalyticsPageState extends State<AssignmentAnalyticsPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String _selectedPeriod = '7days';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    try {
      final response = await DeliveryApiService.getEnhancedAnalytics();
      
      if (mounted) {
        setState(() {
          _analytics = response['analytics'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading analytics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load analytics data');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingScreen() : _buildAnalyticsContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Assignment Analytics',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: AppColors.primary,
      elevation: 0,
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() => _selectedPeriod = value);
            _loadAnalyticsData();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: '7days',
              child: Row(
                children: [
                  Icon(Icons.calendar_view_week, color: _selectedPeriod == '7days' ? AppColors.primary : Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Last 7 Days'),
                ],
              ),
            ),
            PopupMenuItem(
              value: '30days',
              child: Row(
                children: [
                  Icon(Icons.calendar_view_month, color: _selectedPeriod == '30days' ? AppColors.primary : Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Last 30 Days'),
                ],
              ),
            ),
            PopupMenuItem(
              value: '90days',
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: _selectedPeriod == '90days' ? AppColors.primary : Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Last 90 Days'),
                ],
              ),
            ),
          ],
          icon: const Icon(Icons.date_range, color: Colors.white),
        ),
        IconButton(
          onPressed: _loadAnalyticsData,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading analytics data...'),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKPICards(),
              const SizedBox(height: 24),
              _buildPerformanceChart(),
              const SizedBox(height: 24),
              _buildEfficiencyMetrics(),
              const SizedBox(height: 24),
              _buildRecommendations(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPICards() {
    final analytics = _analytics ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Performance Indicators',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                'Total Assignments',
                '${analytics['total_assignments'] ?? 0}',
                Icons.assignment,
                Colors.blue,
                '+12%',
                true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKPICard(
                'Success Rate',
                '${((analytics['delivery_success_rate'] ?? 0) * 100).toInt()}%',
                Icons.check_circle,
                Colors.green,
                '+5%',
                true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                'Avg Time',
                '${analytics['average_delivery_time'] ?? 0}m',
                Icons.timer,
                Colors.orange,
                '-8%',
                false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKPICard(
                'Efficiency',
                '${((analytics['efficiency_score'] ?? 0) * 100).toInt()}%',
                Icons.trending_up,
                Colors.purple,
                '+15%',
                true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color, String change, bool isPositive) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: Container(
            padding: const EdgeInsets.all(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive ? Icons.trending_up : Icons.trending_down,
                            color: isPositive ? Colors.green : Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            change,
                            style: TextStyle(
                              color: isPositive ? Colors.green : Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceChart() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assignment Performance Trend',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedPeriod == '7days' ? 'Weekly' : _selectedPeriod == '30days' ? 'Monthly' : 'Quarterly',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _buildTrendChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final data = _selectedPeriod == '7days' 
        ? [85, 88, 92, 89, 94, 91, 96]
        : _selectedPeriod == '30days'
            ? [82, 85, 88, 91, 89, 93, 95, 92, 96, 94, 97, 95, 98, 96, 99]
            : [78, 82, 85, 88, 91, 94, 96, 98];
    
    final labels = _selectedPeriod == '7days'
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : _selectedPeriod == '30days'
            ? List.generate(15, (i) => '${i + 1}')
            : ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5', 'Week 6', 'Week 7', 'Week 8'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.asMap().entries.map((entry) {
        final index = entry.key;
        final value = entry.value;
        final height = (value / 100) * 150;
        final isHighlight = index == data.length - 1;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isHighlight)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$value%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isHighlight) const SizedBox(height: 4),
            Container(
              width: _selectedPeriod == '30days' ? 15 : 25,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isHighlight 
                      ? [AppColors.primary, AppColors.primary.withOpacity(0.7)]
                      : [Colors.grey[300]!, Colors.grey[200]!],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              labels[index],
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEfficiencyMetrics() {
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
            'Efficiency Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildEfficiencyItem('Route Optimization', 94, Colors.green),
          const SizedBox(height: 16),
          _buildEfficiencyItem('Time Management', 87, Colors.blue),
          const SizedBox(height: 16),
          _buildEfficiencyItem('Resource Allocation', 91, Colors.orange),
          const SizedBox(height: 16),
          _buildEfficiencyItem('Customer Satisfaction', 96, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildEfficiencyItem(String title, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildRecommendations() {
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
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Recommendations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRecommendationItem(
            'Optimize morning deliveries',
            'Consider starting deliveries 30 minutes earlier to avoid traffic',
            Icons.schedule,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildRecommendationItem(
            'Improve route clustering',
            'Group nearby orders to reduce travel time by 15%',
            Icons.route,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildRecommendationItem(
            'Balance workload',
            'Redistribute orders to prevent delivery man overload',
            Icons.balance,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String title, String description, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
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
