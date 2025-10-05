import 'dart:convert';
import 'package:http/http.dart' as http;

class TrackingService {
  static const String baseUrl = "http://10.0.2.2:5000/api/tracking";

  // Get order tracking information
  static Future<Map<String, dynamic>?> getOrderTracking(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/order/$orderId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ? data['data'] : null;
      } else {
        print('Failed to get order tracking. Status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting order tracking: $e');
      return null;
    }
  }

  // Get tracking by tracking number
  static Future<Map<String, dynamic>?> getTrackingByNumber(String trackingNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/track/$trackingNumber'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ? data['data'] : null;
      } else {
        print('Failed to get tracking by number. Status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting tracking by number: $e');
      return null;
    }
  }

  // Update tracking status
  static Future<bool> updateTrackingStatus({
    required int orderId,
    required String status,
    double? locationLat,
    double? locationLng,
    String? locationAddress,
    String? notes,
    int? updatedBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/order/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status,
          'location_lat': locationLat,
          'location_lng': locationLng,
          'location_address': locationAddress,
          'notes': notes,
          'updated_by': updatedBy,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating tracking status: $e');
      return false;
    }
  }

  // Update delivery location (real-time)
  static Future<bool> updateDeliveryLocation({
    required int deliveryAssignmentId,
    required double latitude,
    required double longitude,
    required int deliveryManId,
    double? accuracy,
    double? speed,
    double? heading,
    double? altitude,
    int? batteryLevel,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delivery/$deliveryAssignmentId/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'delivery_man_id': deliveryManId,
          'accuracy': accuracy,
          'speed': speed,
          'heading': heading,
          'altitude': altitude,
          'battery_level': batteryLevel,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating delivery location: $e');
      return false;
    }
  }

  // Get delivery man's current orders
  static Future<List<Map<String, dynamic>>> getDeliveryManOrders(int deliveryManId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/delivery-man/$deliveryManId/orders'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting delivery man orders: $e');
      return [];
    }
  }

  // Get recent orders for quick tracking (filtered by distributor)
  static Future<List<Map<String, dynamic>>> getRecentOrders({
    int limit = 10, 
    int? distributorId
  }) async {
    try {
      String url = '$baseUrl/recent-orders?limit=$limit';
      if (distributorId != null) {
        url += '&distributorId=$distributorId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting recent orders: $e');
      return [];
    }
  }

  // Get delivery analytics
  static Future<Map<String, dynamic>?> getDeliveryAnalytics({int timeframeDays = 7}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics?timeframe=$timeframeDays'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ? data['data'] : null;
      }
      return null;
    } catch (e) {
      print('Error getting delivery analytics: $e');
      return null;
    }
  }

  // Format tracking status for display
  static String formatTrackingStatus(String status) {
    switch (status.toLowerCase()) {
      case 'order_placed':
        return 'Order Placed';
      case 'confirmed':
        return 'Order Confirmed';
      case 'processing':
        return 'Processing';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'assigned':
        return 'Assigned to Delivery';
      case 'picked_up':
        return 'Picked Up';
      case 'in_transit':
        return 'In Transit';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'failed':
        return 'Delivery Failed';
      default:
        return status.replaceAll('_', ' ').split(' ').map((word) => 
          word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
        ).join(' ');
    }
  }

  // Get status color
  static String getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'order_placed':
      case 'confirmed':
        return '#2196F3'; // Blue
      case 'processing':
      case 'ready_for_pickup':
        return '#FF9800'; // Orange
      case 'assigned':
      case 'picked_up':
      case 'in_transit':
      case 'out_for_delivery':
        return '#4CAF50'; // Green
      case 'delivered':
        return '#8BC34A'; // Light Green
      case 'cancelled':
      case 'failed':
        return '#F44336'; // Red
      default:
        return '#757575'; // Grey
    }
  }

  // Calculate estimated delivery time
  static DateTime? calculateEstimatedDelivery(Map<String, dynamic> trackingData) {
    try {
      if (trackingData['delivery'] != null) {
        final estimatedTime = trackingData['delivery']['estimated_delivery_time'];
        if (estimatedTime != null) {
          return DateTime.parse(estimatedTime);
        }
      }
      
      // Fallback calculation based on order creation time
      final orderCreatedAt = trackingData['order']['created_at'];
      if (orderCreatedAt != null) {
        final createdTime = DateTime.parse(orderCreatedAt);
        // Add default 2-3 hours for delivery
        return createdTime.add(const Duration(hours: 3));
      }
      
      return null;
    } catch (e) {
      print('Error calculating estimated delivery: $e');
      return null;
    }
  }

  // Get tracking progress percentage
  static double getTrackingProgress(Map<String, dynamic> trackingData) {
    try {
      if (trackingData['progress'] != null) {
        return (trackingData['progress']['percentage'] ?? 0).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Error getting tracking progress: $e');
      return 0.0;
    }
  }

  // Check if order is trackable
  // Order Lifecycle: Order Created (pending) → Accepted → Delivered
  static bool isOrderTrackable(String status) {
    const trackableStatuses = [
      'pending',
      'accepted', 
      'delivered',
      // Legacy statuses for backward compatibility
      'confirmed',
      'processing',
      'ready_for_pickup',
      'assigned',
      'picked_up',
      'in_transit',
      'out_for_delivery'
    ];
    return trackableStatuses.contains(status.toLowerCase());
  }

  // Get next expected status
  // Order Lifecycle: Order Created (pending) → Accepted → Delivered
  static String? getNextExpectedStatus(String currentStatus) {
    const statusFlow = {
      'pending': 'accepted',
      'accepted': 'delivered',
      'order_placed': 'accepted',  // Legacy support
      'confirmed': 'delivered',    // Legacy support
      'processing': 'delivered',   // Legacy support
      'assigned': 'delivered',     // Legacy support
    };
    
    return statusFlow[currentStatus.toLowerCase()];
  }

  // Format time ago
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // Format duration
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}
