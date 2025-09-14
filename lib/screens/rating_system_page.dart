import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';

class RatingSystemPage extends StatefulWidget {
  final String userRole;

  const RatingSystemPage({
    Key? key,
    required this.userRole,
  }) : super(key: key);

  @override
  State<RatingSystemPage> createState() => _RatingSystemPageState();
}

class _RatingSystemPageState extends State<RatingSystemPage> {
  bool _isLoading = true;
  String? token;
  
  // Rating data
  Map<String, dynamic> _ratingAnalytics = {};
  List<dynamic> _ratableEntities = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    
    if (token != null) {
      await _loadRatingData();
    }
  }

  Future<void> _loadRatingData() async {
    if (token == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Load rating analytics
      final analytics = await ApiService.getRatingAnalytics(token!);
      
      // Load entities available for rating
      final entities = await ApiService.getRatableEntities(token!);
      
      setState(() {
        _ratingAnalytics = analytics;
        _ratableEntities = entities;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading rating data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper methods
  IconData _getEntityIcon(String role) {
    switch (role.toLowerCase()) {
      case 'distributor':
        return Icons.local_shipping;
      case 'delivery':
        return Icons.delivery_dining;
      case 'supermarket':
        return Icons.store;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'distributor':
        return Colors.blue;
      case 'delivery':
        return Colors.green;
      case 'supermarket':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  LinearGradient _getRoleGradient(String role) {
    switch (role.toLowerCase()) {
      case 'distributor':
        return const LinearGradient(colors: [Colors.blue, Colors.blueAccent]);
      case 'delivery':
        return const LinearGradient(colors: [Colors.green, Colors.greenAccent]);
      case 'supermarket':
        return const LinearGradient(colors: [Colors.orange, Colors.orangeAccent]);
      default:
        return const LinearGradient(colors: [Colors.grey, Colors.grey]);
    }
  }

  String _getPageTitle() {
    switch (widget.userRole.toLowerCase()) {
      case 'supermarket':
        return 'Rate Partners';
      case 'distributor':
        return 'Rate Partners';
      case 'delivery':
        return 'Rate Partners';
      default:
        return 'Rating System';
    }
  }

  Widget _buildEntityCard(Map<String, dynamic> entity) {
    final name = entity['name'] ?? entity['store_name'] ?? entity['company_name'] ?? 'Unknown';
    final role = entity['role'] ?? 'Unknown';
    final phone = entity['phone'] ?? 'N/A';
    final address = entity['address'] ?? '';
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: _getRoleGradient(role),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                _getEntityIcon(role),
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            
            // Entity Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getRoleColor(role).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        color: _getRoleColor(role),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (phone != 'N/A') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Rate Button
            ElevatedButton.icon(
              onPressed: () => _showRatingDialog(entity),
              icon: const Icon(Icons.star_rate, size: 18),
              label: const Text('Rate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final totalGiven = _ratingAnalytics['totalRatingsGiven'] ?? 0;
    final totalReceived = _ratingAnalytics['totalRatingsReceived'] ?? 0;
    final avgGiven = (_ratingAnalytics['averageRatingGiven'] ?? 0.0).toStringAsFixed(1);
    final avgReceived = (_ratingAnalytics['averageRatingReceived'] ?? 0.0).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Rating Stats',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatsCard('Ratings Given', '$totalGiven', Icons.thumb_up, Colors.blue),
            const SizedBox(width: 12),
            _buildStatsCard('Ratings Received', '$totalReceived', Icons.star, Colors.orange),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatsCard('Avg Given', avgGiven, Icons.trending_up, Colors.green),
            const SizedBox(width: 12),
            _buildStatsCard('Avg Received', avgReceived, Icons.analytics, Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No partners to rate yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some transactions to start rating your partners',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(Map<String, dynamic> entity) {
    final name = entity['name'] ?? entity['store_name'] ?? entity['company_name'] ?? 'Unknown';
    final role = entity['role'] ?? 'unknown';
    final entityId = entity['id'] ?? 0;
    
    _showDetailedRatingDialog(name, role, entityId: entityId);
  }

  void _showDetailedRatingDialog(String name, String role, {int? entityId}) {
    double selectedRating = 5.0;
    String comment = '';
    List<String> selectedCriteria = [];
    
    // Default criteria based on role
    List<String> availableCriteria = _getCriteriaForRole(role);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: _getRoleGradient(role),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getEntityIcon(role),
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
                      'Rate $name',
                      style: const TextStyle(fontSize: 18),
                    ),
                    Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getRoleColor(role),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Rating:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStarRating(
                        selectedRating,
                        onRatingChanged: (rating) {
                          setState(() => selectedRating = rating);
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        selectedRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Rate specific aspects:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...availableCriteria.map((criteria) => CheckboxListTile(
                  title: Text(criteria),
                  value: selectedCriteria.contains(criteria),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedCriteria.add(criteria);
                      } else {
                        selectedCriteria.remove(criteria);
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                )),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Comments (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'Share your experience...',
                  ),
                  maxLines: 3,
                  onChanged: (value) => comment = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await ApiService.submitNewRating(
                  token!,
                  ratedId: entityId ?? 0,
                  ratedRole: role,
                  overallRating: selectedRating,
                  criteriaRatings: Map.fromEntries(
                    selectedCriteria.map((c) => MapEntry(c, selectedRating))
                  ),
                  comment: comment,
                );
                
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Rating submitted successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  _loadRatingData(); // Refresh data
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to submit rating'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(double rating, {required Function(double) onRatingChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => onRatingChanged((index + 1).toDouble()),
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 32,
          ),
        );
      }),
    );
  }

  List<String> _getCriteriaForRole(String role) {
    switch (role.toLowerCase()) {
      case 'distributor':
        return ['Quality', 'Timeliness', 'Communication', 'Pricing', 'Reliability'];
      case 'delivery':
        return ['Speed', 'Care', 'Communication', 'Professionalism'];
      case 'supermarket':
        return ['Service', 'Quality', 'Communication', 'Payment'];
      default:
        return ['Quality', 'Service', 'Communication'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_getPageTitle()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRatingData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Section
                    _buildStatsSection(),
                    const SizedBox(height: 24),
                    
                    // Partners to Rate Section
                    const Text(
                      'Partners to Rate',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Entity Cards or Empty State
                    if (_ratableEntities.isEmpty)
                      SizedBox(
                        height: 300,
                        child: _buildEmptyState(),
                      )
                    else
                      ...(_ratableEntities.map((entity) => _buildEntityCard(entity)).toList()),
                  ],
                ),
              ),
            ),
    );
  }
}
