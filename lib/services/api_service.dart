import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.0.2.2:5000/api"; // Emulator localhost
  static const String flaskBaseUrl = 'http://10.0.2.2:5001';

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
  final res = await http.post(
    Uri.parse("$baseUrl/auth/signup"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode(data),
  );
  if (res.statusCode == 201) {
    return jsonDecode(res.body);
  } else {
    print('❌ Signup failed: ${res.statusCode}');
    print('💬 ${res.body}');
    return null;
  }
}

static Future<Map<String, dynamic>> fetchUserProfile(String token) async {
  final res = await http.get(
    Uri.parse('$baseUrl/profile/me'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode == 200) {
    return jsonDecode(res.body);
  } else {
    throw Exception('Failed to load profile');
  }
}

static Future<void> updateProfile(String token, Map<String, dynamic> data, String role) async {
  final url = Uri.parse('$baseUrl/profile/me');
  final res = await http.put(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(data),
  );
  if (res.statusCode != 200) {
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to update');
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
    return res.statusCode == 201;
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
  final res = await http.get(
    Uri.parse('$baseUrl/orders/buyer/$buyerId'),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );
  return res.statusCode == 200 ? jsonDecode(res.body) : [];
}

static Future<List<dynamic>> getDistributorOrders(String token, int distributorId) async {
  final res = await http.get(
    Uri.parse('$baseUrl/orders/distributor/$distributorId'),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );
  return res.statusCode == 200 ? jsonDecode(res.body) : [];
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
    final res = await http.get(Uri.parse('$baseUrl/delivery/orders/$deliveryId'));
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<bool> assignOrderToDelivery(int orderId, int deliveryId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/delivery/assign'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"order_id": orderId, "delivery_id": deliveryId}),
    );
    return res.statusCode == 201;
  }


// 🔄 Update delivery status
static Future<bool> updateDeliveryStatus({
  required int orderId,
  required int deliveryId,
  required String status,
}) async {
  final res = await http.put(
    Uri.parse('$baseUrl/delivery/status'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "order_id": orderId,
      "delivery_id": deliveryId,
      "status": status,
    }),
  );
  return res.statusCode == 200;
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

// ✅ Get all delivery men
static Future<List<Map<String, dynamic>>> getAvailableDeliveryMen() async {
  final url = Uri.parse('$baseUrl/users?role=Delivery');
  final res = await http.get(url);

  if (res.statusCode == 200) {
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  } else {
    throw Exception("Failed to fetch delivery personnel");
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
}