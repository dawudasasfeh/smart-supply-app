import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:5000/api"; // Android emulator localhost
  static const String flaskBaseUrl = 'http://10.0.2.2:5001';
  static const String imageBaseUrl = "http://10.0.2.2:5000"; // For image serving

  // Get distributor details
  static Future<Map<String, dynamic>?> getDistributor(int distributorId) async {
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/profile/$distributorId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
        print('Failed to get distributor details. Status code: ${response.statusCode}, Response: ${response.body}');
      return null;
    } catch (e) {
      print('Error getting distributor details: $e');
      return null;
    }
  }

  // 🔐 AUTH
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : null;
  }

static Future<Map<String, dynamic>?> signup(Map<String, dynamic> data) async {
  try {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 30));
    
    if (res.statusCode == 201) {
      return jsonDecode(res.body);
    } else {
      print('❌ Signup failed: ${res.statusCode}');
      print('💬 ${res.body}');
      return null;
    }
  } catch (e) {
    if (e.toString().contains('timeout')) {
      print('❌ Socket error: timeout');
      print('❌ Connection error: timeout');
      throw Exception('Connection timeout. Please check your internet connection and try again.');
    } else {
      print('❌ Signup error: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }
}

static Future<Map<String, dynamic>?> deleteAccount(String password) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final res = await http.delete(
      Uri.parse("$baseUrl/auth/delete-account"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"password": password}),
    ).timeout(const Duration(seconds: 30));
    
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      print('❌ Delete account failed: ${res.statusCode}');
      print('💬 ${res.body}');
      return null;
    }
  } catch (e) {
    print('❌ Delete account error: $e');
    throw Exception('Failed to delete account: ${e.toString()}');
  }
}

static Future<Map<String, dynamic>> fetchUserProfile(String token) async {
  try {
    print('🔗 Calling: $baseUrl/profile/me');
    print('🔑 Token: ${token.substring(0, 20)}...');
    
    final res = await http.get(
      Uri.parse('$baseUrl/profile/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    print('📡 Profile Response Status: ${res.statusCode}');
    print('📄 Profile Response Body: ${res.body}');
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      print('✅ Profile fetched successfully');
      return data;
    } else {
      print('❌ Profile API Error: ${res.statusCode} - ${res.body}');
      throw Exception('Failed to load profile: ${res.statusCode}');
    }
  } catch (e) {
    print('❌ Profile Network Error: $e');
    throw Exception('Network error: $e');
  }
}

static Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> data, String role) async {
  // Determine which endpoint to use based on the data being updated
  bool isRoleSpecificData = data.keys.any((key) => 
    ['address', 'company_name', 'store_name', 'latitude', 'longitude'].contains(key)
  );
  
  final endpoint = isRoleSpecificData ? '/profile/me/role-data' : '/profile/me';
  final url = Uri.parse('$baseUrl$endpoint');
  
  final res = await http.put(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(data),
  );
  
  if (res.statusCode != 200) {
    final errorBody = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    final errorMessage = errorBody['message'] ?? errorBody['error'] ?? 'Failed to update profile';
    throw Exception(errorMessage);
  }
  
  // Return the updated profile data
  final responseData = jsonDecode(res.body);
  return responseData['data'] ?? responseData;
}

// Update role-specific profile data
static Future<Map<String, dynamic>> updateRoleData(String token, Map<String, dynamic> roleData) async {
  final url = Uri.parse('$baseUrl/profile/me/role-data');
  final res = await http.put(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(roleData),
  );
  
  if (res.statusCode == 200) {
    final responseData = jsonDecode(res.body);
    return responseData['data'] ?? responseData;
  } else {
    final errorBody = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    final errorMessage = errorBody['message'] ?? errorBody['error'] ?? 'Failed to update role data';
    throw Exception(errorMessage);
  }
}

//GET ALL DISTRIBUTORS
  
static Future<List<Map<String, dynamic>>> getAllDistributors() async {
  final url = Uri.parse('$baseUrl/users?role=distributor&exclude=0');
  final res = await http.get(url);
  if (res.statusCode == 200) {
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  } else {
    throw Exception('Failed to fetch distributors');
  }
}

  // 📦 PRODUCTS

static Future<List<dynamic>> getProductsWithOffers({int? distributorId}) async {
  final query = distributorId != null ? '?withOffers=true&distributorId=$distributorId' : '?withOffers=true';
  final res = await http.get(Uri.parse('$baseUrl/products$query'));
  return res.statusCode == 200 ? jsonDecode(res.body) : [];
}

static Future<List<dynamic>> getDistributors() async {
  final res = await http.get(Uri.parse('$baseUrl/users?role=distributor'));
  return res.statusCode == 200 ? jsonDecode(res.body) : [];
}


static Future<List<dynamic>> getProducts(String token, {int? distributorId}) async {
  final queryParam = distributorId != null ? '?distributor_id=$distributorId' : '';
  final url = Uri.parse('$baseUrl/products$queryParam');
  final response = await http.get(
    url,
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    print('❌ Error fetching products: ${response.body}');
    throw Exception('Failed to fetch products');
  }
}



  static Future<bool> addProduct(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse("$baseUrl/products"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(data),
    );
  // Backend may return 200 or 201 on success depending on implementation
  return res.statusCode == 200 || res.statusCode == 201;
  }

  static Future<bool> addProductWithImage(String token, Map<String, dynamic> data, File imageFile) async {
    try {
      final dio = Dio();
      
      // Create FormData for multipart request
      final formData = FormData.fromMap({
        'name': data['name'],
        'description': data['description'] ?? '',
        'price': data['price'].toString(),
        'stock': data['stock'].toString(),
        'category': data['category'] ?? '',
        'brand': data['brand'] ?? '',
        'sku': data['sku'] ?? '',
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await dio.post(
        "$baseUrl/products/with-image",
        data: formData,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "multipart/form-data",
          },
        ),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error uploading product with image: $e');
      return false;
    }
  }

  static Future<bool> updateProduct(String token, int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse("$baseUrl/products/$id"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(data),
    );
    return res.statusCode == 200;
  }

  static Future<bool> updateProductWithImage(String token, int id, Map<String, dynamic> data, File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse("$baseUrl/products/$id/with-image"),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Add image file
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating product with image: $e');
      return false;
    }
  }

  static Future<bool> deleteProduct(String token, int id) async {
  final res = await http.delete(
    Uri.parse("$baseUrl/products/$id"),
    headers: {"Authorization": "Bearer $token"},
  );
  return res.statusCode == 204;
}


  // 🛒 ORDERS
static Future<Map<String, dynamic>?> placeMultiOrder({
  required String token,
  required int buyerId, // <-- Add this parameter
  required int distributorId,
  required List<Map<String, dynamic>> items,
}) async {
  final res = await http.post(
    Uri.parse('$baseUrl/orders/multi'),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "buyer_id": buyerId, // <-- Add this field
      "distributor_id": distributorId,
      "items": items,
    }),
  );

  return res.statusCode == 201 ? jsonDecode(res.body) : null;
}

static Future<List<dynamic>> getBuyerOrders(String token, int buyerId) async {
  try {
    print('🔗 Calling: $baseUrl/orders/buyer/$buyerId');
    print('🔑 Token: ${token.substring(0, 20)}...');
    
    final res = await http.get(
      Uri.parse('$baseUrl/orders/buyer/$buyerId'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );
    
    print('📡 Response Status: ${res.statusCode}');
    print('📄 Response Body: ${res.body}');
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      print('✅ Orders fetched: ${data.length} orders');
      return data;
    } else {
      print('❌ API Error: ${res.statusCode} - ${res.body}');
      return [];
    }
  } catch (e) {
    print('❌ Network Error: $e');
    return [];
  }
}

static Future<List<dynamic>> getDistributorOrders(String token, int distributorId) async {
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/orders/distributor/$distributorId'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final orders = List<Map<String, dynamic>>.from(data ?? []);
      return orders.map((order) => _sanitizeOrderData(order)).toList();
    }
    return [];
  } catch (e) {
    print('❌ Error fetching distributor orders: $e');
    return [];
  }
}

  static Future<bool> updateOrderStatus(String token, int id, String status) async {
    final res = await http.put(
      Uri.parse('$baseUrl/orders/$id/status'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"status": status}),
    );
    return res.statusCode == 200;
  }

  // Get order items/products for a specific order
  static Future<List<dynamic>> getOrderItems(int orderId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/orders/$orderId/items'),
        headers: await _getAuthHeaders(),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data;
        } else if (data is Map && data.containsKey('items')) {
          return List<dynamic>.from(data['items'] ?? []);
        } else if (data is Map && data.containsKey('data')) {
          return List<dynamic>.from(data['data'] ?? []);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching order items: $e');
      return [];
    }
  }

  // Get delivery information for an order
  static Future<Map<String, dynamic>?> getOrderDeliveryInfo(int orderId) async {
    try {
      print('🔍 API: Fetching delivery info for order $orderId from: $baseUrl/orders/$orderId/delivery');
      
      final res = await http.get(
        Uri.parse('$baseUrl/orders/$orderId/delivery'),
        headers: await _getAuthHeaders(),
      );

      print('🔍 API Response: Status ${res.statusCode}, Body: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          print('✅ API: Successfully parsed delivery info: ${data.keys.toList()}');
          return data;
        } else {
          print('❌ API: Response is not a Map<String, dynamic>: ${data.runtimeType}');
          return null;
        }
      } else {
        print('❌ API: Failed with status ${res.statusCode}: ${res.body}');
        return null;
      }
    } catch (e) {
      print('❌ API: Error fetching order delivery info: $e');
      return null;
    }
  }

  // Get QR code data for an order
  static Future<String?> getOrderQRCode(int orderId) async {
    try {
      // Get user info to get supermarket_id
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return null;
      
      final userData = jsonDecode(userDataString);
      final supermarketId = userData['id'];
      
      // Call the QR generation endpoint
      final res = await http.post(
        Uri.parse('$baseUrl/qr/generate'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'order_id': orderId,
          'supermarket_id': supermarketId,
        }),
      );

      if (res.statusCode == 200) {
        final response = jsonDecode(res.body);
        if (response['success'] == true && response['data'] != null) {
          // Return the QR data as JSON string
          return jsonEncode(response['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching order QR code: $e');
      return null;
    }
  }

  // Get product details by ID
  static Future<Map<String, dynamic>?> getProductDetails(int productId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/products/$productId'),
        headers: await _getAuthHeaders(),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? data : null;
      }
      return null;
    } catch (e) {
      print('Error fetching product details: $e');
      return null;
    }
  }


static Future<List<dynamic>> getSupermarketInventory(String token) async {
  final res = await http.get(
    Uri.parse("$baseUrl/inventory"),
    headers: {"Authorization": "Bearer $token"},
  );
  return res.statusCode == 200 ? jsonDecode(res.body) : [];
}
static Future<bool> updateStock({required String token,required int productId,required int quantitySold,}) async {
  final res = await http.post(
    Uri.parse('$baseUrl/products/$productId/update_stock'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'quantity_sold': quantitySold,
    }),
  );

  return res.statusCode == 200;
}

  // 🎁 OFFERS
  // Get offers
// Get all current offers (public)
  static Future<List<dynamic>> getOffers() async {
    final res = await http.get(Uri.parse('$baseUrl/offers'));
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }
// Get offers by distributor
  static Future<List<dynamic>> getOffersByDistributor(int distributorId) async {
  final res = await http.get(Uri.parse('$baseUrl/offers?distributorId=$distributorId'));
  return res.statusCode == 200 ? jsonDecode(res.body) : [];
}
  // Get offers created by the authenticated distributor
  static Future<List<dynamic>> getMyOffers(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/offers/mine'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  // Add a new offer
  static Future<bool> addOffer(String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/offers'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    print("🔍 Add Offer Request: ${jsonEncode(data)}");
    print("🔧 Status Code: ${response.statusCode}");
    print("💬 Body: ${response.body}");

    return response.statusCode == 201;
  }

  // Delete an offer
  static Future<bool> deleteOffer(String token, int offerId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/offers/$offerId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return res.statusCode == 204;
  }


  // 💬 MESSAGES (CHAT)
  static Future<List<dynamic>> fetchMessages(int senderId, int receiverId) async {
    final url = Uri.parse('$baseUrl/messages?senderId=$senderId&receiverId=$receiverId');
    final res = await http.get(url);
    return jsonDecode(res.body);
  }

  static Future<void> sendMessage({
    required int senderId,
    required int receiverId,
    required String senderRole,
    required String receiverRole,
    required String message,
  }) async {
    final url = Uri.parse('$baseUrl/messages');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'sender_role': senderRole,
        'receiver_role': receiverRole,
        'message': message,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to send message');
    }
  }

  static Future<void> startChat({
    required int senderId,
    required int receiverId,
    required String senderRole,
    required String receiverRole,
    required String message,
  }) async {
    final url = Uri.parse('$baseUrl/messages/start');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'sender_role': senderRole,
        'receiver_role': receiverRole,
        'message': message,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception("Failed to start chat");
    }
  }

 static Future<List<dynamic>> getChatPartners(int userId, String role) async {
  final url = Uri.parse('$baseUrl/messages/partners?userId=$userId&role=$role');
  final res = await http.get(url);
  print("PARTNER RESPONSE: ${res.body}");
  if (res.statusCode == 200) {
    return jsonDecode(res.body);
  } else {
    throw Exception("Failed to load chat partners");
  }
}
 static Future<List<dynamic>> fetchChatList(int userId) async {
    final uri = Uri.parse('$baseUrl/messages/partners')
        .replace(queryParameters: {'userId': userId.toString(), 'role': 'supermarket'}); // or 'distributor'

    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      print("⚠️ fetchChatList failed: ${res.statusCode} ${res.body}");
      throw Exception('Failed to fetch chat list');
    }
  }
  static Future<List<Map<String, dynamic>>> getAvailableChatPartners(int myId, String role) async {
    final opposite = role == 'supermarket' ? 'distributor' : 'supermarket';
    final url = Uri.parse('$baseUrl/users?role=$opposite&exclude=$myId');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    } else {
      throw Exception("Failed to fetch users");
    }
  }

  // New Socket.IO compatible chat methods
  static Future<List<dynamic>> getAvailableUsers(String role) async {
    final targetRole = _getTargetRole(role);
    final url = Uri.parse('$baseUrl/users?role=$targetRole');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to fetch available users");
    }
  }

  static Future<void> createConversation(int senderId, int receiverId, String senderRole, String receiverRole) async {
    final url = Uri.parse('$baseUrl/messages/conversation');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'sender_role': senderRole,
        'receiver_role': receiverRole,
      }),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Failed to create conversation');
    }
  }

  static Future<void> markAllMessagesAsRead(int myId, int partnerId) async {
    final url = Uri.parse('$baseUrl/messages/mark-all-read');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': myId,
        'partner_id': partnerId,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to mark messages as read');
    }
  }

  static String _getTargetRole(String role) {
    switch (role) {
      case 'supermarket':
        return 'distributor';
      case 'distributor':
        return 'supermarket';
      case 'delivery':
        return 'distributor';
      default:
        return 'user';
    }
  }
  // 📦 Get orders for delivery man
  static Future<List<dynamic>> getAssignedOrders(int deliveryId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/delivery/orders/$deliveryId'),
        headers: await _getAuthHeaders(),
      );

      if (res.statusCode != 200) return [];

      final decoded = jsonDecode(res.body);

      // Accept multiple possible shapes:
      // 1) plain array: [ {...}, ... ]
      // 2) wrapped object: { success: true, orders: [...] }
      // 3) wrapped object with deliveries/data keys
      if (decoded is List) return decoded;

      if (decoded is Map) {
        final list = decoded['orders'] ?? decoded['deliveries'] ?? decoded['data'] ?? [];
        if ((list is List && list.isEmpty) || list == null) {
          print('getAssignedOrders: received empty list or null from server. Raw body: ${res.body}');
        }
        return List<dynamic>.from(list);
      }

      return [];
    } catch (e) {
      print('Error fetching assigned orders: $e');
      return [];
    }
  }

  static Future<bool> assignOrderToDelivery(int orderId, int deliveryId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/delivery/assign'),
      headers: await _getAuthHeaders(),
      body: jsonEncode({"order_id": orderId, "delivery_id": deliveryId}),
    );
    return res.statusCode == 201 || res.statusCode == 200;
  }


// 🔄 Update delivery status
static Future<bool> updateDeliveryStatus({
  required int orderId,
  required int deliveryId,
  required String status,
}) async {
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/delivery/update-status'),
      headers: await _getAuthHeaders(),
      body: jsonEncode({
        "order_id": orderId,
        "status": status,
      }),
    );
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['success'] == true;
    }
    return false;
  } catch (e) {
    print('Error updating delivery status: $e');
    return false;
  }
}

static Future<bool> verifyDelivery(int deliveryId, String verificationCode) async {
  final res = await http.post(
    Uri.parse('$baseUrl/delivery/verify'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "delivery_id": deliveryId,
      "verification_code": verificationCode,
    }),
  );
  return res.statusCode == 200;
}

// QR Code verification for supermarket-delivery authentication
static Future<Map<String, dynamic>> verifyQRDelivery({
  required String verificationKey,
  required String supermarketId,
  required String orderId,
}) async {
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/qr/verify-delivery'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "verification_key": verificationKey,
        "supermarket_id": supermarketId,
        "order_id": orderId,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      }),
    );
    
    final responseData = jsonDecode(res.body);
    
    if (res.statusCode == 200) {
      return {
        'success': true,
        'message': responseData['message'] ?? 'QR code verified successfully',
        'data': responseData['data'] ?? {}
      };
    } else {
      print('❌ QR verification failed: ${res.statusCode} - ${res.body}');
      return {
        'success': false,
        'message': responseData['message'] ?? 'QR code verification failed',
        'error': responseData['error'] ?? 'Unknown error'
      };
    }
  } catch (e) {
    print('🔥 Exception in verifyQRDelivery: $e');
    return {
      'success': false,
      'message': 'Network error during QR verification',
      'error': e.toString()
    };
  }
}

static Future<Map<String, dynamic>?> placeMultiOrderWithQR(String token, Map<String, dynamic> data) async {
  try {
    final url = Uri.parse('$baseUrl/orders/multi');
    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (res.statusCode == 201) {
      final decoded = jsonDecode(res.body);
      print('✅ Order placed successfully: $decoded');
      return decoded;
    } else {
      print('❌ Order failed: ${res.statusCode} - ${res.body}');
      return null;
    }
  } catch (e) {
    print('🔥 Exception in placeMultiOrderWithQR: $e');
    return null;
  }
}

// ✅ Get all delivery men (legacy method)
static Future<List<Map<String, dynamic>>> getDeliveryMenUsers() async {
  final url = Uri.parse('$baseUrl/users?role=Delivery');
  final res = await http.get(url);

  if (res.statusCode == 200) {
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  } else {
    throw Exception('Failed to fetch delivery men');
  }
}

static Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
  final url = Uri.parse('$baseUrl/users?role=$role');
  final res = await http.get(url);
  if (res.statusCode == 200) {
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  } else {
    throw Exception("Failed to fetch users");
  }
}


  // 📊 DASHBOARD DATA

  /// Get dashboard statistics for distributor
  static Future<Map<String, dynamic>> getDistributorStats(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/dashboard/distributor/stats'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : {};
  }

  /// Get enhanced delivery analytics for distributor
  static Future<Map<String, dynamic>> getEnhancedDeliveryAnalytics(String token, int distributorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/distributor/delivery-analytics'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? {};
      }
      throw Exception('Failed to fetch delivery analytics');
    } catch (e) {
      print('Error fetching delivery analytics: $e');
      return {
        'activeDeliveries': 0,
        'pendingPickups': 0,
        'completedToday': 0,
        'totalDeliveries': 0,
        'avgDeliveryTime': 0,
        'onTimeRate': 0.0,
        'efficiencyScore': 0.0,
      };
    }
  }

  /// Get AI-powered suggestions for distributor
  static Future<List<Map<String, dynamic>>> getAISuggestions(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/distributor/ai-suggestions'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching AI suggestions: $e');
      return [];
    }
  }

  /// Get dashboard statistics for supermarket
  static Future<Map<String, dynamic>> getSupermarketStats(String token) async {
    try {
      print('🔗 Calling: $baseUrl/supermarket/stats');
      final res = await http.get(
        Uri.parse('$baseUrl/supermarket/stats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      print('📡 Response status: ${res.statusCode}');
      print('📄 Response body: ${res.body}');
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        print('❌ API Error: ${res.statusCode} - ${res.body}');
        return {};
      }
    } catch (e) {
      print('❌ Network Error: $e');
      return {};
    }
  }

  static Future<bool> restockProduct(String token, int productId, int quantity) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/supermarket/restock'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'product_id': productId,
          'quantity': quantity,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('Error restocking product: $e');
      return false;
    }
  }


  /// Get notifications for user
  static Future<List<dynamic>> getNotifications(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  /// Mark notification as read
  static Future<bool> markNotificationRead(String token, int notificationId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return res.statusCode == 200;
  }

  // ⭐ RATINGS & REVIEWS

  /// Submit a rating
  static Future<bool> submitRating(String token, Map<String, dynamic> ratingData) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ratings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(ratingData),
    );
    return res.statusCode == 201;
  }

  /// Get ratings for a specific entity
  static Future<List<dynamic>> getRatings(String entityType, int entityId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ratings?entityType=$entityType&entityId=$entityId'),
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  /// Get rating analytics for dashboard
  static Future<Map<String, dynamic>> getRatingAnalytics(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ratings/analytics'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['success'] ? data['data'] : {};
    }
    return {};
  }

  /// Get entities available for rating based on user role
  static Future<List<dynamic>> getRatableEntities(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ratings/entities'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print('getRatableEntities response: ${res.statusCode}');
    print('getRatableEntities body: ${res.body}');
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success']) {
        final entities = data['data']['entities'] ?? [];
        print('Found ${entities.length} ratable entities');
        return entities;
      }
    }
    return [];
  }

  /// Get ratings for a specific user
  static Future<Map<String, dynamic>> getUserRatings(String token, int userId, String userRole, {String? ratingType, int page = 1, int limit = 10}) async {
    String url = '$baseUrl/ratings/user/$userId/$userRole?page=$page&limit=$limit';
    if (ratingType != null) {
      url += '&ratingType=$ratingType';
    }
    
    final res = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['success'] ? data['data'] : {};
    }
    return {};
  }

  /// Get rating summary for a user
  static Future<List<dynamic>> getRatingSummary(String token, int userId, String userRole) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ratings/summary/$userId/$userRole'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['success'] ? data['data'] : [];
    }
    return [];
  }

  /// Get detailed ratings with individual reviews
  static Future<Map<String, dynamic>> getDetailedRatings(String token, int userId, String userRole, {int limit = 10, int offset = 0}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ratings/detailed/$userId/$userRole?limit=$limit&offset=$offset'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['success'] ? data['data'] : {};
    }
    return {};
  }

  /// Get distributor rating statistics (detailed averages)
  static Future<Map<String, dynamic>> getDistributorRatingStats(String token, int distributorId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/supplier-ratings/distributor/$distributorId/stats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] ? data['data'] : {};
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Manually update distributor averages (for testing)
  static Future<bool> updateDistributorAverages(String token, int distributorId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/supplier-ratings/distributor/$distributorId/update-averages'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get rating criteria for a specific rating type
  static Future<List<dynamic>> getRatingCriteria(String token, String ratingType) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ratings/criteria/$ratingType'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['success'] ? data['data'] : [];
    }
    return [];
  }

  /// Submit supplier rating after delivery
  static Future<Map<String, dynamic>> submitSupplierRating(String token, {
    required int distributorId,
    required int orderId,
    required double overallRating,
    required double qualityRating,
    required double deliveryRating,
    required double serviceRating,
    required double pricingRating,
    String? comment,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/supplier-ratings/distributor/$distributorId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'orderId': orderId,
          'overallRating': overallRating,
          'qualityRating': qualityRating,
          'deliveryRating': deliveryRating,
          'serviceRating': serviceRating,
          'pricingRating': pricingRating,
          'comment': comment,
        }),
      );
      
      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 201 && data['success'],
        'message': data['message'] ?? 'Unknown error',
        'data': data['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
        'data': null,
      };
    }
  }

  /// Check if order has been rated
  static Future<bool> checkOrderRating(String token, int distributorId, int orderId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/supplier-ratings/distributor/$distributorId/order/$orderId/check'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] && data['data']['hasRated'];
      }
      return false;
    } catch (e) {
      print('Error checking order rating: $e');
      return false;
    }
  }

  /// Submit a new rating
  static Future<bool> submitNewRating(String token, {
    required int ratedId,
    required String ratedRole,
    required double overallRating,
    Map<String, double>? criteriaRatings,
    String? comment,
    int? orderId,
    bool isAnonymous = false,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ratings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'rated_id': ratedId,
        'rated_role': ratedRole,
        'overall_rating': overallRating,
        'criteria_ratings': criteriaRatings,
        'comment': comment,
        'order_id': orderId,
        'is_anonymous': isAnonymous,
      }),
    );
    
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return data['success'] ?? false;
    }
    return false;
  }

  // 🤖 AI PREDICTIONS

  // 📈 ANALYTICS

  /// Get analytics data for charts and insights
  static Future<Map<String, dynamic>> getAnalyticsData(String token, String role, {String? period}) async {
    final periodParam = period != null ? '?period=$period' : '';
    final res = await http.get(
      Uri.parse('$baseUrl/analytics/$role$periodParam'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : {};
  }

  /// Get sales analytics
  static Future<Map<String, dynamic>> getSalesAnalytics(String token, {String? period}) async {
    final periodParam = period != null ? '?period=$period' : '';
    final res = await http.get(
      Uri.parse('$baseUrl/analytics/sales$periodParam'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : {};
  }

  /// Get inventory analytics
  static Future<Map<String, dynamic>> getInventoryAnalytics(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/analytics/inventory'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : {};
  }

  // 🤖 AI INTEGRATION

  /// Get AI restock suggestions for supermarket
  static Future<List<Map<String, dynamic>>> getRestockSuggestions(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/ai/suggestions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['suggestions'] ?? []);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching restock suggestions: $e');
      return [];
    }
  }

  /// Get AI-powered analytics
  static Future<Map<String, dynamic>> getAIAnalytics(String token) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/ai/analytics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success']) {
          return data['analytics'] ?? {};
        }
      }
      return {};
    } catch (e) {
      print('Error fetching AI analytics: $e');
      return {};
    }
  }

  /// Call Flask AI to predict restock quantity with all necessary features
  static Future<Map<String, dynamic>?> predictRestock({
    required int productId,
    required int distributorId,
    required double stockLevel,
    required int previousOrders,
    required int activeOffers,
    required String date,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/ai/predict');
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'product_id': productId,
              'distributor_id': distributorId,
              'stock_level': stockLevel,
              'previous_orders': previousOrders,
              'active_offers': activeOffers,
              'date': date,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        print('Prediction response: $json');
        return json;
      } else {
        print('Prediction error: ${res.statusCode} ${res.body}');
        return null;
      }
    } catch (e) {
      print('Exception in predictRestock: $e');
      return null;
    }
  }

  /// Get supermarket dashboard stats (alternative endpoint)
  static Future<Map<String, dynamic>> getSupermarketAnalytics(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/analytics/supermarket'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {};
    } catch (e) {
      print('Error fetching supermarket stats: $e');
      return {};
    }
  }

  /// Get recent activities
  static Future<List<dynamic>> getRecentActivities(String token, String role) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/activities?role=$role'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return [];
    } catch (e) {
      print('Error fetching recent activities: $e');
      return [];
    }
  }

  static Future<bool> restockProductOld(int productId, int quantity) async {
    final url = Uri.parse('$baseUrl/products/restock');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'product_id': productId, 'quantity': quantity}),
    );
    return res.statusCode == 200;
  }

  // 🚚 SMART DELIVERY MANAGEMENT ENDPOINTS

  /// Get pending orders for delivery assignment (distributor-specific)
  static Future<List<Map<String, dynamic>>> getPendingOrders({int? distributorId}) async {
    try {
      String endpoint;
      if (distributorId != null) {
        // Use distributor-specific endpoint
        endpoint = '$baseUrl/orders/distributor/$distributorId';
      } else {
        // Use general pending orders endpoint
        endpoint = '$baseUrl/orders/pending';
      }
      
      final res = await http.get(
        Uri.parse(endpoint),
        headers: await _getAuthHeaders(),
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> orders;
        
        if (distributorId != null) {
          // Filter distributor orders for pending status
          orders = List<Map<String, dynamic>>.from(data);
          orders = orders.where((order) {
            final status = order['status']?.toString().toLowerCase() ?? '';
            return status == 'pending' || status == 'confirmed' || status == 'processing';
          }).toList();
        } else {
          // Use general endpoint response
          orders = List<Map<String, dynamic>>.from(data['orders'] ?? data);
        }
        
        print('📋 Found ${orders.length} pending orders for distributor $distributorId');
        return orders;
      }
      return [];
    } catch (e) {
      print('❌ Error fetching pending orders: $e');
      return [];
    }
  }

  /// Get available delivery men with location data for smart assignment
  static Future<List<Map<String, dynamic>>> getDeliveryMenWithLocation() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/delivery/available'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['delivery_men'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching delivery men: $e');
      return [];
    }
  }

  /// Update delivery man workload after assignment
  static Future<bool> updateDeliveryManWorkload(int deliveryManId, List<Map<String, dynamic>> assignedOrders) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/delivery/assign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'delivery_man_id': deliveryManId,
          'orders': assignedOrders.map((o) => o['id']).toList(),
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('Error updating delivery workload: $e');
      return false;
    }
  }

  /// Get delivery analytics and performance metrics
  static Future<Map<String, dynamic>> getDeliveryAnalytics() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/delivery/analytics'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {};
    } catch (e) {
      print('Error fetching delivery analytics: $e');
      return {};
    }
  }

  /// Get real-time delivery tracking data
  static Future<List<Map<String, dynamic>>> getActiveDeliveries() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/delivery/active'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching active deliveries: $e');
      return [];
    }
  }

  /// Update delivery status with location tracking
  static Future<bool> updateDeliveryStatusWithLocation(int orderId, String status, {Map<String, dynamic>? locationData}) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/delivery/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'order_id': orderId,
          'status': status,
          'location_data': locationData,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('Error updating delivery status: $e');
      return false;
    }
  }

  /// Get delivery performance by delivery man
  static Future<Map<String, dynamic>> getDeliveryManPerformance(int deliveryManId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/delivery/performance/$deliveryManId'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {};
    } catch (e) {
      print('Error fetching delivery man performance: $e');
      return {};
    }
  }

  // Helper method for authentication headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Public method for authentication headers
  static Future<Map<String, String>> getAuthHeaders() async {
    return await _getAuthHeaders();
  }

  /// Get real-time delivery management data
  static Future<List<Map<String, dynamic>>> getAvailableDeliveryMen() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/delivery/men'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Accept either snake_case `delivery_men` or legacy `deliveryMen`
        final list = data['delivery_men'] ?? data['deliveryMen'] ?? [];
        return List<Map<String, dynamic>>.from(list);
      }
      throw Exception('Failed to load delivery men: ${response.statusCode}');
    } catch (e) {
      print('Error fetching delivery men: $e');
      // Return fallback data for development
      throw e; // No fallback - force real backend integration
    }
  }

  /// Get pending delivery orders from backend for specific distributor
  static Future<List<Map<String, dynamic>>> getPendingDeliveryOrders({int? distributorId}) async {
    try {
      // If distributorId is provided, use distributor-specific endpoint
      String endpoint = distributorId != null 
          ? '$baseUrl/orders/distributor/$distributorId'
          : '$baseUrl/delivery/pending';
      
      final response = await http.get(
        Uri.parse(endpoint),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> orders;
        
        if (distributorId != null) {
          // Use distributor endpoint response and filter for pending
          orders = List<Map<String, dynamic>>.from(data ?? []);
          orders = orders.where((order) {
            final status = (order['status'] ?? 'pending').toString().toLowerCase();
            return status == 'pending' || status == 'confirmed' || status == 'processing';
          }).toList();
          
          // Add null safety to each order
          orders = orders.map((order) => _sanitizeOrderData(order)).toList();
        } else {
          // Use delivery endpoint response
          final rawOrders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
          orders = rawOrders.map((order) => _sanitizeOrderData(order)).toList();
        }
        
        print('📦 Found ${orders.length} pending delivery orders for distributor $distributorId');
        return orders;
      }
      throw Exception('Failed to load pending deliveries: ${response.statusCode}');
    } catch (e) {
      print('❌ Error fetching pending deliveries: $e');
      // Return empty list instead of throwing to prevent crashes
      return [];
    }
  }

  /// Sanitize order data to ensure all fields have safe default values
  static Map<String, dynamic> _sanitizeOrderData(Map<String, dynamic> order) {
    return {
      'id': order['id'] ?? 0,
      'buyer_id': order['buyer_id'] ?? 0,
      'distributor_id': order['distributor_id'] ?? 0,
      'status': (order['status'] ?? 'pending').toString(),
      'delivery_code': (order['delivery_code'] ?? '').toString(),
      'created_at': (order['created_at'] ?? DateTime.now().toIso8601String()).toString(),
      'delivered_at': order['delivered_at']?.toString(),
      'delivery_address': (order['delivery_address'] ?? '').toString(),
      'delivery_latitude': order['delivery_latitude'],
      'delivery_longitude': order['delivery_longitude'],
      'priority_level': order['priority_level'] ?? 1,
      'estimated_delivery': order['estimated_delivery']?.toString(),
      'delivery_man_id': order['delivery_man_id'],
      'total_amount': order['total_amount'] ?? 0.0,
      'buyer': _sanitizeUserData(order['buyer']),
      'distributor': _sanitizeUserData(order['distributor']),
      'shipping_address': _sanitizeAddressData(order['shipping_address']),
      'items': _sanitizeItemsData(order['items']),
    };
  }

  /// Sanitize user data to ensure all fields have safe default values
  static Map<String, dynamic> _sanitizeUserData(dynamic userData) {
    if (userData == null) {
      return {
        'id': 0,
        'name': '',
        'email': '',
        'role': '',
      };
    }
    
    final user = userData is Map<String, dynamic> ? userData : <String, dynamic>{};
    return {
      'id': user['id'] ?? 0,
      'name': (user['name'] ?? '').toString(),
      'email': (user['email'] ?? '').toString(),
      'role': (user['role'] ?? '').toString(),
    };
  }

  /// Sanitize address data to ensure all fields have safe default values
  static Map<String, dynamic> _sanitizeAddressData(dynamic addressData) {
    if (addressData == null) {
      return {
        'street': '',
        'city': '',
        'state': '',
        'postal_code': '',
        'country': '',
        'phone': '',
        'latitude': null,
        'longitude': null,
      };
    }
    
    final address = addressData is Map<String, dynamic> ? addressData : <String, dynamic>{};
    return {
      'street': (address['street'] ?? '').toString(),
      'city': (address['city'] ?? '').toString(),
      'state': (address['state'] ?? '').toString(),
      'postal_code': (address['postal_code'] ?? '').toString(),
      'country': (address['country'] ?? '').toString(),
      'phone': (address['phone'] ?? '').toString(),
      'latitude': address['latitude'],
      'longitude': address['longitude'],
    };
  }

  /// Sanitize items data to ensure all fields have safe default values
  static List<Map<String, dynamic>> _sanitizeItemsData(dynamic itemsData) {
    if (itemsData == null) return [];
    
    final items = itemsData is List ? itemsData : [];
    return items.map((item) {
      if (item is! Map<String, dynamic>) return <String, dynamic>{};
      
      return {
        'id': item['id'] ?? 0,
        'product_id': item['product_id'] ?? 0,
        'quantity': item['quantity'] ?? 0,
        'price': item['price'] ?? 0.0,
        'product': _sanitizeProductData(item['product']),
      };
    }).toList();
  }

  /// Sanitize product data to ensure all fields have safe default values
  static Map<String, dynamic> _sanitizeProductData(dynamic productData) {
    if (productData == null) {
      return {
        'id': 0,
        'name': '',
        'description': '',
        'image': '',
        'category': '',
        'brand': '',
        'sku': '',
      };
    }
    
    final product = productData is Map<String, dynamic> ? productData : <String, dynamic>{};
    return {
      'id': product['id'] ?? 0,
      'name': (product['name'] ?? '').toString(),
      'description': (product['description'] ?? '').toString(),
      'image': (product['image'] ?? '').toString(),
      'category': (product['category'] ?? '').toString(),
      'brand': (product['brand'] ?? '').toString(),
      'sku': (product['sku'] ?? '').toString(),
    };
  }

  /// Get active delivery orders from backend
  static Future<List<Map<String, dynamic>>> getActiveDeliveryOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/delivery/active'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
      }
      throw Exception('Failed to load active deliveries: ${response.statusCode}');
    } catch (e) {
      print('Error fetching active deliveries: $e');
      throw e; // No fallback - force real backend integration
    }
  }

  /// Get completed delivery orders from backend
  static Future<List<Map<String, dynamic>>> getCompletedDeliveryOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/delivery/completed'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
      }
      throw Exception('Failed to load completed deliveries: ${response.statusCode}');
    } catch (e) {
      print('Error fetching completed deliveries: $e');
      throw e; // No fallback - force real backend integration
    }
  }

  /// Assign delivery to delivery man
  static Future<bool> assignDeliveryToMan(int orderId, int deliveryManId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delivery/assign'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'order_id': orderId,
          'delivery_man_id': deliveryManId,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error assigning delivery: $e');
      return false;
    }
  }

  /// Enhanced delivery status update with location
  static Future<bool> updateDeliveryStatusWithLocationData(
    int orderId,
    String status, {
    Map<String, dynamic>? locationData,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/delivery/status'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'order_id': orderId,
          'status': status,
          'location_data': locationData,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating delivery status: $e');
      return false;
    }
  }


  /// Perform smart assignment of orders to delivery men
  static Future<List<Map<String, dynamic>>> performEnhancedSmartAssignment(
    List<Map<String, dynamic>> pendingOrders,
    List<Map<String, dynamic>> availableDeliveryMen,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delivery/smart-assign'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'pending_orders': pendingOrders,
          'available_delivery_men': availableDeliveryMen,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['assignments'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error performing smart assignment: $e');
      return [];
    }
  }

  /// Get delivery history for tracking
  static Future<List<Map<String, dynamic>>> getDeliveryHistory(int deliveryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/delivery/history/$deliveryId'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['history'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching delivery history: $e');
      return [];
    }
  }

  /// Get order delivery tracking data
  static Future<Map<String, dynamic>> getOrderDeliveryTracking(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/delivery/track/$orderId'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error fetching order delivery tracking: $e');
      return {};
    }
  }

  /// Get enhanced delivery man performance
  static Future<Map<String, dynamic>> getEnhancedDeliveryManPerformance(int deliveryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/delivery/performance/$deliveryId'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error fetching delivery man performance: $e');
      return {};
    }
  }

  /// Get delivery performance metrics for the authenticated distributor
  static Future<Map<String, dynamic>> getDeliveryPerformanceMetrics({int period = 30}) async {
    try {
      print('🌐 API Service: Fetching performance metrics...');
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/performance?period=$period'),
        headers: await _getAuthHeaders(),
      );
      
      print('🌐 API Service: Response status: ${response.statusCode}');
      print('🌐 API Service: Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🌐 API Service: Parsed data: $data');
        final result = data['data'] ?? {};
        print('🌐 API Service: Returning data: $result');
        return result;
      }
      print('🌐 API Service: Non-200 status code, returning empty map');
      return {};
    } catch (e) {
      print('🌐 API Service: Error fetching delivery performance metrics: $e');
      return {};
    }
  }

  /// Create or update delivery analytics record
  static Future<bool> createDeliveryAnalytics({
    required int distributorId,
    required int orderId,
    int? deliveryPersonId,
    required DateTime deliveryStartTime,
    DateTime? deliveryEndTime,
    required bool isOnTime,
    required double deliveryCost,
    required double distanceKm,
    required double efficiencyScore,
    required double customerRating,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analytics/create'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'distributorId': distributorId,
          'orderId': orderId,
          'deliveryPersonId': deliveryPersonId,
          'deliveryStartTime': deliveryStartTime.toIso8601String(),
          'deliveryEndTime': deliveryEndTime?.toIso8601String(),
          'isOnTime': isOnTime,
          'deliveryCost': deliveryCost,
          'distanceKm': distanceKm,
          'efficiencyScore': efficiencyScore,
          'customerRating': customerRating,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error creating delivery analytics: $e');
      return false;
    }
  }

  /// Get analytics for a specific order
  static Future<Map<String, dynamic>> getOrderAnalytics(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/order/$orderId'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? {};
      }
      return {};
    } catch (e) {
      print('Error fetching order analytics: $e');
      return {};
    }
  }

  /// Update delivery analytics when status changes
  static Future<bool> updateDeliveryAnalytics({
    required int orderId,
    required String status,
    int? deliveryManId,
    double? latitude,
    double? longitude,
    String? notes,
    String? locationName,
  }) async {
    try {
      print('📊 Updating delivery analytics for order $orderId');
      final response = await http.post(
        Uri.parse('$baseUrl/analytics/update'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'order_id': orderId,
          'status': status,
          'delivery_man_id': deliveryManId,
          'latitude': latitude,
          'longitude': longitude,
          'notes': notes,
          'location_name': locationName,
        }),
      );
      
      if (response.statusCode == 200) {
        print('📊 Analytics updated successfully for order $orderId');
        return true;
      }
      print('❌ Failed to update analytics: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error updating delivery analytics: $e');
      return false;
    }
  }

  // ============================================================================
  // PERSONNEL MANAGEMENT API METHODS
  // ============================================================================

  /// Get all delivery personnel with detailed information
  static Future<List<Map<String, dynamic>>> getAllPersonnel() async {
    try {
      print('👥 Fetching all delivery personnel...');
      final response = await http.get(
        Uri.parse('$baseUrl/personnel'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('👥 Personnel data received: ${data['data']?.length ?? 0} personnel');
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      print('❌ Failed to fetch personnel: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Error fetching personnel: $e');
      return [];
    }
  }

  /// Get personnel statistics
  static Future<Map<String, dynamic>> getPersonnelStats() async {
    try {
      print('📊 Fetching personnel statistics...');
      final response = await http.get(
        Uri.parse('$baseUrl/personnel/stats'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Personnel stats received: $data');
        return data['data'] ?? {};
      }
      print('❌ Failed to fetch personnel stats: ${response.statusCode}');
      return {};
    } catch (e) {
      print('❌ Error fetching personnel stats: $e');
      return {};
    }
  }

  /// Get detailed personnel information
  static Future<Map<String, dynamic>> getPersonnelDetails(int personnelId) async {
    try {
      print('👤 Fetching personnel details for ID: $personnelId');
      final response = await http.get(
        Uri.parse('$baseUrl/personnel/$personnelId'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('👤 Personnel details received: $data');
        return data['data'] ?? {};
      }
      print('❌ Failed to fetch personnel details: ${response.statusCode}');
      return {};
    } catch (e) {
      print('❌ Error fetching personnel details: $e');
      return {};
    }
  }

  /// Get personnel performance analytics
  static Future<Map<String, dynamic>> getPersonnelAnalytics(int personnelId, {int period = 30}) async {
    try {
      print('📈 Fetching personnel analytics for ID: $personnelId');
      final response = await http.get(
        Uri.parse('$baseUrl/personnel/$personnelId/analytics?period=$period'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📈 Personnel analytics received: $data');
        return data['data'] ?? {};
      }
      print('❌ Failed to fetch personnel analytics: ${response.statusCode}');
      return {};
    } catch (e) {
      print('❌ Error fetching personnel analytics: $e');
      return {};
    }
  }

  /// Add new personnel
  static Future<Map<String, dynamic>> addPersonnel({
    required String name,
    required String phone,
    required String email,
    String? vehicleType,
    int? vehicleCapacity,
    String? licenseNumber,
    String? emergencyContact,
    String? emergencyPhone,
    String? shiftStart,
    String? shiftEnd,
  }) async {
    try {
      print('➕ Adding new personnel: $name');
      final response = await http.post(
        Uri.parse('$baseUrl/personnel'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'vehicle_type': vehicleType,
          'vehicle_capacity': vehicleCapacity,
          'plate_number': licenseNumber,
          'emergency_contact': emergencyContact,
          'emergency_phone': emergencyPhone,
          'shift_start': shiftStart,
          'shift_end': shiftEnd,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Personnel added successfully: $data');
        return data['data'] ?? {};
      }
      print('❌ Failed to add personnel: ${response.statusCode}');
      return {};
    } catch (e) {
      print('❌ Error adding personnel: $e');
      return {};
    }
  }

  /// Update personnel information
  static Future<Map<String, dynamic>> updatePersonnel(int personnelId, Map<String, dynamic> updates) async {
    try {
      print('✏️ Updating personnel ID: $personnelId');
      final response = await http.put(
        Uri.parse('$baseUrl/personnel/$personnelId'),
        headers: await _getAuthHeaders(),
        body: jsonEncode(updates),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Personnel updated successfully: $data');
        return data['data'] ?? {};
      }
      print('❌ Failed to update personnel: ${response.statusCode}');
      return {};
    } catch (e) {
      print('❌ Error updating personnel: $e');
      return {};
    }
  }

  /// Toggle personnel availability
  static Future<bool> togglePersonnelAvailability(int personnelId, bool isAvailable) async {
    try {
      print('🔄 Toggling personnel availability for ID: $personnelId to $isAvailable');
      final response = await http.patch(
        Uri.parse('$baseUrl/personnel/$personnelId/availability'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({'is_available': isAvailable}),
      );
      
      if (response.statusCode == 200) {
        print('✅ Personnel availability updated successfully');
        return true;
      }
      print('❌ Failed to toggle availability: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error toggling availability: $e');
      return false;
    }
  }

  /// Deactivate personnel
  static Future<bool> deactivatePersonnel(int personnelId) async {
    try {
      print('🗑️ Deactivating personnel ID: $personnelId');
      final response = await http.delete(
        Uri.parse('$baseUrl/personnel/$personnelId'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        print('✅ Personnel deactivated successfully');
        return true;
      }
      print('❌ Failed to deactivate personnel: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error deactivating personnel: $e');
      return false;
    }
  }
}