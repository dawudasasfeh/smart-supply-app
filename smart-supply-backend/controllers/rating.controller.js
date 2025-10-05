// GET /api/ratings/summary/:userId/:userRole - Get rating summary for any user/role
const pool = require('../db');
const getRatingSummary = async (req, res) => {
  try {
    const { userId, userRole } = req.params;
    
    // Normalize userRole to lowercase for consistency
    const normalizedUserRole = userRole.toLowerCase();
    
    console.log('[DEBUG] getRatingSummary params:', { userId, userRole: normalizedUserRole });
    
    // Query rating_summaries for this user/role
    const summaryQuery = `
      SELECT rating_type, total_ratings, average_rating
      FROM rating_summaries
      WHERE user_id = $1 AND user_role = $2
    `;
    const result = await pool.query(summaryQuery, [userId, normalizedUserRole]);
    console.log('[DEBUG] getRatingSummary SQL result:', result.rows);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching rating summary:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch rating summary'
    });
  }
};


// Rating methodology and business rules
const RATING_PERMISSIONS = {
  Supermarket: {
    canRate: ['Distributor', 'Delivery'],
    canView: ['Distributor', 'Delivery', 'Supermarket']
  },
  Distributor: {
    canRate: ['Supermarket'],
    canView: ['Supermarket', 'Distributor']
  },
  Delivery: {
    canRate: ['Supermarket'],
    canView: ['Supermarket', 'Delivery']
  }
};

const RATING_TYPES = {
  'supermarket-distributor': {
    criteria: ['reliability', 'product_quality', 'delivery_speed', 'communication', 'pricing']
  },
  'supermarket-delivery': {
    criteria: ['punctuality', 'product_handling', 'professionalism', 'communication']
  },
  'distributor-supermarket': {
    criteria: ['payment_reliability', 'order_accuracy', 'communication', 'business_relationship']
  },
  'delivery-supermarket': {
    criteria: ['order_clarity', 'location_accessibility', 'payment_reliability', 'cooperation']
  }
};

// Helper function to validate rating permissions
const canUserRate = (raterRole, ratedRole) => {
  const permissions = RATING_PERMISSIONS[raterRole];
  return permissions && permissions.canRate.includes(ratedRole);
};

// Helper function to get rating type
const getRatingType = (raterRole, ratedRole) => {
  return `${raterRole}-${ratedRole}`;
};

// GET /api/ratings/criteria/:ratingType - Get rating criteria for a specific type
const getRatingCriteria = async (req, res) => {
  try {
    const { ratingType } = req.params;
    if (!RATING_TYPES[ratingType]) {
      return res.status(400).json({
        success: false,
        message: 'Invalid rating type'
      });
    }

    const query = `
      SELECT * FROM rating_criteria 
      WHERE rating_type = $1 
      ORDER BY criteria_name ASC
    `;
    
    const result = await pool.query(query, [ratingType]);

    res.json({
      success: true,
      data: {
        ratingType,
        criteria: result.rows
      }
    });

  } catch (error) {
    console.error('Error fetching rating criteria:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch rating criteria'
    });
  }
};

// POST /api/ratings - Submit a new rating
const submitRating = async (req, res) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const {
      rated_id: ratedId,
      rated_role: ratedRole,
      criteria_ratings: criteriaScores,
      overall_rating: providedOverallRating,
      comment,
      order_id: orderId,
      is_anonymous: isAnonymous = false
    } = req.body;

    const raterId = req.user.id;
    const raterRole = req.user.role;

    // Validate permissions
    if (!canUserRate(raterRole, ratedRole)) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        success: false,
        message: `${raterRole} cannot rate ${ratedRole}`
      });
    }

    const ratingType = getRatingType(raterRole, ratedRole);

    // Check for duplicate rating
    const duplicateCheck = await client.query(
      'SELECT id FROM ratings WHERE rater_id = $1 AND rated_id = $2 AND order_id = $3 AND rating_type = $4',
      [raterId, ratedId, orderId, ratingType]
    );

    if (duplicateCheck.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        message: 'Rating already submitted for this transaction'
      });
    }

    // Use provided overall rating from frontend
    const overallRating = providedOverallRating || 5.0;

    // Create rating record
    const ratingResult = await client.query(
      `INSERT INTO ratings (rater_id, rated_id, rater_role, rated_role, rating_type, overall_rating, comment, order_id, is_anonymous, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW()) RETURNING id`,
      [raterId, ratedId, raterRole, ratedRole, ratingType, overallRating.toFixed(2), comment, orderId, isAnonymous]
    );

    const ratingId = ratingResult.rows[0].id;

    // Create criteria scores from Map format
    if (criteriaScores && typeof criteriaScores === 'object') {
      for (const [criteriaName, score] of Object.entries(criteriaScores)) {
        // Find criteria ID by name for this rating type
        const criteriaResult = await client.query(
          'SELECT id FROM rating_criteria WHERE criteria_name = $1 AND rating_type = $2',
          [criteriaName, ratingType]
        );
        
        if (criteriaResult.rows.length > 0) {
          await client.query(
            'INSERT INTO rating_criteria_scores (rating_id, criteria_id, score, created_at) VALUES ($1, $2, $3, NOW())',
            [ratingId, criteriaResult.rows[0].id, score]
          );
        }
      }
    }

    await client.query('COMMIT');

    res.status(201).json({
      success: true,
      message: 'Rating submitted successfully',
      data: {
        ratingId: ratingId,
        overallRating: overallRating.toFixed(2)
      }
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error submitting rating:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to submit rating'
    });
  } finally {
    client.release();
  }
};

// GET /api/ratings/analytics - Get rating analytics for current user
const getRatingAnalytics = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    
    // Get ratings given by this user
    const ratingsGivenQuery = `
      SELECT COUNT(*) as count, AVG(overall_rating) as avg_rating 
      FROM ratings 
      WHERE rater_id = $1
    `;
    const ratingsGiven = await pool.query(ratingsGivenQuery, [userId]);
    
    // Get ratings received by this user
    const ratingsReceivedQuery = `
      SELECT COUNT(*) as count, AVG(overall_rating) as avg_rating 
      FROM ratings 
      WHERE rated_id = $1 AND rated_role = $2
    `;
    const ratingsReceived = await pool.query(ratingsReceivedQuery, [userId, userRole]);

    // Get recent ratings received
    const recentRatingsQuery = `
      SELECT r.*, rc.criteria_name, rcs.score 
      FROM ratings r
      LEFT JOIN rating_criteria_scores rcs ON r.id = rcs.rating_id
      LEFT JOIN rating_criteria rc ON rcs.criteria_id = rc.id
      WHERE r.rated_id = $1 AND r.rated_role = $2
      ORDER BY r.created_at DESC
      LIMIT 10
    `;
    const recentRatings = await pool.query(recentRatingsQuery, [userId, userRole]);

    const givenStats = ratingsGiven.rows[0];
    const receivedStats = ratingsReceived.rows[0];

    res.json({
      success: true,
      data: {
        totalRatingsGiven: parseInt(givenStats.count) || 0,
        totalRatingsReceived: parseInt(receivedStats.count) || 0,
        averageRatingGiven: parseFloat(givenStats.avg_rating) || 0,
        averageRatingReceived: parseFloat(receivedStats.avg_rating) || 0,
        recentRatings: recentRatings.rows
      }
    });

  } catch (error) {
    console.error('Error fetching rating analytics:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch rating analytics'
    });
  }
};

// GET /api/ratings/entities - Get entities that can be rated by current user
const getRatableEntities = async (req, res) => {
  try {
    console.log('getRatableEntities called');
    console.log('req.user:', req.user);
    
    const userRole = req.user?.role;
    console.log('userRole:', userRole);
    
    const permissions = RATING_PERMISSIONS[userRole];
    console.log('permissions:', permissions);
    
    if (!permissions) {
      return res.status(400).json({
        success: false,
        message: `Invalid user role: ${userRole}`
      });
    }

    // Get actual users from database that can be rated
    const { getUsersByRole } = require('../models/user.model');
    
    let allRatableUsers = [];
    for (const role of permissions.canRate) {
      const users = await getUsersByRole(role, req.user.id);
      allRatableUsers = allRatableUsers.concat(users);
    }
    
    console.log('ratableUsers found:', allRatableUsers.length);

    res.json({
      success: true,
      data: {
        userRole: userRole,
        canRate: permissions.canRate,
        entities: allRatableUsers,
        ratingTypes: permissions.canRate.map(role => ({
          targetRole: role,
          ratingType: getRatingType(userRole, role),
          criteria: RATING_TYPES[getRatingType(userRole, role)]?.criteria || []
        }))
      }
    });

  } catch (error) {
    console.error('Error fetching ratable entities:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch ratable entities',
      error: error.message
    });
  }
};

// GET /api/ratings/user/:userId/:role - Get user's rating history
const getUserRatings = async (req, res) => {
  try {
    const { userId, role } = req.params;
    const { type = 'received', limit = 20, offset = 0 } = req.query;
    
    let query;
    let params;
    
    if (type === 'given') {
      query = `
        SELECT r.*, rc.criteria_name, rcs.score 
        FROM ratings r
        LEFT JOIN rating_criteria_scores rcs ON r.id = rcs.rating_id
        LEFT JOIN rating_criteria rc ON rcs.criteria_id = rc.id
        WHERE r.rater_id = $1 AND r.rater_role = $2
        ORDER BY r.created_at DESC
        LIMIT $3 OFFSET $4
      `;
      params = [userId, role, limit, offset];
    } else {
      query = `
        SELECT r.*, rc.criteria_name, rcs.score 
        FROM ratings r
        LEFT JOIN rating_criteria_scores rcs ON r.id = rcs.rating_id
        LEFT JOIN rating_criteria rc ON rcs.criteria_id = rc.id
        WHERE r.rated_id = $1 AND r.rated_role = $2
        ORDER BY r.created_at DESC
        LIMIT $3 OFFSET $4
      `;
      params = [userId, role, limit, offset];
    }

    const result = await pool.query(query, params);

    res.json({
      success: true,
      data: {
        ratings: result.rows
      }
    });

  } catch (error) {
    console.error('Error fetching user ratings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch user ratings'
    });
  }
};

// GET /api/ratings/stats - Get rating statistics for dashboard
const getRatingStats = async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get rating distribution
    const distributionQuery = `
      SELECT overall_rating, COUNT(*) as count 
      FROM ratings 
      WHERE rated_id = $1 
      GROUP BY overall_rating 
      ORDER BY overall_rating ASC
    `;
    const distribution = await pool.query(distributionQuery, [userId]);
    
    // Get ratings by type
    const byTypeQuery = `
      SELECT rating_type, total_ratings, average_rating 
      FROM rating_summaries 
      WHERE user_id = $1
    `;
    const byType = await pool.query(byTypeQuery, [userId]);
    
    res.json({
      success: true,
      data: {
        distribution: distribution.rows,
        byType: byType.rows
      }
    });
    
  } catch (error) {
    console.error('Error fetching rating stats:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch rating statistics'
    });
  }
};

// GET /api/ratings/detailed/:userId/:userRole - Get detailed ratings with individual reviews
const getDetailedRatings = async (req, res) => {
  try {
    const { userId, userRole } = req.params;
    const { limit = 10, offset = 0 } = req.query;
    
    // Normalize userRole to lowercase for consistency
    const normalizedUserRole = userRole.toLowerCase();
    
    console.log('[DEBUG] getDetailedRatings params:', { userId, userRole: normalizedUserRole, limit, offset });
    
    // Get individual ratings with rater details
    const ratingsQuery = `
      SELECT 
        r.id,
        r.overall_rating,
        r.comment,
        r.rating_type,
        r.created_at,
        r.rated_id,
        r.rated_role,
        rater.name as rater_name,
        rater.role as rater_role,
        rater.id as rater_id,
        o.id as order_id
      FROM ratings r
      LEFT JOIN users rater ON r.rater_id = rater.id
      LEFT JOIN orders o ON r.order_id = o.id
      WHERE r.rated_id = $1 AND r.rated_role = $2 AND r.rating_type = 'supplier_rating'
      ORDER BY r.created_at DESC
      LIMIT $3 OFFSET $4
    `;
    
    const ratingsResult = await pool.query(ratingsQuery, [userId, normalizedUserRole, limit, offset]);
    
    // Get rating criteria scores for each rating
    const ratingsWithCriteria = [];
    for (const rating of ratingsResult.rows) {
      const criteriaQuery = `
        SELECT 
          rc.criteria_name,
          rc.description,
          rcs.score
        FROM rating_criteria_scores rcs
        JOIN rating_criteria rc ON rcs.criteria_id = rc.id
        WHERE rcs.rating_id = $1
        ORDER BY rc.criteria_name
      `;
      
      const criteriaResult = await pool.query(criteriaQuery, [rating.id]);
      
      ratingsWithCriteria.push({
        ...rating,
        criteria_scores: criteriaResult.rows
      });
    }
    
    // Get total count for pagination
    const countQuery = `
      SELECT COUNT(*) as total
      FROM ratings
      WHERE rated_id = $1 AND rated_role = $2 AND rating_type = 'supplier_rating'
    `;
    const countResult = await pool.query(countQuery, [userId, normalizedUserRole]);
    
    res.json({
      success: true,
      data: {
        ratings: ratingsWithCriteria,
        pagination: {
          total: parseInt(countResult.rows[0].total),
          limit: parseInt(limit),
          offset: parseInt(offset),
          hasMore: parseInt(offset) + parseInt(limit) < parseInt(countResult.rows[0].total)
        }
      }
    });
    
  } catch (error) {
    console.error('Error fetching detailed ratings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch detailed ratings'
    });
  }
};

module.exports = {
  getRatingCriteria,
  submitRating,
  getRatingAnalytics,
  getRatableEntities,
  getUserRatings,
  getRatingStats,
  getRatingSummary,
  getDetailedRatings
};
