const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth.middleware');
const crypto = require('crypto');

const {
  createOrder,
  buyerOrders,
  distributorOrders,
  changeStatus,
  allOrders,
} = require('../controllers/order.controller');

// Order routes
router.post('/', auth, createOrder);                         // Place order
router.get('/my', auth, buyerOrders);                        // Supermarket's orders
router.get('/incoming', auth, distributorOrders);            // Distributor's orders
router.put('/:id/status', auth, changeStatus);               // Update order status
router.get('/', auth, allOrders);                            // Admin/dev view


// Create a new order with delivery_code
router.post('/', async (req, res) => {
  const { product_id, distributor_id, quantity, buyer_id } = req.body;

  if (!product_id || !distributor_id || !quantity || !buyer_id) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const delivery_code = crypto.randomBytes(4).toString('hex');

  try {
    await pool.query(
      `INSERT INTO orders (product_id, distributor_id, quantity, buyer_id, status, delivery_code)
       VALUES ($1, $2, $3, $4, 'pending', $5)`,
      [product_id, distributor_id, quantity, buyer_id, delivery_code]
    );

    res.status(201).json({ message: 'Order created', delivery_code });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Order creation failed' });
  }
});

// routes/order.routes.js
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


module.exports = router;
