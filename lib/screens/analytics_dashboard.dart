import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  bool _isLoading = true;
  String? token;
  List<DemandData> _demandData = [];
  List<InventoryData> _inventoryData = [];
  Map<String, dynamic> _kpiData = {};
  List<dynamic> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    
    if (token != null) {
      await _loadAnalyticsData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    
    try {
      if (token != null) {
        // Load analytics data from backend
        final analyticsData = await ApiService.getAnalyticsData(token!, 'supermarket');
        
        // Parse the response and update state
        _kpiData = analyticsData['kpis'] ?? {};
        _demandData = _parseDemandData(analyticsData['demandForecast'] ?? []);
        _inventoryData = _parseInventoryData(analyticsData['inventoryLevels'] ?? []);
        _alerts = analyticsData['alerts'] ?? [];
      } else {
        // No token - show empty state
        _demandData = [];
        _inventoryData = [];
        _kpiData = {};
        _alerts = [];
      }
      
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      // Show empty state on error instead of mock data
      _demandData = [];
      _inventoryData = [];
      _kpiData = {};
      _alerts = [];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<DemandData> _parseDemandData(List<dynamic> data) {
    if (data.isEmpty) return [];
    
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return DemandData(index, (item['demand'] ?? 0).toDouble());
    }).toList();
  }

  List<InventoryData> _parseInventoryData(List<dynamic> data) {
    if (data.isEmpty) return [];
    
    return data.map((item) => InventoryData(
      item['product'] ?? 'Unknown',
      item['stock'] ?? 0,
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalyticsData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKPICards(),
                    const SizedBox(height: 24),
                    _buildDemandForecastChart(),
                    const SizedBox(height: 24),
                    _buildInventoryLevelsChart(),
                    const SizedBox(height: 24),
                    _buildSupplierPerformanceChart(),
                    const SizedBox(height: 24),
                    _buildRecentAlerts(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKPICards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildKPICard('Total Orders', '${_kpiData['totalOrders']}', Icons.shopping_cart, AppColors.primaryGradient)),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('Revenue', '\$${_kpiData['revenue']}', Icons.attach_money, AppColors.successGradient)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKPICard('Low Stock Items', '${_kpiData['lowStock']}', Icons.warning, const LinearGradient(colors: [AppColors.warning, Color(0xFFFF8C00)]))),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('Avg Delivery Time', '${_kpiData['avgDelivery']} hrs', Icons.local_shipping, const LinearGradient(colors: [AppColors.info, Color(0xFF1E90FF)]))),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, LinearGradient gradient) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 8,
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
              Icon(icon, color: Colors.white, size: 24),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandForecastChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Demand Forecast',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'AI Powered',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 50,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (value.toInt() >= 0 && value.toInt() < days.length) {
                            return Text(
                              days[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _demandData.map((data) => FlSpot(data.day.toDouble(), data.demand)).toList(),
                      isCurved: true,
                      gradient: AppColors.primaryGradient,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryGradient.colors.first.withOpacity(0.3),
                            AppColors.primaryGradient.colors.last.withOpacity(0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryLevelsChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory Levels',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1000,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _inventoryData.length) {
                            return Text(
                              _inventoryData[value.toInt()].product,
                              style: const TextStyle(fontSize: 8),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: _inventoryData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data.stock.toDouble(),
                          gradient: data.stock < 100 
                              ? const LinearGradient(colors: [AppColors.error, Color(0xFFFF6B6B)])
                              : data.stock < 300
                                  ? const LinearGradient(colors: [AppColors.warning, Color(0xFFFFD93D)])
                                  : AppColors.successGradient,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierPerformanceChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supplier Performance',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: AppColors.success,
                      value: 65,
                      title: 'Excellent\n65%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppColors.info,
                      value: 25,
                      title: 'Good\n25%',
                      radius: 55,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppColors.warning,
                      value: 10,
                      title: 'Average\n10%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlerts() {
    final alertItems = _alerts.map((alert) {
      return AlertItem(
        alert['title'] ?? 'Alert',
        alert['description'] ?? 'No description',
        _getAlertColor(alert['type'] ?? 'info'),
        _getAlertIcon(alert['type'] ?? 'info'),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Alerts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ...alertItems.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: alert.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(alert.icon, color: alert.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          alert.description,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getAlertColor(String type) {
    switch (type.toLowerCase()) {
      case 'warning':
        return AppColors.warning;
      case 'error':
      case 'danger':
        return AppColors.error;
      case 'success':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'warning':
        return Icons.warning;
      case 'error':
      case 'danger':
        return Icons.error;
      case 'success':
        return Icons.check_circle;
      case 'delivery':
        return Icons.local_shipping;
      case 'inventory':
        return Icons.inventory;
      case 'demand':
        return Icons.trending_up;
      default:
        return Icons.info;
    }
  }

}

class DemandData {
  final int day;
  final double demand;

  DemandData(this.day, this.demand);
}

class InventoryData {
  final String product;
  final int stock;

  InventoryData(this.product, this.stock);
}

class AlertItem {
  final String title;
  final String description;
  final Color color;
  final IconData icon;

  AlertItem(this.title, this.description, this.color, this.icon);
}
