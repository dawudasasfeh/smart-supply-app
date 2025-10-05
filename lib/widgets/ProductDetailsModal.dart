import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'RatingDetailsModal.dart';
import '../l10n/app_localizations.dart';

class ProductDetailsModal {
  static void show(BuildContext context, Map<String, dynamic> product, dynamic offer, Map<String, dynamic>? distributor, Function(Map<String, dynamic>) addToCart) async {
    // Get language preference from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('app_language') ?? 'en';
    final isRTL = languageCode == 'ar';
    
    // Get distributor rating summary
    double avgRating = 0.0;
    int reviewCount = 0;
    if (distributor != null) {
      try {
        final token = prefs.getString('token') ?? '';
        final summary = await ApiService.getRatingSummary(token, distributor['id'], 'distributor');
        if (summary.isNotEmpty) {
          final supplierRating = summary.firstWhere(
            (s) => s['rating_type'] == 'supplier_rating',
            orElse: () => null,
          );
          if (supplierRating != null) {
            avgRating = double.tryParse(supplierRating['average_rating']?.toString() ?? '0') ?? 0.0;
            reviewCount = int.tryParse(supplierRating['total_ratings']?.toString() ?? '0') ?? 0;
          }
        }
      } catch (e) {
        print('Error fetching distributor rating: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 60,
                height: 6,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image with Hero Animation
                      Center(
                        child: Hero(
                          tag: 'product_${(product['id'] ?? 0).toString()}',
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: product['image_url'] != null && product['image_url'].toString().isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: product['image_url'].startsWith('http')
                                          ? product['image_url']
                                          : '${ApiService.imageBaseUrl}${(product['image_url'] ?? '').toString()}',
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[100],
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[100],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.image_not_supported, size: 60, color: Colors.grey[400]),
                                            const SizedBox(height: 8),
                                            Text(isRTL ? 'لا توجد صورة' : 'No Image', style: TextStyle(color: Colors.grey[600])),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[100],
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.shopping_basket, size: 60, color: AppColors.primary.withOpacity(0.6)),
                                          const SizedBox(height: 8),
                                          Text(isRTL ? 'صورة المنتج' : 'Product Image', style: TextStyle(color: Colors.grey[600])),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Product Name and Brand
                      Text(
                        product['name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (product['brand'] != null && product['brand'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product['brand'],
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      
                      // Distributor Info with Rating
                      if (distributor != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
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
                                    child: Icon(Icons.store, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          distributor['name'] ?? 'Unknown Distributor',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () => RatingDetailsModal.show(context, distributor),
                                          child: TweenAnimationBuilder<double>(
                                            duration: const Duration(milliseconds: 600),
                                            tween: Tween(begin: 0.0, end: 1.0),
                                            curve: Curves.easeOutBack,
                                            builder: (context, value, _) {
                                              return Transform.scale(
                                                scale: 0.9 + (0.1 * value),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    gradient: avgRating > 0 
                                                        ? LinearGradient(
                                                            colors: [
                                                              Colors.amber.withOpacity(0.9),
                                                              Colors.orange.withOpacity(0.8),
                                                            ],
                                                          )
                                                        : LinearGradient(
                                                            colors: [
                                                              Colors.grey[300]!,
                                                              Colors.grey[200]!,
                                                            ],
                                                          ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: avgRating > 0 
                                                            ? Colors.amber.withOpacity(0.3)
                                                            : Colors.grey.withOpacity(0.2),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.star_rounded,
                                                        size: 18,
                                                        color: avgRating > 0 ? Colors.white : Colors.grey[500],
                                                      ),
                                                      const SizedBox(width: 6),
                                                      TweenAnimationBuilder<double>(
                                                        duration: const Duration(milliseconds: 1000),
                                                        tween: Tween(begin: 0.0, end: avgRating),
                                                        curve: Curves.easeOutCubic,
                                                        builder: (context, animatedRating, _) {
                                                          return Text(
                                                            avgRating > 0 ? animatedRating.toStringAsFixed(1) : (isRTL ? 'لا يوجد تقييم' : 'No rating'),
                                                            style: TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.bold,
                                                              color: avgRating > 0 ? Colors.white : Colors.grey[600],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      if (reviewCount > 0) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white.withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            '$reviewCount',
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.chevron_right_rounded,
                                                        size: 16,
                                                        color: avgRating > 0 ? Colors.white : Colors.grey[500],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
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
                        const SizedBox(height: 16),
                      
                      // Product Description
                      if (product['description'] != null && product['description'].toString().isNotEmpty) ...[
                        Text(
                          isRTL ? 'الوصف' : 'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product['description'],
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Product Details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(isRTL ? 'الفئة' : 'Category', product['category'] ?? (isRTL ? 'غير محدد' : 'Not specified'), isRTL),
                            _buildDetailRow('SKU', product['sku'] ?? (isRTL ? 'غير محدد' : 'Not specified'), isRTL),
                            _buildDetailRow(isRTL ? 'المخزون المتاح' : 'Stock Available', '${(product['stock'] ?? 0).toString()} ${isRTL ? 'وحدة' : 'units'}', isRTL),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Price and Offer Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.1),
                              AppColors.primary.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (offer != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.orange, Colors.deepOrange],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_offer, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      () {
                                        final originalPriceModal = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
                                        final discountPriceModal = double.tryParse(offer['discount_price']?.toString() ?? '0') ?? 0.0;
                                        if (originalPriceModal > 0) {
                                          return '${((originalPriceModal - discountPriceModal) / originalPriceModal * 100).round()}% OFF';
                                        }
                                        return 'SALE';
                                      }(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    '\$${(double.tryParse(product['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '\$${(double.tryParse(offer['discount_price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                '\$${(double.tryParse(product['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Add to Cart Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (product['stock'] ?? 0) <= 0 
                              ? null 
                              : () {
                                  addToCart(product);
                                  Navigator.pop(context);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (product['stock'] ?? 0) <= 0 ? Colors.grey : AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: (product['stock'] ?? 0) <= 0 ? 0 : 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                (product['stock'] ?? 0) <= 0 ? Icons.block : Icons.add_shopping_cart,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (product['stock'] ?? 0) <= 0 ? (isRTL ? 'غير متوفر' : 'Out of Stock') : (isRTL ? 'أضف للسلة' : 'Add to Cart'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildDetailRow(String label, String value, bool isRTL) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
