const express = require('express');
const router = express.Router();
const axios = require('axios');

const AI_API_URL = 'http://127.0.0.1:5001/predict'; // Flask server

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

module.exports = router;
