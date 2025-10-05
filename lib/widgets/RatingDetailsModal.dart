import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class RatingDetailsModal {
  static Future<Map<String, dynamic>> _getRatingData(String token, int distributorId, {int limit = 50, int offset = 0}) async {
    try {
      // Fetch both stats and detailed ratings in parallel
      final statsFuture = ApiService.getDistributorRatingStats(token, distributorId);
      // Fetch ratings with proper pagination - increased default limit to 50
      final ratingsFuture = ApiService.getDetailedRatings(token, distributorId, 'distributor', limit: limit, offset: offset);
      
      final results = await Future.wait([statsFuture, ratingsFuture]);
      
      final ratingsData = results[1];
      final ratings = ratingsData['ratings'] as List? ?? [];
      final pagination = ratingsData['pagination'] as Map<String, dynamic>? ?? {};
      
      
      return {
        'stats': results[0],
        'ratings': ratings,
        'pagination': pagination,
      };
    } catch (e) {
      print('Error fetching rating data: $e');
      return {'stats': {}, 'ratings': [], 'pagination': {}};
    }
  }

  static void show(BuildContext context, Map<String, dynamic> distributor) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.store, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                distributor['name'] ?? 'Unknown Distributor',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Customer Reviews & Ratings',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
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
              
              // Ratings Content
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _getRatingData(token, distributor['id'], limit: 50, offset: 0),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }
                    
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Unable to load ratings',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    final data = snapshot.data!;
                    final stats = data['stats'] as Map<String, dynamic>? ?? {};
                    final ratings = data['ratings'] as List<dynamic>? ?? [];
                    final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
                    
                    
                    // Show "no reviews" only if both stats and individual ratings are empty
                    if ((stats.isEmpty || (stats['totalRatings'] ?? 0) == 0) && ratings.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No reviews yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to rate this distributor',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    // Use stored averages from stats if available, otherwise calculate from individual ratings
                    int totalRatings;
                    double averageRating;
                    Map<String, double> criteriaAverages;
                    
                    if (stats.isNotEmpty && (stats['totalRatings'] ?? 0) > 0) {
                      // Use stored averages - convert string values to double
                      totalRatings = stats['totalRatings'] ?? 0;
                      averageRating = double.tryParse(stats['avgOverall']?.toString() ?? '0') ?? 0.0;
                      criteriaAverages = {
                        'Product Quality': double.tryParse(stats['avgQuality']?.toString() ?? '0') ?? 0.0,
                        'Delivery Time': double.tryParse(stats['avgDelivery']?.toString() ?? '0') ?? 0.0,
                        'Customer Service': double.tryParse(stats['avgService']?.toString() ?? '0') ?? 0.0,
                        'Pricing': double.tryParse(stats['avgPricing']?.toString() ?? '0') ?? 0.0,
                      };
                    } else {
                      // Calculate from individual ratings
                      totalRatings = ratings.length;
                      averageRating = ratings.isNotEmpty 
                          ? ratings.map((r) => double.tryParse(r['overall_rating']?.toString() ?? '0') ?? 0.0)
                              .reduce((a, b) => a + b) / totalRatings
                          : 0.0;
                      
                      // Calculate criteria averages from individual ratings
                      final Map<String, List<double>> criteriaScores = {};
                      for (final rating in ratings) {
                        final criteriaList = rating['criteria_scores'] as List<dynamic>? ?? [];
                        for (final criteria in criteriaList) {
                          final criteriaName = criteria['criteria_name']?.toString() ?? '';
                          final score = double.tryParse(criteria['score']?.toString() ?? '0') ?? 0.0;
                          if (criteriaName.isNotEmpty) {
                            criteriaScores.putIfAbsent(criteriaName, () => []);
                            criteriaScores[criteriaName]!.add(score);
                          }
                        }
                      }
                      
                      criteriaAverages = {};
                      criteriaScores.forEach((name, scores) {
                        if (scores.isNotEmpty) {
                          criteriaAverages[name] = scores.reduce((a, b) => a + b) / scores.length;
                        }
                      });
                    }
                    
                    // Get recent comments (without showing who wrote them)
                    final recentComments = ratings
                        .where((r) => r['comment'] != null && r['comment'].toString().isNotEmpty)
                        .take(3)
                        .map((r) => r['comment'].toString())
                        .toList();

                    return _buildSimplifiedRatingView(averageRating, totalRatings, recentComments, criteriaAverages, pagination);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildSimplifiedRatingView(double averageRating, int totalRatings, List<String> recentComments, Map<String, double> criteriaAverages, Map<String, dynamic> pagination) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Overall Rating Display
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutBack,
            builder: (context, value, _) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.amber.withOpacity(0.1),
                        Colors.orange.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Large Rating Number
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1200),
                        tween: Tween(begin: 0.0, end: averageRating),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedRating, _) {
                          return Text(
                            animatedRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          );
                        },
                      ),
                      
                      // Stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 800 + (index * 100)),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOutBack,
                            builder: (context, starValue, _) {
                              return Transform.scale(
                                scale: starValue,
                                child: Icon(
                                  index < averageRating.floor() 
                                      ? Icons.star_rounded
                                      : index < averageRating 
                                          ? Icons.star_half_rounded
                                          : Icons.star_border_rounded,
                                  color: Colors.amber[600],
                                  size: 32,
                                ),
                              );
                            },
                          );
                        }),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Rating Count
                      Text(
                        'Based on $totalRatings reviews',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Detailed Criteria Breakdown
          if (criteriaAverages.isNotEmpty) ...[
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.withOpacity(0.05),
                    Colors.purple.withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.8),
                              Colors.purple.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Rating Breakdown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Criteria Items
                  ...criteriaAverages.entries.toList().asMap().entries.map((entry) {
                    final int index = entry.key;
                    final criteriaEntry = entry.value;
                    final String criteriaName = criteriaEntry.key.replaceAll('_', ' ');
                    final double score = criteriaEntry.value;
                    
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 800 + (index * 150)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, animationValue, _) {
                        return Transform.translate(
                          offset: Offset(40 * (1 - animationValue), 0),
                          child: Opacity(
                            opacity: animationValue,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Criteria Name
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      criteriaName.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  
                                  // Progress Bar
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: (score / 5.0) * animationValue,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.blue,
                                                Colors.purple,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Score Badge
                                  TweenAnimationBuilder<double>(
                                    duration: Duration(milliseconds: 1000 + (index * 150)),
                                    tween: Tween(begin: 0.0, end: score),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, animatedScore, _) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.withOpacity(0.9),
                                              Colors.purple.withOpacity(0.9),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              animatedScore.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
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
          ],
          
          // Recent Comments (if any)
          if (recentComments.isNotEmpty) ...[
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Recent Feedback',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  ...recentComments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final comment = entry.value;
                    
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 600 + (index * 200)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, commentValue, _) {
                        return Transform.translate(
                          offset: Offset(30 * (1 - commentValue), 0),
                          child: Opacity(
                            opacity: commentValue,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.format_quote_rounded,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      comment,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        height: 1.4,
                                        fontStyle: FontStyle.italic,
                                      ),
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
          ],
          
          // Load More Button (if there are more ratings)
          if (pagination['hasMore'] == true) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  // For now, show a message that more ratings are available
                  // In a full implementation, this would load more ratings
                },
                icon: const Icon(Icons.expand_more),
                label: Text(
                  'Load More Reviews (${(pagination['total'] ?? 0) - (pagination['limit'] ?? 0)} more available)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
