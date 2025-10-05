const express = require('express');
const router = express.Router();
const pool = require('../db');

// ============================================================================
// DELIVERY MANAGEMENT SYSTEM - BUILT FROM SCRATCH
// ============================================================================

// Get all delivery men
router.get('/men', async (req, res) => {
  try {
    console.log('📋 Fetching delivery men...');
    
    const result = await pool.query(`
      SELECT 
        dm.id,
        dm.user_id,
        dm.name,
        u.phone,
        u.email,
        COALESCE(dm.vehicle_type, 'motorcycle') AS vehicle_type,
        COALESCE(dm.is_online, true) AS is_available,
        dm.is_active,
        COALESCE(dm.rating, 4.5) AS rating,
        CASE 
          WHEN COALESCE(dm.is_online, false) = false THEN 'offline'
          WHEN COALESCE(dm.is_online, true) = false THEN 'off_duty'
          WHEN COALESCE(dm.is_online, true) = true THEN 'available'
          ELSE 'available'
        END AS status
      FROM delivery_men dm
      JOIN users u ON dm.user_id = u.id
      WHERE dm.is_active = true
      ORDER BY dm.name ASC
    `);

    console.log(`✅ Found ${result.rows.length} delivery men`);

    res.json({
      success: true,
      deliveryMen: result.rows,
      delivery_men: result.rows,
      count: result.rows.length
    });

  } catch (error) {
    console.error('❌ Error fetching delivery men:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch delivery men'
    });
  }
});

// Get pending orders (orders without delivery assignments)
router.get('/pending', async (req, res) => {
  try {
    const { distributorId } = req.query;
    console.log(`📋 Fetching pending orders${distributorId ? ` for distributor ${distributorId}` : ''}...`);
    
    let query = `
      SELECT 
        o.id,
        o.buyer_id,
        o.status,
        o.total_amount,
        o.delivery_address,
        o.created_at,
        u.name as customer_name,
        u.phone as customer_phone,
        u.email as customer_email
      FROM orders o
      JOIN users u ON o.buyer_id = u.id
      WHERE o.status = 'pending' 
    `;
    
    const queryParams = [];
    
    // Add distributor filter if provided
    if (distributorId) {
      // Check if distributor_id column exists, fallback to seller_id or buyer_id
      const columnCheck = await pool.query(`
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name IN ('distributor_id', 'seller_id')
      `);
      
      const hasDistributorIdColumn = columnCheck.rows.some(row => row.column_name === 'distributor_id');
      const hasSellerIdColumn = columnCheck.rows.some(row => row.column_name === 'seller_id');
      
      if (hasDistributorIdColumn) {
        query += ` AND o.distributor_id = $1`;
        queryParams.push(distributorId);
      } else if (hasSellerIdColumn) {
        query += ` AND o.seller_id = $1`;
        queryParams.push(distributorId);
      } else {
        query += ` AND o.buyer_id = $1`;
        queryParams.push(distributorId);
      }
    }
    
    query += ` ORDER BY o.created_at ASC`;
    
    const result = await pool.query(query, queryParams);

    console.log(`✅ Found ${result.rows.length} pending orders${distributorId ? ` for distributor ${distributorId}` : ''}`);

    res.json({
      success: true,
      data: result.rows,
      orders: result.rows,
      count: result.rows.length
    });

  } catch (error) {
    console.error('❌ Error fetching pending orders:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch pending orders'
    });
  }
});

// Get active deliveries
router.get('/active', async (req, res) => {
  try {
    const { distributorId } = req.query;
    console.log(`📋 Fetching active deliveries${distributorId ? ` for distributor ${distributorId}` : ''}...`);
    
    let query = `
      SELECT 
        o.id,
        o.buyer_id,
        o.status,
        o.total_amount,
        o.delivery_address,
        o.created_at,
        da.id as assignment_id,
        da.delivery_man_id,
        da.assigned_at,
        da.status as assignment_status,
        dm.name as delivery_man_name,
        du.phone as delivery_man_phone,
        dm.vehicle_type,
        u.name as customer_name,
        u.phone as customer_phone
      FROM orders o
      LEFT JOIN delivery_assignments da ON o.id = da.order_id
      LEFT JOIN delivery_men dm ON da.delivery_man_id = dm.id
      LEFT JOIN users du ON dm.user_id = du.id
      JOIN users u ON o.buyer_id = u.id
      WHERE o.status = 'accepted'
    `;
    
    const queryParams = [];
    
    // Add distributor filter if provided
    if (distributorId) {
      // Check if distributor_id column exists, fallback to seller_id or buyer_id
      const columnCheck = await pool.query(`
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name IN ('distributor_id', 'seller_id')
      `);
      
      const hasDistributorIdColumn = columnCheck.rows.some(row => row.column_name === 'distributor_id');
      const hasSellerIdColumn = columnCheck.rows.some(row => row.column_name === 'seller_id');
      
      if (hasDistributorIdColumn) {
        query += ` AND o.distributor_id = $1`;
        queryParams.push(distributorId);
      } else if (hasSellerIdColumn) {
        query += ` AND o.seller_id = $1`;
        queryParams.push(distributorId);
      } else {
        query += ` AND o.buyer_id = $1`;
        queryParams.push(distributorId);
      }
    }
    
    query += ` ORDER BY da.assigned_at DESC`;
    
    const result = await pool.query(query, queryParams);

    console.log(`✅ Found ${result.rows.length} active deliveries${distributorId ? ` for distributor ${distributorId}` : ''}`);

    res.json({
      success: true,
      data: result.rows,
      deliveries: result.rows,
      count: result.rows.length
    });

  } catch (error) {
    console.error('❌ Error fetching active deliveries:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch active deliveries'
    });
  }
});

// Get completed deliveries
router.get('/completed', async (req, res) => {
  try {
    const { distributorId } = req.query;
    console.log(`📋 Fetching completed deliveries${distributorId ? ` for distributor ${distributorId}` : ''}...`);
    
    let query = `
      SELECT 
        o.id,
        o.buyer_id,
        o.status,
        o.total_amount,
        o.delivery_address,
        o.created_at,
        da.id as assignment_id,
        da.delivery_man_id,
        da.assigned_at,
        da.status as assignment_status,
        dm.name as delivery_man_name,
        du.phone as delivery_man_phone,
        u.name as customer_name,
        u.phone as customer_phone
      FROM orders o
      LEFT JOIN delivery_assignments da ON o.id = da.order_id
      LEFT JOIN delivery_men dm ON da.delivery_man_id = dm.id
      LEFT JOIN users du ON dm.user_id = du.id
      JOIN users u ON o.buyer_id = u.id
      WHERE o.status = 'delivered'
    `;
    
    const queryParams = [];
    
    // Add distributor filter if provided
    if (distributorId) {
      // Check if distributor_id column exists, fallback to seller_id or buyer_id
      const columnCheck = await pool.query(`
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name IN ('distributor_id', 'seller_id')
      `);
      
      const hasDistributorIdColumn = columnCheck.rows.some(row => row.column_name === 'distributor_id');
      const hasSellerIdColumn = columnCheck.rows.some(row => row.column_name === 'seller_id');
      
      if (hasDistributorIdColumn) {
        query += ` AND o.distributor_id = $1`;
        queryParams.push(distributorId);
      } else if (hasSellerIdColumn) {
        query += ` AND o.seller_id = $1`;
        queryParams.push(distributorId);
      } else {
        query += ` AND o.buyer_id = $1`;
        queryParams.push(distributorId);
      }
    }
    
    query += ` ORDER BY da.assigned_at DESC LIMIT 50`;
    
    const result = await pool.query(query, queryParams);

    console.log(`✅ Found ${result.rows.length} completed deliveries${distributorId ? ` for distributor ${distributorId}` : ''}`);

    res.json({
      success: true,
      data: result.rows,
      deliveries: result.rows,
      count: result.rows.length
    });

  } catch (error) {
    console.error('❌ Error fetching completed deliveries:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch completed deliveries'
    });
  }
});

// Assign order to delivery man
router.post('/assign', async (req, res) => {
  const { order_id, delivery_man_id, priority = 'medium' } = req.body;
  
  console.log(`📦 Assigning order ${order_id} to delivery man ${delivery_man_id}`);
  
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Check if order exists and is assignable
    const orderCheck = await client.query(
      'SELECT id, status FROM orders WHERE id = $1',
      [order_id]
    );

    if (orderCheck.rows.length === 0) {
      throw new Error('Order not found');
    }

    const order = orderCheck.rows[0];
    if (!['pending'].includes(order.status)) {
      throw new Error(`Order cannot be assigned. Current status: ${order.status}`);
    }

    // Check if delivery man exists and is available
    const deliveryManCheck = await client.query(
      'SELECT id, name, is_online FROM delivery_men WHERE id = $1 AND is_active = true',
      [delivery_man_id]
    );

    if (deliveryManCheck.rows.length === 0) {
      throw new Error('Delivery man not found or inactive');
    }

    const deliveryMan = deliveryManCheck.rows[0];
    if (!deliveryMan.is_online) {
      console.log('⚠️ Delivery man is offline but assignment will proceed');
    }

    // Create delivery assignment
    const assignmentResult = await client.query(`
      INSERT INTO delivery_assignments 
      (order_id, delivery_man_id, assigned_at, status, priority, created_at, updated_at)
      VALUES ($1, $2, NOW(), 'assigned', $3, NOW(), NOW())
      RETURNING id
    `, [order_id, delivery_man_id, priority]);

    const assignmentId = assignmentResult.rows[0].id;

    // Create initial delivery analytics data for assigned orders
    try {
      const orderResult = await client.query(
        `SELECT distributor_id FROM orders WHERE id = $1`,
        [order_id]
      );

      if (orderResult.rows.length > 0) {
        const distributorId = orderResult.rows[0].distributor_id;
        
        await client.query(`
          INSERT INTO delivery_analytics 
          (distributor_id, order_id, delivery_man_id, status, priority, created_at, updated_at)
          VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
          ON CONFLICT (order_id) 
          DO UPDATE SET 
            delivery_man_id = EXCLUDED.delivery_man_id,
            status = EXCLUDED.status,
            priority = EXCLUDED.priority,
            updated_at = NOW()
        `, [
          distributorId,
          order_id,
          delivery_man_id,
          'assigned',
          priority
        ]);
        
        console.log(`📊 Analytics data created for assigned order ${order_id}`);
      }
    } catch (analyticsError) {
      console.warn('Failed to create analytics data for assigned order:', analyticsError);
    }

    // Update order status
    await client.query(
      'UPDATE orders SET status = $1, updated_at = NOW() WHERE id = $2',
      ['assigned', order_id]
    );

    // Add status history entry
    await client.query(`
      INSERT INTO delivery_status_history 
      (assignment_id, status, location_name, notes, created_at, created_by)
      VALUES ($1, $2, $3, $4, NOW(), $5)
    `, [assignmentId, 'assigned', 'Distribution Center', 'Order assigned to delivery man', 'system']);

    await client.query('COMMIT');

    console.log(`✅ Order ${order_id} successfully assigned to ${deliveryMan.name}`);

    // Emit Socket.IO event for real-time updates
    const io = req.app.get('io');
    if (io) {
      io.emit('delivery_assigned', {
        order_id: order_id,
        delivery_man_id: delivery_man_id,
        delivery_man_name: deliveryMan.name,
        customer_name: order.customer_name || 'Customer',
        delivery_address: order.delivery_address || 'Address not specified',
        priority: priority,
        timestamp: new Date().toISOString()
      });
    }

    res.json({
      success: true,
      message: `Order assigned to ${deliveryMan.name}`,
      assignment_id: assignmentId,
      delivery_man_name: deliveryMan.name
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error assigning order:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to assign order'
    });
  } finally {
    client.release();
  }
});

// Get delivery analytics
router.get('/analytics', async (req, res) => {
  try {
    console.log('📊 Fetching delivery analytics...');
    
    const result = await pool.query(`
      SELECT 
        COUNT(da.id) as total_assignments,
        COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as total_deliveries,
        COUNT(CASE WHEN o.status IN ('assigned', 'shipped', 'in_transit') THEN 1 END) as active_deliveries,
        COUNT(CASE WHEN o.status = 'pending' THEN 1 END) as pending_orders
      FROM delivery_assignments da
      RIGHT JOIN orders o ON da.order_id = o.id
      WHERE o.created_at >= CURRENT_DATE - INTERVAL '30 days'
    `);

    const analytics = result.rows[0] || {
      total_assignments: 0,
      total_deliveries: 0,
      active_deliveries: 0,
      pending_orders: 0
    };

    // Add default values for missing metrics
    const fullAnalytics = {
      ...analytics,
      completed_today: 0,
      average_delivery_time: 30,
      on_time_rate: 0.85,
      efficiency_score: 0.80,
      average_rating: 4.2
    };

    console.log('✅ Analytics fetched successfully');

    res.json({
      success: true,
      analytics: fullAnalytics
    });

  } catch (error) {
    console.error('❌ Error fetching analytics:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch analytics'
    });
  }
});

// Get delivery history for an order
router.get('/history/:orderId', async (req, res) => {
  try {
    const { orderId } = req.params;
    console.log(`📋 Fetching delivery history for order ${orderId}`);
    
    const result = await pool.query(`
      SELECT 
        dsh.id,
        dsh.assignment_id,
        dsh.status,
        dsh.location_name,
        dsh.latitude,
        dsh.longitude,
        dsh.notes,
        dsh.created_at,
        dsh.created_by,
        da.order_id
      FROM delivery_status_history dsh
      JOIN delivery_assignments da ON dsh.assignment_id = da.id
      WHERE da.order_id = $1
      ORDER BY dsh.created_at ASC
    `, [orderId]);

    console.log(`✅ Found ${result.rows.length} history entries for order ${orderId}`);

    res.json({
      success: true,
      history: result.rows,
      count: result.rows.length
    });

  } catch (error) {
    console.error('❌ Error fetching delivery history:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch delivery history'
    });
  }
});

const AssignmentService = require('../services/assignmentService');

// Smart assignment using advanced AI algorithm
router.post('/smart-assign', async (req, res) => {
  try {
    const distributorId = req.user?.id || req.body.distributorId || 4; // Default to distributor 4 for testing
    console.log('🤖 Starting AI-powered smart assignment for distributor:', distributorId);
    
    const result = await AssignmentService.performAutoAssignment(distributorId);
    
    console.log(`✅ Smart assignment completed: ${result.statistics?.assignedOrders || 0} orders assigned`);

    res.json({
      success: result.success,
      message: result.message,
      assignments: result.assignments || [],
      count: result.statistics?.assignedOrders || 0,
      statistics: result.statistics || {},
      algorithm: 'AI-powered geographic and workload optimization'
    });

  } catch (error) {
    console.error('❌ Error in smart assignment:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Smart assignment failed'
    });
  }
});

// Get assignment analytics
router.get('/assignment-analytics', async (req, res) => {
  try {
    const distributorId = req.user?.id || 4;
    const days = parseInt(req.query.days) || 7;
    
    console.log(`📊 Fetching assignment analytics for distributor ${distributorId}, last ${days} days`);
    
    const analytics = await AssignmentService.getAssignmentAnalytics(distributorId, days);
    
    res.json({
      success: true,
      data: analytics,
      message: 'Assignment analytics retrieved successfully'
    });
    
  } catch (error) {
    console.error('❌ Error fetching assignment analytics:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch assignment analytics'
    });
  }
});

// Get assignment status
router.get('/assignment-status', async (req, res) => {
  try {
    const distributorId = req.user?.id || 4;
    
    console.log(`📋 Fetching assignment status for distributor ${distributorId}`);
    
    const status = await AssignmentService.getAssignmentStatus(distributorId);
    
    res.json({
      success: true,
      data: status,
      message: 'Assignment status retrieved successfully'
    });
    
  } catch (error) {
    console.error('❌ Error fetching assignment status:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch assignment status'
    });
  }
});

// Update delivery status
router.post('/update-status', async (req, res) => {
  const { order_id, status, latitude, longitude, notes = '', location_name = '' } = req.body;
  
  console.log(`📦 Updating delivery status for order ${order_id} to ${status}`);
  
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Get assignment info
    const assignmentResult = await client.query(
      'SELECT id, delivery_man_id FROM delivery_assignments WHERE order_id = $1',
      [order_id]
    );

    if (assignmentResult.rows.length === 0) {
      throw new Error('Delivery assignment not found');
    }

    const { id: assignmentId, delivery_man_id } = assignmentResult.rows[0];

    // Update order status
    let orderStatus = status;
    if (status === 'picked_up' || status === 'in_transit') {
      orderStatus = 'shipped';
    }

    await client.query(
      'UPDATE orders SET status = $1, updated_at = NOW() WHERE id = $2',
      [orderStatus, order_id]
    );

    // Update assignment status
    await client.query(
      'UPDATE delivery_assignments SET status = $1, updated_at = NOW() WHERE id = $2',
      [status, assignmentId]
    );

    // Add status history
    await client.query(`
      INSERT INTO delivery_status_history 
      (assignment_id, status, latitude, longitude, location_name, notes, created_at, created_by)
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), $7)
    `, [assignmentId, status, latitude, longitude, location_name, notes, 'delivery_man']);

    // Update delivery man location if provided
    if (latitude && longitude) {
      await client.query(`
        UPDATE delivery_men 
        SET latitude = $1, longitude = $2, last_location_update = NOW(), updated_at = NOW()
        WHERE id = $3
      `, [latitude, longitude, delivery_man_id]);
    }

    // Create/update delivery analytics data
    try {
      const analyticsData = {
        distributor_id: req.user.id,
        order_id: order_id,
        delivery_man_id: delivery_man_id,
        status: status,
        latitude: latitude,
        longitude: longitude,
        notes: notes,
        location_name: location_name
      };
      
      await client.query(`
        INSERT INTO delivery_analytics 
        (distributor_id, order_id, delivery_man_id, status, latitude, longitude, notes, location_name, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW())
        ON CONFLICT (order_id) 
        DO UPDATE SET 
          status = EXCLUDED.status,
          latitude = EXCLUDED.latitude,
          longitude = EXCLUDED.longitude,
          notes = EXCLUDED.notes,
          location_name = EXCLUDED.location_name,
          updated_at = NOW()
      `, [
        analyticsData.distributor_id,
        analyticsData.order_id,
        analyticsData.delivery_man_id,
        analyticsData.status,
        analyticsData.latitude,
        analyticsData.longitude,
        analyticsData.notes,
        analyticsData.location_name
      ]);
      
      console.log(`📊 Analytics data updated for order ${order_id}`);
    } catch (analyticsError) {
      console.warn('Failed to update analytics data:', analyticsError);
      // Don't fail the main transaction for analytics errors
    }

    await client.query('COMMIT');

    console.log(`✅ Status updated successfully for order ${order_id}`);

    // Emit Socket.IO event for real-time status updates
    const io = req.app.get('io');
    if (io) {
      io.emit('delivery_status_update', {
        order_id: order_id,
        status: status,
        delivery_man_id: delivery_man_id,
        location: { latitude, longitude },
        location_name: location_name,
        notes: notes,
        timestamp: new Date().toISOString()
      });
    }

    res.json({
      success: true,
      message: `Status updated to ${status}`,
      order_id: order_id,
      new_status: status
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error updating status:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to update status'
    });
  } finally {
    client.release();
  }
});

// Get delivery statistics for dashboard
router.get('/stats', async (req, res) => {
  try {
    console.log('📊 Fetching delivery dashboard stats...');
    
    const stats = await pool.query(`
      SELECT 
        COUNT(CASE WHEN o.status IN ('pending', 'accepted', 'confirmed') AND da.id IS NULL THEN 1 END) as pending_orders,
        COUNT(CASE WHEN o.status IN ('assigned', 'shipped', 'in_transit') THEN 1 END) as active_deliveries,
        COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as completed_deliveries,
        COUNT(CASE WHEN da.assigned_at >= CURRENT_DATE THEN 1 END) as today_assignments
      FROM orders o
      LEFT JOIN delivery_assignments da ON o.id = da.order_id
      WHERE o.created_at >= CURRENT_DATE - INTERVAL '30 days'
    `);

    const deliveryMenStats = await pool.query(`
      SELECT 
        COUNT(*) as total_delivery_men,
        COUNT(CASE WHEN is_online = true THEN 1 END) as available_delivery_men,
        COUNT(CASE WHEN is_active = true THEN 1 END) as active_delivery_men
      FROM delivery_men
    `);

    const result = {
      ...stats.rows[0],
      ...deliveryMenStats.rows[0]
    };

    console.log('✅ Dashboard stats fetched successfully');
    
    res.json({
      success: true,
      stats: result,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error fetching delivery stats:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch delivery statistics'
    });
  }
});

// Get enhanced analytics for Flutter dashboard
router.get('/enhanced-analytics', async (req, res) => {
  try {
    console.log('📈 Fetching enhanced delivery analytics...');
    
    // Basic metrics with fallback for missing data
    const basicMetrics = await pool.query(`
      SELECT 
        COUNT(da.id) as total_assignments,
        COUNT(CASE WHEN da.status = 'delivered' THEN 1 END) as total_deliveries,
        COUNT(CASE WHEN da.status IN ('assigned', 'picked_up', 'in_transit') THEN 1 END) as active_deliveries,
        COUNT(CASE WHEN da.assigned_at >= CURRENT_DATE THEN 1 END) as completed_today
      FROM delivery_assignments da
      LEFT JOIN orders o ON da.order_id = o.id
      WHERE da.assigned_at >= CURRENT_DATE - INTERVAL '30 days'
    `);

    // Performance metrics with defaults
    const analytics = {
      ...basicMetrics.rows[0],
      average_delivery_time: 35,
      on_time_rate: 0.87,
      efficiency_score: 0.82,
      average_rating: 4.3,
      delivery_success_rate: 0.94
    };

    console.log('✅ Enhanced analytics fetched successfully');
    
    res.json({
      success: true,
      analytics: analytics,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error fetching enhanced analytics:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch enhanced analytics'
    });
  }
});

// Get delivery man performance
router.get('/performance/:deliveryManId', async (req, res) => {
  try {
    const { deliveryManId } = req.params;
    console.log(`📊 Fetching performance for delivery man ${deliveryManId}`);
    
    const performance = await pool.query(`
      SELECT 
        dm.id,
        dm.name,
        u.phone,
        dm.rating,
        dm.vehicle_type,
        COUNT(da.id) as total_assignments,
        COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as completed_deliveries,
        COUNT(CASE WHEN o.status IN ('assigned', 'shipped', 'in_transit') THEN 1 END) as active_deliveries
      FROM delivery_men dm
      JOIN users u ON dm.user_id = u.id
      LEFT JOIN delivery_assignments da ON dm.id = da.delivery_man_id
      LEFT JOIN orders o ON da.order_id = o.id
      WHERE dm.id = $1 AND dm.is_active = true
      GROUP BY dm.id, dm.name, u.phone, dm.rating, dm.vehicle_type
    `, [deliveryManId]);

    if (performance.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Delivery man not found'
      });
    }

    const result = {
      ...performance.rows[0],
      avg_delivery_time: 32,
      success_rate: 0.91,
      customer_rating: 4.4
    };

    console.log(`✅ Performance data fetched for delivery man ${deliveryManId}`);
    
    res.json({
      success: true,
      performance: result,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error fetching delivery man performance:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch delivery man performance'
    });
  }
});

// Bulk assign multiple orders
router.post('/bulk-assign', async (req, res) => {
  const { assignments } = req.body; // Array of {order_id, delivery_man_id}
  
  console.log(`📦 Starting bulk assignment of ${assignments?.length || 0} orders`);
  
  if (!assignments || !Array.isArray(assignments) || assignments.length === 0) {
    return res.status(400).json({
      success: false,
      message: 'Invalid assignments data'
    });
  }

  const client = await pool.connect();
  const results = [];
  const errors = [];

  try {
    await client.query('BEGIN');

    for (const assignment of assignments) {
      try {
        const { order_id, delivery_man_id } = assignment;

        // Verify order and delivery man
        const orderCheck = await client.query(
          'SELECT id, status FROM orders WHERE id = $1',
          [order_id]
        );

        const deliveryManCheck = await client.query(
          'SELECT id, name, is_online FROM delivery_men WHERE id = $1 AND is_active = true',
          [delivery_man_id]
        );

        if (orderCheck.rows.length === 0) {
          errors.push({ order_id, error: 'Order not found' });
          continue;
        }

        if (deliveryManCheck.rows.length === 0) {
          errors.push({ order_id, error: 'Delivery man not found or inactive' });
          continue;
        }

        if (!deliveryManCheck.rows[0].is_online) {
          console.log(`⚠️ Delivery man ${delivery_man_id} is offline but assignment will proceed`);
        }

        // Create assignment
        const assignmentResult = await client.query(`
          INSERT INTO delivery_assignments 
          (order_id, delivery_man_id, assigned_at, status, assigned_by, updated_at)
          VALUES ($1, $2, NOW(), 'accepted', $3, NOW())
          RETURNING id
        `, [order_id, delivery_man_id, 1]); // Using 1 as default assigned_by for now

        // Update order status
        await client.query(
          'UPDATE orders SET status = $1, updated_at = NOW() WHERE id = $2',
          ['accepted', order_id]
        );

        // Add status history
        await client.query(`
          INSERT INTO delivery_status_history 
          (assignment_id, status, location_name, notes, created_by)
          VALUES ($1, $2, $3, $4, $5)
        `, [assignmentResult.rows[0].id, 'accepted', 'Distribution Center', 'Bulk assignment', 1]);

        results.push({
          order_id,
          delivery_man_id,
          delivery_man_name: deliveryManCheck.rows[0].name,
          assignment_id: assignmentResult.rows[0].id,
          success: true
        });

      } catch (assignmentError) {
        console.error(`Failed to assign order ${assignment.order_id}:`, assignmentError.message);
        errors.push({ 
          order_id: assignment.order_id, 
          error: assignmentError.message 
        });
      }
    }

    await client.query('COMMIT');

    console.log(`✅ Bulk assignment completed: ${results.length} successful, ${errors.length} failed`);

    res.json({
      success: true,
      message: `Bulk assignment completed: ${results.length} successful, ${errors.length} failed`,
      successful_assignments: results,
      failed_assignments: errors,
      summary: {
        total: assignments.length,
        successful: results.length,
        failed: errors.length,
        success_rate: Math.round((results.length / assignments.length) * 100)
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error in bulk assignment:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Bulk assignment failed'
    });
  } finally {
    client.release();
  }
});

// Get orders assigned to a specific delivery man (Flutter specific)
router.get('/orders/:deliveryId', async (req, res) => {
  try {
    const { deliveryId } = req.params;
    console.log(`📋 Fetching orders for delivery man ${deliveryId}...`);
    
    const result = await pool.query(`
      SELECT 
        o.id,
        o.buyer_id,
        o.status,
        o.total_amount,
        o.delivery_address,
        o.created_at,
        o.updated_at,
        da.id as assignment_id,
        da.delivery_man_id,
        da.assigned_at,
        da.status as delivery_status,
        da.status as deliveryStatus,
        u.name as customer_name,
        u.phone as customer_phone,
        u.email as customer_email
      FROM delivery_assignments da
      JOIN orders o ON da.order_id = o.id
      JOIN users u ON o.buyer_id = u.id
      WHERE da.delivery_man_id = $1
      ORDER BY da.assigned_at DESC
    `, [deliveryId]);

    console.log(`✅ Found ${result.rows.length} orders for delivery man ${deliveryId}`);

    res.json({
      success: true,
      orders: result.rows,
      deliveries: result.rows,
      data: result.rows,
      count: result.rows.length,
      delivery_man_id: deliveryId,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error fetching delivery man orders:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch delivery man orders'
    });
  }
});

// Get orders by distributor (Flutter specific)
router.get('/distributor-orders/:distributorId', async (req, res) => {
  try {
    const { distributorId } = req.params;
    const { status } = req.query;
    
    console.log(`📋 Fetching orders for distributor ${distributorId}, status: ${status || 'all'}`);
    
    let statusCondition = '';
    const queryParams = [distributorId];
    
    if (status) {
      statusCondition = 'AND o.status = $2';
      queryParams.push(status);
    }
    
    const result = await pool.query(`
      SELECT 
        o.id,
        o.buyer_id,
        o.status,
        o.total_amount,
        o.delivery_address,
        o.created_at,
        da.id as assignment_id,
        da.delivery_man_id,
        da.assigned_at,
        da.status as assignment_status,
        dm.name as delivery_man_name,
        du.phone as delivery_man_phone,
        u.name as customer_name,
        u.phone as customer_phone
      FROM orders o
      JOIN users distributor ON o.distributor_id = distributor.id
      LEFT JOIN delivery_assignments da ON o.id = da.order_id
      LEFT JOIN delivery_men dm ON da.delivery_man_id = dm.id
      LEFT JOIN users du ON dm.user_id = du.id
      JOIN users u ON o.buyer_id = u.id
      WHERE distributor.id = $1 ${statusCondition}
      ORDER BY o.created_at DESC
    `, queryParams);

    console.log(`✅ Found ${result.rows.length} orders for distributor ${distributorId}`);

    res.json({
      success: true,
      orders: result.rows,
      count: result.rows.length,
      distributor_id: distributorId,
      filter_status: status || 'all',
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error fetching distributor orders:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to fetch distributor orders'
    });
  }
});

// Health check endpoint
router.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Delivery system is running',
    version: '2.0.0',
    endpoints: [
      'GET /health', 'GET /men', 'GET /pending', 'GET /active', 
      'GET /completed', 'GET /analytics', 'GET /stats', 
      'GET /enhanced-analytics', 'GET /history/:orderId',
      'GET /performance/:deliveryManId', 'GET /orders/:deliveryId',
      'GET /distributor-orders/:distributorId',
      'POST /assign', 'POST /bulk-assign', 'POST /update-status', 
      'POST /smart-assign'
    ],
    timestamp: new Date().toISOString()
  });
});

module.exports = router;
