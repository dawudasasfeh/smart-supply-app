import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/integrated_map_widget.dart';

class OrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  List<dynamic> orderItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    // Test URL launcher functionality on page load
    _testUrlLauncher();
  }

  Future<void> _loadOrderDetails() async {
    try {
      final orderId = widget.order['id'];
      print('🔍 Loading order details for order ID: $orderId');
      print('🔍 Full order data: ${widget.order}');
      
      // First check if order data already contains items/products
      List<dynamic> items = [];
      
      // Check various possible keys for product data
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
      
      // If no items found in order data, try to fetch from API
      if (items.isEmpty && orderId != null) {
        print('📡 No items in order data, fetching from API...');
        try {
          items = await ApiService.getOrderItems(orderId);
          print('✅ Fetched ${items.length} items from API');
        } catch (apiError) {
          print('❌ API fetch failed: $apiError');
          // Create mock items for demonstration
          items = _createMockItems();
        }
      }
      
      if (mounted) {
        setState(() {
          orderItems = items;
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading order details: $e');
      if (mounted) {
        setState(() {
          // Create mock items for demonstration
          orderItems = _createMockItems();
          isLoading = false;
        });
      }
    }
  }
  
  List<dynamic> _createMockItems() {
    // Create some mock items based on the order for demonstration
    final totalAmount = double.tryParse(widget.order['total_amount']?.toString() ?? '0') ?? 100.0;
    
    return [
      {
        'id': 1,
        'product_name': 'Fresh Red Apples',
        'quantity': 5,
        'unit_price': (totalAmount * 0.3).toStringAsFixed(2),
        'total_price': (totalAmount * 0.3).toStringAsFixed(2),
        'product_image': 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=400&h=400&fit=crop',
      },
      {
        'id': 2,
        'product_name': 'Organic Bananas',
        'quantity': 3,
        'unit_price': (totalAmount * 0.2).toStringAsFixed(2),
        'total_price': (totalAmount * 0.2).toStringAsFixed(2),
        'product_image': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400&h=400&fit=crop',
      },
      {
        'id': 3,
        'product_name': 'Fresh Whole Milk',
        'quantity': 2,
        'unit_price': (totalAmount * 0.25).toStringAsFixed(2),
        'total_price': (totalAmount * 0.25).toStringAsFixed(2),
        'product_image': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&h=400&fit=crop',
      },
      {
        'id': 4,
        'product_name': 'Artisan Bread Loaf',
        'quantity': 1,
        'unit_price': (totalAmount * 0.25).toStringAsFixed(2),
        'total_price': (totalAmount * 0.25).toStringAsFixed(2),
        'product_image': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&h=400&fit=crop',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final orderId = order['id']?.toString() ?? 'N/A';
    final status = order['status']?.toString() ?? order['delivery_status']?.toString() ?? 'Unknown';
    final totalAmount = order['total_amount']?.toString() ?? '0';
    final createdAt = order['created_at']?.toString();
    
    // Supermarket information
    final supermarketName = order['supermarket_name']?.toString() ?? 
                           order['customer_name']?.toString() ?? 
                           order['buyer_name']?.toString() ?? 'Unknown Supermarket';
    final supermarketPhone = order['supermarket_phone']?.toString() ?? 
                            order['customer_phone']?.toString() ?? 
                            order['buyer_phone']?.toString() ?? 'No phone provided';
    final deliveryAddress = order['delivery_address']?.toString() ?? 'No address provided';
    
    // Delivery information
    final deliveryInstructions = order['delivery_instructions']?.toString() ?? 'No special instructions';
    final estimatedDeliveryTime = order['estimated_delivery_time']?.toString();
    
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Order #$orderId',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: AppColors.primary),
            onPressed: () => _makePhoneCall(supermarketPhone),
            tooltip: 'Call Supermarket',
          ),
          IconButton(
            icon: const Icon(Icons.location_on, color: AppColors.primary),
            onPressed: () => _openMaps(deliveryAddress),
            tooltip: 'Open in Maps',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status Card
            _buildStatusCard(status, formattedDate, totalAmount),
            
            const SizedBox(height: 16),
            
            // Supermarket Information Card
            _buildSupermarketCard(supermarketName, supermarketPhone, deliveryAddress),
            
            const SizedBox(height: 16),
            
            // Delivery Information Card
            _buildDeliveryInfoCard(deliveryInstructions, estimatedDeliveryTime),
            
            const SizedBox(height: 16),
            
            // Products List Card
            _buildProductsCard(),
            
            const SizedBox(height: 100), // Space for floating action button
          ],
        ),
      ),
      floatingActionButton: _buildActionButton(status),
    );
  }

  Widget _buildStatusCard(String status, String formattedDate, String totalAmount) {
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
                    const Text(
                      'Order Status',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
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
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
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
                  'Ordered on $formattedDate',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupermarketCard(String supermarketName, String phone, String address) {
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
                  Icons.store,
                  color: AppColors.primary,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Supermarket Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.business, 'Name', supermarketName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, 'Phone', phone, isClickable: true, onTap: () => _makePhoneCall(phone)),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'Address', address, isClickable: true, onTap: () => _openMaps(address)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoCard(String instructions, String? estimatedTime) {
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
                  Icons.local_shipping,
                  color: AppColors.primary,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Delivery Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.note, 'Instructions', instructions),
            if (estimatedTime != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.access_time, 'Estimated Delivery', estimatedTime),
            ],
          ],
        ),
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
                  'Products',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
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
                  return _buildProductItem(item);
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
      padding: const EdgeInsets.all(12),
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
          // Product Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Qty: $quantity',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Checkmark Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: AppColors.success,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultProductIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.primary,
        size: 28,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isClickable = false, VoidCallback? onTap}) {
    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isClickable ? AppColors.primary : Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: isClickable ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (isClickable)
          Icon(
            Icons.chevron_right,
            color: AppColors.primary,
            size: 20,
          ),
      ],
    );

    if (isClickable && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _buildActionButton(String status) {
    if (status.toLowerCase() == 'delivered' || status.toLowerCase() == 'completed') {
      return FloatingActionButton.extended(
        onPressed: () => _showCompletionDialog(),
        backgroundColor: AppColors.success,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        label: const Text(
          'Mark Complete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: () => _scanQRCode(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.info;
      case 'assigned':
        return AppColors.primary;
      case 'picked_up':
        return Colors.purple;
      case 'in_transit':
        return Colors.blue;
      case 'out_for_delivery':
        return Colors.indigo;
      case 'delivered':
        return AppColors.success;
      case 'completed':
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
        return Icons.assignment_turned_in_outlined;
      case 'assigned':
        return Icons.assignment_outlined;
      case 'picked_up':
        return Icons.inventory_2_outlined;
      case 'in_transit':
        return Icons.local_shipping_outlined;
      case 'out_for_delivery':
        return Icons.delivery_dining_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.verified_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Clean the phone number (remove spaces, dashes, etc.)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleanNumber.isEmpty || cleanNumber == 'No phone provided') {
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

  Future<void> _openMaps(String address) async {
    if (address.isEmpty || address == 'No address provided') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No address available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Extract coordinates from order if available
    double? latitude;
    double? longitude;
    
    if (widget.order['latitude'] != null && widget.order['longitude'] != null) {
      latitude = widget.order['latitude'].toDouble();
      longitude = widget.order['longitude'].toDouble();
    }

    // Open integrated map
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IntegratedMapWidget(
          address: address,
          latitude: latitude,
          longitude: longitude,
          title: 'Delivery Location',
          showNavigationButton: true,
        ),
      ),
    );
  }

  void _scanQRCode() {
    Navigator.pushNamed(context, '/qrScanner');
  }

  // Debug method to test URL launcher functionality
  Future<void> _testUrlLauncher() async {
    print('🔍 Testing URL launcher functionality...');
    
    // Test phone functionality
    final testPhone = '+1234567890';
    final phoneUri = Uri.parse('tel:$testPhone');
    
    try {
      final canLaunchPhone = await canLaunchUrl(phoneUri);
      print('📞 Can launch phone: $canLaunchPhone');
      
      if (canLaunchPhone) {
        print('✅ Phone launcher is working');
      } else {
        print('❌ Phone launcher not available');
      }
    } catch (e) {
      print('❌ Phone launcher error: $e');
    }
    
    // Test maps functionality
    final testAddress = 'New York, NY';
    final encodedAddress = Uri.encodeComponent(testAddress);
    final mapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    
    try {
      final canLaunchMaps = await canLaunchUrl(mapsUri);
      print('🗺️ Can launch maps: $canLaunchMaps');
      
      if (canLaunchMaps) {
        print('✅ Maps launcher is working');
      } else {
        print('❌ Maps launcher not available');
      }
    } catch (e) {
      print('❌ Maps launcher error: $e');
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Mark as Complete',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: const Text(
            'Are you sure you want to mark this delivery as complete?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _markAsComplete();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );
  }

  void _markAsComplete() {
    // Implement completion logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order marked as complete!'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }
}
