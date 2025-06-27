const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth.middleware');
const pool = require('../db');

const {
  createOrder,
  buyerOrders,
  distributorOrders,
  changeStatus,
  allOrders,
} = require('../controllers/order.controller');

// Place order (with stock update now handled in model)
router.post('/', auth, createOrder);

// Buyer orders (supermarket)
router.get('/my', auth, buyerOrders);

// Distributor orders
router.get('/incoming', auth, distributorOrders);

// Update order status
router.put('/:id/status', auth, changeStatus);

// Admin view
router.get('/', auth, allOrders);

// Incoming orders + delivery name
router.get('/incoming', auth, async (req, res) => {
  try {
    const distributorId = req.user.id;
    const result = await pool.query(
      `SELECT o.*, 
              da.delivery_id, 
              u.name AS delivery_name
       FROM orders o
       LEFT JOIN delivery_assignments da ON o.id = da.order_id
       LEFT JOIN users u ON da.delivery_id = u.id
       WHERE o.distributor_id = $1
       ORDER BY o.created_at DESC`,
      [distributorId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch incoming orders' });
  }
});

// Inventory for supermarkets
router.get('/inventory', auth, async (req, res) => {
  const userId = req.user.id;
  try {
    const result = await pool.query(`
      SELECT 
        p.id AS product_id,
        p.name AS product_name,
        SUM(o.quantity) AS total_quantity
      FROM orders o
      JOIN products p ON o.product_id = p.id
      WHERE o.buyer_id = $1 AND o.status = 'delivered'
      GROUP BY p.id, p.name
      ORDER BY p.name
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching inventory:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
