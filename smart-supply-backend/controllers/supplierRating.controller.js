const pool = require('../db');

/**
 * Submit a rating for a distributor after order delivery
 * POST /api/ratings/distributor/:distributorId
 */
const submitSupplierRating = async (req, res) => {
  try {
    console.log('[DEBUG] ========== RATING SUBMISSION START ==========');
    const { distributorId } = req.params;
    const { 
      orderId, 
      overallRating,
      qualityRating, 
      deliveryRating, 
      serviceRating, 
      pricingRating, 
      comment 
    } = req.body;

    // Use the overall rating from frontend (already calculated)
    const ratings = [qualityRating, deliveryRating, serviceRating, pricingRating];
    
    const supermarketId = req.user.id; // From auth middleware
    
    console.log('[DEBUG] Submit supplier rating:', {
      distributorId,
      supermarketId,
      orderId,
      ratings: { overallRating, qualityRating, deliveryRating, serviceRating, pricingRating }
    });

    // Validation
  if (!orderId || !overallRating || !qualityRating || !deliveryRating || !serviceRating || !pricingRating) {
      return res.status(400).json({
        success: false,
        message: 'Missing required rating fields'
      });
    }

    // Validate rating values (1-5)
    for (const rating of ratings) {
      if (rating < 1 || rating > 5) {
        return res.status(400).json({
          success: false,
          message: 'Rating values must be between 1 and 5'
        });
      }
    }
    
    // Validate overall rating
    if (overallRating < 1 || overallRating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Overall rating must be between 1 and 5'
      });
    }

    // Verify user is a supermarket
    const userQuery = 'SELECT role FROM users WHERE id = $1';
    const userResult = await pool.query(userQuery, [supermarketId]);
    
    if (userResult.rows.length === 0 || userResult.rows[0].role.toLowerCase() !== 'supermarket') {
      console.log('[DEBUG] User role check failed. User role:', userResult.rows[0]?.role);
      return res.status(403).json({
        success: false,
        message: 'Only supermarket users can rate suppliers'
      });
    }

    // Verify order exists, belongs to this supermarket, and is delivered
    const orderQuery = `
      SELECT id, status, distributor_id 
      FROM orders 
      WHERE id = $1 AND buyer_id = $2 AND status = 'delivered'
    `;
    console.log('[DEBUG] Order validation query:', orderQuery);
    console.log('[DEBUG] Query parameters:', [orderId, supermarketId]);
    const orderResult = await pool.query(orderQuery, [orderId, supermarketId]);
    
    if (orderResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order not found, not yours, or not delivered yet'
      });
    }

    // Verify distributor ID matches order
    if (orderResult.rows[0].distributor_id != distributorId) {
      return res.status(400).json({
        success: false,
        message: 'Distributor ID does not match order distributor'
      });
    }

    // Check if rating already exists for this order
    const existingRatingQuery = 'SELECT id FROM supplier_ratings WHERE supermarket_id = $1 AND order_id = $2';
    const existingResult = await pool.query(existingRatingQuery, [supermarketId, orderId]);
    
    if (existingResult.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'You have already rated this order'
      });
    }

    // Insert the rating
    const insertQuery = `
      INSERT INTO supplier_ratings (
        distributor_id, 
        supermarket_id, 
        order_id, 
        overall_rating, 
        quality_rating, 
        delivery_rating, 
        service_rating, 
        pricing_rating, 
        comment
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING id, created_at
    `;
    
    const insertResult = await pool.query(insertQuery, [
      distributorId,
      supermarketId,
      orderId,
      overallRating,
      qualityRating,
      deliveryRating,
      serviceRating,
      pricingRating,
      comment || null
    ]);

    // Update ratings table for compatibility with existing system
    // Add rater_role (required, NOT NULL)
    const compatibilityInsert = `
      INSERT INTO ratings (
        rater_id,
        rated_id,
        rater_role,
        rated_role,
        rating_type,
        overall_rating,
        comment,
        order_id
      ) VALUES ($1, $2, $3, 'distributor', 'supplier_rating', $4, $5, $6)
    `;
    try {
      await pool.query(compatibilityInsert, [
        supermarketId,
        distributorId,
        'supermarket',
        overallRating,
        comment || null,
        orderId
      ]);
    } catch (compatErr) {
      // Roll back supplier_ratings row if compatibility insert fails
      await pool.query('DELETE FROM supplier_ratings WHERE id = $1', [insertResult.rows[0].id]);
      console.error('Error inserting compatibility rating, rolled back supplier_ratings:', compatErr);
      return res.status(500).json({
        success: false,
        message: 'Internal error saving rating (compatibility insert failed)',
        error: process.env.NODE_ENV === 'development' ? compatErr.message : undefined
      });
    }

    // Insert criteria scores for compatibility - use proper criteria names
    const criteriaData = [
      { name: 'Product Quality', score: qualityRating },
      { name: 'Delivery Time', score: deliveryRating },
      { name: 'Customer Service', score: serviceRating },
      { name: 'Pricing', score: pricingRating }
    ];

    const ratingId = insertResult.rows[0].id;
    
    // Get the rating ID from the ratings table for criteria scores
    const ratingIdQuery = 'SELECT id FROM ratings WHERE rater_id = $1 AND rated_id = $2 AND order_id = $3 ORDER BY created_at DESC LIMIT 1';
    const ratingIdResult = await pool.query(ratingIdQuery, [supermarketId, distributorId, orderId]);
    
    if (ratingIdResult.rows.length > 0) {
      const mainRatingId = ratingIdResult.rows[0].id;
      
      for (const criteria of criteriaData) {
        // Get or create criteria
        let criteriaQuery = 'SELECT id FROM rating_criteria WHERE criteria_name = $1';
        let criteriaResult = await pool.query(criteriaQuery, [criteria.name]);
        
        let criteriaId;
        if (criteriaResult.rows.length === 0) {
          const createCriteriaQuery = 'INSERT INTO rating_criteria (criteria_name, rating_type, description) VALUES ($1, $2, $3) RETURNING id';
          const newCriteria = await pool.query(createCriteriaQuery, [criteria.name, 'supplier_rating', criteria.name]);
          criteriaId = newCriteria.rows[0].id;
        } else {
          criteriaId = criteriaResult.rows[0].id;
        }
        
        // Insert criteria score
        const scoreQuery = 'INSERT INTO rating_criteria_scores (rating_id, criteria_id, score) VALUES ($1, $2, $3)';
        await pool.query(scoreQuery, [mainRatingId, criteriaId, criteria.score]);
      }
    }

    // Update distributor's average ratings
    console.log('[DEBUG] Updating distributor average ratings...');
    await updateDistributorAverageRatings(distributorId);

    res.status(201).json({
      success: true,
      message: 'Rating submitted successfully',
      data: {
        ratingId: insertResult.rows[0].id,
        createdAt: insertResult.rows[0].created_at
      }
    });

  } catch (error) {
    console.error('Error submitting supplier rating:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Check if an order has been rated by the supermarket
 * GET /api/ratings/distributor/:distributorId/order/:orderId/check
 */
const checkOrderRating = async (req, res) => {
  try {
    const { distributorId, orderId } = req.params;
    const supermarketId = req.user.id;

    const query = 'SELECT id FROM supplier_ratings WHERE supermarket_id = $1 AND order_id = $2 AND distributor_id = $3';
    const result = await pool.query(query, [supermarketId, orderId, distributorId]);

    res.json({
      success: true,
      data: {
        hasRated: result.rows.length > 0
      }
    });

  } catch (error) {
    console.error('Error checking order rating:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Get distributor rating statistics
 * GET /api/ratings/distributor/:distributorId/stats
 */
const getDistributorStats = async (req, res) => {
  try {
    const { distributorId } = req.params;

    // First try to get from distributor_detailed_averages table
    let query = 'SELECT * FROM distributor_detailed_averages WHERE distributor_id = $1';
    let result = await pool.query(query, [distributorId]);
    
    console.log('[DEBUG] Checking distributor_detailed_averages for distributor', distributorId, ':', result.rows.length, 'rows');

    // If not found, calculate from individual ratings
    if (result.rows.length === 0) {
      // First, let's check what criteria names exist for this distributor
      const criteriaCheckQuery = `
        SELECT DISTINCT rc.criteria_name, COUNT(*) as count
        FROM ratings r
        JOIN rating_criteria_scores rcs ON r.id = rcs.rating_id
        JOIN rating_criteria rc ON rcs.criteria_id = rc.id
        WHERE r.rated_id = $1 AND r.rated_role = 'distributor' AND r.rating_type = 'supplier_rating'
        GROUP BY rc.criteria_name
      `;
      const criteriaResult = await pool.query(criteriaCheckQuery, [distributorId]);
      console.log('[DEBUG] Available criteria for distributor', distributorId, ':', criteriaResult.rows);
      
      // Calculate detailed averages from individual ratings
      const detailedQuery = `
        SELECT 
          COUNT(*) as total_ratings,
          ROUND(AVG(r.overall_rating), 2) as avg_overall,
          ROUND(AVG(CASE WHEN rc.criteria_name = 'Product Quality' THEN rcs.score END), 2) as avg_quality,
          ROUND(AVG(CASE WHEN rc.criteria_name = 'Delivery Time' THEN rcs.score END), 2) as avg_delivery,
          ROUND(AVG(CASE WHEN rc.criteria_name = 'Customer Service' THEN rcs.score END), 2) as avg_service,
          ROUND(AVG(CASE WHEN rc.criteria_name = 'Pricing' THEN rcs.score END), 2) as avg_pricing
        FROM ratings r
        LEFT JOIN rating_criteria_scores rcs ON r.id = rcs.rating_id
        LEFT JOIN rating_criteria rc ON rcs.criteria_id = rc.id
        WHERE r.rated_id = $1 AND r.rated_role = 'distributor' AND r.rating_type = 'supplier_rating'
      `;
      result = await pool.query(detailedQuery, [distributorId]);
      console.log('[DEBUG] Detailed query result:', result.rows[0]);
      
      // If still no results, try rating_summaries as fallback
      if (result.rows.length === 0 || result.rows[0].total_ratings == 0) {
        query = `
          SELECT 
            total_ratings,
            average_rating as avg_overall,
            0.0 as avg_quality,
            0.0 as avg_delivery,
            0.0 as avg_service,
            0.0 as avg_pricing
          FROM rating_summaries 
          WHERE user_id = $1 AND rating_type = 'supplier_rating'
        `;
        result = await pool.query(query, [distributorId]);
        console.log('[DEBUG] rating_summaries fallback result:', result.rows.length, 'rows');
        
        // If still no results, try the old ratings table as final fallback
        if (result.rows.length === 0 || result.rows[0].total_ratings == 0) {
          console.log('[DEBUG] Trying old ratings table as final fallback...');
          const oldRatingsQuery = `
            SELECT 
              COUNT(*) as total_ratings,
              ROUND(AVG(overall_rating), 2) as avg_overall,
              0.0 as avg_quality,
              0.0 as avg_delivery,
              0.0 as avg_service,
              0.0 as avg_pricing
            FROM ratings 
            WHERE rated_id = $1 AND rated_role = 'distributor' AND rating_type = 'supplier_rating'
          `;
          result = await pool.query(oldRatingsQuery, [distributorId]);
          console.log('[DEBUG] Old ratings table result:', result.rows[0]);
        }
      }
    }

    if (result.rows.length === 0) {
      return res.json({
        success: true,
        data: {
          totalRatings: 0,
          avgOverall: 0,
          avgQuality: 0,
          avgDelivery: 0,
          avgService: 0,
          avgPricing: 0
        }
      });
    }

    const stats = result.rows[0];
    console.log('[DEBUG] Final stats data:', stats);
    
    const responseData = {
      totalRatings: parseInt(stats.total_ratings) || 0,
      avgOverall: parseFloat(stats.avg_overall) || 0,
      avgQuality: parseFloat(stats.avg_quality) || 0,
      avgDelivery: parseFloat(stats.avg_delivery) || 0,
      avgService: parseFloat(stats.avg_service) || 0,
      avgPricing: parseFloat(stats.avg_pricing) || 0
    };
    
    console.log('[DEBUG] Response data:', responseData);
    
    res.json({
      success: true,
      data: responseData
    });

  } catch (error) {
    console.error('Error getting distributor stats:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Update distributor's average ratings in rating_summaries table
 */
async function updateDistributorAverageRatings(distributorId) {
  try {
    console.log(`[DEBUG] Calculating new averages for distributor ${distributorId}...`);
    
    // Calculate new averages from supplier_ratings table
    const avgQuery = `
      SELECT 
        COUNT(*) as total_ratings,
        ROUND(AVG(overall_rating), 2) as avg_overall,
        ROUND(AVG(quality_rating), 2) as avg_quality,
        ROUND(AVG(delivery_rating), 2) as avg_delivery,
        ROUND(AVG(service_rating), 2) as avg_service,
        ROUND(AVG(pricing_rating), 2) as avg_pricing
      FROM supplier_ratings 
      WHERE distributor_id = $1
    `;
    
    const avgResult = await pool.query(avgQuery, [distributorId]);
    const stats = avgResult.rows[0];
    
    console.log('[DEBUG] New averages calculated:', stats);
    
    // Update or insert into rating_summaries table
    const upsertQuery = `
      INSERT INTO rating_summaries (
        user_id, 
        user_role, 
        rating_type, 
        total_ratings, 
        average_rating, 
        total_score,
        last_rating_date,
        updated_at
      ) VALUES ($1, 'distributor', 'supplier_rating', $2, $3, $4, NOW(), NOW())
      ON CONFLICT (user_id, rating_type) 
      DO UPDATE SET
        total_ratings = $2,
        average_rating = $3,
        total_score = $4,
        last_rating_date = NOW(),
        updated_at = NOW()
    `;
    
    const totalScore = stats.total_ratings * stats.avg_overall;
    
    await pool.query(upsertQuery, [
      distributorId,
      stats.total_ratings,
      stats.avg_overall,
      totalScore
    ]);
    
    console.log(`[DEBUG] Rating summary updated for distributor ${distributorId}`);
    
    // Also update the detailed averages in a separate table for the new rating system
    const detailedUpsertQuery = `
      INSERT INTO distributor_detailed_averages (
        distributor_id,
        total_ratings,
        avg_overall,
        avg_quality,
        avg_delivery,
        avg_service,
        avg_pricing,
        updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
      ON CONFLICT (distributor_id)
      DO UPDATE SET
        total_ratings = $2,
        avg_overall = $3,
        avg_quality = $4,
        avg_delivery = $5,
        avg_service = $6,
        avg_pricing = $7,
        updated_at = NOW()
    `;
    
    // Create the detailed averages table if it doesn't exist
    await pool.query(`
      CREATE TABLE IF NOT EXISTS distributor_detailed_averages (
        distributor_id INTEGER PRIMARY KEY,
        total_ratings INTEGER DEFAULT 0,
        avg_overall DECIMAL(3,2) DEFAULT 0.00,
        avg_quality DECIMAL(3,2) DEFAULT 0.00,
        avg_delivery DECIMAL(3,2) DEFAULT 0.00,
        avg_service DECIMAL(3,2) DEFAULT 0.00,
        avg_pricing DECIMAL(3,2) DEFAULT 0.00,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    await pool.query(detailedUpsertQuery, [
      distributorId,
      stats.total_ratings,
      stats.avg_overall,
      stats.avg_quality,
      stats.avg_delivery,
      stats.avg_service,
      stats.avg_pricing
    ]);
    
    console.log(`[DEBUG] Detailed averages updated for distributor ${distributorId}:`, {
      total_ratings: stats.total_ratings,
      avg_overall: stats.avg_overall,
      avg_quality: stats.avg_quality,
      avg_delivery: stats.avg_delivery,
      avg_service: stats.avg_service,
      avg_pricing: stats.avg_pricing
    });
    
  } catch (error) {
    console.error('Error updating distributor average ratings:', error);
    // Don't throw error - rating submission should still succeed even if average update fails
  }
}

/**
 * Manually update distributor averages (for testing)
 * POST /api/supplier-ratings/distributor/:distributorId/update-averages
 */
const updateDistributorAverages = async (req, res) => {
  try {
    const { distributorId } = req.params;
    await updateDistributorAverageRatings(distributorId);
    res.json({
      success: true,
      message: 'Distributor averages updated successfully'
    });
  } catch (error) {
    console.error('Error updating distributor averages:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

module.exports = {
  submitSupplierRating,
  checkOrderRating,
  getDistributorStats,
  updateDistributorAverages
};
