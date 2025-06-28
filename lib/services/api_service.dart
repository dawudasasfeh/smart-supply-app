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
  static Future<bool> placeOrder({
    required String token,
    required int productId,
    required int distributorId,
    required int quantity,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/orders"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "product_id": productId,
        "distributor_id": distributorId,
        "quantity": quantity,
      }),
    );
    return res.statusCode == 201;
  }

  static Future<List<dynamic>> getBuyerOrders(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/orders/my"),
      headers: {"Authorization": "Bearer $token"},
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getDistributorOrders(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/orders/incoming"),
      headers: {"Authorization": "Bearer $token"},
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<bool> updateOrderStatus(String token, int id, String status) async {
    final res = await http.put(
      Uri.parse("$baseUrl/orders/$id/status"),
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
    Uri.parse("$baseUrl/orders/inventory"),
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
  // 📦 Get orders for delivery man
static Future<List<dynamic>> getAssignedOrders(int deliveryId) async {
  final res = await http.get(Uri.parse('$baseUrl/delivery/orders/$deliveryId'));
  return res.statusCode == 200 ? jsonDecode(res.body) : [];
}

// ✅ Assign order to delivery man
static Future<bool> assignOrderToDelivery(int orderId, int deliveryId) async {
  final response = await http.post(
    Uri.parse('$baseUrl/delivery/assign'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "order_id": orderId,
      "delivery_id": deliveryId,
    }),
  );
  return response.statusCode == 201;
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

static Future<bool> verifyDelivery(int orderId, String code) async {
  final res = await http.post(
    Uri.parse('$baseUrl/delivery/verify'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "order_id": orderId,
      "delivery_code": code,
    }),
  );
  return res.statusCode == 200;
}

static Future<Map<String, dynamic>?> placeOrderWithQR({
  required String token,
  required int productId,
  required int distributorId,
  required int quantity,
}) async {
  final res = await http.post(
    Uri.parse("$baseUrl/orders"),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "product_id": productId,
      "distributor_id": distributorId,
      "quantity": quantity,
    }),
  );

  if (res.statusCode == 201) {
    return jsonDecode(res.body); // should include { order_id, delivery_code }
  } else {
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


  //AI
  // ✅ Call Flask AI prediction
static Future<int?> predictRestock({required int productId, required int daysAhead}) async {
  try {
    final url = Uri.parse('$flaskBaseUrl/predict');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'product_id': productId, 'days_ahead': daysAhead}),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      print('Prediction response: $json');
      return json['restock_quantity'] as int?;
    } else {
      print('Prediction error: ${res.statusCode} ${res.body}');
      return null;
    }
  } catch (e) {
    print('Exception in predictRestock: $e');
    return null;
  }
}


  // ✅ Create internal restock order (simulate by adding stock or log it)
  static Future<bool> restockProduct(int productId, int quantity) async {
    final url = Uri.parse('$baseUrl/products/restock');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'product_id': productId, 'quantity': quantity}),
    );
    return res.statusCode == 200;
  }
}
