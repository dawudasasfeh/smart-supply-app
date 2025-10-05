const routeOptimizationService = require('../services/routeOptimizationService');
const pool = require('../db');

/**
 * Create a new route optimization session
 */
const createOptimizationSession = async (req, res) => {
  try {
    const { sessionName, deliveryManId, distributorId, algorithm } = req.body;
    const userId = req.user.id;

    // Validate required fields
    if (!sessionName || !deliveryManId || !distributorId) {
      return res.status(400).json({
        success: false,
        error: 'Session name, delivery man ID, and distributor ID are required'
      });
    }

    // Check if user has permission to create session
    // Allow delivery men to create sessions for their own routes
    if (req.user.role !== 'distributor' && req.user.role !== 'admin' && req.user.role !== 'delivery') {
      return res.status(403).json({
        success: false,
        error: 'Insufficient permissions'
      });
    }
    
    // If user is delivery, ensure they can only create sessions for themselves
    if (req.user.role === 'delivery') {
      // Get the delivery man ID for this user
      const deliveryManResult = await pool.query(
        'SELECT id FROM delivery_men WHERE user_id = $1',
        [req.user.id]
      );
      
      if (deliveryManResult.rows.length === 0) {
        return res.status(403).json({
          success: false,
          error: 'Delivery man profile not found'
        });
      }
      
      const userDeliveryManId = deliveryManResult.rows[0].id;
      if (deliveryManId !== userDeliveryManId) {
        return res.status(403).json({
          success: false,
          error: 'Delivery men can only create sessions for themselves'
        });
      }
    }

    const session = await routeOptimizationService.createOptimizationSession({
      sessionName,
      deliveryManId,
      distributorId,
      algorithm
    });

    res.status(201).json({
      success: true,
      data: session,
      message: 'Route optimization session created successfully'
    });
  } catch (error) {
    console.error('Error creating optimization session:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create optimization session'
    });
  }
};

/**
 * Get orders for route optimization
 */
const getOrdersForOptimization = async (req, res) => {
  try {
    const { deliveryManId, distributorId } = req.params;
    const userId = req.user.id;

    // Validate permissions
    if (req.user.role === 'delivery') {
      // Get the delivery man ID for this user
      const deliveryManResult = await pool.query(
        'SELECT id FROM delivery_men WHERE user_id = $1',
        [userId]
      );
      
      if (deliveryManResult.rows.length === 0) {
        return res.status(403).json({
          success: false,
          error: 'Delivery man profile not found'
        });
      }
      
      const userDeliveryManId = deliveryManResult.rows[0].id;
      if (parseInt(deliveryManId) !== userDeliveryManId) {
        return res.status(403).json({
          success: false,
          error: 'Delivery men can only access their own orders'
        });
      }
    }

    const orders = await routeOptimizationService.getOrdersForOptimization(
      parseInt(deliveryManId),
      req.user.role === 'delivery' ? null : parseInt(distributorId)
    );

    res.json({
      success: true,
      data: orders,
      count: orders.length
    });
  } catch (error) {
    console.error('Error getting orders for optimization:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get orders for optimization'
    });
  }
};

/**
 * Optimize route for a delivery man
 */
const optimizeRoute = async (req, res) => {
  try {
    const { sessionId, deliveryManId, distributorId, algorithm = 'nearest_neighbor' } = req.body;
    const userId = req.user.id;

    // Validate permissions
    if (req.user.role === 'delivery') {
      // Get the delivery man ID for this user
      const deliveryManResult = await pool.query(
        'SELECT id FROM delivery_men WHERE user_id = $1',
        [userId]
      );
      
      if (deliveryManResult.rows.length === 0) {
        return res.status(403).json({
          success: false,
          error: 'Delivery man profile not found'
        });
      }
      
      const userDeliveryManId = deliveryManResult.rows[0].id;
      if (parseInt(deliveryManId) !== userDeliveryManId) {
        return res.status(403).json({
          success: false,
          error: 'Delivery men can only optimize their own routes'
        });
      }
    }

    // Get orders for optimization
    const orders = await routeOptimizationService.getOrdersForOptimization(
      parseInt(deliveryManId),
      parseInt(distributorId)
    );

    if (orders.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No orders found for optimization'
      });
    }

    // Get delivery man's starting location
    const startLocation = await routeOptimizationService.getDeliveryManLocation(
      parseInt(deliveryManId)
    );

    // Update session status to optimizing
    await pool.query(
      `UPDATE route_optimization_sessions 
       SET status = 'optimizing', started_at = CURRENT_TIMESTAMP 
       WHERE id = $1`,
      [sessionId]
    );

    // Perform route optimization
    let optimizationResults;
    switch (algorithm) {
      case 'nearest_neighbor':
        optimizationResults = await routeOptimizationService.optimizeRouteNearestNeighbor(
          orders,
          startLocation
        );
        break;
      default:
        optimizationResults = await routeOptimizationService.optimizeRouteNearestNeighbor(
          orders,
          startLocation
        );
    }

    // Save results to database
    await routeOptimizationService.saveOptimizationResults(sessionId, optimizationResults);

    // Generate Google Maps URL
    const googleMapsUrl = routeOptimizationService.generateGoogleMapsUrl(
      optimizationResults.optimizedRoute
    );

    res.json({
      success: true,
      data: {
        sessionId,
        optimizationResults,
        googleMapsUrl,
        ordersCount: orders.length,
        message: 'Route optimized successfully'
      }
    });
  } catch (error) {
    console.error('Error optimizing route:', error);
    
    // Update session status to failed
    if (req.body.sessionId) {
      try {
        await pool.query(
          `UPDATE route_optimization_sessions 
           SET status = 'failed', notes = $1 
           WHERE id = $2`,
          [error.message, req.body.sessionId]
        );
      } catch (updateError) {
        console.error('Error updating session status:', updateError);
      }
    }

    res.status(500).json({
      success: false,
      error: 'Failed to optimize route'
    });
  }
};

/**
 * Get optimization session details
 */
const getOptimizationSession = async (req, res) => {
  try {
    const { sessionId } = req.params;
    const userId = req.user.id;

    const sessionData = await routeOptimizationService.getOptimizationSession(
      parseInt(sessionId)
    );

    // Check permissions
    const session = sessionData.session;
    if (req.user.role === 'delivery') {
      // Get the delivery man ID for this user
      const deliveryManResult = await pool.query(
        'SELECT id FROM delivery_men WHERE user_id = $1',
        [userId]
      );
      
      if (deliveryManResult.rows.length === 0) {
        return res.status(403).json({
          success: false,
          error: 'Delivery man profile not found'
        });
      }
      
      const userDeliveryManId = deliveryManResult.rows[0].id;
      if (session.delivery_man_id !== userDeliveryManId) {
        return res.status(403).json({
          success: false,
          error: 'Delivery men can only access their own session results'
        });
      }
    }

    if (req.user.role === 'distributor' && session.distributor_id !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Insufficient permissions'
      });
    }

    // Generate Google Maps URL
    const googleMapsUrl = routeOptimizationService.generateGoogleMapsUrl(
      sessionData.waypoints
    );

    res.json({
      success: true,
      data: {
        ...sessionData,
        googleMapsUrl
      }
    });
  } catch (error) {
    console.error('Error getting optimization session:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get optimization session'
    });
  }
};

/**
 * Get all optimization sessions for a user
 */
const getOptimizationSessions = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const { page = 1, limit = 10, status } = req.query;

    let query = `
      SELECT 
        ros.*,
        dm.name as delivery_man_name,
        u2.name as distributor_name
      FROM route_optimization_sessions ros
      JOIN delivery_men dm ON ros.delivery_man_id = dm.id
      JOIN users u2 ON ros.distributor_id = u2.id
      WHERE 1=1
    `;
    const queryParams = [];
    let paramCount = 0;

    // Add role-based filtering
    if (userRole === 'delivery') {
      // Get the delivery man ID for this user
      const deliveryManResult = await pool.query(
        'SELECT id FROM delivery_men WHERE user_id = $1',
        [userId]
      );
      
      if (deliveryManResult.rows.length > 0) {
        query += ` AND ros.delivery_man_id = $${++paramCount}`;
        queryParams.push(deliveryManResult.rows[0].id);
      } else {
        // If no delivery man profile found, return empty result
        query += ` AND 1=0`;
      }
    } else if (userRole === 'distributor') {
      query += ` AND ros.distributor_id = $${++paramCount}`;
      queryParams.push(userId);
    }

    // Add status filtering
    if (status) {
      query += ` AND ros.status = $${++paramCount}`;
      queryParams.push(status);
    }

    query += ` ORDER BY ros.created_at DESC`;

    // Add pagination
    const offset = (parseInt(page) - 1) * parseInt(limit);
    query += ` LIMIT $${++paramCount} OFFSET $${++paramCount}`;
    queryParams.push(parseInt(limit), offset);

    const result = await pool.query(query, queryParams);

    // Get total count
    let countQuery = `
      SELECT COUNT(*) as total
      FROM route_optimization_sessions ros
      WHERE 1=1
    `;
    const countParams = [];
    let countParamCount = 0;

    if (userRole === 'delivery') {
      // Get the delivery man ID for this user
      const deliveryManResult = await pool.query(
        'SELECT id FROM delivery_men WHERE user_id = $1',
        [userId]
      );
      
      if (deliveryManResult.rows.length > 0) {
        countQuery += ` AND ros.delivery_man_id = $${++countParamCount}`;
        countParams.push(deliveryManResult.rows[0].id);
      } else {
        // If no delivery man profile found, return empty result
        countQuery += ` AND 1=0`;
      }
    } else if (userRole === 'distributor') {
      countQuery += ` AND ros.distributor_id = $${++countParamCount}`;
      countParams.push(userId);
    }

    if (status) {
      countQuery += ` AND ros.status = $${++countParamCount}`;
      countParams.push(status);
    }

    const countResult = await pool.query(countQuery, countParams);
    const total = parseInt(countResult.rows[0].total);

    res.json({
      success: true,
      data: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error getting optimization sessions:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get optimization sessions'
    });
  }
};

/**
 * Delete optimization session
 */
const deleteOptimizationSession = async (req, res) => {
  try {
    const { sessionId } = req.params;
    const userId = req.user.id;
    const userRole = req.user.role;

    // Check permissions
    const sessionResult = await pool.query(
      `SELECT * FROM route_optimization_sessions WHERE id = $1`,
      [sessionId]
    );

    if (sessionResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Session not found'
      });
    }

    const session = sessionResult.rows[0];
    if (userRole === 'delivery') {
      // Get the delivery man ID for this user
      const deliveryManResult = await pool.query(
        'SELECT id FROM delivery_men WHERE user_id = $1',
        [userId]
      );
      
      if (deliveryManResult.rows.length === 0 || session.delivery_man_id !== deliveryManResult.rows[0].id) {
        return res.status(403).json({
          success: false,
          error: 'Insufficient permissions'
        });
      }
    }

    if (userRole === 'distributor' && session.distributor_id !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Insufficient permissions'
      });
    }

    // Delete session (cascade will handle related records)
    await pool.query(
      `DELETE FROM route_optimization_sessions WHERE id = $1`,
      [sessionId]
    );

    res.json({
      success: true,
      message: 'Optimization session deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting optimization session:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete optimization session'
    });
  }
};

/**
 * Get route optimization analytics
 */
const getOptimizationAnalytics = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const { period = '30' } = req.query; // days

    let whereClause = `WHERE ros.created_at >= CURRENT_DATE - INTERVAL '${period} days'`;
    const queryParams = [];
    let paramCount = 0;

    if (userRole === 'delivery') {
      // Get the delivery man ID for this user
      const deliveryManResult = await pool.query(
        'SELECT id FROM delivery_men WHERE user_id = $1',
        [userId]
      );
      
      if (deliveryManResult.rows.length > 0) {
        whereClause += ` AND ros.delivery_man_id = $${++paramCount}`;
        queryParams.push(deliveryManResult.rows[0].id);
      } else {
        // If no delivery man profile found, return empty result
        whereClause += ` AND 1=0`;
      }
    } else if (userRole === 'distributor') {
      whereClause += ` AND ros.distributor_id = $${++paramCount}`;
      queryParams.push(userId);
    }

    // Get analytics data
    const analyticsQuery = `
      SELECT 
        COUNT(*) as total_sessions,
        AVG(total_distance_km) as avg_distance,
        AVG(total_duration_minutes) as avg_duration,
        AVG(fuel_cost) as avg_fuel_cost,
        AVG(optimization_score) as avg_score,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_sessions,
        COUNT(*) FILTER (WHERE status = 'failed') as failed_sessions
      FROM route_optimization_sessions ros
      ${whereClause}
    `;

    const analyticsResult = await pool.query(analyticsQuery, queryParams);
    const analytics = analyticsResult.rows[0];

    // Get recent sessions
    const recentSessionsQuery = `
      SELECT 
        ros.*,
        dm.name as delivery_man_name,
        u2.name as distributor_name
      FROM route_optimization_sessions ros
      JOIN delivery_men dm ON ros.delivery_man_id = dm.id
      JOIN users u2 ON ros.distributor_id = u2.id
      ${whereClause}
      ORDER BY ros.created_at DESC
      LIMIT 5
    `;

    const recentSessionsResult = await pool.query(recentSessionsQuery, queryParams);

    res.json({
      success: true,
      data: {
        analytics,
        recentSessions: recentSessionsResult.rows
      }
    });
  } catch (error) {
    console.error('Error getting optimization analytics:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get optimization analytics'
    });
  }
};

module.exports = {
  createOptimizationSession,
  getOrdersForOptimization,
  optimizeRoute,
  getOptimizationSession,
  getOptimizationSessions,
  deleteOptimizationSession,
  getOptimizationAnalytics
};
