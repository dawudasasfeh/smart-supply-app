import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class AddOfferPage extends StatefulWidget {
  final int productId;
  final String productName;
  final double? originalPrice;
  final String? productImage;

  const AddOfferPage({
    super.key, 
    required this.productId, 
    required this.productName,
    this.originalPrice,
    this.productImage,
  });

  @override
  State<AddOfferPage> createState() => _AddOfferPageState();
}

class _AddOfferPageState extends State<AddOfferPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _discountPriceController = TextEditingController();
  final TextEditingController _discountPercentController = TextEditingController();
  
  DateTime? _selectedDate;
  bool _isSubmitting = false;
  bool _usePercentage = false;
  double? _calculatedDiscount;
  
  // Current product data (from route args or widget)
  late int _currentProductId;
  late String _currentProductName;
  double? _currentOriginalPrice;
  String? _currentProductImage;
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    
    // Set default expiration date to 30 days from now
    _selectedDate = DateTime.now().add(const Duration(days: 30));
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _slideController.forward();
      _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _discountPriceController.dispose();
    _discountPercentController.dispose();
    super.dispose();
  }

  void _calculateDiscount({double? originalPrice}) {
    if (originalPrice == null) return;
    
    if (_usePercentage && _discountPercentController.text.isNotEmpty) {
      final percentage = double.tryParse(_discountPercentController.text) ?? 0;
      final discount = originalPrice * (percentage / 100);
      final discountedPrice = originalPrice - discount;
      
      setState(() {
        _calculatedDiscount = discountedPrice;
        _discountPriceController.text = discountedPrice.toStringAsFixed(2);
      });
    }
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      _showErrorSnackBar('Please fill in all required fields');
      return;
    }

    // Haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final discountPrice = double.parse(_discountPriceController.text);
      double? discountPercentage;
      
      // Calculate discount percentage if we have original price
      if (_currentOriginalPrice != null && _currentOriginalPrice! > 0) {
        final savings = _currentOriginalPrice! - discountPrice;
        discountPercentage = (savings / _currentOriginalPrice!) * 100;
      }

      final offerData = {
        'product_id': _currentProductId,
        'product_name': _currentProductName,
        'discount_price': discountPrice,
        'expiration_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      };
      
      // Add discount_percentage if calculated
      if (discountPercentage != null) {
        offerData['discount_percentage'] = discountPercentage;
      }

      print('🔍 Add Offer Request: $offerData');

      final success = await ApiService.addOffer(token, offerData);

      setState(() => _isSubmitting = false);

      if (!mounted) return;

      if (success) {
        // Success animation
        HapticFeedback.mediumImpact();
        _showSuccessDialog();
      } else {
        _showErrorSnackBar('Failed to create offer. Please try again.');
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showErrorSnackBar('An error occurred: ${e.toString()}');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Offer Created Successfully!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your offer for $_currentProductName has been created and is now live.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use widget properties directly since they're now passed via constructor
    _currentProductId = widget.productId;
    _currentProductName = widget.productName;
    _currentOriginalPrice = widget.originalPrice;
    _currentProductImage = widget.productImage;
    
    print('🔍 AddOffer Debug - Using widget properties');
    print('📸 Product Image: $_currentProductImage');
    print('💰 Original Price: $_currentOriginalPrice');
    
    return _buildScaffold(
      productId: _currentProductId,
      productName: _currentProductName,
      originalPrice: _currentOriginalPrice,
      productImage: _currentProductImage,
    );
  }

  Widget _buildScaffold({
    required int productId,
    required String productName,
    double? originalPrice,
    String? productImage,
  }) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Create Offer',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductCard(productName: productName, originalPrice: originalPrice, productImage: productImage),
                  const SizedBox(height: 24),
                  _buildPricingSection(originalPrice: originalPrice),
                  const SizedBox(height: 24),
                  _buildExpirationSection(),
                  const SizedBox(height: 24),
                  _buildOfferSummary(productName: productName, originalPrice: originalPrice),
                  const SizedBox(height: 32),
                  _buildSubmitButton(productId: productId, productName: productName, originalPrice: originalPrice),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard({
    required String productName,
    double? originalPrice,
    String? productImage,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: productImage != null && productImage!.isNotEmpty
                ? Builder(
                    builder: (context) {
                      print('🖼️ Displaying image: $productImage');
                      final imageUrl = productImage!.startsWith('http') 
                          ? productImage!
                          : '${ApiService.imageBaseUrl}${productImage!}';
                      print('🌐 Final image URL: $imageUrl');
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            print('🔥 Image load error: $error');
                            print('📸 Image URL: $url');
                            return Container(
                              color: Colors.grey[100],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_offer,
                                    size: 32,
                                    color: AppColors.primary.withOpacity(0.6),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Product',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  )
                : Icon(
                    Icons.local_offer,
                    color: AppColors.primary,
                    size: 40,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (originalPrice != null) ...[
                  Text(
                    'Original Price: \$${originalPrice!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection({double? originalPrice}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_offer,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pricing Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (originalPrice != null) ...[
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Fixed Price'),
                    value: false,
                    groupValue: _usePercentage,
                    onChanged: (value) {
                      setState(() {
                        _usePercentage = value!;
                        _discountPercentController.clear();
                        _calculatedDiscount = null;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Percentage'),
                    value: true,
                    groupValue: _usePercentage,
                    onChanged: (value) {
                      setState(() {
                        _usePercentage = value!;
                        _discountPriceController.clear();
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (_usePercentage && originalPrice != null) ...[
            TextFormField(
              controller: _discountPercentController,
              decoration: InputDecoration(
                labelText: 'Discount Percentage',
                hintText: 'Enter discount percentage',
                suffixText: '%',
                prefixIcon: const Icon(Icons.percent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _calculateDiscount(originalPrice: originalPrice),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter discount percentage';
                }
                final percentage = double.tryParse(value);
                if (percentage == null || percentage <= 0 || percentage >= 100) {
                  return 'Please enter a valid percentage (1-99)';
                }
                return null;
              },
            ),
            if (_calculatedDiscount != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Calculated Price: \$${_calculatedDiscount!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            TextFormField(
              controller: _discountPriceController,
              decoration: InputDecoration(
                labelText: 'Discount Price',
                hintText: 'Enter discounted price',
                prefixText: '\$ ',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter discount price';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Please enter a valid price';
                }
                if (originalPrice != null && price >= originalPrice!) {
                  return 'Discount price must be less than original price';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpirationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Offer Duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expiration Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedDate == null
                              ? 'Select expiration date'
                              : DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _selectedDate == null 
                                ? AppColors.textSecondary 
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offer will be active for ${_selectedDate!.difference(DateTime.now()).inDays} days',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfferSummary({required String productName, double? originalPrice}) {
    if (_selectedDate == null || _discountPriceController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final discountPrice = double.tryParse(_discountPriceController.text) ?? 0;
    final savings = originalPrice != null 
        ? originalPrice! - discountPrice 
        : 0;
    final savingsPercentage = originalPrice != null && originalPrice! > 0
        ? (savings / originalPrice!) * 100
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.summarize,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Offer Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Product', productName),
          if (originalPrice != null) ...[
            _buildSummaryRow('Original Price', '\$${originalPrice!.toStringAsFixed(2)}'),
            _buildSummaryRow('Discount Price', '\$${discountPrice.toStringAsFixed(2)}'),
            if (savings > 0) ...[
              _buildSummaryRow(
                'Customer Savings', 
                '\$${savings.toStringAsFixed(2)} (${savingsPercentage.toStringAsFixed(1)}%)',
                isHighlight: true,
              ),
            ],
          ],
          _buildSummaryRow(
            'Valid Until', 
            DateFormat('MMM d, yyyy').format(_selectedDate!),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isHighlight ? Colors.green : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton({required int productId, required String productName, double? originalPrice}) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitOffer,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Create Offer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
