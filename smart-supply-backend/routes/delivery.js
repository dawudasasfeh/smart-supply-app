const express = require('express');
const router = express.Router();
const pool = require('../db');

// ✅ Assign order to delivery man
router.post('/assign', async (req, res) => {
  const { order_id, delivery_id } = req.body;

  if (!order_id || !delivery_id) {
    return res.status(400).json({ error: "Missing fields" });
  }

  try {
    // Ensure the delivery user exists
    const userCheck = await pool.query(
      'SELECT id FROM users WHERE id = $1 AND role ILIKE $2',
      [delivery_id, 'delivery']
    );

    if (userCheck.rows.length === 0) {
      return res.status(404).json({ error: "Delivery user not found" });
    }

    // Insert assignment
    await pool.query(
      'INSERT INTO delivery_assignments (order_id, delivery_id) VALUES ($1, $2)',
      [order_id, delivery_id]
    );

    res.status(201).json({ status: "Order assigned to delivery" });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ error: err.message });
  }
});


// ✅ Get orders assigned to a delivery man
// GET assigned orders
router.get('/orders/:deliveryId', async (req, res) => {
  try {
    const { deliveryId } = req.params;
    const result = await pool.query(
      `SELECT o.*, da.status AS delivery_status
       FROM orders o
       JOIN delivery_assignments da ON o.id = da.order_id
       WHERE da.delivery_id = $1`,
      [deliveryId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// ✅ Update delivery status
router.put('/status', async (req, res) => {
  const { order_id, delivery_id, status } = req.body;
  if (!order_id || !delivery_id || !status) {
    return res.status(400).json({ error: "Missing fields" });
  }

  try {
    await pool.query(
      `UPDATE delivery_assignments SET status = $1 WHERE order_id = $2 AND delivery_id = $3`,
      [status, order_id, delivery_id]
    );
    await pool.query(`UPDATE orders SET status = $1 WHERE id = $2`, [status, order_id]);
    res.json({ message: "Delivery status updated" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ✅ Get all delivery men
router.get('/men', async (req, res) => {
  try {
    const result = await pool.query(`SELECT id, name FROM users WHERE role = 'delivery'`);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
