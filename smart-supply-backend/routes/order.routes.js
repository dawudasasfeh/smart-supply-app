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

// Place multi-product order
router.post('/multi', auth, createOrder);

// Supermarket
router.get('/my', auth, buyerOrders);

// Distributor
router.get('/incoming', auth, distributorOrders);

// Admin
router.get('/', auth, allOrders);

// Change order status
router.put('/:id/status', auth, changeStatus);

// Inventory for supermarkets
router.get('/inventory', auth, async (req, res) => {
  const userId = req.user.id;
  try {
    const result = await pool.query(`
      SELECT 
        p.id AS product_id,
        p.name AS product_name,
        SUM(oi.quantity) AS total_quantity
      FROM orders o
      JOIN order_items oi ON o.id = oi.order_id
      JOIN products p ON oi.product_id = p.id
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
