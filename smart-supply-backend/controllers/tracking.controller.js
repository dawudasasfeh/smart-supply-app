const pool = require('../db');

// Order Tracking Controller
class TrackingController {
  
  // Get order tracking information by order ID
  static async getOrderTracking(req, res) {
    try {
      const { orderId } = req.params;
      
      // Get basic order details first
      const orderQuery = `
        SELECT 
          o.*,
          u.name as customer_name,
          u.email as customer_email,
          u.phone as customer_phone
        FROM orders o
        LEFT JOIN users u ON o.buyer_id = u.id
        WHERE o.id = $1
      `;
      
      const orderResult = await pool.query(orderQuery, [orderId]);
      
      if (orderResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Order not found'
        });
      }
      
      const order = orderResult.rows[0];
      
      // Get tracking history
      const historyQuery = `
        SELECT 
          oth.*,
          u.name as updated_by_name
        FROM order_tracking_history oth
        LEFT JOIN users u ON oth.updated_by = u.id
        WHERE oth.order_id = $1
        ORDER BY oth.created_at ASC
      `;
      
      const historyResult = await pool.query(historyQuery, [orderId]);
      
      // Calculate delivery progress based on current status
      const progress = calculateDeliveryProgress(order.delivery_status || order.status, historyResult.rows);
      
      res.json({
        success: true,
        data: {
          order: {
            id: order.id,
            tracking_number: order.tracking_number,
            status: order.status,
            delivery_status: order.delivery_status || order.status,
            total_amount: order.total_amount,
            created_at: order.created_at,
            estimated_delivery_date: order.estimated_delivery_date,
            actual_delivery_date: order.actual_delivery_date,
            delivery_address: order.delivery_address,
            delivery_instructions: order.delivery_instructions,
            customer: {
              name: order.customer_name,
              email: order.customer_email,
              phone: order.customer_phone
            }
          },
          delivery: null, // Will be enhanced later when delivery tables are ready
          tracking_history: historyResult.rows,
          delivery_history: [], // Will be enhanced later
          progress: progress
        }
      });
      
    } catch (error) {
      console.error('Error getting order tracking:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get order tracking information',
        error: error.message
      });
    }
  }
  
  // Get tracking by tracking number
  static async getTrackingByNumber(req, res) {
    try {
      const { trackingNumber } = req.params;
      
      const orderQuery = `
        SELECT id FROM orders WHERE tracking_number = $1
      `;
      
      const result = await pool.query(orderQuery, [trackingNumber]);
      
      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Tracking number not found'
        });
      }
      
      // Redirect to order tracking
      req.params.orderId = result.rows[0].id;
      return TrackingController.getOrderTracking(req, res);
      
    } catch (error) {
      console.error('Error getting tracking by number:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get tracking information',
        error: error.message
      });
    }
  }
  
  // Update order tracking status
  static async updateTrackingStatus(req, res) {
    try {
      const { orderId } = req.params;
      const { 
        status, 
        location_lat, 
        location_lng, 
        location_address, 
        notes,
        updated_by 
      } = req.body;
      
      // Insert tracking history
      const historyQuery = `
        INSERT INTO order_tracking_history 
        (order_id, status, location_lat, location_lng, location_address, notes, updated_by)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING *
      `;
      
      const historyResult = await pool.query(historyQuery, [
        orderId, status, location_lat, location_lng, location_address, notes, updated_by
      ]);
      
      // Update order delivery status
      const updateOrderQuery = `
        UPDATE orders 
        SET delivery_status = $1, updated_at = CURRENT_TIMESTAMP
        WHERE id = $2
      `;
      
      await pool.query(updateOrderQuery, [status, orderId]);
      
      res.json({
        success: true,
        message: 'Tracking status updated successfully',
        data: historyResult.rows[0]
      });
      
    } catch (error) {
      console.error('Error updating tracking status:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update tracking status',
        error: error.message
      });
    }
  }
  
  // Update delivery location (real-time tracking)
  static async updateDeliveryLocation(req, res) {
    try {
      const { deliveryAssignmentId } = req.params;
      const { 
        latitude, 
        longitude, 
        accuracy, 
        speed, 
        heading, 
        altitude,
        battery_level,
        delivery_man_id 
      } = req.body;
      
      // Insert location tracking
      const locationQuery = `
        INSERT INTO delivery_location_tracking 
        (delivery_assignment_id, delivery_man_id, latitude, longitude, accuracy, speed, heading, altitude, battery_level)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING *
      `;
      
      const locationResult = await pool.query(locationQuery, [
        deliveryAssignmentId, delivery_man_id, latitude, longitude, 
        accuracy, speed, heading, altitude, battery_level
      ]);
      
      // Update delivery man current location
      const updateDeliveryManQuery = `
        UPDATE delivery_men 
        SET current_location_lat = $1, 
            current_location_lng = $2, 
            last_location_update = CURRENT_TIMESTAMP
        WHERE user_id = $3
      `;
      
      await pool.query(updateDeliveryManQuery, [latitude, longitude, delivery_man_id]);
      
      res.json({
        success: true,
        message: 'Location updated successfully',
        data: locationResult.rows[0]
      });
      
    } catch (error) {
      console.error('Error updating delivery location:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update delivery location',
        error: error.message
      });
    }
  }
  
  // Get delivery man's current deliveries
  static async getDeliveryManOrders(req, res) {
    try {
      const { deliveryManId } = req.params;
      
      const query = `
        SELECT 
          o.id,
          o.tracking_number,
          o.total_amount,
          o.delivery_address,
          o.delivery_instructions,
          o.delivery_lat,
          o.delivery_lng,
          da.id as assignment_id,
          da.status,
          da.estimated_pickup_time,
          da.estimated_delivery_time,
          da.pickup_address,
          da.delivery_address as assignment_delivery_address,
          da.distance_km,
          u.name as customer_name,
          u.phone as customer_phone
        FROM delivery_assignments da
        JOIN orders o ON da.order_id = o.id
        JOIN users u ON o.buyer_id = u.id
        WHERE da.delivery_man_id = $1 
        AND da.status IN ('assigned', 'picked_up', 'in_transit')
        ORDER BY da.estimated_delivery_time ASC
      `;
      
      const result = await pool.query(query, [deliveryManId]);
      
      res.json({
        success: true,
        data: result.rows
      });
      
    } catch (error) {
      console.error('Error getting delivery man orders:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get delivery orders',
        error: error.message
      });
    }
  }
  
  // Get recent orders for quick tracking (filtered by distributor)
  static async getRecentOrders(req, res) {
    try {
      const { limit = 10, distributorId } = req.query;
      
      // Check which column exists for distributor relationship
      const columnCheckQuery = `
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name IN ('distributor_id', 'seller_id')
      `;
      
      const columnCheck = await pool.query(columnCheckQuery);
      const hasDistributorIdColumn = columnCheck.rows.some(row => row.column_name === 'distributor_id');
      const hasSellerIdColumn = columnCheck.rows.some(row => row.column_name === 'seller_id');
      
      let recentOrdersQuery;
      let queryParams;
      
      if (distributorId) {
        if (hasDistributorIdColumn) {
          // Use distributor_id for distributor filtering
          recentOrdersQuery = `
            SELECT 
              o.id,
              o.tracking_number,
              o.status,
              o.delivery_status,
              o.total_amount,
              o.created_at,
              u.name as customer_name,
              u.phone as customer_phone
            FROM orders o
            LEFT JOIN users u ON o.buyer_id = u.id
            WHERE o.tracking_number IS NOT NULL 
              AND o.distributor_id = $1
            ORDER BY o.created_at DESC
            LIMIT $2
          `;
          queryParams = [distributorId, limit];
        } else if (hasSellerIdColumn) {
          // Use seller_id for distributor filtering
          recentOrdersQuery = `
            SELECT 
              o.id,
              o.tracking_number,
              o.status,
              o.delivery_status,
              o.total_amount,
              o.created_at,
              u.name as customer_name,
              u.phone as customer_phone
            FROM orders o
            LEFT JOIN users u ON o.buyer_id = u.id
            WHERE o.tracking_number IS NOT NULL 
              AND o.seller_id = $1
            ORDER BY o.created_at DESC
            LIMIT $2
          `;
          queryParams = [distributorId, limit];
        } else {
          // Fallback to buyer_id if neither exists
          recentOrdersQuery = `
            SELECT 
              o.id,
              o.tracking_number,
              o.status,
              o.delivery_status,
              o.total_amount,
              o.created_at,
              u.name as customer_name,
              u.phone as customer_phone
            FROM orders o
            LEFT JOIN users u ON o.buyer_id = u.id
            WHERE o.tracking_number IS NOT NULL 
              AND o.buyer_id = $1
            ORDER BY o.created_at DESC
            LIMIT $2
          `;
          queryParams = [distributorId, limit];
        }
      } else {
        // No distributor filtering - return all orders
        recentOrdersQuery = `
          SELECT 
            o.id,
            o.tracking_number,
            o.status,
            o.delivery_status,
            o.total_amount,
            o.created_at,
            u.name as customer_name,
            u.phone as customer_phone
          FROM orders o
          LEFT JOIN users u ON o.buyer_id = u.id
          WHERE o.tracking_number IS NOT NULL
          ORDER BY o.created_at DESC
          LIMIT $1
        `;
        queryParams = [limit];
      }
      
      const result = await pool.query(recentOrdersQuery, queryParams);
      
      res.json({
        success: true,
        data: result.rows
      });
      
    } catch (error) {
      console.error('Error getting recent orders:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get recent orders',
        error: error.message
      });
    }
  }

  // Get delivery analytics
  static async getDeliveryAnalytics(req, res) {
    try {
      const { timeframe = '7' } = req.query; // days
      
      const analyticsQuery = `
        SELECT 
          COUNT(*) as total_deliveries,
          COUNT(CASE WHEN da.status = 'delivered' THEN 1 END) as completed_deliveries,
          COUNT(CASE WHEN da.status IN ('assigned', 'picked_up', 'in_transit') THEN 1 END) as active_deliveries,
          AVG(CASE WHEN da.actual_delivery_time IS NOT NULL AND da.actual_pickup_time IS NOT NULL 
              THEN EXTRACT(EPOCH FROM (da.actual_delivery_time - da.actual_pickup_time))/3600 END) as avg_delivery_time_hours,
          AVG(da.distance_km) as avg_distance_km,
          SUM(da.delivery_fee) as total_delivery_fees,
          COUNT(CASE WHEN da.actual_delivery_time <= da.estimated_delivery_time THEN 1 END) * 100.0 / 
            NULLIF(COUNT(CASE WHEN da.status = 'delivered' THEN 1 END), 0) as on_time_percentage
        FROM delivery_assignments da
        WHERE da.created_at >= CURRENT_DATE - INTERVAL '$1 days'
      `;
      
      const result = await pool.query(analyticsQuery, [timeframe]);
      
      // Get top performing delivery men
      const topPerformersQuery = `
        SELECT 
          u.name,
          dm.rating,
          COUNT(da.id) as total_assignments,
          COUNT(CASE WHEN da.status = 'delivered' THEN 1 END) as completed_assignments,
          AVG(CASE WHEN da.actual_delivery_time IS NOT NULL AND da.actual_pickup_time IS NOT NULL 
              THEN EXTRACT(EPOCH FROM (da.actual_delivery_time - da.actual_pickup_time))/3600 END) as avg_delivery_time
        FROM delivery_men dm
        JOIN users u ON dm.user_id = u.id
        LEFT JOIN delivery_assignments da ON dm.user_id = da.delivery_man_id 
          AND da.created_at >= CURRENT_DATE - INTERVAL '$1 days'
        GROUP BY u.id, u.name, dm.rating
        ORDER BY dm.rating DESC, completed_assignments DESC
        LIMIT 5
      `;
      
      const topPerformersResult = await pool.query(topPerformersQuery, [timeframe]);
      
      res.json({
        success: true,
        data: {
          overview: result.rows[0],
          top_performers: topPerformersResult.rows,
          timeframe: `${timeframe} days`
        }
      });
      
    } catch (error) {
      console.error('Error getting delivery analytics:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get delivery analytics',
        error: error.message
      });
    }
  }
}

// Helper function to calculate delivery progress
function calculateDeliveryProgress(status, trackingHistory) {
  const statusSteps = [
    'pending',
    'confirmed',
    'processing',
    'ready_for_pickup',
    'assigned',
    'picked_up',
    'in_transit',
    'out_for_delivery',
    'delivered'
  ];
  
  let currentStep = 0;
  let completedSteps = [];
  
  // Find current step based on status
  const statusIndex = statusSteps.indexOf(status);
  if (statusIndex !== -1) {
    currentStep = statusIndex;
    completedSteps = statusSteps.slice(0, statusIndex + 1);
  } else {
    // Default to first step if status not found
    currentStep = 0;
    completedSteps = [statusSteps[0]];
  }
  
  // Calculate percentage
  const percentage = Math.round((currentStep / (statusSteps.length - 1)) * 100);
  
  return {
    current_step: currentStep,
    total_steps: statusSteps.length,
    percentage: percentage,
    status: status,
    completed_steps: completedSteps,
    next_step: statusIndex < statusSteps.length - 1 ? statusSteps[statusIndex + 1] : null
  };
}

module.exports = TrackingController;
