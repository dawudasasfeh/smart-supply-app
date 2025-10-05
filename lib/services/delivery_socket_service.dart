import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';

class DeliverySocketService {
  static IO.Socket? _socket;
  static bool _isConnected = false;
  
  // Stream controllers for real-time events
  static final StreamController<Map<String, dynamic>> _deliveryAssignedController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _statusUpdateController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _locationUpdateController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _newAssignmentController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream getters
  static Stream<Map<String, dynamic>> get deliveryAssignedStream => 
      _deliveryAssignedController.stream;
  static Stream<Map<String, dynamic>> get statusUpdateStream => 
      _statusUpdateController.stream;
  static Stream<Map<String, dynamic>> get locationUpdateStream => 
      _locationUpdateController.stream;
  static Stream<Map<String, dynamic>> get newAssignmentStream => 
      _newAssignmentController.stream;

  /// Initialize Socket.IO connection for delivery updates
  static void initializeDeliverySocket({
    required int userId,
    required String userName,
    required String userRole,
  }) {
    try {
      print('🔌 Initializing delivery Socket.IO connection...');
      
      _socket = IO.io(
        AppConfig.baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      // Connection events
      _socket!.onConnect((_) {
        _isConnected = true;
        print('✅ Connected to delivery Socket.IO server');
        
        // Join user-specific rooms
        _socket!.emit('join', {
          'id': userId,
          'name': userName,
          'role': userRole,
        });
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        print('❌ Disconnected from delivery Socket.IO server');
      });

      _socket!.onConnectError((error) {
        _isConnected = false;
        print('❌ Delivery Socket.IO connection error: $error');
      });

      // Delivery-specific event listeners
      _setupDeliveryEventListeners();

      // Connect to server
      _socket!.connect();
      
    } catch (e) {
      print('❌ Error initializing delivery socket: $e');
    }
  }

  /// Set up delivery-specific event listeners
  static void _setupDeliveryEventListeners() {
    if (_socket == null) return;

    // Listen for delivery assignments
    _socket!.on('delivery_assigned', (data) {
      print('📦 Delivery assigned event received: $data');
      _deliveryAssignedController.add(Map<String, dynamic>.from(data));
    });

    // Listen for assignment creation (for distributors)
    _socket!.on('assignment_created', (data) {
      print('📋 Assignment created event received: $data');
      _deliveryAssignedController.add(Map<String, dynamic>.from(data));
    });

    // Listen for new assignments (for delivery men)
    _socket!.on('new_assignment', (data) {
      print('🚚 New assignment for delivery man: $data');
      _newAssignmentController.add(Map<String, dynamic>.from(data));
    });

    // Listen for delivery status changes
    _socket!.on('delivery_status_changed', (data) {
      print('📦 Delivery status changed: $data');
      _statusUpdateController.add(Map<String, dynamic>.from(data));
    });

    // Listen for order status updates (for customers)
    _socket!.on('order_status_update', (data) {
      print('📱 Order status update: $data');
      _statusUpdateController.add(Map<String, dynamic>.from(data));
    });

    // Listen for location updates
    _socket!.on('delivery_location_update', (data) {
      print('📍 Delivery location update: $data');
      _locationUpdateController.add(Map<String, dynamic>.from(data));
    });

    // Listen for general delivery updates
    _socket!.on('delivery_update', (data) {
      print('🔄 General delivery update: $data');
      _statusUpdateController.add(Map<String, dynamic>.from(data));
    });
  }

  /// Emit delivery status update
  static void emitStatusUpdate({
    required int orderId,
    required String status,
    int? deliveryManId,
    double? latitude,
    double? longitude,
    String? locationName,
    String? notes,
    String? estimatedArrival,
  }) {
    if (_socket == null || !_isConnected) {
      print('❌ Socket not connected, cannot emit status update');
      return;
    }

    try {
      final data = {
        'order_id': orderId,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (deliveryManId != null) data['delivery_man_id'] = deliveryManId;
      if (latitude != null && longitude != null) {
        data['location'] = {'latitude': latitude, 'longitude': longitude};
      }
      if (locationName != null) data['location_name'] = locationName;
      if (notes != null) data['notes'] = notes;
      if (estimatedArrival != null) data['estimated_arrival'] = estimatedArrival;

      _socket!.emit('delivery_status_update', data);
      print('📤 Emitted delivery status update: $data');
    } catch (e) {
      print('❌ Error emitting status update: $e');
    }
  }

  /// Emit location update
  static void emitLocationUpdate({
    required int deliveryManId,
    required int orderId,
    required double latitude,
    required double longitude,
    String? address,
  }) {
    if (_socket == null || !_isConnected) {
      print('❌ Socket not connected, cannot emit location update');
      return;
    }

    try {
      final data = {
        'delivery_man_id': deliveryManId,
        'order_id': orderId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (address != null) data['address'] = address;

      _socket!.emit('location_update', data);
      print('📤 Emitted location update: $data');
    } catch (e) {
      print('❌ Error emitting location update: $e');
    }
  }

  /// Emit delivery assignment notification
  static void emitDeliveryAssigned({
    required int orderId,
    required int deliveryManId,
    required String deliveryManName,
    required String customerName,
    required String deliveryAddress,
    String priority = 'medium',
  }) {
    if (_socket == null || !_isConnected) {
      print('❌ Socket not connected, cannot emit delivery assignment');
      return;
    }

    try {
      final data = {
        'order_id': orderId,
        'delivery_man_id': deliveryManId,
        'delivery_man_name': deliveryManName,
        'customer_name': customerName,
        'delivery_address': deliveryAddress,
        'priority': priority,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _socket!.emit('delivery_assigned', data);
      print('📤 Emitted delivery assignment: $data');
    } catch (e) {
      print('❌ Error emitting delivery assignment: $e');
    }
  }

  /// Check connection status
  static bool get isConnected => _isConnected;

  /// Get socket instance
  static IO.Socket? get socket => _socket;

  /// Reconnect to server
  static void reconnect() {
    if (_socket != null) {
      print('🔄 Reconnecting to delivery Socket.IO server...');
      _socket!.connect();
    }
  }

  /// Disconnect from server
  static void disconnect() {
    if (_socket != null) {
      print('🔌 Disconnecting from delivery Socket.IO server...');
      _socket!.disconnect();
      _isConnected = false;
    }
  }

  /// Dispose resources
  static void dispose() {
    disconnect();
    _deliveryAssignedController.close();
    _statusUpdateController.close();
    _locationUpdateController.close();
    _newAssignmentController.close();
    _socket = null;
  }

  /// Listen to specific delivery events with callback
  static void listenToDeliveryEvents({
    Function(Map<String, dynamic>)? onDeliveryAssigned,
    Function(Map<String, dynamic>)? onStatusUpdate,
    Function(Map<String, dynamic>)? onLocationUpdate,
    Function(Map<String, dynamic>)? onNewAssignment,
  }) {
    if (onDeliveryAssigned != null) {
      deliveryAssignedStream.listen(onDeliveryAssigned);
    }
    
    if (onStatusUpdate != null) {
      statusUpdateStream.listen(onStatusUpdate);
    }
    
    if (onLocationUpdate != null) {
      locationUpdateStream.listen(onLocationUpdate);
    }
    
    if (onNewAssignment != null) {
      newAssignmentStream.listen(onNewAssignment);
    }
  }

  /// Format delivery event for display
  static String formatDeliveryEvent(Map<String, dynamic> event) {
    final eventType = event['type'] ?? 'update';
    final orderId = event['order_id'] ?? 'Unknown';
    final status = event['status'] ?? 'unknown';
    
    switch (eventType) {
      case 'assignment':
        return 'Order #$orderId assigned to delivery';
      case 'status_update':
        return 'Order #$orderId status: ${status.toString().replaceAll('_', ' ')}';
      case 'location_update':
        return 'Delivery location updated for order #$orderId';
      default:
        return 'Delivery update for order #$orderId';
    }
  }

  /// Get event icon based on type
  static String getEventIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'assignment':
        return '📦';
      case 'status_update':
        return '🔄';
      case 'location_update':
        return '📍';
      case 'delivered':
        return '✅';
      case 'cancelled':
        return '❌';
      default:
        return '📱';
    }
  }
}
