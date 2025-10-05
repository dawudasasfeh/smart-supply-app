import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/rate_supplier_card.dart';
import '../../l10n/app_localizations.dart';

class SupermarketOrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(int)? onRatingSubmitted;
  final Function(int)? onRatingDismissed;
  final bool isRated;
  final bool isDismissed;

  const SupermarketOrderDetailsPage({
    super.key, 
    required this.order,
    this.onRatingSubmitted,
    this.onRatingDismissed,
    this.isRated = false,
    this.isDismissed = false,
  });

  @override
  State<SupermarketOrderDetailsPage> createState() => _SupermarketOrderDetailsPageState();
}

class _SupermarketOrderDetailsPageState extends State<SupermarketOrderDetailsPage> 
    with TickerProviderStateMixin {
  List<dynamic> orderItems = [];
  Map<String, dynamic>? deliveryInfo;
  bool isLoadingItems = true;
  String supermarketId = '';
  String supermarketName = '';
  bool isRated = false;
  bool isDismissed = false;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    isRated = widget.isRated;
    isDismissed = widget.isDismissed;
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    _loadOrderDetails();
    
    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _scaleController.forward();
    });
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    try {
      final orderId = widget.order['id'];
      print('🔍 Loading supermarket order details for order ID: $orderId');
      
      // Load supermarket info for QR generation (same as Orders page)
      final prefs = await SharedPreferences.getInstance();
      supermarketId = prefs.getInt('user_id')?.toString() ?? '1';
      supermarketName = prefs.getString('name') ?? 'SuperMarket';
      print('🔍 Loaded supermarket info: ID=$supermarketId, Name=$supermarketName');
      
      // Load order items
      List<dynamic> items = [];
      
      // Always try to fetch real items from API first
      if (orderId != null) {
        print('📡 Fetching real order items from API for order: $orderId');
        try {
          items = await ApiService.getOrderItems(orderId);
          print('✅ Fetched ${items.length} items from API');
          
          // If API returned items, enhance them with product details
          if (items.isNotEmpty) {
            items = await _enhanceItemsWithProductDetails(items);
          }
        } catch (apiError) {
          print('❌ API fetch failed: $apiError');
        }
      }
      
      // Fallback: Check if order data contains items
      if (items.isEmpty) {
        if (widget.order.containsKey('items')) {
          items = List<dynamic>.from(widget.order['items'] ?? []);
          print('✅ Found items in order data: ${items.length} items');
        } else if (widget.order.containsKey('products')) {
          items = List<dynamic>.from(widget.order['products'] ?? []);
          print('✅ Found products in order data: ${items.length} items');
        } else if (widget.order.containsKey('order_items')) {
          items = List<dynamic>.from(widget.order['order_items'] ?? []);
          print('✅ Found order_items in order data: ${items.length} items');
        }
      }
      
      // Final fallback: Create mock items if still empty
      if (items.isEmpty) {
        print('📝 Creating mock items as final fallback');
        items = _createMockItems();
      }
      
      // Load delivery information
      await _loadDeliveryInfo();
      
      if (mounted) {
        setState(() {
          orderItems = items;
          isLoadingItems = false;
        });
      }
    } catch (e) {
      print('❌ Error loading order details: $e');
      if (mounted) {
        setState(() {
          orderItems = _createMockItems();
          isLoadingItems = false;
        });
      }
    }
  }

  Future<void> _loadDeliveryInfo() async {
    try {
      final orderId = widget.order['id'];
      final status = widget.order['status']?.toString().toLowerCase() ?? '';
      
      // For accepted and delivered orders, we need delivery info
      if (status == 'accepted' || status == 'delivered') {
        if (orderId != null) {
          // Try to get delivery assignment info from API
          try {
            print('🔍 Fetching delivery info for order: $orderId');
            final deliveryData = await ApiService.getOrderDeliveryInfo(orderId);
            
            if (mounted) {
              setState(() {
                if (deliveryData != null && deliveryData.isNotEmpty) {
                  
                  // Check if we have actual delivery man data (not just order data)
                  final deliveryManName = deliveryData['delivery_man_name'];
                  final hasDeliveryMan = deliveryManName != null && 
                                       deliveryManName.toString() != 'null' &&
                                       deliveryManName.toString().trim().isNotEmpty;
                  
                  
                  if (hasDeliveryMan) {
                    // Use real delivery data from backend
                    deliveryInfo = deliveryData;
                    print('✅ Loaded REAL delivery info from backend: ${deliveryData.keys.toList()}');
                    print('✅ Delivery man: ${deliveryData['delivery_man_name']}');
                  } else {
                    // Order exists but no delivery assignment yet
                    deliveryInfo = _createFallbackDeliveryInfo();
                    print('⚠️ Order found but no delivery man assigned yet');
                    print('⚠️ API returned: ${deliveryData.toString()}');
                  }
                } else {
                  // No delivery assignment yet, create fallback info with real order data
                  deliveryInfo = _createFallbackDeliveryInfo();
                  print('⚠️ No delivery assignment found, using fallback info');
                }
              });
              
              // QR code will be generated when needed
            }
          } catch (e) {
            print('❌ Error loading delivery info: $e');
            if (mounted) {
              setState(() {
                deliveryInfo = _createFallbackDeliveryInfo();
              });
            }
          }
        } else {
          // No order ID, create fallback info
          if (mounted) {
            setState(() {
              deliveryInfo = _createFallbackDeliveryInfo();
            });
          }
        }
      } else {
        // Order not in delivery status, create fallback info
        if (mounted) {
          setState(() {
            deliveryInfo = _createFallbackDeliveryInfo();
          });
        }
      }
    } catch (e) {
      print('Error in _loadDeliveryInfo: $e');
      final status = widget.order['status']?.toString().toLowerCase() ?? '';
      if (status == 'accepted' || status == 'delivered') {
        // Always provide mock delivery info for accepted/delivered orders
        if (mounted) {
          setState(() {
            deliveryInfo = _createMockDeliveryInfo();
          });
        }
      }
    }
  }


  Future<List<dynamic>> _enhanceItemsWithProductDetails(List<dynamic> items) async {
    List<dynamic> enhancedItems = [];
    
    for (var item in items) {
      try {
        final productId = item['product_id'];
        if (productId != null) {
          print('📡 Fetching product details for product ID: $productId');
          
          // Get product details from API
          final productDetails = await ApiService.getProductDetails(productId);
          
          if (productDetails != null) {
            // Merge order item data with product details
            final enhancedItem = {
              ...item,
              'name': productDetails['name'] ?? item['product_name'] ?? item['name'] ?? 'Unknown Product',
              'product_name': productDetails['name'] ?? item['product_name'] ?? item['name'] ?? 'Unknown Product',
              'image_url': productDetails['image_url'] ?? item['product_image'] ?? item['image_url'],
              'product_image': productDetails['image_url'] ?? item['product_image'] ?? item['image_url'],
              'description': productDetails['description'] ?? item['product_description'] ?? item['description'],
              'product_description': productDetails['description'] ?? item['product_description'] ?? item['description'],
              'price': item['unit_price'] ?? item['price'] ?? productDetails['price'] ?? '0',
              'unit_price': item['unit_price'] ?? item['price'] ?? productDetails['price'] ?? '0',
              'total_price': item['total_price'] ?? item['price'] ?? '0',
              'category': productDetails['category'],
              'brand': productDetails['brand'],
            };
            enhancedItems.add(enhancedItem);
            print('✅ Enhanced item: ${enhancedItem['product_name']}');
          } else {
            // Keep original item if product details not found
            enhancedItems.add(item);
            print('❌ No product details found for ID: $productId');
          }
        } else {
          // Keep original item if no product_id
          enhancedItems.add(item);
        }
      } catch (e) {
        print('❌ Error enhancing item: $e');
        // Keep original item on error
        enhancedItems.add(item);
      }
    }
    
    return enhancedItems;
  }

  List<dynamic> _createMockItems() {
    final totalAmount = double.tryParse(widget.order['total_amount']?.toString() ?? '0') ?? 100.0;
    
    return [
      {
        'id': 1,
        'name': 'Fresh Red Apples',
        'product_name': 'Fresh Red Apples',
        'quantity': 5,
        'price': (totalAmount * 0.3).toStringAsFixed(2),
        'unit_price': (totalAmount * 0.3).toStringAsFixed(2),
        'total_price': (totalAmount * 0.3).toStringAsFixed(2),
        'image_url': 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=400&h=400&fit=crop',
        'product_image': 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=400&h=400&fit=crop',
      },
      {
        'id': 2,
        'name': 'Organic Bananas',
        'product_name': 'Organic Bananas',
        'quantity': 3,
        'price': (totalAmount * 0.2).toStringAsFixed(2),
        'unit_price': (totalAmount * 0.2).toStringAsFixed(2),
        'total_price': (totalAmount * 0.2).toStringAsFixed(2),
        'image_url': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400&h=400&fit=crop',
        'product_image': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400&h=400&fit=crop',
      },
      {
        'id': 3,
        'name': 'Fresh Whole Milk',
        'product_name': 'Fresh Whole Milk',
        'quantity': 2,
        'price': (totalAmount * 0.25).toStringAsFixed(2),
        'unit_price': (totalAmount * 0.25).toStringAsFixed(2),
        'total_price': (totalAmount * 0.25).toStringAsFixed(2),
        'image_url': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&h=400&fit=crop',
        'product_image': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&h=400&fit=crop',
      },
      {
        'id': 4,
        'name': 'Artisan Bread Loaf',
        'product_name': 'Artisan Bread Loaf',
        'quantity': 1,
        'price': (totalAmount * 0.25).toStringAsFixed(2),
        'unit_price': (totalAmount * 0.25).toStringAsFixed(2),
        'total_price': (totalAmount * 0.25).toStringAsFixed(2),
        'image_url': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&h=400&fit=crop',
        'product_image': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&h=400&fit=crop',
      },
    ];
  }

  Map<String, dynamic> _createFallbackDeliveryInfo() {
    final orderId = widget.order['id']?.toString() ?? '1';
    // Ensure delivery code is never empty
    final deliveryCode = widget.order['delivery_code']?.toString().isNotEmpty == true 
        ? widget.order['delivery_code'].toString()
        : 'DEL_${orderId}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    print('🔧 Creating fallback delivery info (no assignment yet) with delivery_code: $deliveryCode');
    
    return {
      'delivery_man_name': 'Pending Assignment',
      'delivery_man_phone': 'Not assigned yet',
      'delivery_man_email': 'pending@assignment.com',
      'vehicle_type': 'To be assigned',
      'vehicle_plate': 'PENDING',
      'vehicle_color': 'Not assigned',
      'plate_number': 'PENDING',
      'estimated_delivery': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      'delivery_status': widget.order['status']?.toString() ?? 'pending',
      'delivery_code': deliveryCode,
      'tracking_number': 'TRK-${widget.order['id']}-${DateTime.now().millisecondsSinceEpoch}',
      'qr_data': deliveryCode, // QR code will contain the delivery code
    };
  }

  Map<String, dynamic> _createMockDeliveryInfo() {
    final orderId = widget.order['id']?.toString() ?? '1';
    // Ensure delivery code is never empty
    final deliveryCode = widget.order['delivery_code']?.toString().isNotEmpty == true 
        ? widget.order['delivery_code'].toString()
        : 'DEL_${orderId}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    print('🔧 Creating mock delivery info with delivery_code: $deliveryCode');
    
    return {
      'delivery_man_name': 'Ahmed Hassan',
      'delivery_man_phone': '+201001234567',
      'delivery_man_email': 'ahmed.hassan@delivery.com',
      'vehicle_type': 'Motorcycle',
      'vehicle_plate': 'ABC-1234',
      'vehicle_color': 'Blue Honda',
      'plate_number': 'DL123456789',
      'estimated_delivery': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      'delivery_status': widget.order['status']?.toString() ?? 'pending',
      'delivery_code': deliveryCode,
      'tracking_number': 'TRK-${widget.order['id']}-${DateTime.now().millisecondsSinceEpoch}',
      'qr_data': deliveryCode, // QR code will contain the delivery code
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final locale = AppLocalizations.of(context);
    
    final order = widget.order;
    final orderId = order['id']?.toString() ?? 'N/A';
    final status = order['status']?.toString() ?? 'Unknown';
    final totalAmount = order['total_amount']?.toString() ?? '0';
    final createdAt = order['created_at']?.toString();
    final distributorName = order['distributor']?['name'] ?? order['distributor_name'] ?? 'Unknown Distributor';
    final distributorId = order['distributor_id'] as int? ?? 0;
    
    String formattedDate = 'Unknown date';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
      } catch (e) {
        formattedDate = createdAt;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        // Animated Order Icon
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _fadeAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${locale?.isRTL == true ? 'الطلب' : 'Order'} #$orderId',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      locale?.isRTL == true ? 'تفاصيل الطلب والتتبع' : 'Order Details & Tracking',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: subtextColor,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // Action Buttons
                        if (deliveryInfo != null && deliveryInfo!['delivery_man_phone'] != null)
                          AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    onPressed: () => _makePhoneCall(deliveryInfo!['delivery_man_phone']),
                                    icon: const Icon(
                                      Icons.phone_rounded,
                                      color: Color(0xFF3B82F6),
                                      size: 20,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Order Status Card
                        _buildModernStatusCard(status, formattedDate, totalAmount, distributorName),
                        
                        const SizedBox(height: 20),
                        
                        // Delivery Information Card
                        if (status.toLowerCase() == 'accepted' || status.toLowerCase() == 'delivered')
                          _buildModernDeliveryCard(),
                        
                        // Order Status Info Card (only for pending orders)
                        if (status.toLowerCase() == 'pending')
                          _buildModernPendingCard(status),
                        
                        const SizedBox(height: 20),
                        
                        // Products List Card
                        _buildModernProductsCard(),
                        
                        const SizedBox(height: 20),
                        
                        // Rate Supplier Card (for delivered orders)
                        if (status.toLowerCase() == 'delivered' && 
                            distributorId > 0 && 
                            !isRated &&
                            !isDismissed)
                          RateSupplierCard(
                            distributorId: distributorId,
                            orderId: int.tryParse(orderId) ?? 0,
                            distributorName: distributorName,
                            onDismissed: () {
                              setState(() {
                                isDismissed = true;
                              });
                              if (widget.onRatingDismissed != null) {
                                widget.onRatingDismissed!(int.tryParse(orderId) ?? 0);
                              }
                            },
                            onRatingSubmitted: () {
                              setState(() {
                                isRated = true;
                              });
                              if (widget.onRatingSubmitted != null) {
                                widget.onRatingSubmitted!(int.tryParse(orderId) ?? 0);
                              }
                            },
                          ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status, String formattedDate, String totalAmount, String distributorName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final locale = AppLocalizations.of(context);
    
    return Card(
      elevation: 4,
      shadowColor: isDark ? Colors.black.withOpacity(0.3) : Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    _getStatusColor(status).withOpacity(0.1),
                    const Color(0xFF0A0A0A),
                  ]
                : [
                    _getStatusColor(status).withOpacity(0.1),
                    Colors.white,
                  ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale?.isRTL == true ? 'حالة الطلب' : 'Order Status',
                      style: TextStyle(
                        fontSize: 14,
                        color: subtextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(status).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            size: 16,
                            color: _getStatusColor(status),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      locale?.isRTL == true ? 'المبلغ الإجمالي' : 'Total Amount',
                      style: TextStyle(
                        fontSize: 14,
                        color: subtextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${double.tryParse(totalAmount)?.toStringAsFixed(2) ?? totalAmount}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                    Text(
                      '${locale?.isRTL == true ? 'تم الطلب في' : 'Ordered on'} $formattedDate',
                      style: TextStyle(
                        fontSize: 14,
                        color: subtextColor,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.business,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '${locale?.isRTL == true ? 'الموزع' : 'Distributor'}: $distributorName',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusInfoCard(String status) {
    // This is only called for pending orders now
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.warning.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.schedule,
                    color: AppColors.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Pending',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your order is waiting for distributor confirmation. You will be notified once it\'s accepted and assigned to a delivery person.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final locale = AppLocalizations.of(context);
    
    print('🔍 _buildDeliveryInfoCard called, deliveryInfo: $deliveryInfo');
    
    if (deliveryInfo == null) {
      print('❌ deliveryInfo is null, returning empty widget');
      return const SizedBox.shrink();
    }

    final driverName = deliveryInfo!['delivery_man_name'] ?? 'Unknown Driver';
    final driverPhone = deliveryInfo!['delivery_man_phone'] ?? 'No phone';
    final plateNumber = deliveryInfo!['vehicle_plate'] ?? 'No plate';
    final rawDeliveryCode = deliveryInfo!['delivery_code'] ?? deliveryInfo!['qr_data'] ?? '';
    final deliveryCode = rawDeliveryCode.isNotEmpty 
        ? rawDeliveryCode 
        : 'DEL_${widget.order['id']}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    print('🔍 DeliveryInfo data: ${deliveryInfo.toString()}');
    print('🔍 Raw deliveryCode: $rawDeliveryCode');
    print('🔍 Final deliveryCode: $deliveryCode');

    return Card(
      elevation: 8,
      shadowColor: isDark ? Colors.black.withOpacity(0.3) : AppColors.primary.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0A0A0A),
                    const Color(0xFF000000),
                  ]
                : [
                    Colors.white,
                    AppColors.primary.withOpacity(0.02),
                  ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delivery_dining,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      locale?.isRTL == true ? 'معلومات التوصيل' : 'Delivery Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Main Content
              Column(
                children: [
                  // Driver Card
                  _buildDriverCard(driverName, driverPhone),
                  
                  const SizedBox(height: 16),
                  
                  // Vehicle Card
                  _buildVehicleCard(plateNumber),
                  
                  const SizedBox(height: 16),
                  
                  // QR Code Card
                  _buildQRCard(deliveryCode),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverCard(String driverName, String driverPhone) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final locale = AppLocalizations.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0A0A0A),
                  const Color(0xFF000000),
                ]
              : [
                  Colors.green.withOpacity(0.1),
                  Colors.green.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1F1F1F) : Colors.green.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.green.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Your Driver',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Driver Name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF1F1F1F) : Colors.green.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Driver Name',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  driverName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          
          // Phone Button
          GestureDetector(
            onTap: () => _makePhoneCall(driverPhone),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Column(
                    children: [
                      const Text(
                        'Call Driver',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        driverPhone,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(String plateNumber) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final locale = AppLocalizations.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0A0A0A),
                  const Color(0xFF000000),
                ]
              : [
                  Colors.blue.withOpacity(0.1),
                  Colors.blue.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1F1F1F) : Colors.blue.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.blue.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.motorcycle,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Vehicle Info',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // License Plate
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF1F1F1F) : Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Text(
                  'License Plate',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
                  ),
                  child: Text(
                    plateNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  String _generateOrdersPageQRData(Map<String, dynamic> order) {
    // Use consistent delivery code format: DEL + zero-padded order ID (same as Orders page)
    final orderId = order['id']?.toString() ?? '0';
    final deliveryCode = 'DEL${orderId.padLeft(3, '0')}'; // DEL014, DEL004, etc.
    
    print('🔍 Orders page QR generation - orderId: $orderId, deliveryCode: $deliveryCode');
    
    final qrContent = {
      'type': 'delivery_verification',
      'supermarket_id': supermarketId,
      'supermarket_name': supermarketName,
      'order_id': int.tryParse(orderId) ?? 0,
      'delivery_code': deliveryCode,
      'verification_key': deliveryCode,
    };
    
    print('🔍 Generated QR content: ${jsonEncode(qrContent)}');
    
    return jsonEncode(qrContent);
  }


  void _showWorkingQRDialog(Map<String, dynamic> order) {
    final deliveryCode = (order['delivery_code'] ?? 'DEL${(order['id'] ?? 0).toString()}').toString();
    final qrData = _generateOrdersPageQRData(order);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.qr_code_2,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery QR Code',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Order #${(order['id'] ?? 0).toString()}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // QR Code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Delivery Code
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Delivery Code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deliveryCode,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Show this QR code to the delivery person to verify your order delivery.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQRCard(String deliveryCode) {
    // Ensure delivery code is never empty
    final validDeliveryCode = deliveryCode.isNotEmpty 
        ? deliveryCode 
        : deliveryInfo?['delivery_code']?.toString() ?? 
          'DEL_${widget.order['id']}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    print('🔍 Building QR card with delivery code: $validDeliveryCode');
    
    // Generate QR code using same method as Orders page
    final qrData = _generateOrdersPageQRData(widget.order);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // QR Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Delivery QR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // QR Code Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // QR Code (Clickable)
                GestureDetector(
                  onTap: () {
                    _showWorkingQRDialog(widget.order);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 300, // Extra large QR code matching dialog size
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Delivery Code
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    validDeliveryCode,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                
                const SizedBox(height: 6),
                
                const Text(
                  'Show this QR code to\nthe delivery person',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.inventory,
                  color: AppColors.primary,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Products Ordered',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoadingItems)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else if (orderItems.isEmpty)
              const Center(
                child: Text(
                  'No products information available',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orderItems.length,
                itemBuilder: (context, index) {
                  final item = orderItems[index];
                  // Cast to proper type to avoid type errors
                  final itemMap = Map<String, dynamic>.from(item as Map);
                  return _buildProductItem(itemMap);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item) {
    final productName = item['product_name']?.toString() ?? item['name']?.toString() ?? 'Unknown Product';
    final quantity = item['quantity']?.toString() ?? '1';
    final imageUrl = item['product_image']?.toString() ?? item['image_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product Image (larger)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl.startsWith('http') 
                          ? imageUrl 
                          : 'http://10.0.2.2:5000$imageUrl',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultProductIcon();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    )
                  : _buildDefaultProductIcon(),
            ),
          ),
          const SizedBox(width: 16),
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primary.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shopping_cart,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Qty: $quantity',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Checkmark indicator
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.check,
              color: AppColors.success,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultProductIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.primary,
        size: 36,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.primary;
      case 'delivered':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_outlined;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'delivered':
        return Icons.verified_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _getLocalizedStatus(String status, AppLocalizations? locale) {
    final isArabic = locale?.isRTL == true;
    switch (status.toLowerCase()) {
      case 'pending':
        return isArabic ? 'قيد الانتظار' : 'PENDING';
      case 'accepted':
        return isArabic ? 'مقبول' : 'ACCEPTED';
      case 'delivered':
        return isArabic ? 'تم التوصيل' : 'DELIVERED';
      default:
        return status.toUpperCase();
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleanNumber.isEmpty || cleanNumber == 'No phone') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check and request phone permission
    var phonePermission = await Permission.phone.status;
    print('📞 Current phone permission status: $phonePermission');
    
    if (phonePermission.isDenied) {
      phonePermission = await Permission.phone.request();
      print('📞 Requested phone permission, new status: $phonePermission');
    }
    
    // Try multiple approaches for phone calling
    bool launched = false;
    
    // Approach 1: Direct phone call (requires CALL_PHONE permission)
    if (phonePermission.isGranted) {
      final callUri = Uri.parse('tel:$cleanNumber');
      try {
        print('🔍 Trying direct call with permission: $callUri');
        if (await canLaunchUrl(callUri)) {
          await launchUrl(callUri, mode: LaunchMode.externalApplication);
          launched = true;
          print('✅ Successfully launched phone app with call permission');
        }
      } catch (e) {
        print('❌ Direct call failed: $e');
      }
    }
    
    // Approach 2: Open dialer without auto-call (doesn't require CALL_PHONE permission)
    if (!launched) {
      final List<Uri> dialerUris = [
        Uri.parse('tel:$cleanNumber'),
        Uri(scheme: 'tel', path: cleanNumber),
      ];
      
      for (final dialerUri in dialerUris) {
        try {
          print('🔍 Trying to open dialer: $dialerUri');
          if (await canLaunchUrl(dialerUri)) {
            await launchUrl(dialerUri, mode: LaunchMode.externalApplication);
            launched = true;
            print('✅ Successfully opened dialer');
            break;
          }
        } catch (e) {
          print('❌ Failed to open dialer $dialerUri: $e');
          continue;
        }
      }
    }
    
    // Approach 3: Show dialog with options
    if (!launched && mounted) {
      _showPhoneOptionsDialog(cleanNumber);
    }
  }

  void _showPhoneOptionsDialog(String phoneNumber) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.phone, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Call Options'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phone: $phoneNumber'),
              const SizedBox(height: 16),
              const Text('Choose an option:'),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: phoneNumber));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Phone number copied to clipboard'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Number'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                // Try to open phone app directly
                try {
                  final phoneUri = Uri.parse('tel:$phoneNumber');
                  await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not open phone app: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.phone),
              label: const Text('Open Dialer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Modern Status Card
  Widget _buildModernStatusCard(String status, String formattedDate, String totalAmount, String distributorName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final locale = AppLocalizations.of(context);
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0A0A0A), const Color(0xFF000000)]
                      : [Colors.white, const Color(0xFFF8FAFC)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
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
                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_getStatusColor(status), _getStatusColor(status).withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(status).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getStatusIcon(status),
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
                              _getLocalizedStatus(status, locale),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(status),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedDate,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '\$${(double.tryParse(totalAmount) ?? 0.0).toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Distributor Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.store_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locale?.isRTL == true ? 'المورد' : 'SUPPLIER',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: subtextColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                distributorName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Modern Delivery Card
  Widget _buildModernDeliveryCard() {
    if (deliveryInfo == null) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final locale = AppLocalizations.of(context);
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0A0A0A), const Color(0xFF000000)]
                      : [Colors.white, const Color(0xFFF8FAFC)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          locale?.isRTL == true ? 'معلومات التوصيل' : 'Delivery Information',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  if (deliveryInfo!['delivery_man_name'] != null) ...[
                    _buildInfoRow(
                      Icons.person_rounded,
                      locale?.isRTL == true ? 'مندوب التوصيل' : 'Delivery Person',
                      deliveryInfo!['delivery_man_name'].toString(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (deliveryInfo!['delivery_man_phone'] != null) ...[
                    _buildInfoRow(
                      Icons.phone_rounded,
                      locale?.isRTL == true ? 'رقم الهاتف' : 'Phone Number',
                      deliveryInfo!['delivery_man_phone'].toString(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (deliveryInfo!['plate_number'] != null) ...[
                    _buildInfoRow(
                      Icons.local_shipping_rounded,
                      locale?.isRTL == true ? 'لوحة السيارة' : 'Vehicle Plate',
                      deliveryInfo!['plate_number'].toString(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (deliveryInfo!['estimated_delivery'] != null) ...[
                    _buildInfoRow(
                      Icons.schedule_rounded,
                      locale?.isRTL == true ? 'التوصيل المتوقع' : 'Estimated Delivery',
                      deliveryInfo!['estimated_delivery'].toString(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Modern Pending Card
  Widget _buildModernPendingCard(String status) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0A0A0A),
                          const Color(0xFF000000),
                        ]
                      : [
                          const Color(0xFFFEF3C7),
                          const Color(0xFFFDE68A),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFBBF24),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      color: Color(0xFFF59E0B),
                      size: 32,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    locale?.isRTL == true ? 'قيد الانتظار' : 'Order Pending',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    locale?.isRTL == true
                        ? 'يتم معالجة طلبك بواسطة الموزع. سيتم إعلامك بمجرد قبوله.'
                        : 'Your order is being processed by the distributor. You will be notified once it\'s accepted.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF92400E),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Modern Products Card
  Widget _buildModernProductsCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final locale = AppLocalizations.of(context);
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0A0A0A), const Color(0xFF000000)]
                      : [Colors.white, const Color(0xFFF8FAFC)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '${locale?.isRTL == true ? 'عناصر الطلب' : 'Order Items'} (${orderItems.length})',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  if (isLoadingItems)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF3B82F6),
                      ),
                    )
                  else if (orderItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          locale?.isRTL == true ? 'لا توجد عناصر' : 'No items found',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  else
                    ...orderItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 600 + (index * 100)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutBack,
                        builder: (context, itemValue, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - itemValue)),
                            child: Opacity(
                              opacity: itemValue.clamp(0.0, 1.0),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                                            ? Image.network(
                                                item['image_url'].toString(),
                                                width: 46,
                                                height: 46,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 46,
                                                    height: 46,
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                                      ),
                                                      borderRadius: BorderRadius.circular(7),
                                                    ),
                                                    child: const Icon(
                                                      Icons.shopping_bag_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  );
                                                },
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Container(
                                                    width: 46,
                                                    height: 46,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF8FAFC),
                                                      borderRadius: BorderRadius.circular(7),
                                                    ),
                                                    child: const Center(
                                                      child: SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Color(0xFF3B82F6),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : Container(
                                                width: 46,
                                                height: 46,
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(7),
                                                ),
                                                child: const Icon(
                                                  Icons.shopping_bag_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name']?.toString() ?? 'Unknown Product',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${locale?.isRTL == true ? 'الكمية' : 'Qty'}: ${item['quantity']?.toString() ?? '0'}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF3B82F6),
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: subtextColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
