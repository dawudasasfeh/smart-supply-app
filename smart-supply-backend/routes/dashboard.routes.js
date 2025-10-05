const express = require('express');
const router = express.Router();
const pool = require('../db');
const authenticate = require('../middleware/auth.middleware');

/**
 * GET /api/dashboard/distributor/stats
 * Get dashboard statistics for distributor
 */
router.get('/distributor/stats', authenticate, async (req, res) => {
  try {
    const distributorId = req.user.id;
    
    // Get product count for this distributor
    const productCountResult = await pool.query(
      'SELECT COUNT(*) as count FROM products WHERE distributor_id = $1',
      [distributorId]
    );
    const totalProducts = parseInt(productCountResult.rows[0].count);
    
    // Get pending orders count
    const pendingOrdersResult = await pool.query(
      'SELECT COUNT(*) as count FROM orders WHERE distributor_id = $1 AND status = $2',
      [distributorId, 'pending']
    );
    const pendingOrders = parseInt(pendingOrdersResult.rows[0].count);
    
    // Get monthly revenue (orders from current month)
    const monthlyRevenueResult = await pool.query(`
      SELECT COALESCE(SUM(total_amount), 0) as revenue 
      FROM orders 
      WHERE distributor_id = $1 
      AND status = 'delivered' 
      AND EXTRACT(MONTH FROM created_at) = EXTRACT(MONTH FROM CURRENT_DATE)
      AND EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM CURRENT_DATE)
    `, [distributorId]);
    const monthlyRevenue = parseFloat(monthlyRevenueResult.rows[0].revenue);
    
    // Get active offers count
    const activeOffersResult = await pool.query(`
      SELECT COUNT(*) as count 
      FROM offers o 
      JOIN products p ON o.product_id = p.id 
      WHERE p.distributor_id = $1 
      AND o.expiration_date >= CURRENT_DATE
    `, [distributorId]);
    const activeOffers = parseInt(activeOffersResult.rows[0].count);
    
    res.json({
      totalProducts,
      pendingOrders,
      monthlyRevenue,
      activeOffers
    });
    
  } catch (error) {
    console.error('Dashboard stats error:', error);
    res.status(500).json({ 
      error: 'Failed to fetch dashboard statistics',
      message: error.message 
    });
  }
});

/**
 * GET /api/dashboard/supermarket/stats
 * Get dashboard statistics for supermarket
 */
router.get('/supermarket/stats', authenticate, async (req, res) => {
  try {
    const supermarketId = req.user.id;
    
    // Get inventory count
    const inventoryResult = await pool.query(`
      SELECT COUNT(*) as count 
      FROM products p 
      JOIN order_items oi ON p.id = oi.product_id 
      JOIN orders o ON oi.order_id = o.id 
      WHERE o.buyer_id = $1
    `, [supermarketId]);
    const totalInventory = parseInt(inventoryResult.rows[0].count);
    
    // Get pending orders count
    const pendingOrdersResult = await pool.query(
      'SELECT COUNT(*) as count FROM orders WHERE buyer_id = $1 AND status = $2',
      [supermarketId, 'pending']
    );
    const pendingOrders = parseInt(pendingOrdersResult.rows[0].count);
    
    // Get monthly spending
    const monthlySpendingResult = await pool.query(`
      SELECT COALESCE(SUM(total_amount), 0) as spending 
      FROM orders 
      WHERE buyer_id = $1 
      AND status = 'delivered' 
      AND EXTRACT(MONTH FROM created_at) = EXTRACT(MONTH FROM CURRENT_DATE)
      AND EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM CURRENT_DATE)
    `, [supermarketId]);
    const monthlySpending = parseFloat(monthlySpendingResult.rows[0].spending);
    
    // Get active offers count
    const activeOffersResult = await pool.query(`
      SELECT COUNT(*) as count 
      FROM offers o 
      JOIN products p ON o.product_id = p.id 
      WHERE o.expiration_date >= CURRENT_DATE
    `);
    const activeOffers = parseInt(activeOffersResult.rows[0].count);
    
    res.json({
      totalInventory,
      pendingOrders,
      monthlySpending,
      activeOffers
    });
    
  } catch (error) {
    console.error('Supermarket dashboard stats error:', error);
    res.status(500).json({ 
      error: 'Failed to fetch dashboard statistics',
      message: error.message 
    });
  }
});

/**
 * GET /api/dashboard/distributor/delivery-analytics
 * Get comprehensive delivery analytics for distributor
 */
router.get('/distributor/delivery-analytics', authenticate, async (req, res) => {
  try {
    const distributorId = req.user.id;
    
    // Get active deliveries (orders with delivery assignments in progress)
    const activeDeliveriesResult = await pool.query(`
      SELECT COUNT(*) as count 
      FROM orders o
      JOIN delivery_assignments da ON o.id = da.order_id
      WHERE o.distributor_id = $1 
        AND da.status IN ('assigned', 'picked_up', 'in_transit')
    `, [distributorId]);
    const activeDeliveries = parseInt(activeDeliveriesResult.rows[0].count);
    
    // Get pending pickups (orders assigned but not picked up)
    const pendingPickupsResult = await pool.query(`
      SELECT COUNT(*) as count 
      FROM orders o
      JOIN delivery_assignments da ON o.id = da.order_id
      WHERE o.distributor_id = $1 
        AND da.status = 'assigned'
    `, [distributorId]);
    const pendingPickups = parseInt(pendingPickupsResult.rows[0].count);
    
    // Get completed today
    const completedTodayResult = await pool.query(`
      SELECT COUNT(*) as count 
      FROM orders o
      JOIN delivery_assignments da ON o.id = da.order_id
      WHERE o.distributor_id = $1 
        AND da.status = 'delivered'
        AND DATE(da.updated_at) = CURRENT_DATE
    `, [distributorId]);
    const completedToday = parseInt(completedTodayResult.rows[0].count);
    
    // Get total deliveries this month
    const totalDeliveriesResult = await pool.query(`
      SELECT COUNT(*) as count 
      FROM orders o
      JOIN delivery_assignments da ON o.id = da.order_id
      WHERE o.distributor_id = $1 
        AND da.status = 'delivered'
        AND da.updated_at >= DATE_TRUNC('month', CURRENT_DATE)
    `, [distributorId]);
    const totalDeliveries = parseInt(totalDeliveriesResult.rows[0].count);
    
    // Get average delivery time in minutes
    const avgDeliveryTimeResult = await pool.query(`
      SELECT AVG(EXTRACT(EPOCH FROM (da.updated_at - da.assigned_at))/60) as avg_minutes
      FROM delivery_assignments da
      JOIN orders o ON da.order_id = o.id
      WHERE o.distributor_id = $1 
        AND da.status = 'delivered'
        AND da.assigned_at IS NOT NULL
        AND da.updated_at IS NOT NULL
    `, [distributorId]);
    const avgDeliveryTime = parseFloat(avgDeliveryTimeResult.rows[0].avg_minutes) || 0;
    
    // Get on-time delivery rate
    const onTimeRateResult = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN da.updated_at <= (da.assigned_at + INTERVAL '1 minute' * da.estimated_delivery_time) THEN 1 END) as on_time
      FROM delivery_assignments da
      JOIN orders o ON da.order_id = o.id
      WHERE o.distributor_id = $1 
        AND da.status = 'delivered'
        AND da.estimated_delivery_time IS NOT NULL
        AND da.assigned_at IS NOT NULL
    `, [distributorId]);
    const onTimeRate = onTimeRateResult.rows[0].total > 0 
      ? onTimeRateResult.rows[0].on_time / onTimeRateResult.rows[0].total 
      : 0;
    
    res.json({
      success: true,
      data: {
        activeDeliveries,
        pendingPickups,
        completedToday,
        totalDeliveries,
        avgDeliveryTime: Math.round(avgDeliveryTime),
        onTimeRate: Math.round(onTimeRate * 100) / 100,
        efficiencyScore: Math.round((onTimeRate + (avgDeliveryTime > 0 ? Math.max(0, 1 - avgDeliveryTime/120) : 0)) / 2 * 100) / 100,
      }
    });
  } catch (error) {
    console.error('Error fetching delivery analytics:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/dashboard/distributor/ai-suggestions
 * Get AI-powered suggestions for distributor
 */
router.get('/distributor/ai-suggestions', authenticate, async (req, res) => {
  try {
    const distributorId = req.user.id;
    const suggestions = [];
    
    // Get low stock products
    const lowStockResult = await pool.query(`
      SELECT p.id, p.name, p.stock, p.category, p.price
      FROM products p
      WHERE p.distributor_id = $1 
        AND p.stock < 20
        AND p.is_active = true
      ORDER BY p.stock ASC
      LIMIT 5
    `, [distributorId]);
    
    lowStockResult.rows.forEach(product => {
      suggestions.push({
        type: 'restock',
        priority: 'high',
        title: 'Low Stock Alert',
        description: '${product.name} is running low (${product.stock} units left)',
        productId: product.id,
        productName: product.name,
        suggestedQuantity: Math.max(50, product.stock * 3),
        currentStock: product.stock,
        category: product.category,
        estimatedCost: product.price * Math.max(50, product.stock * 3),
        icon: 'inventory_2',
        color: '#FF5722'
      });
    });
    
    // Get products with no recent orders
    const noOrdersResult = await pool.query(`
      SELECT p.id, p.name, p.category, p.price, p.created_at
      FROM products p
      LEFT JOIN order_items oi ON p.id = oi.product_id
      LEFT JOIN orders o ON oi.order_id = o.id AND o.created_at >= NOW() - INTERVAL '30 days'
      WHERE p.distributor_id = $1 
        AND p.is_active = true
        AND o.id IS NULL
      ORDER BY p.created_at ASC
      LIMIT 3
    `, [distributorId]);
    
    noOrdersResult.rows.forEach(product => {
      suggestions.push({
        type: 'marketing',
        priority: 'medium',
        title: 'Marketing Opportunity',
        description: '${product.name} hasn\'t received orders in 30 days',
        productId: product.id,
        productName: product.name,
        category: product.category,
        suggestedAction: 'Create promotional offer or review pricing',
        icon: 'campaign',
        color: '#FF9800'
      });
    });
    
    // Get top performing products for offer suggestions
    const topProductsResult = await pool.query(`
      SELECT p.id, p.name, p.category, p.price, COUNT(oi.id) as order_count
      FROM products p
      JOIN order_items oi ON p.id = oi.product_id
      JOIN orders o ON oi.order_id = o.id
      WHERE p.distributor_id = $1 
        AND o.created_at >= NOW() - INTERVAL '30 days'
        AND o.status = 'delivered'
      GROUP BY p.id, p.name, p.category, p.price
      ORDER BY order_count DESC
      LIMIT 3
    `, [distributorId]);
    
    topProductsResult.rows.forEach(product => {
      suggestions.push({
        type: 'offer',
        priority: 'low',
        title: 'Create Special Offer',
        description: '${product.name} is popular (${product.order_count} orders) - consider a special offer',
        productId: product.id,
        productName: product.name,
        category: product.category,
        orderCount: product.order_count,
        suggestedDiscount: '10-15%',
        icon: 'local_offer',
        color: '#4CAF50'
      });
    });
    
    // Get delivery performance insights
    const deliveryInsightsResult = await pool.query(`
      SELECT 
        AVG(EXTRACT(EPOCH FROM (da.updated_at - da.assigned_at))/60) as avg_delivery_time,
        COUNT(CASE WHEN da.status = 'delivered' THEN 1 END) as completed_deliveries,
        COUNT(*) as total_assignments
      FROM delivery_assignments da
      JOIN orders o ON da.order_id = o.id
      WHERE o.distributor_id = $1 
        AND da.assigned_at >= NOW() - INTERVAL '7 days'
    `, [distributorId]);
    
    if (deliveryInsightsResult.rows[0].total_assignments > 0) {
      const avgTime = deliveryInsightsResult.rows[0].avg_delivery_time;
      const completed = deliveryInsightsResult.rows[0].completed_deliveries;
      const total = deliveryInsightsResult.rows[0].total_assignments;
      
      if (avgTime > 60) {
        suggestions.push({
          type: 'delivery',
          priority: 'medium',
          title: 'Delivery Optimization',
          description: 'Average delivery time is ${Math.round(avgTime)} minutes. Consider optimizing routes.',
          avgDeliveryTime: Math.round(avgTime),
          completionRate: Math.round((completed / total) * 100),
          suggestedAction: 'Review delivery routes and driver assignments',
          icon: 'route',
          color: '#2196F3'
        });
      }
    }
    
    // Sort suggestions by priority
    suggestions.sort((a, b) => {
      const priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
      return priorityOrder[b.priority] - priorityOrder[a.priority];
    });
    
    res.json({
      success: true,
      data: suggestions.slice(0, 6) // Return top 6 suggestions
    });
  } catch (error) {
    console.error('Error fetching AI suggestions:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
