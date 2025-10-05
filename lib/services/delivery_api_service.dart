import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class DeliveryApiService {
  static const String baseUrl = AppConfig.baseUrl;
  
  // ============================================================================
  // DELIVERY MEN ENDPOINTS
  // ============================================================================
  
  /// Get all available delivery men - optionally filtered by distributor
  static Future<Map<String, dynamic>> getDeliveryMen({int? distributorId}) async {
    try {
      print('🚚 Fetching delivery men${distributorId != null ? ' for distributor $distributorId' : ''}...');
      
      String url = '$baseUrl/api/delivery/men';
      if (distributorId != null) {
        url += '?distributorId=$distributorId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Delivery men fetched: ${data['count'] ?? 0} found${distributorId != null ? ' for distributor $distributorId' : ''}');
        return data;
      } else {
        throw Exception('Failed to load delivery men: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching delivery men: $e');
      rethrow;
    }
  }

  /// Get delivery man performance by ID
  static Future<Map<String, dynamic>> getDeliveryManPerformance(int deliveryManId) async {
    try {
      print('📊 Fetching performance for delivery man $deliveryManId...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/delivery/performance/$deliveryManId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Performance data fetched for delivery man $deliveryManId');
        return data;
      } else {
        throw Exception('Failed to load performance data: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching performance data: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ORDER MANAGEMENT ENDPOINTS
  // ============================================================================
  
  /// Get pending orders (unassigned) - optionally filtered by distributor
  static Future<Map<String, dynamic>> getPendingOrders({int? distributorId}) async {
    try {
      print('📦 Fetching pending orders${distributorId != null ? ' for distributor $distributorId' : ''}...');
      
      String url = '$baseUrl/api/delivery/pending';
      if (distributorId != null) {
        url += '?distributorId=$distributorId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Pending orders fetched: ${data['data']?.length ?? 0} found${distributorId != null ? ' for distributor $distributorId' : ''}');
        return data;
      } else {
        throw Exception('Failed to load pending orders: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching pending orders: $e');
      rethrow;
    }
  }

  /// Get active deliveries - optionally filtered by distributor
  static Future<Map<String, dynamic>> getActiveDeliveries({int? distributorId}) async {
    try {
      print('🚛 Fetching active deliveries${distributorId != null ? ' for distributor $distributorId' : ''}...');
      
      String url = '$baseUrl/api/delivery/active';
      if (distributorId != null) {
        url += '?distributorId=$distributorId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Active deliveries fetched: ${data['count'] ?? 0} found${distributorId != null ? ' for distributor $distributorId' : ''}');
        return data;
      } else {
        throw Exception('Failed to load active deliveries: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching active deliveries: $e');
      rethrow;
    }
  }

  /// Get completed deliveries
  static Future<Map<String, dynamic>> getCompletedDeliveries() async {
    try {
      print('✅ Fetching completed deliveries...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/delivery/completed'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Completed deliveries fetched: ${data['count'] ?? 0} found');
        return data;
      } else {
        throw Exception('Failed to load completed deliveries: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching completed deliveries: $e');
      rethrow;
    }
  }

  /// Get orders by distributor ID
  static Future<Map<String, dynamic>> getDistributorOrders(int distributorId, {String? status}) async {
    try {
      print('📋 Fetching orders for distributor $distributorId...');
      
      String url = '$baseUrl/api/delivery/distributor-orders/$distributorId';
      if (status != null) {
        url += '?status=$status';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Distributor orders fetched: ${data['count'] ?? 0} found');
        return data;
      } else {
        throw Exception('Failed to load distributor orders: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching distributor orders: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ASSIGNMENT ENDPOINTS
  // ============================================================================
  
  /// Assign single order to delivery man
  static Future<Map<String, dynamic>> assignOrder({
    required int orderId,
    required int deliveryManId,
    String priority = 'medium',
  }) async {
    try {
      print('📦 Assigning order $orderId to delivery man $deliveryManId...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/delivery/assign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'order_id': orderId,
          'delivery_man_id': deliveryManId,
          'priority': priority,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Order $orderId assigned successfully');
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to assign order');
      }
    } catch (e) {
      print('❌ Error assigning order: $e');
      rethrow;
    }
  }

  /// Bulk assign multiple orders
  static Future<Map<String, dynamic>> bulkAssignOrders(List<Map<String, int>> assignments) async {
    try {
      print('📦 Bulk assigning ${assignments.length} orders...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/delivery/bulk-assign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'assignments': assignments,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Bulk assignment completed: ${data['summary']['successful']} successful');
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to bulk assign orders');
      }
    } catch (e) {
      print('❌ Error in bulk assignment: $e');
      rethrow;
    }
  }

  /// Smart assignment using AI algorithm
  static Future<Map<String, dynamic>> performSmartAssignment({int? distributorId}) async {
    try {
      print('🤖 Performing smart assignment...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/delivery/smart-assign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'distributorId': distributorId ?? 4}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Smart assignment completed: ${data['count'] ?? 0} orders assigned');
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Smart assignment failed');
      }
    } catch (e) {
      print('❌ Error in smart assignment: $e');
      rethrow;
    }
  }

  // ============================================================================
  // STATUS UPDATE ENDPOINTS
  // ============================================================================
  
  /// Update delivery status
  static Future<Map<String, dynamic>> updateDeliveryStatus({
    required int orderId,
    required String status,
    double? latitude,
    double? longitude,
    String? notes,
    String? locationName,
  }) async {
    try {
      print('📍 Updating delivery status for order $orderId to $status...');
      
      final body = {
        'order_id': orderId,
        'status': status,
        'notes': notes ?? '',
        'location_name': locationName ?? '',
      };

      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/delivery/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Status updated successfully for order $orderId');
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      print('❌ Error updating status: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ANALYTICS ENDPOINTS
  // ============================================================================
  
  /// Get basic delivery analytics
  static Future<Map<String, dynamic>> getDeliveryAnalytics() async {
    try {
      print('📊 Fetching delivery analytics...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/delivery/analytics'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Analytics fetched successfully');
        return data;
      } else {
        throw Exception('Failed to load analytics: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching analytics: $e');
      rethrow;
    }
  }

  /// Get enhanced analytics for dashboard
  static Future<Map<String, dynamic>> getEnhancedAnalytics() async {
    try {
      print('📈 Fetching enhanced delivery analytics...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/delivery/enhanced-analytics'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Enhanced analytics fetched successfully');
        return data;
      } else {
        throw Exception('Failed to load enhanced analytics: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching enhanced analytics: $e');
      rethrow;
    }
  }

  /// Get delivery statistics for dashboard
  static Future<Map<String, dynamic>> getDeliveryStats() async {
    try {
      print('📊 Fetching delivery dashboard stats...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/delivery/stats'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Dashboard stats fetched successfully');
        return data;
      } else {
        throw Exception('Failed to load dashboard stats: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching dashboard stats: $e');
      rethrow;
    }
  }

  // ============================================================================
  // TRACKING ENDPOINTS
  // ============================================================================
  
  /// Get delivery history for an order
  static Future<Map<String, dynamic>> getDeliveryHistory(int orderId) async {
    try {
      print('📋 Fetching delivery history for order $orderId...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/delivery/history/$orderId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Delivery history fetched: ${data['count'] ?? 0} entries');
        return data;
      } else {
        throw Exception('Failed to load delivery history: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching delivery history: $e');
      rethrow;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================
  
  /// Check delivery system health
  static Future<Map<String, dynamic>> checkSystemHealth() async {
    try {
      print('🏥 Checking delivery system health...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/delivery/health'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ System health check passed');
        return data;
      } else {
        throw Exception('System health check failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error checking system health: $e');
      rethrow;
    }
  }

  /// Format delivery status for display
  static String formatDeliveryStatus(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return 'Assigned';
      case 'picked_up':
        return 'Picked Up';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }

  /// Get status color for UI
  static String getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return '#2196F3'; // Blue
      case 'picked_up':
        return '#FF9800'; // Orange
      case 'in_transit':
        return '#9C27B0'; // Purple
      case 'delivered':
        return '#4CAF50'; // Green
      case 'cancelled':
        return '#F44336'; // Red
      default:
        return '#757575'; // Grey
    }
  }

  /// Calculate delivery priority score
  static int getPriorityScore(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 2;
    }
  }

  /// Format time ago for display
  static String formatTimeAgo(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
