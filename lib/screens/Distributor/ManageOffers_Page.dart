import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../themes/role_theme_manager.dart';
import '../../l10n/app_localizations.dart';

class ManageOffersPage extends StatefulWidget {
  const ManageOffersPage({super.key});

  @override
  State<ManageOffersPage> createState() => _ManageOffersPageState();
}

class _ManageOffersPageState extends State<ManageOffersPage> with TickerProviderStateMixin {
  List<dynamic> offers = [];
  List<dynamic> filteredOffers = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedFilter = 'all'; // all, active, expiring, expired
  
  late AnimationController _listController;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchMyOffers();
  }

  void _initializeAnimations() {
    _listController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _listController.dispose();
    _fabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String getRelativeDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = date.difference(now).inDays;
      
      if (difference < 0) {
        return 'Expired ${(-difference)} days ago';
      } else if (difference == 0) {
        return 'Expires today';
      } else if (difference == 1) {
        return 'Expires tomorrow';
      } else if (difference <= 7) {
        return 'Expires in $difference days';
      } else {
        return 'Expires ${formatDate(dateStr)}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  bool isOfferExpired(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return date.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  bool isOfferExpiringSoon(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final difference = date.difference(DateTime.now()).inDays;
      return difference >= 0 && difference <= 7;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchMyOffers() async {
    setState(() => isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final result = await ApiService.getMyOffers(token);
      
      setState(() {
        offers = result;
        _applyFilters();
        isLoading = false;
      });
      
      _listController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _fabController.forward();
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to load offers: ${e.toString()}');
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(offers);
    
    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((offer) {
        final productName = (offer['product_name'] ?? '').toString().toLowerCase();
        return productName.contains(searchQuery.toLowerCase());
      }).toList();
    }
    
    // Apply status filter
    switch (selectedFilter) {
      case 'active':
        filtered = filtered.where((offer) => !isOfferExpired(offer['expiration_date'])).toList();
        break;
      case 'expiring':
        filtered = filtered.where((offer) => 
          !isOfferExpired(offer['expiration_date']) && 
          isOfferExpiringSoon(offer['expiration_date'])
        ).toList();
        break;
      case 'expired':
        filtered = filtered.where((offer) => isOfferExpired(offer['expiration_date'])).toList();
        break;
    }
    
    // Sort by expiration date
    filtered.sort((a, b) {
      final dateA = DateTime.parse(a['expiration_date']);
      final dateB = DateTime.parse(b['expiration_date']);
      return dateA.compareTo(dateB);
    });
    
    setState(() {
      filteredOffers = filtered;
    });
  }

  Future<void> deleteOffer(int id, String productName) async {
    final confirmed = await _showDeleteConfirmation(productName);
    if (!confirmed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      await ApiService.deleteOffer(token, id);
      
      HapticFeedback.mediumImpact();
      _showSuccessSnackBar('Offer deleted successfully');
      fetchMyOffers();
    } catch (e) {
      _showErrorSnackBar('Failed to delete offer: ${e.toString()}');
    }
  }

  Future<bool> _showDeleteConfirmation(String productName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            const Text('Delete Offer'),
          ],
        ),
        content: Text('Are you sure you want to delete the offer for "$productName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        title: const Text(
          'Manage Offers',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchMyOffers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          _buildStatsBar(),
          Expanded(
            child: isLoading 
              ? _buildLoadingState()
              : filteredOffers.isEmpty 
                ? _buildEmptyState()
                : _buildOffersList(),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/manageProducts')
              .then((_) => fetchMyOffers()),
          backgroundColor: const Color(0xFFFF9800),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New Offer'),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search offers...',
              prefixIcon: const Icon(Icons.search, color: const Color(0xFFFF9800)),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => searchQuery = '');
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: const Color(0xFFFF9800), width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() => searchQuery = value);
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Expiring Soon', 'expiring'),
                const SizedBox(width: 8),
                _buildFilterChip('Expired', 'expired'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => selectedFilter = value);
        _applyFilters();
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Color(0xFFFF9800).withOpacity(0.2),
      checkmarkColor: Color(0xFFFF9800),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFFFF9800) : Colors.grey,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatsBar() {
    final activeCount = offers.where((offer) => !isOfferExpired(offer['expiration_date'])).length;
    final expiringCount = offers.where((offer) => 
      !isOfferExpired(offer['expiration_date']) && 
      isOfferExpiringSoon(offer['expiration_date'])
    ).length;
    final expiredCount = offers.where((offer) => isOfferExpired(offer['expiration_date'])).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildStatItem('Total', offers.length.toString(), Colors.blue),
          _buildStatItem('Active', activeCount.toString(), Colors.green),
          _buildStatItem('Expiring', expiringCount.toString(), Colors.orange),
          _buildStatItem('Expired', expiredCount.toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFF9800)),
          const SizedBox(height: 16),
          Text(
            'Loading your offers...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            searchQuery.isNotEmpty || selectedFilter != 'all'
                ? 'No offers found'
                : 'No offers yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            searchQuery.isNotEmpty || selectedFilter != 'all'
                ? 'Try adjusting your search or filters'
                : 'Create your first offer to boost sales',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/manageProducts')
                .then((_) => fetchMyOffers()),
            icon: const Icon(Icons.add),
            label: const Text('Create Offer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    return FadeTransition(
      opacity: _listController,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOffers.length,
        itemBuilder: (context, index) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _listController,
              curve: Interval(
                index * 0.1,
                1.0,
                curve: Curves.easeOutCubic,
              ),
            )),
            child: _buildOfferCard(filteredOffers[index], index),
          );
        },
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer, int index) {
    final isExpired = isOfferExpired(offer['expiration_date']);
    final isExpiringSoon = isOfferExpiringSoon(offer['expiration_date']);
    final originalPrice = double.tryParse(offer['original_price']?.toString() ?? '0') ?? 0;
    final discountPrice = double.tryParse(offer['discount_price']?.toString() ?? '0') ?? 0;
    final savings = originalPrice > 0 ? originalPrice - discountPrice : 0;
    final savingsPercentage = originalPrice > 0 ? (savings / originalPrice) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        border: isExpired 
            ? Border.all(color: Colors.red.withOpacity(0.3))
            : isExpiringSoon 
                ? Border.all(color: Colors.orange.withOpacity(0.3))
                : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    offer['product_name'] ?? 'Unnamed Product',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(offer['expiration_date']),
              ],
            ),
            const SizedBox(height: 8),
            
            // Product image and pricing
            Row(
              children: [
                // Product Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFFF9800).withOpacity(0.1),
                  ),
                  child: offer['image_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: offer['image_url'].startsWith('http') 
                                ? offer['image_url']
                                : '${ApiService.imageBaseUrl}${offer['image_url']}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.local_offer,
                              color: const Color(0xFFFF9800),
                              size: 30,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.local_offer,
                          color: const Color(0xFFFF9800),
                          size: 30,
                        ),
                ),
                const SizedBox(width: 16),
                
                // Pricing Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (originalPrice > 0) ...[
                        Text(
                          'Original: \$${originalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Row(
                        children: [
                          Text(
                            '\$${discountPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                          if (savings > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${savingsPercentage.toStringAsFixed(0)}% OFF',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Expiration info
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: isExpired 
                      ? Colors.red 
                      : isExpiringSoon 
                          ? Colors.orange 
                          : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    getRelativeDate(offer['expiration_date']),
                    style: TextStyle(
                      fontSize: 14,
                      color: isExpired 
                          ? Colors.red 
                          : isExpiringSoon 
                              ? Colors.orange 
                              : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => deleteOffer(offer['id'], offer['product_name'] ?? 'Product'),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red[400],
                      tooltip: 'Delete Offer',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String expirationDate) {
    final isExpired = isOfferExpired(expirationDate);
    final isExpiringSoon = isOfferExpiringSoon(expirationDate);
    
    Color color;
    String text;
    IconData icon;
    
    if (isExpired) {
      color = Colors.red;
      text = 'Expired';
      icon = Icons.cancel;
    } else if (isExpiringSoon) {
      color = Colors.orange;
      text = 'Expiring Soon';
      icon = Icons.warning;
    } else {
      color = Colors.green;
      text = 'Active';
      icon = Icons.check_circle;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
