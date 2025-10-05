const db = require('../db');

// Get delivery performance metrics for a distributor
const getDeliveryPerformanceMetrics = async (req, res) => {
  try {
    // Use authenticated user's ID instead of URL parameter for security
    const distributorId = req.user.id;
    const { period = '30' } = req.query; // days, default 30 days

    if (!distributorId) {
      return res.status(400).json({
        success: false,
        message: 'User authentication required'
      });
    }

    // Verify user is a distributor
    if (req.user.role !== 'distributor') {
      return res.status(403).json({
        success: false,
        message: 'Access denied. Distributor role required.'
      });
    }

    // Calculate date range - use a more inclusive range
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - parseInt(period));
    
    // Add some buffer to ensure we capture all recent data
    endDate.setHours(23, 59, 59, 999);
    startDate.setHours(0, 0, 0, 0);

    // Get delivery analytics data
    const analytics = await db.query(`
      SELECT 
        COUNT(*) as total_deliveries,
        AVG(delivery_duration_minutes) as avg_delivery_time_minutes,
        SUM(CASE WHEN is_on_time = true THEN 1 ELSE 0 END) as on_time_deliveries,
        AVG(efficiency_score) as avg_efficiency_score,
        AVG(delivery_cost) as avg_delivery_cost,
        AVG(customer_rating) as avg_customer_rating,
        AVG(distance_km) as avg_distance_km
      FROM delivery_analytics 
      WHERE distributor_id = $1 
        AND delivery_start_time >= $2 
        AND delivery_start_time <= $3
    `, [distributorId, startDate, endDate]);

    const metrics = analytics.rows[0] || {};

    // Calculate performance metrics
    const totalDeliveries = parseInt(metrics.total_deliveries) || 0;
    const avgDeliveryTimeMinutes = parseFloat(metrics.avg_delivery_time_minutes) || 0;
    const onTimeDeliveries = parseInt(metrics.on_time_deliveries) || 0;
    const avgEfficiencyScore = parseFloat(metrics.avg_efficiency_score) || 0;
    const avgDeliveryCost = parseFloat(metrics.avg_delivery_cost) || 0;
    const avgCustomerRating = parseFloat(metrics.avg_customer_rating) || 0;
    const avgDistance = parseFloat(metrics.avg_distance_km) || 0;

    // Calculate percentages and trends
    const onTimeRate = totalDeliveries > 0 ? (onTimeDeliveries / totalDeliveries) * 100 : 0;
    const avgDeliveryTimeHours = avgDeliveryTimeMinutes / 60;

    // Get previous period for comparison
    const prevStartDate = new Date(startDate);
    prevStartDate.setDate(prevStartDate.getDate() - parseInt(period));
    const prevEndDate = new Date(startDate);

    const prevAnalytics = await db.query(`
      SELECT 
        COUNT(*) as total_deliveries,
        AVG(delivery_duration_minutes) as avg_delivery_time_minutes,
        SUM(CASE WHEN is_on_time = true THEN 1 ELSE 0 END) as on_time_deliveries,
        AVG(efficiency_score) as avg_efficiency_score,
        AVG(delivery_cost) as avg_delivery_cost
      FROM delivery_analytics 
      WHERE distributor_id = $1 
        AND delivery_start_time >= $2 
        AND delivery_start_time < $3
    `, [distributorId, prevStartDate, prevEndDate]);

    const prevMetrics = prevAnalytics.rows[0] || {};
    const prevTotalDeliveries = parseInt(prevMetrics.total_deliveries) || 0;
    const prevAvgDeliveryTimeMinutes = parseFloat(prevMetrics.avg_delivery_time_minutes) || 0;
    const prevOnTimeDeliveries = parseInt(prevMetrics.on_time_deliveries) || 0;
    const prevAvgEfficiencyScore = parseFloat(prevMetrics.avg_efficiency_score) || 0;
    const prevAvgDeliveryCost = parseFloat(prevMetrics.avg_delivery_cost) || 0;

    // Calculate trends
    const deliveryTimeTrend = prevAvgDeliveryTimeMinutes > 0 
      ? ((avgDeliveryTimeMinutes - prevAvgDeliveryTimeMinutes) / prevAvgDeliveryTimeMinutes) * 100 
      : 0;
    
    const onTimeRateTrend = prevTotalDeliveries > 0 
      ? ((onTimeRate - (prevOnTimeDeliveries / prevTotalDeliveries) * 100) / ((prevOnTimeDeliveries / prevTotalDeliveries) * 100)) * 100 
      : 0;
    
    const efficiencyTrend = prevAvgEfficiencyScore > 0 
      ? ((avgEfficiencyScore - prevAvgEfficiencyScore) / prevAvgEfficiencyScore) * 100 
      : 0;
    
    const costTrend = prevAvgDeliveryCost > 0 
      ? ((avgDeliveryCost - prevAvgDeliveryCost) / prevAvgDeliveryCost) * 100 
      : 0;

    // Format response
    const performanceMetrics = {
      totalDeliveries,
      avgDeliveryTime: {
        hours: Math.round(avgDeliveryTimeHours * 10) / 10,
        minutes: Math.round(avgDeliveryTimeMinutes),
        trend: Math.round(deliveryTimeTrend * 10) / 10
      },
      onTimeRate: {
        percentage: Math.round(onTimeRate * 10) / 10,
        trend: Math.round(onTimeRateTrend * 10) / 10
      },
      efficiencyScore: {
        score: Math.round(avgEfficiencyScore * 10) / 10,
        trend: Math.round(efficiencyTrend * 10) / 10
      },
      costPerDelivery: {
        cost: Math.round(avgDeliveryCost * 100) / 100,
        trend: Math.round(costTrend * 10) / 10
      },
      additionalMetrics: {
        avgCustomerRating: Math.round(avgCustomerRating * 10) / 10,
        avgDistance: Math.round(avgDistance * 10) / 10,
        period: `${period} days`
      }
    };

    res.json({
      success: true,
      data: performanceMetrics,
      message: 'Delivery performance metrics retrieved successfully'
    });

  } catch (error) {
    console.error('Error fetching delivery performance metrics:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch delivery performance metrics',
      error: error.message
    });
  }
};

// Create or update delivery analytics record
const createDeliveryAnalytics = async (req, res) => {
  try {
    const {
      distributorId,
      orderId,
      deliveryPersonId,
      deliveryStartTime,
      deliveryEndTime,
      isOnTime,
      deliveryCost,
      distanceKm,
      efficiencyScore,
      customerRating
    } = req.body;

    // Calculate delivery duration
    const startTime = new Date(deliveryStartTime);
    const endTime = new Date(deliveryEndTime);
    const durationMinutes = Math.round((endTime - startTime) / (1000 * 60));

    // Check if record already exists
    const existingRecord = await db.query(`
      SELECT id FROM delivery_analytics 
      WHERE distributor_id = $1 AND order_id = $2
    `, [distributorId, orderId]);

    if (existingRecord.rows.length > 0) {
      // Update existing record
      await db.query(`
        UPDATE delivery_analytics SET
          delivery_person_id = $1,
          delivery_start_time = $2,
          delivery_end_time = $3,
          delivery_duration_minutes = $4,
          is_on_time = $5,
          delivery_cost = $6,
          distance_km = $7,
          efficiency_score = $8,
          customer_rating = $9,
          updated_at = CURRENT_TIMESTAMP
        WHERE distributor_id = $10 AND order_id = $11
      `, [
        deliveryPersonId,
        deliveryStartTime,
        deliveryEndTime,
        durationMinutes,
        isOnTime,
        deliveryCost,
        distanceKm,
        efficiencyScore,
        customerRating,
        distributorId,
        orderId
      ]);
    } else {
      // Create new record
      await db.query(`
        INSERT INTO delivery_analytics (
          distributor_id, order_id, delivery_person_id, delivery_start_time,
          delivery_end_time, delivery_duration_minutes, is_on_time,
          delivery_cost, distance_km, efficiency_score, customer_rating
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      `, [
        distributorId, orderId, deliveryPersonId, deliveryStartTime,
        deliveryEndTime, durationMinutes, isOnTime,
        deliveryCost, distanceKm, efficiencyScore, customerRating
      ]);
    }

    res.json({
      success: true,
      message: 'Delivery analytics record created/updated successfully'
    });

  } catch (error) {
    console.error('Error creating delivery analytics:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create delivery analytics record',
      error: error.message
    });
  }
};

// Get delivery analytics for a specific order
const getOrderAnalytics = async (req, res) => {
  try {
    const { orderId } = req.params;

    const analytics = await db.query(`
      SELECT * FROM delivery_analytics 
      WHERE order_id = $1
    `, [orderId]);

    if (analytics.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'No analytics data found for this order'
      });
    }

    res.json({
      success: true,
      data: analytics.rows[0],
      message: 'Order analytics retrieved successfully'
    });

  } catch (error) {
    console.error('Error fetching order analytics:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch order analytics',
      error: error.message
    });
  }
};

module.exports = {
  getDeliveryPerformanceMetrics,
  createDeliveryAnalytics,
  getOrderAnalytics
};
