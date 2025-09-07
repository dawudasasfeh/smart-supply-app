const orderModel = require('../models/order.model');


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
  console.log('Fetching orders for buyer:', req.params.buyerId);
  try {
    const buyerId = parseInt(req.params.buyerId, 10);
    const orders = await orderModel.getBuyerOrders(buyerId);
    res.json(orders);
  } catch (err) {
    console.error('Error fetching buyer orders:', err);
    res.status(500).json({ error: 'Internal server error' });
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


module.exports = {
  placeMultiProductOrder,
  getBuyerOrders,
  getDistributorOrders,
  updateOrderStatus,
  updateStatus,
  getAllOrders,
};
