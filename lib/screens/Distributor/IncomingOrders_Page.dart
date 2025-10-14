import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/notification_service.dart';
import '../../themes/role_theme_manager.dart';
import '../../l10n/app_localizations.dart';

class IncomingOrdersPage extends StatefulWidget {
  const IncomingOrdersPage({super.key});

  @override
  State<IncomingOrdersPage> createState() => _IncomingOrdersPageState();
}

class _IncomingOrdersPageState extends State<IncomingOrdersPage> with TickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pendingOrders = [];
  List<dynamic> _processingOrders = [];
  List<dynamic> _completedOrders = [];
  List<dynamic> _cancelledOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? token;
  int? userId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Stats (commented out as they're not currently used)
  // int _totalOrders = 0;
  // int _pendingCount = 0;
  // int _processingCount = 0;
  // int _completedCount = 0;
  // double _totalRevenue = 0.0;
  
  // Socket.IO
  final SocketService _socketService = SocketService.instance;
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<Map<String, dynamic>>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _orderSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
      userId = prefs.getInt('user_id');
      
      if (token != null && userId != null) {
        await _initializeSocketConnection();
        await _loadOrders();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadOrders() async {
    if (token == null || userId == null) return;
    
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('🔄 Loading orders for distributor ID: $userId');
      final orders = await ApiService.getDistributorOrders(token!, userId!);
      print('📦 Received ${orders.length} orders');
      print('📋 Orders data: $orders');
      
      if (!mounted) return;
      _categorizeOrders(orders);
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load orders. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _categorizeOrders(List<dynamic> orders) {
    print('🔄 Categorizing ${orders.length} orders');
    
    setState(() {
      List<dynamic> pending = [];
      List<dynamic> processing = [];
      List<dynamic> completed = [];
      List<dynamic> cancelled = [];

      for (final dynamic rawOrder in orders) {
        try {
          final Map<String, dynamic> order = Map<String, dynamic>.from(rawOrder as Map);
          final String status = (order['status']?.toString() ?? '').toLowerCase().trim();

          // Order Lifecycle: Order Created (pending) → Accepted → Delivered
          if (status == 'pending' || status == 'new' || status == 'awaiting' || status == 'awaiting_confirmation') {
            pending.add(order);
          } else if (status == 'accepted' || status == 'processing' || status == 'packed' || status == 'shipped' || status == 'out_for_delivery' || status == 'assigned') {
            processing.add(order);
          } else if (status == 'completed' || status == 'delivered') {
            completed.add(order);
          } else if (status == 'cancelled' || status == 'canceled' || status == 'rejected' || status == 'failed') {
            cancelled.add(order);
          } else {
            processing.add(order);
          }
        } catch (_) {
          // If structure unexpected, still show the order under processing
          processing.add(rawOrder);
        }
      }

      _pendingOrders = pending;
      _processingOrders = processing;
      _completedOrders = completed;
      _cancelledOrders = cancelled;
    });
    
    print('📊 Categorized orders:');
    print('   Pending: ${_pendingOrders.length}');
    print('   Processing: ${_processingOrders.length}');
    print('   Completed: ${_completedOrders.length}');
    print('   Cancelled: ${_cancelledOrders.length}');
  }
  
  // Commented out as these stats aren't currently used
  // void _calculateStats() {
  //   _totalOrders = _pendingOrders.length + _processingOrders.length + _completedOrders.length + _cancelledOrders.length;
  //   _pendingCount = _pendingOrders.length;
  //   _processingCount = _processingOrders.length;
  //   _completedCount = _completedOrders.length;
    
  //   _totalRevenue = _completedOrders.fold(0.0, (sum, order) {
  //     return sum + (double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0);
  //   });
  // }
  
  Future<void> _initializeSocketConnection() async {
    try {
      await _socketService.connect();
      
      _orderSubscription = _socketService.orderStream.listen((event) {
        if (event['type'] == 'new_order' || event['type'] == 'order_updated') {
          _loadOrders(); // Refresh orders when there's an update
          
          // Show notification for new orders
          if (event['type'] == 'new_order' && mounted) {
            final order = event['data'];
            _notificationService.showOrderStatusNotification(
              orderId: order['id'].toString(),
              status: 'New Order',
              message: 'New order #${order['id']} received',
            );
          }
        }
      });
    } catch (e) {
      print('Error initializing socket: $e');
    }
  }
  
  Future<void> _updateOrderStatus(String orderId, String status) async {
    if (token == null) return;
    
    try {
      final success = await ApiService.updateOrderStatus(token!, int.parse(orderId), status);
      if (success) {
        await _loadOrders(); // Refresh orders after status update
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order status updated to $status')),
          );
        }
      } else {
        throw Exception('Failed to update order status');
      }
    } catch (e) {
      print('Error updating order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update order status')),
        );
      }
    }
  }
  
  Future<void> _showOrderDetails(Map<String, dynamic> order) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final isRTL = locale?.isRTL == true;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildOrderDetailsHeader(order, isDark, locale, isRTL),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Summary
                      _buildOrderSummarySection(order, isDark, locale, isRTL),
                      
                      const SizedBox(height: 24),
                      
                      // Customer Information
                      _buildCustomerInfoSection(order, isDark, locale, isRTL),
                      
                      const SizedBox(height: 24),
                      
                      // Order Items
                      _buildOrderItemsSection(order, isDark, locale, isRTL),
                      
                      const SizedBox(height: 24),
                      
                      // Delivery Information
                      _buildDeliveryInfoSection(order, isDark, locale, isRTL),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              
              // Actions
              _buildOrderDetailsActions(order, isDark, locale, isRTL),
            ],
          ),
        ),
      ),
    );
  }

  // New modern order details dialog components
  Widget _buildOrderDetailsHeader(Map<String, dynamic> order, bool isDark, AppLocalizations? locale, bool isRTL) {
    final status = order['status']?.toString() ?? 'Unknown';
    final orderId = order['id']?.toString() ?? 'N/A';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: isDark ? Border(
          bottom: BorderSide(color: const Color(0xFF1F1F1F)),
        ) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRTL ? 'طلب رقم #$orderId' : 'Order #$orderId',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                _buildCleanStatusChip(status, isDark, AppLocalizations.of(context), DistributorColors(isDark: isDark)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
            ),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummarySection(Map<String, dynamic> order, bool isDark, AppLocalizations? locale, bool isRTL) {
    final createdAt = order['created_at']?.toString();
    final totalAmount = order['total_amount']?.toString() ?? '0';
    final items = order['items'] as List<dynamic>? ?? [];
    final itemCount = items.length;
    
    DateTime orderDate = DateTime.now();
    if (createdAt != null) {
      try {
        orderDate = DateTime.parse(createdAt);
      } catch (e) {
        orderDate = DateTime.now();
      }
    }

    return _buildSection(
      title: isRTL ? 'ملخص الطلب' : 'Order Summary',
      isDark: isDark,
      isRTL: isRTL,
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.calendar_today_rounded,
            label: isRTL ? 'تاريخ الطلب' : 'Order Date',
            value: '${orderDate.day}/${orderDate.month}/${orderDate.year} ${orderDate.hour}:${orderDate.minute.toString().padLeft(2, '0')}',
            isDark: isDark,
            isRTL: isRTL,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.shopping_bag_rounded,
            label: isRTL ? 'عدد المنتجات' : 'Items Count',
            value: '$itemCount ${isRTL ? 'منتج' : 'items'}',
            isDark: isDark,
            isRTL: isRTL,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.attach_money_rounded,
            label: isRTL ? 'المبلغ الإجمالي' : 'Total Amount',
            value: 'JOD ${totalAmount}',
            isDark: isDark,
            isRTL: isRTL,
            isHighlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoSection(Map<String, dynamic> order, bool isDark, AppLocalizations? locale, bool isRTL) {
    final customerName = order['buyer']?['name']?.toString() ?? 'N/A';
    final customerPhone = order['shipping_address']?['phone']?.toString() ?? order['buyer']?['phone']?.toString() ?? 'N/A';
    final customerEmail = order['buyer']?['email']?.toString() ?? 'N/A';

    return _buildSection(
      title: isRTL ? 'معلومات العميل' : 'Customer Information',
      isDark: isDark,
      isRTL: isRTL,
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.person_rounded,
            label: isRTL ? 'الاسم' : 'Name',
            value: customerName,
            isDark: isDark,
            isRTL: isRTL,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.phone_rounded,
            label: isRTL ? 'رقم الهاتف' : 'Phone',
            value: customerPhone,
            isDark: isDark,
            isRTL: isRTL,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.email_rounded,
            label: isRTL ? 'البريد الإلكتروني' : 'Email',
            value: customerEmail,
            isDark: isDark,
            isRTL: isRTL,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsSection(Map<String, dynamic> order, bool isDark, AppLocalizations? locale, bool isRTL) {
    final items = order['items'] as List<dynamic>? ?? [];

    return _buildSection(
      title: isRTL ? 'منتجات الطلب' : 'Order Items',
      isDark: isDark,
      isRTL: isRTL,
      child: items.isEmpty
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isRTL ? 'لا توجد تفاصيل للمنتجات' : 'No item details available',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value as Map<String, dynamic>;
                return Column(
                  children: [
                    if (index > 0) const SizedBox(height: 12),
                    _buildOrderItem(item, isDark, isRTL),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item, bool isDark, bool isRTL) {
    final product = item['product'] as Map<String, dynamic>? ?? {};
    final productName = product['name']?.toString() ?? item['product_name']?.toString() ?? 'Unknown Product';
    final quantity = item['quantity']?.toString() ?? '1';
    final price = item['price']?.toString() ?? '0';
    final total = (double.tryParse(price) ?? 0) * (int.tryParse(quantity) ?? 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF2D2D2D)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: _buildProductImage(item, product, isDark, isRTL),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isRTL ? 'الكمية' : 'Qty'}: $quantity × JOD ${price}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'JOD ${total.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: DistributorColors(isDark: isDark).primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoSection(Map<String, dynamic> order, bool isDark, AppLocalizations? locale, bool isRTL) {
    final shippingAddress = order['shipping_address'] as Map<String, dynamic>? ?? {};
    final street = shippingAddress['street']?.toString() ?? '';
    final city = shippingAddress['city']?.toString() ?? '';
    final state = shippingAddress['state']?.toString() ?? '';
    final postalCode = shippingAddress['postal_code']?.toString() ?? '';
    final country = shippingAddress['country']?.toString() ?? '';
    
    final fullAddress = [street, city, state, postalCode, country]
        .where((part) => part.isNotEmpty)
        .join(', ');
    
    final deliveryAddress = fullAddress.isNotEmpty ? fullAddress : 'N/A';
    final deliveryNotes = order['notes']?.toString() ?? '';

    return _buildSection(
      title: isRTL ? 'معلومات التوصيل' : 'Delivery Information',
      isDark: isDark,
      isRTL: isRTL,
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.location_on_rounded,
            label: isRTL ? 'عنوان التوصيل' : 'Delivery Address',
            value: deliveryAddress,
            isDark: isDark,
            isRTL: isRTL,
          ),
          if (deliveryNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.note_rounded,
              label: isRTL ? 'ملاحظات التوصيل' : 'Delivery Notes',
              value: deliveryNotes,
              isDark: isDark,
              isRTL: isRTL,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required bool isDark,
    required bool isRTL,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required bool isRTL,
    bool isHighlighted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isHighlighted 
                ? DistributorColors(isDark: isDark).primary.withOpacity(0.1)
                : (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isHighlighted 
                ? DistributorColors(isDark: isDark).primary
                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                  color: isHighlighted 
                      ? DistributorColors(isDark: isDark).primary
                      : (isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetailsActions(Map<String, dynamic> order, bool isDark, AppLocalizations? locale, bool isRTL) {
    final status = order['status']?.toString().toLowerCase() ?? '';
    final distributorColors = DistributorColors(isDark: isDark);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: isDark ? Border(
          top: BorderSide(color: const Color(0xFF1F1F1F)),
        ) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Close Button
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    isRTL ? 'إغلاق' : 'Close',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Action Button (based on status)
              Expanded(
                flex: 2,
                child: _buildActionButton(order, status, isDark, isRTL, distributorColors),
              ),
            ],
          ),
          
          // Additional actions for pending orders
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showRejectDialog(order['id'].toString());
                },
                icon: Icon(Icons.close_rounded, size: 18),
                label: Text(
                  isRTL ? 'رفض الطلب' : 'Reject Order',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(Map<String, dynamic> order, String status, bool isDark, bool isRTL, DistributorColors distributorColors) {
    String buttonText;
    IconData buttonIcon;
    VoidCallback? onPressed;

    switch (status) {
      case 'pending':
        buttonText = isRTL ? 'قبول الطلب' : 'Accept Order';
        buttonIcon = Icons.check_rounded;
        onPressed = () {
          Navigator.of(context).pop();
          _updateOrderStatus(order['id'].toString(), 'processing');
        };
        break;
      case 'processing':
        buttonText = isRTL ? 'شحن الطلب' : 'Ship Order';
        buttonIcon = Icons.local_shipping_rounded;
        onPressed = () {
          Navigator.of(context).pop();
          _updateOrderStatus(order['id'].toString(), 'shipped');
        };
        break;
      case 'shipped':
        buttonText = isRTL ? 'تم التسليم' : 'Mark as Delivered';
        buttonIcon = Icons.done_all_rounded;
        onPressed = () {
          Navigator.of(context).pop();
          _updateOrderStatus(order['id'].toString(), 'completed');
        };
        break;
      default:
        buttonText = isRTL ? 'عرض التفاصيل' : 'View Details';
        buttonIcon = Icons.visibility_rounded;
        onPressed = null;
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(buttonIcon, size: 18),
      label: Text(
        buttonText,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? distributorColors.primary : (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0)),
        foregroundColor: onPressed != null ? Colors.white : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal 
                ? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                : null,
          ),
          Text(
            value,
            style: isTotal 
                ? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignDeliveryDialog(String orderId) async {
    if (token == null) return;
    
    try {
      // Fetch available delivery men
      final deliveryMen = await ApiService.getAvailableDeliveryMen();
      
      if (deliveryMen.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No available delivery men found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final selectedDeliveryMan = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assign Delivery Man'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: deliveryMen.length,
              itemBuilder: (context, index) {
                final deliveryMan = deliveryMen[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFF9800).withOpacity(0.1),
                    child: Text(
                      (deliveryMan['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: const Color(0xFFFF9800)),
                    ),
                  ),
                  title: Text(deliveryMan['name'] ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Phone: ${(deliveryMan['phone'] ?? 'N/A').toString()}'),
                      Text('Rating: ${(deliveryMan['rating'] ?? 0.0).toString()}★'),
                      Text('Capacity: ${(deliveryMan['current_orders'] ?? 0).toString()}/${(deliveryMan['max_capacity'] ?? 5).toString()}'),
                    ],
                  ),
                  onTap: () => Navigator.pop(context, deliveryMan),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      
      if (selectedDeliveryMan != null) {
        // Assign the order to the selected delivery man
        final success = await ApiService.assignDeliveryToMan(
          int.parse(orderId),
          selectedDeliveryMan['id'],
        );
        
        if (success) {
          // Update order status to assigned
          await _updateOrderStatus(orderId, 'assigned');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Order assigned to ${(selectedDeliveryMan['name'] ?? 'Unknown').toString()}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to assign delivery'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error assigning delivery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(String orderId) async {
    final reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejecting this order:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _updateOrderStatus(orderId, 'rejected');
      
      // In a real app, you might want to notify the buyer about the rejection
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order has been rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusChip(String status) {
    final lower = status.toLowerCase();
    Color color;
    String label;
    switch (lower) {
      case 'pending':
      case 'new':
      case 'awaiting':
      case 'awaiting_confirmation':
        color = Colors.orange;
        label = 'PENDING';
        break;
      case 'processing':
      case 'accepted':
      case 'packed':
      case 'shipped':
      case 'out_for_delivery':
        color = Colors.blue;
        label = lower.toUpperCase();
        break;
      case 'completed':
      case 'delivered':
        color = Colors.green;
        label = lower == 'delivered' ? 'DELIVERED' : 'COMPLETED';
        break;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'failed':
        color = Colors.red;
        label = lower == 'rejected' ? 'REJECTED' : 'CANCELLED';
        break;
      default:
        color = Colors.grey;
        label = lower.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }


  List<dynamic> _filterOrdersByQuery(List<dynamic> orders) {
    if (_searchQuery.trim().isEmpty) return orders;
    final q = _searchQuery.toLowerCase();
    return orders.where((o) {
      final id = o['id']?.toString() ?? '';
      final status = (o['status']?.toString() ?? '').toLowerCase();
      final buyer = (o['buyer']?['name']?.toString() ?? '').toLowerCase();
      return id.contains(q) || status.contains(q) || buyer.contains(q);
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final distributorColors = DistributorColors(isDark: isDark);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: distributorColors.primary),
              const SizedBox(height: 16),
              Text(
                locale?.isRTL == true ? 'جاري تحميل الطلبات...' : 'Loading orders...',
                style: GoogleFonts.inter(fontSize: 14, color: subtextColor),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
          foregroundColor: textColor,
          automaticallyImplyLeading: false,
          title: Text(
            locale?.isRTL == true ? 'الطلبات الواردة' : 'Incoming Orders',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16, color: textColor),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadOrders,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    locale?.isRTL == true ? 'إعادة المحاولة' : 'Retry',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: distributorColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
        foregroundColor: textColor,
        automaticallyImplyLeading: false,
        title: Text(
          locale?.isRTL == true ? 'الطلبات الواردة' : 'Incoming Orders',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadOrders,
            icon: Icon(Icons.refresh_rounded, color: textColor),
            tooltip: locale?.isRTL == true ? 'تحديث' : 'Refresh',
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildSearchSection(context, isDark, locale, textColor, subtextColor),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildTabSection(context, isDark, locale, distributorColors, textColor),
            ),
          ),
          _buildOrdersList(context, isDark, locale, distributorColors, textColor, subtextColor),
        ],
      ),
    );
  }



  // Search section
  Widget _buildSearchSection(BuildContext context, bool isDark, AppLocalizations? locale, Color textColor, Color subtextColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(color: textColor, fontSize: 16),
        decoration: InputDecoration(
          hintText: locale?.isRTL == true ? 'البحث برقم الطلب أو العميل أو الحالة' : 'Search by order ID, customer, or status',
          hintStyle: GoogleFonts.inter(color: subtextColor, fontSize: 16),
          prefixIcon: Icon(Icons.search_rounded, color: subtextColor, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: textColor, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  // Tab section
  Widget _buildTabSection(BuildContext context, bool isDark, AppLocalizations? locale, DistributorColors distributorColors, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: distributorColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textColor,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.all(4),
        tabs: [
          Tab(text: locale?.isRTL == true ? 'معلقة (${_pendingOrders.length})' : 'Pending (${_pendingOrders.length})'),
          Tab(text: locale?.isRTL == true ? 'قيد المعالجة (${_processingOrders.length})' : 'Processing (${_processingOrders.length})'),
          Tab(text: locale?.isRTL == true ? 'مكتملة (${_completedOrders.length})' : 'Completed (${_completedOrders.length})'),
          Tab(text: locale?.isRTL == true ? 'ملغاة (${_cancelledOrders.length})' : 'Cancelled (${_cancelledOrders.length})'),
        ],
      ),
    );
  }

  // Orders list
  Widget _buildOrdersList(BuildContext context, bool isDark, AppLocalizations? locale, DistributorColors distributorColors, Color textColor, Color subtextColor) {
    return SliverFillRemaining(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildCleanOrderList(_pendingOrders, 'pending', isDark, locale, distributorColors, textColor, subtextColor),
          _buildCleanOrderList(_processingOrders, 'processing', isDark, locale, distributorColors, textColor, subtextColor),
          _buildCleanOrderList(_completedOrders, 'completed', isDark, locale, distributorColors, textColor, subtextColor),
          _buildCleanOrderList(_cancelledOrders, 'cancelled', isDark, locale, distributorColors, textColor, subtextColor),
        ],
      ),
    );
  }

  // Clean order list
  Widget _buildCleanOrderList(List<dynamic> orders, String status, bool isDark, AppLocalizations? locale, DistributorColors distributorColors, Color textColor, Color subtextColor) {
    final filtered = _filterOrdersByQuery(orders);

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 72,
                color: subtextColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty 
                    ? (locale?.isRTL == true ? 'لا توجد طلبات $status بعد' : 'No $status orders yet')
                    : (locale?.isRTL == true ? 'لا توجد نتائج تطابق البحث' : 'No results match your search'),
                style: GoogleFonts.inter(fontSize: 16, color: subtextColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: distributorColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final order = filtered[index];
          return _buildCleanOrderCard(order, status, isDark, locale, distributorColors, textColor, subtextColor);
        },
      ),
    );
  }

  // Clean order card matching the design
  Widget _buildCleanOrderCard(Map<String, dynamic> order, String status, bool isDark, AppLocalizations? locale, DistributorColors distributorColors, Color textColor, Color subtextColor) {
    final orderDate = order['created_at'] != null 
        ? DateTime.parse(order['created_at'])
        : DateTime.now();
    
    final orderId = order['id']?.toString() ?? 'Unknown';
    final buyerName = order['buyer']?['name'] ?? (locale?.isRTL == true ? 'عميل غير معروف' : 'Unknown Customer');
    final items = order['items'] as List<dynamic>? ?? [];
    final totalAmount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and date header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCleanStatusChip(status, isDark, locale, distributorColors),
                  Text(
                    locale?.isRTL == true ? 'اليوم • ${DateFormat('h:mm a').format(orderDate)}' : 'Today • ${DateFormat('h:mm a').format(orderDate)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: subtextColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Restaurant/Store info row
              Row(
                children: [
                  // Store logo placeholder
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: distributorColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: distributorColors.primary.withOpacity(0.2)),
                    ),
                    child: Icon(
                      Icons.store_rounded,
                      color: distributorColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Store name and order info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buyerName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${locale?.isRTL == true ? 'رقم الطلب' : 'Order ID'}: $orderId',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: subtextColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Dropdown arrow
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: subtextColor,
                    size: 24,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Order total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'JOD ${totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '${items.length} ${locale?.isRTL == true ? 'عنصر' : 'Item${items.length != 1 ? 's' : ''}'}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: subtextColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action buttons row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showOrderDetails(order),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        locale?.isRTL == true ? 'عرض التفاصيل' : 'View details',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (status == 'pending') ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateOrderStatus(orderId, 'processing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: distributorColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(
                          locale?.isRTL == true ? 'قبول الطلب' : 'Accept Order',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else if (status == 'processing') ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateOrderStatus(orderId, 'shipped'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: distributorColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(
                          locale?.isRTL == true ? 'شحن الطلب' : 'Ship Order',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateOrderStatus(orderId, 'processing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF1F5F9),
                          foregroundColor: textColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(
                          locale?.isRTL == true ? 'طلب مرة أخرى' : 'Order again',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              // Rating section for completed orders
              if (status == 'completed' || status == 'delivered') ...[
                const SizedBox(height: 16),
                Divider(color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      locale?.isRTL == true ? 'تقييم' : 'Rate',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(5, (index) => 
                        Icon(
                          Icons.star_border_rounded,
                          color: subtextColor.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanStatusChip(String status, bool isDark, AppLocalizations? locale, DistributorColors distributorColors) {
    final lower = status.toLowerCase();
    Color color;
    String label;
    
    switch (lower) {
      case 'pending':
      case 'new':
      case 'awaiting':
      case 'awaiting_confirmation':
        color = Colors.orange;
        label = locale?.isRTL == true ? 'معلقة' : 'Pending';
        break;
      case 'processing':
      case 'accepted':
      case 'packed':
      case 'shipped':
      case 'out_for_delivery':
        color = Colors.blue;
        label = locale?.isRTL == true ? 'قيد المعالجة' : 'Processing';
        break;
      case 'completed':
      case 'delivered':
        color = Colors.green;
        label = locale?.isRTL == true ? 'مكتملة' : 'Delivered';
        break;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'failed':
        color = Colors.red;
        label = locale?.isRTL == true ? 'ملغاة' : 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> item, Map<String, dynamic> product, bool isDark, bool isRTL) {
    // Try multiple possible image field names
    final imageUrl = product['image_url']?.toString() ?? 
                    product['image']?.toString() ?? 
                    product['picture']?.toString() ?? 
                    product['photo']?.toString() ?? 
                    item['product_image']?.toString() ?? 
                    item['image_url']?.toString() ?? 
                    item['image']?.toString() ?? '';

    print('🖼️ Product Image URL: $imageUrl');
    print('🔍 Product data: ${product.toString()}');
    print('🔍 Item data: ${item.toString()}');

    if (imageUrl.isNotEmpty && Uri.tryParse(imageUrl) != null) {
      return Image.network(
        imageUrl,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Failed to load image: $imageUrl');
          print('❌ Error: $error');
          return _buildFallbackIcon(isDark);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DistributorColors(isDark: isDark).primary,
                ),
              ),
            ),
          );
        },
      );
    } else {
      return _buildFallbackIcon(isDark);
    }
  }

  Widget _buildFallbackIcon(bool isDark) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DistributorColors(isDark: isDark).primary,
            DistributorColors(isDark: isDark).primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        Icons.inventory_2_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }

}
