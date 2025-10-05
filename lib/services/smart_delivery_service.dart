import 'dart:math';
import 'api_service.dart';

class SmartDeliveryService {
  // Instance method for performing smart assignment
  Future<List<Map<String, dynamic>>> performSmartAssignment(
    List<Map<String, dynamic>> pendingOrders,
    List<Map<String, dynamic>> availableDeliveryMen,
  ) async {
    List<Map<String, dynamic>> assignments = [];
    
    if (pendingOrders.isEmpty || availableDeliveryMen.isEmpty) {
      return assignments;
    }

    // Sort delivery men by current workload and rating
    availableDeliveryMen.sort((a, b) {
      int workloadA = a['current_orders'] ?? 0;
      int workloadB = b['current_orders'] ?? 0;
      if (workloadA != workloadB) {
        return workloadA.compareTo(workloadB);
      }
      // If workload is same, prefer higher rated delivery men
      double ratingA = a['rating'] ?? 0.0;
      double ratingB = b['rating'] ?? 0.0;
      return ratingB.compareTo(ratingA);
    });

    List<Map<String, dynamic>> remainingOrders = List.from(pendingOrders);

    for (var deliveryMan in availableDeliveryMen) {
      if (remainingOrders.isEmpty) break;

      int maxCapacity = deliveryMan['max_capacity'] ?? 3;
      int currentOrders = deliveryMan['current_orders'] ?? 0;
      int availableCapacity = maxCapacity - currentOrders;

      if (availableCapacity <= 0) continue;

      // Get delivery man's location
      double deliveryLat = _parseCoordinate(deliveryMan['latitude']);
      double deliveryLon = _parseCoordinate(deliveryMan['longitude']);

      // Find best orders for this delivery man
      List<Map<String, dynamic>> bestOrders = _findOptimalOrders(
        remainingOrders,
        deliveryLat,
        deliveryLon,
        availableCapacity,
      );

      if (bestOrders.isNotEmpty) {
        for (var order in bestOrders) {
          double orderLat = _parseCoordinate(order['delivery_latitude']);
          double orderLon = _parseCoordinate(order['delivery_longitude']);
          double distance = calculateDistance(deliveryLat, deliveryLon, orderLat, orderLon);
          
          assignments.add({
            'orderId': order['id'],
            'deliveryManId': deliveryMan['id'],
            'estimatedTime': _calculateEstimatedTime(distance),
            'priority': _calculatePriority(order, distance),
            'distance': distance,
          });
        }

        // Remove assigned orders
        for (var order in bestOrders) {
          remainingOrders.removeWhere((o) => o['id'] == order['id']);
        }
      }
    }

    return assignments;
  }

  double _parseCoordinate(dynamic coord) {
    if (coord == null) return 0.0;
    if (coord is double) return coord;
    if (coord is int) return coord.toDouble();
    if (coord is String) return double.tryParse(coord) ?? 0.0;
    return 0.0;
  }

  List<Map<String, dynamic>> _findOptimalOrders(
    List<Map<String, dynamic>> orders,
    double deliveryLat,
    double deliveryLon,
    int maxOrders,
  ) {
    if (orders.isEmpty) return [];

    // Calculate distances and sort
    List<Map<String, dynamic>> ordersWithDistance = orders.map((order) {
      double orderLat = _parseCoordinate(order['delivery_latitude']);
      double orderLon = _parseCoordinate(order['delivery_longitude']);
      double distance = calculateDistance(deliveryLat, deliveryLon, orderLat, orderLon);
      
      return {
        ...order,
        'calculated_distance': distance,
      };
    }).toList();

    // Sort by distance and priority
    ordersWithDistance.sort((a, b) {
      double distanceA = a['calculated_distance'];
      double distanceB = b['calculated_distance'];
      return distanceA.compareTo(distanceB);
    });

    return ordersWithDistance.take(maxOrders).toList();
  }

  int _calculateEstimatedTime(double distance) {
    // Base time calculation: 15 min per km + 10 min handling time
    return ((distance * 15) + 10).round();
  }

  String _calculatePriority(Map<String, dynamic> order, double distance) {
    // Priority based on order value and distance
    double orderValue = _parseCoordinate(order['total_amount']);
    
    if (orderValue > 100 && distance < 5) return 'high';
    if (orderValue > 50 || distance < 10) return 'medium';
    return 'low';
  }

  // Calculate distance between two points using Haversine formula
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Smart assignment algorithm
  static Future<Map<String, dynamic>> assignOrdersToDeliveryMen() async {
    try {
      // Fetch pending orders and available delivery personnel
      final pendingOrders = await ApiService.getPendingOrders();
      final deliveryMen = await ApiService.getDeliveryMenWithLocation();
      
      if (pendingOrders.isEmpty || deliveryMen.isEmpty) {
        return {
          'success': false,
          'message': 'No pending orders or available delivery personnel',
          'assignments': []
        };
      }

      List<Map<String, dynamic>> assignments = [];
      List<Map<String, dynamic>> unassignedOrders = List.from(pendingOrders);

      // Sort delivery men by current workload (ascending)
      deliveryMen.sort((a, b) => (a['current_orders'] ?? 0).compareTo(b['current_orders'] ?? 0));

      for (var deliveryMan in deliveryMen) {
        if (unassignedOrders.isEmpty) break;

        double deliveryLat = deliveryMan['latitude'] ?? 0.0;
        double deliveryLon = deliveryMan['longitude'] ?? 0.0;
        int maxCapacity = deliveryMan['max_capacity'] ?? 5;
        int currentOrders = deliveryMan['current_orders'] ?? 0;
        int availableCapacity = maxCapacity - currentOrders;

        if (availableCapacity <= 0) continue;

        // Find nearest orders for this delivery person
        List<Map<String, dynamic>> nearestOrders = _findNearestOrders(
          unassignedOrders, 
          deliveryLat, 
          deliveryLon, 
          availableCapacity
        );

        if (nearestOrders.isNotEmpty) {
          // Create assignment
          Map<String, dynamic> assignment = {
            'delivery_man_id': deliveryMan['id'],
            'delivery_man_name': deliveryMan['name'],
            'delivery_man_phone': deliveryMan['phone'],
            'current_location': {
              'latitude': deliveryLat,
              'longitude': deliveryLon,
              'address': deliveryMan['current_address'] ?? 'Unknown'
            },
            'assigned_orders': nearestOrders,
            'total_distance': _calculateTotalRouteDistance(nearestOrders, deliveryLat, deliveryLon),
            'estimated_time': _estimateDeliveryTime(nearestOrders.length),
            'assignment_timestamp': DateTime.now().toIso8601String(),
          };

          assignments.add(assignment);

          // Remove assigned orders from unassigned list
          for (var order in nearestOrders) {
            unassignedOrders.removeWhere((o) => o['id'] == order['id']);
          }

          // Update delivery man's workload in backend
          await _updateDeliveryManWorkload(deliveryMan['id'], nearestOrders);
        }
      }

      return {
        'success': true,
        'message': 'Smart assignment completed',
        'assignments': assignments,
        'unassigned_orders': unassignedOrders,
        'total_assigned': assignments.fold(0, (sum, a) => sum + (a['assigned_orders'] as List).length),
        'total_unassigned': unassignedOrders.length,
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Assignment failed: $e',
        'assignments': []
      };
    }
  }

  // Find nearest orders within reasonable distance
  static List<Map<String, dynamic>> _findNearestOrders(
    List<Map<String, dynamic>> orders,
    double deliveryLat,
    double deliveryLon,
    int maxOrders
  ) {
    // Calculate distance for each order and sort by proximity
    List<Map<String, dynamic>> ordersWithDistance = orders.map((order) {
      double orderLat = order['delivery_latitude'] ?? 0.0;
      double orderLon = order['delivery_longitude'] ?? 0.0;
      double distance = calculateDistance(deliveryLat, deliveryLon, orderLat, orderLon);
      
      return {
        ...order,
        'distance_km': distance,
      };
    }).toList();

    // Sort by distance (nearest first)
    ordersWithDistance.sort((a, b) => a['distance_km'].compareTo(b['distance_km']));

    // Apply clustering logic - group nearby orders
    List<Map<String, dynamic>> clusteredOrders = _clusterNearbyOrders(
      ordersWithDistance, 
      maxOrders
    );

    return clusteredOrders.take(maxOrders).toList();
  }

  // Cluster nearby orders to optimize routes
  static List<Map<String, dynamic>> _clusterNearbyOrders(
    List<Map<String, dynamic>> orders,
    int maxOrders
  ) {
    if (orders.isEmpty) return [];

    List<Map<String, dynamic>> clustered = [];
    List<Map<String, dynamic>> remaining = List.from(orders);
    
    // Start with the nearest order
    clustered.add(remaining.removeAt(0));

    while (clustered.length < maxOrders && remaining.isNotEmpty) {
      Map<String, dynamic>? bestNext;
      double bestScore = double.infinity;

      // Find the order that minimizes total route distance
      for (var order in remaining) {
        double score = _calculateRouteScore(clustered, order);
        if (score < bestScore) {
          bestScore = score;
          bestNext = order;
        }
      }

      if (bestNext != null) {
        clustered.add(bestNext);
        remaining.remove(bestNext);
      } else {
        break;
      }
    }

    return clustered;
  }

  // Calculate route optimization score
  static double _calculateRouteScore(List<Map<String, dynamic>> currentOrders, Map<String, dynamic> newOrder) {
    if (currentOrders.isEmpty) return newOrder['distance_km'];

    double totalDistance = 0;
    
    // Calculate distance from last order to new order
    var lastOrder = currentOrders.last;
    double lastLat = lastOrder['delivery_latitude'] ?? 0.0;
    double lastLon = lastOrder['delivery_longitude'] ?? 0.0;
    double newLat = newOrder['delivery_latitude'] ?? 0.0;
    double newLon = newOrder['delivery_longitude'] ?? 0.0;
    
    totalDistance += calculateDistance(lastLat, lastLon, newLat, newLon);
    
    // Penalize if too far from cluster center
    double avgLat = currentOrders.fold(0.0, (sum, o) => sum + (o['delivery_latitude'] ?? 0.0)) / currentOrders.length;
    double avgLon = currentOrders.fold(0.0, (sum, o) => sum + (o['delivery_longitude'] ?? 0.0)) / currentOrders.length;
    
    double distanceFromCenter = calculateDistance(avgLat, avgLon, newLat, newLon);
    
    return totalDistance + (distanceFromCenter * 0.5); // Weight center proximity
  }

  // Calculate total route distance
  static double _calculateTotalRouteDistance(List<Map<String, dynamic>> orders, double startLat, double startLon) {
    if (orders.isEmpty) return 0.0;

    double totalDistance = 0.0;
    double currentLat = startLat;
    double currentLon = startLon;

    for (var order in orders) {
      double orderLat = order['delivery_latitude'] ?? 0.0;
      double orderLon = order['delivery_longitude'] ?? 0.0;
      
      totalDistance += calculateDistance(currentLat, currentLon, orderLat, orderLon);
      currentLat = orderLat;
      currentLon = orderLon;
    }

    return totalDistance;
  }

  // Estimate delivery time based on number of orders and distance
  static int _estimateDeliveryTime(int orderCount) {
    // Base time: 15 minutes per order + 5 minutes travel time per order
    return (orderCount * 20) + 30; // Additional 30 minutes buffer
  }

  // Update delivery man workload in backend
  static Future<void> _updateDeliveryManWorkload(int deliveryManId, List<Map<String, dynamic>> assignedOrders) async {
    try {
      await ApiService.updateDeliveryManWorkload(deliveryManId, assignedOrders);
    } catch (e) {
      print('Failed to update delivery man workload: $e');
    }
  }

  // Get delivery performance analytics
  static Future<Map<String, dynamic>> getDeliveryAnalytics() async {
    try {
      final analytics = await ApiService.getDeliveryAnalytics();
      
      return {
        'total_deliveries_today': analytics['total_deliveries_today'] ?? 0,
        'average_delivery_time': analytics['average_delivery_time'] ?? 0,
        'on_time_percentage': analytics['on_time_percentage'] ?? 0.0,
        'active_delivery_men': analytics['active_delivery_men'] ?? 0,
        'pending_orders': analytics['pending_orders'] ?? 0,
        'completed_orders': analytics['completed_orders'] ?? 0,
        'total_distance_covered': analytics['total_distance_covered'] ?? 0.0,
        'efficiency_score': _calculateEfficiencyScore(analytics),
      };
    } catch (e) {
      return {
        'total_deliveries_today': 0,
        'average_delivery_time': 0,
        'on_time_percentage': 0.0,
        'active_delivery_men': 0,
        'pending_orders': 0,
        'completed_orders': 0,
        'total_distance_covered': 0.0,
        'efficiency_score': 0.0,
      };
    }
  }

  // Calculate overall delivery efficiency score
  static double _calculateEfficiencyScore(Map<String, dynamic> analytics) {
    double onTimeScore = (analytics['on_time_percentage'] ?? 0.0) * 0.4;
    double speedScore = _calculateSpeedScore(analytics['average_delivery_time'] ?? 0) * 0.3;
    double utilizationScore = _calculateUtilizationScore(analytics) * 0.3;
    
    return (onTimeScore + speedScore + utilizationScore).clamp(0.0, 100.0);
  }

  static double _calculateSpeedScore(int avgTime) {
    // Optimal time is 30 minutes per delivery
    if (avgTime <= 30) return 100.0;
    if (avgTime >= 60) return 0.0;
    return ((60 - avgTime) / 30) * 100;
  }

  static double _calculateUtilizationScore(Map<String, dynamic> analytics) {
    int active = analytics['active_delivery_men'] ?? 0;
    int total = analytics['total_delivery_men'] ?? 1;
    return (active / total) * 100;
  }
}
