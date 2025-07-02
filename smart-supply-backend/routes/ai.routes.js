// backend/routes/ai.routes.js

const express = require('express');
const router = express.Router();
const axios = require('axios');
const { Pool } = require('pg');

const AI_API_URL = 'http://127.0.0.1:5001/predict'; // Flask AI server URL

const pool = new Pool({
  connectionString: 'postgresql://postgres:dawud@localhost:5432/GP'
});

// POST /api/ai/restock
// Expects full input for AI prediction
router.post('/restock', async (req, res) => {
  try {
    const {
      product_id,
      distributor_id,
      stock_level,
      previous_orders,
      active_offers,
      date
    } = req.body;

    // Validate input presence
    if (
      product_id === undefined ||
      distributor_id === undefined ||
      stock_level === undefined ||
      previous_orders === undefined ||
      active_offers === undefined ||
      !date
    ) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Call Flask AI predict endpoint
    const response = await axios.post(AI_API_URL, {
      product_id,
      distributor_id,
      stock_level,
      previous_orders,
      active_offers,
      date
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

// GET /api/ai/restock_suggestions
// Aggregates AI predictions for all products with required features fetched from DB
router.get('/restock_suggestions', async (req, res) => {
  try {
    const query = `
      SELECT
        ps.product_id,
        p.name AS product_name,
        ps.distributor_id,
        COALESCE(ps.stock_level, 0) AS stock_level,
        COALESCE(ps.previous_orders, 0) AS previous_orders,
        COALESCE(ps.active_offers, 0) AS active_offers
      FROM product_sales ps
      JOIN products p ON p.id = ps.product_id
    `;

    const { rows: products } = await pool.query(query);

    const today = new Date().toISOString().slice(0, 10);

    const suggestions = [];

    for (const product of products) {
      try {
        const aiResponse = await axios.post(AI_API_URL, {
          product_id: product.product_id,
          distributor_id: product.distributor_id,
          stock_level: product.stock_level,
          previous_orders: product.previous_orders,
          active_offers: product.active_offers,
          date: today
        });

        suggestions.push({
          product_name: product.product_name,
          predicted_demand: aiResponse.data.predicted_demand,
          low_stock_alert: aiResponse.data.low_stock_alert
        });
      } catch (error) {
        console.error(`AI prediction failed for product ${product.product_id}:`, error.message);
        suggestions.push({
          product_name: product.product_name,
          predicted_demand: 0,
          low_stock_alert: false
        });
      }
    }

    res.json(suggestions);

  } catch (error) {
    console.error('Error fetching restock suggestions:', error);
    res.status(500).json({ error: 'Failed to get restock suggestions' });
  }
});
module.exports = router;
