const orderModel = require('../models/order.model');

// Create single order (for payment flow)
const createOrder = async (req, res) => {
  try {
    const { total_amount, items, item_count, status = 'pending' } = req.body;
    const userId = req.user.id; // From auth middleware
    
    console.log('Creating order for user:', userId);
    console.log('Order data:', { total_amount, items, item_count, status });
    
    if (!total_amount || !items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'Invalid order data: total_amount and items are required' 
      });
    }

    // Create the order in database
    const order = await orderModel.createSingleOrder({
      buyer_id: userId,
      total_amount,
      items,
      item_count: item_count || items.length,
      status
    });

    console.log('Order created successfully:', order);
    
    res.status(201).json({
      success: true,
      message: 'Order created successfully',
      data: order
    });
  } catch (err) {
    console.error('Error creating order:', err);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to create order',
      error: err.message 
    });
  }
};

const placeMultiProductOrder = async (req, res) => {
  console.log('Received body:', req.body); // Add this line
  try {
    const { buyer_id, distributor_id, items } = req.body;
    if (!buyer_id || !distributor_id || !items || !Array.isArray(items)) {
      return res.status(400).json({ error: 'Invalid order data' });
    }

    const order = await orderModel.placeMultiProductOrder({ buyer_id, distributor_id, items });
    res.status(201).json(order);
  } catch (err) {
    console.error('Error placing multi-product order:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
};

const getBuyerOrders = async (req, res) => {
  console.log('🔍 Fetching orders for buyer:', req.params.buyerId);
  try {
    const buyerId = parseInt(req.params.buyerId, 10);
    console.log('🔍 Parsed buyer ID:', buyerId);
    
    const orders = await orderModel.getBuyerOrders(buyerId);
    console.log('🔍 Found orders:', orders.length);
    
    if (orders.length > 0) {
      console.log('🔍 First order sample:', JSON.stringify(orders[0], null, 2));
    }
    
    res.json(orders);
  } catch (err) {
    console.error('❌ Error fetching buyer orders:', err);
    res.status(500).json({ error: 'Internal server error', details: err.message });
  }
};

const getDistributorOrders = async (req, res) => {
  console.log('Fetching orders for distributor:', req.params.distributorId);
  try {
    const distributorId = parseInt(req.params.distributorId, 10);
    const orders = await orderModel.getDistributorOrders(distributorId);
    res.json(orders);
  } catch (err) {
    console.error('Error fetching distributor orders:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
};

const updateOrderStatus = async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { status } = req.body;
    if (!status) {
      return res.status(400).json({ error: 'Status is required' });
    }

    const updatedOrder = await orderModel.updateStatus(id, status);
    res.json(updatedOrder);
  } catch (err) {
    console.error('Error updating order status:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
};

const updateStatus = async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  try {
    // Update order status first
    // Order Lifecycle: Order Created (pending) → Accepted → Delivered
    const updatedOrder = await OrderModel.updateStatus(id, status);

    if (!updatedOrder) {
      return res.status(404).json({ error: 'Order not found' });
    }

    // If status is 'delivered', update supermarket_stock accordingly
    if (status.toLowerCase() === 'delivered') {
      // Get order items
      const result = await pool.query(
        `SELECT oi.product_id, oi.quantity, o.buyer_id AS supermarket_id, o.distributor_id
         FROM order_items oi
         JOIN orders o ON oi.order_id = o.id
         WHERE o.id = $1`,
        [id]
      );

      const items = result.rows;

      // For each item, update or insert into supermarket_stock
      for (const item of items) {
        const { product_id, quantity, supermarket_id, distributor_id } = item;

        // Check if stock record exists
        const stockRes = await pool.query(
          `SELECT stock FROM supermarket_stock
           WHERE supermarket_id = $1 AND product_id = $2 AND distributor_id = $3`,
          [supermarket_id, product_id, distributor_id]
        );

        if (stockRes.rows.length > 0) {
          // Update existing stock by adding quantity
          await pool.query(
            `UPDATE supermarket_stock
             SET stock = stock + $1
             WHERE supermarket_id = $2 AND product_id = $3 AND distributor_id = $4`,
            [quantity, supermarket_id, product_id, distributor_id]
          );
        } else {
          // Insert new stock record
          await pool.query(
            `INSERT INTO supermarket_stock (supermarket_id, product_id, distributor_id, stock)
             VALUES ($1, $2, $3, $4)`,
            [supermarket_id, product_id, distributor_id, quantity]
          );
        }
      }

      // Create/update delivery analytics data for delivered orders
      try {
        const orderResult = await pool.query(
          `SELECT o.distributor_id, da.delivery_man_id, o.created_at, o.delivered_at
           FROM orders o
           LEFT JOIN delivery_assignments da ON o.id = da.order_id
           WHERE o.id = $1`,
          [id]
        );

        if (orderResult.rows.length > 0) {
          const order = orderResult.rows[0];
          const deliveryTime = order.delivered_at ? 
            new Date(order.delivered_at) - new Date(order.created_at) : 0;
          
          await pool.query(`
            INSERT INTO delivery_analytics 
            (distributor_id, order_id, delivery_man_id, status, delivery_time_minutes, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
            ON CONFLICT (order_id) 
            DO UPDATE SET 
              status = EXCLUDED.status,
              delivery_time_minutes = EXCLUDED.delivery_time_minutes,
              updated_at = NOW()
          `, [
            order.distributor_id,
            id,
            order.delivery_man_id,
            'delivered',
            Math.round(deliveryTime / (1000 * 60)) // Convert to minutes
          ]);
          
          console.log(`📊 Analytics data created for delivered order ${id}`);
        }
      } catch (analyticsError) {
        console.warn('Failed to create analytics data for delivered order:', analyticsError);
      }
    }

    res.json(updatedOrder);
  } catch (error) {
    console.error('Error updating order status:', error);
    res.status(500).json({ error: 'Failed to update order status' });
  }
};

const getAllOrders = async (req, res) => {
  try {
    const orders = await orderModel.getAllOrders();
    res.json(orders);
  } catch (err) {
    console.error('Error fetching all orders:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
};

const getOrderItems = async (req, res) => {
  try {
    const orderId = parseInt(req.params.id, 10);
    console.log('🔍 Fetching items for order:', orderId);
    
    const items = await orderModel.getOrderItems(orderId);
    console.log('✅ Found order items:', items.length);
    
    res.json(items);
  } catch (err) {
    console.error('❌ Error fetching order items:', err);
    res.status(500).json({ error: 'Internal server error', details: err.message });
  }
};

const getOrderDeliveryInfo = async (req, res) => {
  try {
    const orderId = parseInt(req.params.id, 10);
    console.log('🔍 Fetching delivery info for order:', orderId);
    
    const deliveryInfo = await orderModel.getOrderDeliveryInfo(orderId);
    
    if (deliveryInfo) {
      console.log('✅ Found delivery info for order:', orderId);
      res.json(deliveryInfo);
    } else {
      console.log('❌ No delivery info found for order:', orderId);
      res.status(404).json({ error: 'Delivery information not found' });
    }
  } catch (err) {
    console.error('❌ Error fetching order delivery info:', err);
    res.status(500).json({ error: 'Internal server error', details: err.message });
  }
};


module.exports = {
  createOrder,
  placeMultiProductOrder,
  getBuyerOrders,
  getDistributorOrders,
  updateOrderStatus,
  updateStatus,
  getAllOrders,
  getOrderItems,
  getOrderDeliveryInfo,
};
