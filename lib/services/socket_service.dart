import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SocketService {
  static SocketService? _instance;
  static SocketService get instance => _instance ??= SocketService._();
  
  SocketService._();
  
  IO.Socket? _socket;
  bool _isConnected = false;
  
  // Stream controllers for real-time events
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _onlineStatusController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageStatusController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _orderController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _deliveryController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Getters for streams
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get onlineStatusStream => _onlineStatusController.stream;
  Stream<Map<String, dynamic>> get messageStatusStream => _messageStatusController.stream;
  Stream<Map<String, dynamic>> get orderStream => _orderController.stream;
  Stream<Map<String, dynamic>> get deliveryStream => _deliveryController.stream;
  
  bool get isConnected => _isConnected;
  
  Future<void> connect() async {
    if (_isConnected) return;
    
    try {
      print('Attempting to connect to Socket.IO server...');
      _socket = IO.io('${ApiService.imageBaseUrl}', <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': false,
        'forceNew': true,
        'timeout': 20000,
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionAttempts': 5,
      });
      
      _socket!.onConnect((_) {
        print('✅ Connected to Socket.IO server successfully');
        _isConnected = true;
        _joinWithUserData();
      });
      
      _socket!.onDisconnect((_) {
        print('❌ Disconnected from Socket.IO server');
        _isConnected = false;
      });
      
      _socket!.onConnectError((data) {
        print('❌ Connection error: $data');
        _isConnected = false;
      });
      
      _socket!.onError((data) {
        print('❌ Socket error: $data');
      });
      
      // Setup event listeners before connecting
      _setupEventListeners();
      
      // Connect to the server
      _socket!.connect();
      
    } catch (e) {
      print('❌ Socket connection error: $e');
      _isConnected = false;
    }
  }
  
  void _setupEventListeners() {
    if (_socket == null) return;
    
    print('Setting up Socket.IO event listeners...');
    
    // Listen for incoming messages (only once)
    _socket!.on('receive_message', (data) {
      if (!_messageController.isClosed) {
        _messageController.add(Map<String, dynamic>.from(data));
      }
    });
    
    // Listen for message sent confirmation
    _socket!.on('message_sent', (data) {
      print('Message sent confirmation: $data');
      if (!_messageStatusController.isClosed) {
        _messageStatusController.add({
          'type': 'sent',
          'data': Map<String, dynamic>.from(data)
        });
      }
    });
    
    _socket!.on('message_read', (data) {
      if (!_messageStatusController.isClosed) {
        _messageStatusController.add({
          'type': 'read',
          'data': Map<String, dynamic>.from(data)
        });
      }
    });
    
    // Listen for typing indicators
    _socket!.on('user_typing', (data) {
      if (!_typingController.isClosed) {
        _typingController.add(Map<String, dynamic>.from(data));
      }
    });
    
    // Listen for online status changes
    _socket!.on('user_online', (data) {
      if (!_onlineStatusController.isClosed) {
        _onlineStatusController.add({
          'type': 'online',
          'data': Map<String, dynamic>.from(data)
        });
      }
    });
    
    _socket!.on('user_offline', (data) {
      if (!_onlineStatusController.isClosed) {
        _onlineStatusController.add({
          'type': 'offline',
          'data': Map<String, dynamic>.from(data)
        });
      }
    });
    
    // Listen for errors
    _socket!.on('message_error', (data) {
      if (!_messageStatusController.isClosed) {
        _messageStatusController.add({
          'type': 'error',
          'data': Map<String, dynamic>.from(data)
        });
      }
    });
    
    // Listen for order events
    _socket!.on('new_order', (data) {
      print('New order received: $data');
      if (!_orderController.isClosed) {
        _orderController.add({
          'type': 'new_order',
          'data': Map<String, dynamic>.from(data)
        });
      }
    });
    
    _socket!.on('order_updated', (data) {
      print('Order updated: $data');
      if (!_orderController.isClosed) {
        _orderController.add({
          'type': 'order_updated',
          'data': Map<String, dynamic>.from(data)
        });
      }
    });
    
    _socket!.on('order_assigned', (data) {
      print('Order assigned: $data');
      if (!_orderController.isClosed) {
        _orderController.add({
          'type': 'order_assigned',
          'data': Map<String, dynamic>.from(data)
        });
      }
    });
    
    // Listen for delivery events
    _socket!.on('delivery_status_updated', (data) {
      print('Delivery status updated: $data');
      if (!_deliveryController.isClosed) {
        _deliveryController.add({
          'type': 'delivery_status_updated',
          'data': Map<String, dynamic>.from(data)
        });
      }
    });
    
    _socket!.on('delivery_assigned', (data) {
      print('Delivery assigned: $data');
      if (!_deliveryController.isClosed) {
        _deliveryController.add({
          'type': 'delivery_assigned',
          'data': Map<String, dynamic>.from(data)
        });
      }
    });
  }
  
  Future<void> _joinWithUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final role = prefs.getString('role');
    final name = prefs.getString('name') ?? 'User';
    
    if (userId != null && role != null) {
      _socket!.emit('join', {
        'userId': userId,
        'role': role,
        'name': name,
      });
    }
  }
  
  void sendMessage({
    required int senderId,
    required int receiverId,
    required String message,
    required String senderRole,
    required String receiverRole,
  }) {
    if (!_isConnected || _socket == null) {
      print('Socket not connected');
      return;
    }
    
    _socket!.emit('send_message', {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'senderRole': senderRole,
      'receiverRole': receiverRole,
    });
  }
  
  void markMessageAsRead(int messageId) {
    if (!_isConnected || _socket == null) return;
    
    _socket!.emit('mark_read', messageId);
  }
  
  void sendTypingIndicator(int receiverId, bool isTyping) {
    if (!_isConnected || _socket == null) return;
    
    _socket!.emit('typing', {
      'receiverId': receiverId,
      'isTyping': isTyping,
    });
  }
  
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
    _isConnected = false;
  }
  
  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _onlineStatusController.close();
    _messageStatusController.close();
    _orderController.close();
    _deliveryController.close();
  }
}
