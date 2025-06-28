const express = require('express');
const router = express.Router();
const axios = require('axios');
const { Pool } = require('pg');

const AI_API_URL = 'http://127.0.0.1:5001/predict'; // Flask server

const pool = new Pool({
  connectionString: 'postgresql://postgres:dawud@localhost:5432/GP'
});

// POST /api/ai/restock
router.post('/restock', async (req, res) => {
  const { product_id, days_ahead } = req.body;

  try {
    const response = await axios.post(AI_API_URL, {
      product_id,
      days_ahead
    });

    res.json(response.data);
  } catch (err) {
    console.error('❌ AI API error:', err.message);
    if (err.response) {
      return res.status(err.response.status).json(err.response.data);
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/restock_suggestions', async (req, res) => {
  try {
    // 1. Fetch products from DB
    const { rows: products } = await pool.query('SELECT id, name FROM products');

    // 2. For each product, call AI prediction endpoint
    const suggestions = await Promise.all(products.map(async (product) => {
      try {
        const aiResponse = await axios.post(AI_API_URL, {
          product_id: product.id,
          days_ahead: 7
        });
        return {
          product_name: product.name,
          quantity: aiResponse.data.restock_quantity || 0,
        };
      } catch (error) {
        console.error(`AI prediction failed for product ${product.id}:`, error.message);
        return {
          product_name: product.name,
          quantity: 0,
        };
      }
    }));

    // 3. Return the aggregated suggestions
    res.json(suggestions);

  } catch (error) {
    console.error('Error fetching restock suggestions:', error);
    res.status(500).json({ error: 'Failed to get restock suggestions' });
  }
});

module.exports = router;
