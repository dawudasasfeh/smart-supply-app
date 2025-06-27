const express = require('express');
const router = express.Router();
const pool = require('../db');


// POST: Add a new offer
router.post('/', async (req, res) => {
  const { product_id, product_name, discount_price, expiration_date } = req.body;

  if (!product_id || !product_name || !discount_price || !expiration_date) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    await pool.query(
      `INSERT INTO offers (product_id, product_name, discount_price, expiration_date)
       VALUES ($1, $2, $3, $4)`,
      [product_id, product_name, discount_price, expiration_date]
    );
    res.status(201).json({ message: 'Offer created successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET: Fetch all offers
router.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM offers ORDER BY expiration_date ASC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE offer
router.delete('/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM offers WHERE id = $1', [req.params.id]);
    res.sendStatus(204);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
