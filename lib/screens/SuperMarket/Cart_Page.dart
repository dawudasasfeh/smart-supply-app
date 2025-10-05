import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/cart_manager.dart';
import '../../constants/app_dimensions.dart';
import '../../services/api_service.dart';
import '../../services/payment_service.dart';
import '../../l10n/app_localizations.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartManager _cartManager = CartManager();
  String paymentMethod = 'Cash on Delivery';
  bool isLoading = false;
  bool isProcessingOrder = false;
  Map<int, Map<String, dynamic>> distributorDetails = {};
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  
  // Payment methods state
  List<Map<String, dynamic>> paymentMethods = [];
  Map<String, dynamic>? selectedPaymentMethod;
  bool isLoadingPaymentMethods = false;
  
  @override
  void initState() {
    super.initState();
    _loadCartData();
    _loadDistributorDetails();
    _loadPaymentMethods();
  }

  Future<void> _loadCartData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      await _cartManager.loadCart();
    } catch (e) {
      // Handle cart loading error silently
      print('Error loading cart: $e');
    }
    
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadDistributorDetails() async {
    try {
      final distributors = await ApiService.getAllDistributors();
      setState(() {
        distributorDetails.clear();
        for (var distributor in distributors) {
          // Ensure all distributor fields are available
          final enhancedDistributor = {
            'id': distributor['id'],
            'name': distributor['name'] ?? (AppLocalizations.of(context)?.unknownDistributor ?? 'Unknown Distributor'),
            'email': distributor['email'],
            'phone': distributor['phone'],
            'address': distributor['address'],
            'image_url': distributor['image_url'] ?? distributor['profile_image'],
            'profile_image': distributor['profile_image'],
            'business_name': distributor['business_name'] ?? distributor['name'],
            'description': distributor['description'],
            'rating': distributor['rating'] ?? 0.0,
            'created_at': distributor['created_at'],
            'updated_at': distributor['updated_at'],
          };
          distributorDetails[distributor['id']] = enhancedDistributor;
        }
      });
      print('Loaded ${distributorDetails.length} distributors with details');
    } catch (e) {
      print('Error loading distributor details: $e');
      // Provide fallback empty distributor details
      setState(() {
        distributorDetails.clear();
      });
    }
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      isLoadingPaymentMethods = true;
    });
    
    try {
      final methods = await PaymentService.getPaymentMethods();
      
      // Filter to only show Cash on Delivery and Card payments
      final filteredMethods = methods.where((method) {
        final type = method['type']?.toString().toLowerCase() ?? '';
        return type == 'cod' || type == 'card' || type == 'cash' || type == 'credit_card' || type == 'debit_card';
      }).toList();
      
      setState(() {
        paymentMethods = filteredMethods.isNotEmpty ? filteredMethods : _getFallbackPaymentMethods();
        selectedPaymentMethod = paymentMethods[0];
        isLoadingPaymentMethods = false;
      });
    } catch (e) {
      print('Error loading payment methods: $e');
      final fallbackMethods = _getFallbackPaymentMethods();
      setState(() {
        paymentMethods = fallbackMethods;
        selectedPaymentMethod = fallbackMethods[0];
        isLoadingPaymentMethods = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFallbackPaymentMethods() {
    final locale = AppLocalizations.of(context);
    return [
      {
        'id': 1,
        'name': locale?.cashOnDelivery ?? 'Cash on Delivery',
        'type': 'cod',
        'description': locale?.cashOnDeliveryDesc ?? 'Pay with cash when you receive your order',
        'icon': 'money',
        'is_active': true,
        'processing_fee_percentage': 0.0,
      },
      {
        'id': 2,
        'name': locale?.cardPayment ?? 'Card Payment',
        'type': 'card',
        'description': locale?.cardPaymentDesc ?? 'Visa, Mastercard, Amex & other cards accepted',
        'icon': 'credit_card',
        'is_active': true,
        'processing_fee_percentage': 2.5,
      },
    ];
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final locale = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(locale?.clearCart ?? 'Clear Cart'),
          content: Text(locale?.clearCartConfirm ?? 'Are you sure you want to clear your cart?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(locale?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(locale?.clearCart ?? 'Clear Cart'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
    }
  }

  Future<Map<String, dynamic>?> _createOrderInDatabase(Map<String, dynamic> orderData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      if (token.isEmpty) {
        if (mounted) {
          final locale = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locale?.pleaseLogin ?? 'Please log in again to continue'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }
      
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(orderData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return responseData['data'];
        }
      } else {
        // Show specific error from backend
        if (mounted) {
          String errorMsg = 'Server error (${response.statusCode})';
          try {
            final errorData = jsonDecode(response.body);
            errorMsg = errorData['message'] ?? errorMsg;
          } catch (e) {
            // Use default error message
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
      
      return null;
    } catch (e) {
      if (mounted) {
        final locale = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale?.networkError ?? 'Network error: Please check your connection'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return null;
    }
  }

  void _placeOrders() async {
    if (isProcessingOrder) return; // Prevent double-tap
    
    setState(() {
      isProcessingOrder = true;
    });
    

    try {
      // Validate authentication
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final buyerId = prefs.getInt('user_id');

      if (token == null || buyerId == null) {
        throw Exception('Please log in to continue');
      }

      // Validate cart
      if (_cartManager.cartItems.isEmpty) {
        throw Exception('Your cart is empty');
      }

      // Calculate safe total with bulletproof conversion
      double safeTotal = 0.0;
      final safeItems = <Map<String, dynamic>>[];

      // Process each cart item with maximum safety
      for (var rawItem in _cartManager.cartItems) {
        try {
          // Extract basic info safely
          final itemId = rawItem['id']?.toString() ?? '';
          final itemName = rawItem['name']?.toString() ?? (AppLocalizations.of(context)?.unknownProduct ?? 'Unknown Product');
          
          // Safe numeric conversions with multiple fallbacks
          double itemPrice = 0.0;
          int itemQuantity = 1;
          
          // Price conversion with multiple attempts
          final priceRaw = rawItem['price'];
          if (priceRaw is double) {
            itemPrice = priceRaw;
          } else if (priceRaw is int) {
            itemPrice = priceRaw.toDouble();
          } else if (priceRaw is String) {
            itemPrice = double.tryParse(priceRaw) ?? 0.0;
          }
          
          // Quantity conversion with multiple attempts
          final quantityRaw = rawItem['quantity'];
          if (quantityRaw is int) {
            itemQuantity = quantityRaw;
          } else if (quantityRaw is double) {
            itemQuantity = quantityRaw.round();
          } else if (quantityRaw is String) {
            itemQuantity = int.tryParse(quantityRaw) ?? 1;
          }
          
          final itemTotal = itemPrice * itemQuantity;
          safeTotal += itemTotal;
          
          // Create safe item data
          safeItems.add({
            'id': itemId,
            'name': itemName,
            'price': itemPrice,
            'quantity': itemQuantity,
            'total': itemTotal,
            'formatted_price': itemPrice.toStringAsFixed(2),
            'formatted_total': itemTotal.toStringAsFixed(2),
          });
          
        } catch (itemError) {
          // Skip problematic items rather than failing completely
          continue;
        }
      }

      // Final validation
      if (safeItems.isEmpty) {
        throw Exception('No valid items found in cart');
      }

      // Create order in database first, then get the real order ID
      final orderCreateData = {
        'total_amount': safeTotal,
        'items': safeItems,
        'item_count': safeItems.length,
        'status': 'pending',
      };
      
      // Call API to create orders and get real order IDs
      final createdOrdersResponse = await _createOrderInDatabase(orderCreateData);
      if (createdOrdersResponse == null) {
        // Show more specific error message
        if (mounted) {
          final locale = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locale?.unableToCreateOrders ?? 'Unable to create orders. Please check your connection and try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        throw Exception('Failed to create orders in database');
      }
      
      final orderData = createdOrdersResponse;

      // Validate payment method
      if (selectedPaymentMethod == null) {
        setState(() {
          isProcessingOrder = false;
        });
        if (mounted) {
          final locale = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locale?.pleaseSelectPayment ?? 'Please select a payment method'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get first order ID for payment processing
      final orders = orderData['orders'] as List;
      final firstOrder = orders.isNotEmpty ? orders[0] : {};
      final orderId = _safeToInt(firstOrder['id']);
      
      if (orderId == 0) {
        setState(() {
          isProcessingOrder = false;
        });
        throw Exception('Invalid order ID');
      }

      // Process payment
      try {
        print('🔄 Processing payment for order #$orderId...');
        final paymentResult = await PaymentService.processPayment(
          orderId: orderId,
          paymentMethodId: _safeToInt(selectedPaymentMethod!['id']),
          amount: safeTotal,
        );

        setState(() {
          isProcessingOrder = false;
        });

        if (paymentResult != null) {
          print('✅ Payment successful!');
          // Show success modal
          if (mounted) {
            await _showOrderSuccessModal(createdOrdersResponse);
            // Clear the cart after successful payment
            _cartManager.clearCart();
          }
        } else {
          throw Exception('Payment processing failed');
        }
      } catch (paymentError) {
        setState(() {
          isProcessingOrder = false;
        });
        print('❌ Payment error: $paymentError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${paymentError.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        rethrow;
      }

    } catch (e) {
      setState(() {
        isProcessingOrder = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Handle payment error
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF000000) : theme.colorScheme.background;
    final surfaceColor = isDark ? const Color(0xFF000000) : theme.colorScheme.surface;
    final textColor = isDark ? const Color(0xFFF9FAFB) : theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;
    final locale = AppLocalizations.of(context);
    
    return Scaffold(
        backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(AppDimensions.appBarExpandedHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                  ? [const Color(0xFF000000), const Color(0xFF000000)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Main Content - Shifted for logo positioning
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    locale?.isRTL == true ? 20 : 68, // Space for back button
                    20,
                    locale?.isRTL == true ? 68 : 20,
                    16,
                  ),
                  child: Row(
                    children: [
                      // Cart Icon (Logo)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, primaryColor.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Title and Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              locale?.shoppingCart ?? 'Shopping Cart',
                              style: GoogleFonts.inter(
                                fontSize: AppDimensions.titleFontSize,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              locale?.reviewItems ?? 'Review your items',
                              style: GoogleFonts.inter(
                                fontSize: AppDimensions.subtitleFontSize,
                                color: textColor.withOpacity(0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Floating Back Button
                Positioned(
                  left: locale?.isRTL == true ? null : 20,
                  right: locale?.isRTL == true ? 20 : null,
                  top: 20,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0A0A) : Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                
                // Floating Clear Cart Button
                Positioned(
                  right: locale?.isRTL == true ? null : 20,
                  left: locale?.isRTL == true ? 20 : null,
                  top: 20,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0A0A) : Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _clearCart,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_cartManager.cartItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isProcessingOrder ? null : _placeOrders,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isProcessingOrder ? Colors.grey : const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: isProcessingOrder
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              locale?.processing ?? 'Processing...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 20),
                            SizedBox(width: 8),
                            Text(
                              () {
                                try {
                                  final total = _calculateSafeTotal();
                                  final formatted = total.toStringAsFixed(2);
                                  final distributorCount = _getDistributorCount();
                                  if (distributorCount > 1) {
                                    return 'Create $distributorCount Orders - \$$formatted';
                                  } else {
                                    return '${locale?.proceedToPayment ?? 'Proceed to Payment'} - \$$formatted';
                                  }
                                } catch (e) {
                                  return 'Proceed to Payment - \$0.00';
                                }
                              }(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          // Bottom navigation removed - not needed for cart page
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : _cartManager.cartItems.isEmpty
              ? _buildEmptyCart()
              : _buildCartContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)?.yourCartIsEmpty ?? 'Your cart is empty',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributorOrderCard(int distributorId, List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF0A0A0A) : theme.colorScheme.surface;
    final textColor = isDark ? const Color(0xFFF9FAFB) : theme.colorScheme.onSurface;
    
    double subtotal = 0.0;
    for (var item in items) {
      final price = _safeToDouble(item['price']);
      final quantity = _safeToInt(item['quantity']);
      subtotal += price * quantity;
    }

    // Get distributor name
    final distributor = distributorDetails[distributorId];
    final locale = AppLocalizations.of(context);
    final distributorName = distributor?['name'] ?? (locale?.unknownDistributor ?? 'Unknown Distributor');

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Distributor header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF000000), const Color(0xFF000000)]
                    : [
                        const Color(0xFFF8FAFC),
                        const Color(0xFFE2E8F0).withOpacity(0.5),
                      ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                _buildDistributorImage(distributor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distributorName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        '${items.length} ${items.length > 1 ? (locale?.items ?? 'items') : (locale?.item ?? 'item')} • ${locale?.order ?? 'Order'} #${_getOrderNumber(distributorId)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: textColor.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF1E293B).withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    currencyFormat.format(subtotal),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Items list
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: items.map((item) => _buildCartItem(item)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F1F1F) : Colors.grey.shade200;
    final textColor = isDark ? const Color(0xFFF9FAFB) : theme.colorScheme.onSurface;
    final priceColor = theme.colorScheme.primary;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                ? Image.network(
                    item['image_url'].toString().startsWith('http')
                        ? item['image_url'].toString()
                        : '${ApiService.imageBaseUrl}${item['image_url']}',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0A0A0A) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0A0A0A) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.image, color: textColor.withOpacity(0.5)),
                      );
                    },
                  )
                : Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0A0A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image, color: textColor.withOpacity(0.5)),
                  ),
          ),
          const SizedBox(width: 12),
          
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Product',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(_safeToDouble(item['price'])),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: priceColor,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  final currentQty = _safeToInt(item['quantity']);
                  if (currentQty > 1) {
                    _cartManager.updateQuantity(item['id'].toString(), currentQty - 1);
                  } else {
                    _cartManager.removeFromCart(item['id'].toString());
                  }
                  setState(() {});
                },
                icon: Icon(Icons.remove_circle_outline, color: textColor),
                iconSize: 24,
              ),
              Text(
                '${_safeToInt(item['quantity'])}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              IconButton(
                onPressed: () {
                  final currentQty = _safeToInt(item['quantity']);
                  _cartManager.updateQuantity(item['id'].toString(), currentQty + 1);
                  setState(() {});
                },
                icon: Icon(Icons.add_circle_outline, color: priceColor),
                iconSize: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF0A0A0A) : theme.colorScheme.surface;
    final locale = AppLocalizations.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  locale?.selectPaymentMethod ?? 'Select Payment Method',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          
          if (isLoadingPaymentMethods)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (paymentMethods.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No payment methods available',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            )
          else
            Column(
              children: paymentMethods.map((method) {
                final isSelected = selectedPaymentMethod?['id'] == method['id'];
                return _buildPaymentMethodCard(method, isSelected);
              }).toList(),
            ),
        ],
      ),
    );
  }

  String _translatePaymentMethodName(String name, AppLocalizations? locale) {
    if (name.isEmpty) return '';
    
    final lowerName = name.toLowerCase().replaceAll(' ', '_');
    
    // Direct key mapping for database keys
    if (lowerName == 'cash_on_delivery' || lowerName == 'cod') {
      return locale?.cashOnDelivery ?? 'Cash on Delivery';
    } else if (lowerName == 'credit_card') {
      return locale?.creditCard ?? 'Credit Card';
    } else if (lowerName == 'debit_card') {
      return locale?.debitCard ?? 'Debit Card';
    }
    
    // Fallback: check if it contains keywords
    if (lowerName.contains('cash') || lowerName.contains('delivery')) {
      return locale?.cashOnDelivery ?? name;
    } else if (lowerName.contains('credit')) {
      return locale?.creditCard ?? name;
    } else if (lowerName.contains('debit')) {
      return locale?.debitCard ?? name;
    } else if (lowerName.contains('card')) {
      return locale?.cardPayment ?? name;
    }
    return name;
  }

  String _translatePaymentMethodDescription(String name, String? description, AppLocalizations? locale) {
    if (description == null || description.isEmpty) return '';
    
    final lowerDesc = description.toLowerCase().trim().replaceAll(' ', '_');
    final lowerName = name.toLowerCase().replaceAll(' ', '_');
    
    // Direct key mapping for database keys
    if (lowerDesc == 'pay_when_delivered' || lowerDesc == 'pay_when_order_is_delivered') {
      return locale?.payWhenDelivered ?? 'Pay when order is delivered';
    } else if (lowerDesc == 'credit_card_desc') {
      return locale?.creditCardDesc ?? 'Visa, MasterCard, American Express';
    } else if (lowerDesc == 'debit_card_desc') {
      return locale?.debitCardDesc ?? 'Local and international debit cards';
    }
    
    // Fallback: check method name
    if (lowerName.contains('cash') || lowerName.contains('cod') || lowerName.contains('delivery')) {
      return locale?.payWhenDelivered ?? description;
    } else if (lowerName.contains('credit')) {
      return locale?.creditCardDesc ?? description;
    } else if (lowerName.contains('debit')) {
      return locale?.debitCardDesc ?? description;
    }
    return description;
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method, bool isSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final textColor = isDark ? const Color(0xFFF9FAFB) : theme.colorScheme.onSurface;
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.grey.shade50;
    final iconBgColor = isDark ? const Color(0xFF1F1F1F) : Colors.grey.shade200;
    final borderColor = isDark ? const Color(0xFF1F1F1F) : Colors.grey.shade200;
    final locale = AppLocalizations.of(context);
    
    final iconName = method['icon'] ?? 'credit_card';
    IconData iconData;
    switch (iconName) {
      case 'money':
        iconData = Icons.money;
        break;
      case 'credit_card':
        iconData = Icons.credit_card;
        break;
      case 'account_balance_wallet':
        iconData = Icons.account_balance_wallet;
        break;
      case 'account_balance':
        iconData = Icons.account_balance;
        break;
      default:
        iconData = Icons.payment;
    }

    return InkWell(
      onTap: () {
        setState(() {
          selectedPaymentMethod = method;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0A0A0A), const Color(0xFF0A0A0A)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                )
              : null,
          color: isSelected ? null : (isDark ? const Color(0xFF0A0A0A) : cardColor),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                iconData,
                color: isSelected ? Colors.white : (isDark ? textColor.withOpacity(0.7) : Colors.grey.shade600),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _translatePaymentMethodName(method['name'] ?? 'Payment Method', locale),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (method['description'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _translatePaymentMethodDescription(method['name'] ?? '', method['description'], locale),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(double total) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final locale = AppLocalizations.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                locale?.orderSummary ?? 'Order Summary',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${locale?.subtotal ?? 'Subtotal'} (${_cartManager.cartItems.length} ${_cartManager.cartItems.length > 1 ? (locale?.items ?? 'items') : (locale?.item ?? 'item')})',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              Text(
                currencyFormat.format(total),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale?.deliveryFee ?? 'Delivery Fee',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              Text(
                locale?.free ?? 'Free',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF10B981) : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale?.total ?? 'Total',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currencyFormat.format(total),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributorImage(Map<String, dynamic>? distributor) {
    if (distributor != null && distributor['logo'] != null && distributor['logo'].toString().isNotEmpty) {
      final logoUrl = distributor['logo'].toString();
      final fullUrl = logoUrl.startsWith('http') 
          ? logoUrl 
          : '${ApiService.imageBaseUrl}$logoUrl';
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          fullUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.store,
                color: Colors.grey,
                size: 20,
              ),
            );
          },
        ),
      );
    }
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.store,
        color: Colors.grey,
        size: 20,
      ),
    );
  }

  double _calculateSafeTotal() {
    return _cartManager.totalAmount;
  }

  // Helper methods for safe type conversion
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Get distributor count from cart items
  int _getDistributorCount() {
    final distributors = <int>{};
    for (var item in _cartManager.cartItems) {
      final distributorId = item['distributor_id'] ?? 1;
      distributors.add(distributorId);
    }
    return distributors.length;
  }

  // Get distributor items grouped by distributor ID
  Map<int, List<Map<String, dynamic>>> _getDistributorItems() {
    final distributorItems = <int, List<Map<String, dynamic>>>{};
    for (var item in _cartManager.cartItems) {
      final distributorId = item['distributor_id'] ?? 1;
      if (!distributorItems.containsKey(distributorId)) {
        distributorItems[distributorId] = [];
      }
      distributorItems[distributorId]!.add(item);
    }
    return distributorItems;
  }

  // Get order number for distributor (sequential numbering)
  String _getOrderNumber(int distributorId) {
    final distributorIds = _getDistributorItems().keys.toList()..sort();
    final index = distributorIds.indexOf(distributorId);
    return (index + 1).toString();
  }

  // Show order success modal
  Future<void> _showOrderSuccessModal(Map<String, dynamic> orderResponse) async {
    final orders = orderResponse['orders'] as List? ?? [];
    final totalOrders = orderResponse['total_orders'] ?? orders.length;
    final combinedTotal = _safeToDouble(orderResponse['combined_total'] ?? 0);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                Text(
                  totalOrders > 1 ? '$totalOrders Orders Created!' : 'Order Created!',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF065F46),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Order Details
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      children: orders.map<Widget>((order) {
                        final orderId = order['id']?.toString() ?? 'N/A';
                        final deliveryCode = order['delivery_code']?.toString() ?? 'N/A';
                        final itemCount = order['item_count'] ?? 0;
                        final orderTotal = _safeToDouble(order['total_amount']);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order #$orderId',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF065F46),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      currencyFormat.format(orderTotal),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.qr_code, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Code: $deliveryCode',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$itemCount items',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                
                if (totalOrders > 1) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF10B981).withOpacity(0.1),
                          const Color(0xFF059669).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                        Text(
                          currencyFormat.format(combinedTotal),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue Shopping',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartContent() {
    final cartTotal = _cartManager.totalAmount;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : theme.colorScheme.onSurface;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Multi-distributor info banner (only show if multiple distributors)
          if (_getDistributorCount() > 1)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0A0A0A), const Color(0xFF0A0A0A)]
                      : [
                          const Color(0xFF3B82F6).withOpacity(0.05),
                          const Color(0xFF3B82F6).withOpacity(0.02),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFF3B82F6).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multiple Distributors',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? textColor : const Color(0xFF3B82F6),
                          ),
                        ),
                        Text(
                          'Your items will be split into ${_getDistributorCount()} separate orders for payment and delivery.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? textColor.withOpacity(0.7) : const Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Cart summary header
          Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              final surfaceColor = theme.colorScheme.surface;
              final textColor = theme.colorScheme.onSurface;
              final primaryColor = theme.colorScheme.primary;
              final locale = AppLocalizations.of(context);
              
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A0A0A) : surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locale?.isRTL == true 
                            ? '${_cartManager.cartItems.length > 1 ? (locale?.items ?? 'منتجات') : (locale?.item ?? 'منتج')} ${_cartManager.cartItems.length} ${locale?.inCart ?? 'في السلة'}'
                            : '${_cartManager.cartItems.length} ${_cartManager.cartItems.length > 1 ? (locale?.items ?? 'items') : (locale?.item ?? 'item')} ${locale?.inCart ?? 'in cart'}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        _getDistributorCount() > 1 
                            ? '${locale?.from ?? 'From'} ${_getDistributorCount()} ${locale?.distributors ?? 'distributors'} • ${_getDistributorCount()} ${locale?.separateOrdersWillBeCreated ?? 'separate orders will be created'}'
                            : '${locale?.from ?? 'From'} 1 ${locale?.distributor ?? 'distributor'} • 1 ${locale?.orderWillBeCreated ?? 'order will be created'}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currencyFormat.format(cartTotal),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Distributor sections
          ...(_getDistributorItems().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildDistributorOrderCard(entry.key, entry.value),
            );
          }).toList()),
          
          const SizedBox(height: 16),
          _buildPaymentMethodSelector(),
          _buildOrderSummary(cartTotal),
          const SizedBox(height: 100), // Space for bottom navigation
        ],
      ),
    );
  }
}