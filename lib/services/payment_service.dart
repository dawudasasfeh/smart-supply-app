import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class PaymentService {
  static const String baseUrl = ApiService.baseUrl;
  
  // ============================================================================
  // PAYMENT METHODS
  // ============================================================================
  
  /// Get all active payment methods
  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/methods'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      throw Exception('Failed to fetch payment methods');
    } catch (e) {
      print('Error fetching payment methods: $e');
      return [];
    }
  }
  
  /// Get user's payment methods
  static Future<List<Map<String, dynamic>>> getUserPaymentMethods() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/user/methods'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      throw Exception('Failed to fetch user payment methods');
    } catch (e) {
      print('Error fetching user payment methods: $e');
      return [];
    }
  }
  
  /// Get user's default payment method
  static Future<Map<String, dynamic>?> getDefaultPaymentMethod() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/user/methods/default'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      print('Error fetching default payment method: $e');
      return null;
    }
  }
  
  /// Add payment method for user
  static Future<Map<String, dynamic>?> addPaymentMethod({
    required int paymentMethodId,
    bool isDefault = false,
    String? cardLastFour,
    String? cardBrand,
    String? bankName,
    String? accountNumberMasked,
    int? expiryMonth,
    int? expiryYear,
    Map<String, dynamic>? billingAddress,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/user/methods'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'payment_method_id': paymentMethodId,
          'is_default': isDefault,
          'card_last_four': cardLastFour,
          'card_brand': cardBrand,
          'bank_name': bankName,
          'account_number_masked': accountNumberMasked,
          'expiry_month': expiryMonth,
          'expiry_year': expiryYear,
          'billing_address': billingAddress,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      throw Exception('Failed to add payment method');
    } catch (e) {
      print('Error adding payment method: $e');
      return null;
    }
  }
  
  /// Set default payment method
  static Future<bool> setDefaultPaymentMethod(int paymentMethodId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/payment/user/methods/default'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'payment_method_id': paymentMethodId,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error setting default payment method: $e');
      return false;
    }
  }
  
  /// Delete user payment method
  static Future<bool> deletePaymentMethod(int paymentMethodId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/payment/user/methods/$paymentMethodId'),
        headers: await _getAuthHeaders(),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting payment method: $e');
      return false;
    }
  }
  
  // ============================================================================
  // PAYMENT TRANSACTIONS
  // ============================================================================
  
  /// Create payment transaction
  static Future<Map<String, dynamic>?> createTransaction({
    required int orderId,
    required int paymentMethodId,
    required double amount,
    String currency = 'EGP',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/transactions'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'order_id': orderId,
          'payment_method_id': paymentMethodId,
          'amount': amount,
          'currency': currency,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      throw Exception('Failed to create payment transaction');
    } catch (e) {
      print('Error creating payment transaction: $e');
      return null;
    }
  }
  
  /// Process payment
  static Future<Map<String, dynamic>?> processPayment({
    required int orderId,
    required int paymentMethodId,
    required double amount,
    String currency = 'EGP',
  }) async {
    try {
      final headers = await _getAuthHeaders();
      
      final requestBody = {
        'order_id': orderId,
        'payment_method_id': paymentMethodId,
        'amount': amount,
        'currency': currency,
      };
      
      print('🔄 Processing payment...');
      print('📍 URL: $baseUrl/payment/process');
      print('📦 Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse('$baseUrl/payment/process'),
        headers: headers,
        body: jsonEncode(requestBody),
      );
      
      print('📊 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Payment successful!');
        return data['data'] ?? data;
      } else {
        print('❌ Payment failed: ${response.statusCode} - ${response.body}');
        throw Exception('Payment failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Payment error: $e');
      rethrow;
    }
  }
  
  /// Get transaction by ID
  static Future<Map<String, dynamic>?> getTransaction(int transactionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/transactions/$transactionId'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      print('Error fetching transaction: $e');
      return null;
    }
  }
  
  /// Get user's transactions
  static Future<List<Map<String, dynamic>>> getUserTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/user/transactions?limit=$limit&offset=$offset'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching user transactions: $e');
      return [];
    }
  }
  
  /// Get transactions by order ID
  static Future<List<Map<String, dynamic>>> getOrderTransactions(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/orders/$orderId/transactions'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching order transactions: $e');
      return [];
    }
  }
  
  /// Update transaction status
  static Future<bool> updateTransactionStatus({
    required String transactionId,
    required String status,
    Map<String, dynamic>? gatewayResponse,
    String? failureReason,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/payment/transactions/$transactionId/status'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'status': status,
          'gateway_response': gatewayResponse,
          'failure_reason': failureReason,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating transaction status: $e');
      return false;
    }
  }
  
  /// Get transaction statistics
  static Future<Map<String, dynamic>> getTransactionStats({
    String? startDate,
    String? endDate,
  }) async {
    try {
      String url = '$baseUrl/payment/transactions/stats';
      if (startDate != null || endDate != null) {
        final params = <String, String>{};
        if (startDate != null) params['startDate'] = startDate;
        if (endDate != null) params['endDate'] = endDate;
        url += '?${Uri(queryParameters: params).query}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? {};
      }
      return {};
    } catch (e) {
      print('Error fetching transaction stats: $e');
      return {};
    }
  }
  
  // ============================================================================
  // PAYMENT REFUNDS
  // ============================================================================
  
  /// Create refund
  static Future<Map<String, dynamic>?> createRefund({
    required String transactionId,
    required double amount,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/refunds'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'transaction_id': transactionId,
          'amount': amount,
          'reason': reason,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      throw Exception('Failed to create refund');
    } catch (e) {
      print('Error creating refund: $e');
      return null;
    }
  }
  
  /// Get refunds by transaction ID
  static Future<List<Map<String, dynamic>>> getRefundsByTransaction(String transactionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/transactions/$transactionId/refunds'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching refunds: $e');
      return [];
    }
  }
  
  /// Update refund status
  static Future<bool> updateRefundStatus({
    required String refundId,
    required String status,
    Map<String, dynamic>? gatewayResponse,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/payment/refunds/$refundId/status'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'status': status,
          'gateway_response': gatewayResponse,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating refund status: $e');
      return false;
    }
  }
  
  // ============================================================================
  // PAYMENT SETTINGS
  // ============================================================================
  
  /// Get payment settings
  static Future<List<Map<String, dynamic>>> getPaymentSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/settings'),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching payment settings: $e');
      return [];
    }
  }
  
  /// Update payment setting
  static Future<bool> updatePaymentSetting({
    required String key,
    required String value,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/payment/settings/$key'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'value': value,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating payment setting: $e');
      return false;
    }
  }
  
  // ============================================================================
  // UTILITY METHODS
  // ============================================================================
  
  /// Get authentication headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
  
  /// Format currency
  static String formatCurrency(dynamic amount, {String currency = 'EGP'}) {
    try {
      // Safe conversion to double
      double safeAmount = 0.0;
      if (amount is double) {
        safeAmount = amount;
      } else if (amount is int) {
        safeAmount = amount.toDouble();
      } else if (amount is String) {
        safeAmount = double.tryParse(amount) ?? 0.0;
      } else {
        safeAmount = double.tryParse(amount.toString()) ?? 0.0;
      }
      
      return '${safeAmount.toStringAsFixed(2)} $currency';
    } catch (e) {
      return '0.00 $currency';
    }
  }
  
  /// Calculate processing fee
  static double calculateProcessingFee(dynamic amount, dynamic feePercentage) {
    // Safe conversion to double
    double safeAmount = 0.0;
    if (amount is double) {
      safeAmount = amount;
    } else if (amount is int) {
      safeAmount = amount.toDouble();
    } else if (amount is String) {
      safeAmount = double.tryParse(amount) ?? 0.0;
    }
    
    double safeFeePercentage = 0.0;
    if (feePercentage is double) {
      safeFeePercentage = feePercentage;
    } else if (feePercentage is int) {
      safeFeePercentage = feePercentage.toDouble();
    } else if (feePercentage is String) {
      safeFeePercentage = double.tryParse(feePercentage) ?? 0.0;
    }
    
    return (safeAmount * safeFeePercentage) / 100;
  }
  
  /// Validate payment amount
  static bool validatePaymentAmount(dynamic amount, {double minAmount = 0, double maxAmount = 999999.99}) {
    // Safe conversion to double
    double safeAmount = 0.0;
    if (amount is double) {
      safeAmount = amount;
    } else if (amount is int) {
      safeAmount = amount.toDouble();
    } else if (amount is String) {
      safeAmount = double.tryParse(amount) ?? 0.0;
    }
    return safeAmount >= minAmount && safeAmount <= maxAmount;
  }
  
  /// Get payment method icon
  static String getPaymentMethodIcon(String type) {
    switch (type.toLowerCase()) {
      case 'card':
        return '💳';
      case 'bank_transfer':
        return '🏦';
      case 'cash':
        return '💵';
      case 'digital_wallet':
        return '📱';
      default:
        return '💳';
    }
  }
  
  /// Get payment status color
  static String getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'green';
      case 'pending':
        return 'orange';
      case 'processing':
        return 'blue';
      case 'failed':
        return 'red';
      case 'cancelled':
        return 'grey';
      case 'refunded':
        return 'purple';
      default:
        return 'grey';
    }
  }
  
  /// Get payment status text
  static String getPaymentStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      default:
        return 'Unknown';
    }
  }
}
