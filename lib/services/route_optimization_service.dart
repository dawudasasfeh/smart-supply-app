import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteOptimizationService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api/route-optimization';

  // Get authentication headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Create a new route optimization session
  static Future<Map<String, dynamic>> createOptimizationSession({
    required String sessionName,
    required int deliveryManId,
    required int distributorId,
    String algorithm = 'nearest_neighbor',
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/sessions'),
        headers: headers,
        body: jsonEncode({
          'sessionName': sessionName,
          'deliveryManId': deliveryManId,
          'distributorId': distributorId,
          'algorithm': algorithm,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to create optimization session: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating optimization session: $e');
      rethrow; // Let the error propagate to the UI
    }
  }


  /// Get orders for route optimization
  static Future<List<Map<String, dynamic>>> getOrdersForOptimization({
    required int deliveryManId,
    required int distributorId,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/orders/$deliveryManId/$distributorId'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to get orders for optimization: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting orders for optimization: $e');
      rethrow; // Let the error propagate to the UI
    }
  }


  /// Optimize route for a delivery man
  static Future<Map<String, dynamic>> optimizeRoute({
    required int sessionId,
    required int deliveryManId,
    required int distributorId,
    String algorithm = 'nearest_neighbor',
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/optimize'),
        headers: headers,
        body: jsonEncode({
          'sessionId': sessionId,
          'deliveryManId': deliveryManId,
          'distributorId': distributorId,
          'algorithm': algorithm,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to optimize route: ${response.statusCode}');
      }
    } catch (e) {
      print('Error optimizing route: $e');
      rethrow; // Let the error propagate to the UI
    }
  }



  /// Get optimization session details
  static Future<Map<String, dynamic>> getOptimizationSession(int sessionId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/sessions/$sessionId'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to get optimization session: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting optimization session: $e');
      rethrow; // Let the error propagate to the UI
    }
  }

  /// Get all optimization sessions for a user
  static Future<Map<String, dynamic>> getOptimizationSessions({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (status != null) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$_baseUrl/sessions').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get optimization sessions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting optimization sessions: $e');
      rethrow;
    }
  }

  /// Delete optimization session
  static Future<bool> deleteOptimizationSession(int sessionId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/sessions/$sessionId'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting optimization session: $e');
      return false;
    }
  }

  /// Get route optimization analytics
  static Future<Map<String, dynamic>> getOptimizationAnalytics({int period = 30}) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/analytics?period=$period'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to get optimization analytics: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting optimization analytics: $e');
      rethrow;
    }
  }

  /// Launch Google Maps with optimized route
  static Future<bool> launchGoogleMapsRoute(String googleMapsUrl) async {
    try {
      final uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        print('Could not launch Google Maps URL: $googleMapsUrl');
        return false;
      }
    } catch (e) {
      print('Error launching Google Maps: $e');
      return false;
    }
  }

  /// Generate Google Maps URL from waypoints
  static String generateGoogleMapsUrl(List<Map<String, dynamic>> waypoints) {
    if (waypoints.length < 2) return '';

    final origin = '${waypoints.first['latitude']},${waypoints.first['longitude']}';
    final destination = '${waypoints.last['latitude']},${waypoints.last['longitude']}';
    
    final waypointsParam = waypoints
        .skip(1)
        .take(waypoints.length - 2)
        .map((wp) => '${wp['latitude']},${wp['longitude']}')
        .join('|');

    if (waypointsParam.isNotEmpty) {
      return 'https://www.google.com/maps/dir/$origin/$waypointsParam/$destination';
    } else {
      return 'https://www.google.com/maps/dir/$origin/$destination';
    }
  }

  /// Calculate simple distance between two coordinates (Haversine formula)
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * asin(sqrt(a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  /// Format distance for display
  static String formatDistance(dynamic distanceKm) {
    double distance;
    if (distanceKm is num) {
      distance = distanceKm.toDouble();
    } else if (distanceKm is String) {
      distance = double.tryParse(distanceKm) ?? 0.0;
    } else {
      distance = 0.0;
    }
    
    if (distance < 1) {
      return '${(distance * 1000).round()} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }

  /// Format duration for display
  static String formatDuration(dynamic durationMinutes) {
    int duration;
    if (durationMinutes is num) {
      duration = durationMinutes.toInt();
    } else if (durationMinutes is String) {
      duration = int.tryParse(durationMinutes) ?? 0;
    } else {
      duration = 0;
    }
    
    if (duration < 60) {
      return '$duration min';
    } else {
      final hours = duration ~/ 60;
      final minutes = duration % 60;
      if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${minutes}m';
      }
    }
  }

  /// Get status color for optimization session
  static int getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0xFFF59E0B; // Amber
      case 'optimizing':
        return 0xFF3B82F6; // Blue
      case 'completed':
        return 0xFF10B981; // Green
      case 'failed':
        return 0xFFEF4444; // Red
      default:
        return 0xFF6B7280; // Gray
    }
  }

  /// Get status text for optimization session
  static String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'optimizing':
        return 'Optimizing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return 'Unknown';
    }
  }
}
