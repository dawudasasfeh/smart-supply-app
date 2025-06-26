const express = require('express');
const router = express.Router();
const pool = require('../db');

// GET all offers
router.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM offers ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST add a new offer
router.post('/', async (req, res) => {
  const { product_id, product_name, discount_price } = req.body;
  if (!product_id || !product_name || !discount_price) {
    return res.status(400).json({ error: 'Missing fields' });
  }
  try {
    await pool.query(
      'INSERT INTO offers (product_id, product_name, discount_price) VALUES ($1, $2, $3)',
      [product_id, product_name, discount_price]
    );
    res.status(201).json({ status: 'Offer added' });
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
