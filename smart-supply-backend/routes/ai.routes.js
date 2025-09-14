const express = require('express');
const axios = require('axios');
const pool = require('../db');
const router = express.Router();

const AI_API_URL = 'http://localhost:5001';

// GET /api/ai/suggestions
router.get('/suggestions', async (req, res) => {
  try {
    const user_id = req.user?.id || 32; // Default to user 32 for testing
    
    // Get basic product data without complex joins
    const productsQuery = `
      SELECT ss.product_id, p.name as product_name, ss.stock as current_stock, 
             ss.distributor_id, p.price
      FROM supermarket_stock ss
      JOIN products p ON ss.product_id = p.id
      WHERE ss.supermarket_id = $1
      LIMIT 10
    `;
    
    const productsResult = await pool.query(productsQuery, [user_id]);
    const products = productsResult.rows.map(row => ({
      product_id: row.product_id,
      product_name: row.product_name,
      current_stock: row.current_stock,
      distributor_id: row.distributor_id,
      previous_orders: Math.floor(Math.random() * 20), // Mock data
      active_offers: Math.floor(Math.random() * 3)
    }));

    if (products.length === 0) {
      return res.json({
        success: true,
        suggestions: [],
        message: 'No products found for analysis'
      });
    }

    // Call AI service
    const response = await axios.post(`${AI_API_URL}/suggestions`, {
      products: products
    }, { timeout: 10000 });

    res.json(response.data);

  } catch (err) {
    console.error('❌ AI Suggestions error:', err.message);
    
    // Return fallback suggestions with consistent quantity calculation
    const fallbackStock = 15;
    const fallbackDemand = 20;
    const fallbackQuantity = Math.max(10, Math.ceil(fallbackDemand * 1.5 - fallbackStock));
    
    res.json({
      success: true,
      suggestions: [
        {
          product_id: 23,
          product_name: 'Cake',
          current_stock: fallbackStock,
          predicted_demand: fallbackDemand,
          suggested_quantity: fallbackQuantity,
          priority: 'medium',
          reason: 'Stock level below optimal threshold',
          reorder_point: fallbackDemand * 1.5
        }
      ],
      fallback: true
    });
  }
});

// GET /api/ai/analytics
router.get('/analytics', async (req, res) => {
  try {
    const user_id = req.user?.id || 32;
    
    // Get basic product data
    const productsQuery = `
      SELECT ss.product_id, p.name as product_name, ss.stock as current_stock, 
             ss.distributor_id
      FROM supermarket_stock ss
      JOIN products p ON ss.product_id = p.id
      WHERE ss.supermarket_id = $1
    `;
    
    const productsResult = await pool.query(productsQuery, [user_id]);
    const products = productsResult.rows.map(row => ({
      product_id: row.product_id,
      product_name: row.product_name,
      current_stock: row.current_stock,
      distributor_id: row.distributor_id,
      previous_orders: Math.floor(Math.random() * 20),
      active_offers: Math.floor(Math.random() * 3)
    }));

    if (products.length === 0) {
      return res.json({
        success: true,
        analytics: {
          total_products: 0,
          low_stock_products: 0,
          stock_health_score: 0
        }
      });
    }

    // Call AI service
    const response = await axios.post(`${AI_API_URL}/analytics`, {
      products: products
    }, { timeout: 10000 });

    res.json(response.data);

  } catch (err) {
    console.error('❌ AI Analytics error:', err.message);
    
    // Return fallback analytics
    const totalProducts = 5;
    const lowStockItems = 2;
    
    res.json({
      success: true,
      analytics: {
        total_products: totalProducts,
        low_stock_products: lowStockItems,
        stock_health_score: Math.round((totalProducts - lowStockItems) / totalProducts * 100),
        insights: ['Monitor inventory levels closely', 'Consider restocking low-stock items']
      },
      fallback: true
    });
  }
});

// POST /api/ai/predict
router.post('/predict', async (req, res) => {
  try {
    const { product_id, stock_level, distributor_id } = req.body;
    
    // Get product info
    const productQuery = `
      SELECT p.name as product_name, p.price
      FROM products p
      WHERE p.id = $1
    `;
    
    const productResult = await pool.query(productQuery, [product_id]);
    const product = productResult.rows[0];
    
    const requestData = {
      product_id: product_id,
      product_name: product?.product_name || 'Unknown Product',
      current_stock: stock_level,
      distributor_id: distributor_id,
      previous_orders: Math.floor(Math.random() * 20),
      active_offers: Math.floor(Math.random() * 3)
    };

    // Call AI service
    const response = await axios.post(`${AI_API_URL}/predict`, requestData, { timeout: 10000 });

    res.json(response.data);

  } catch (err) {
    console.error('❌ AI Prediction error:', err.message);
    
    // Return fallback prediction with consistent quantity
    const currentStock = req.body.stock_level || 0;
    const predictedDemand = 25.5;
    const suggestedQuantity = Math.max(10, Math.ceil(predictedDemand * 1.5 - currentStock));
    
    res.json({
      success: true,
      predicted_demand: predictedDemand,
      current_stock: currentStock,
      suggested_quantity: suggestedQuantity,
      suggested_restock: suggestedQuantity, // Keep both for compatibility
      urgency_level: 'medium',
      confidence: 0.75,
      fallback: true
    });
  }
});

// GET /api/ai/health
router.get('/health', async (req, res) => {
  try {
    const response = await axios.get(`${AI_API_URL}/health`, { timeout: 5000 });
    res.json(response.data);
  } catch (err) {
    res.status(503).json({
      status: 'unhealthy',
      error: 'AI service unavailable',
      timestamp: new Date().toISOString()
    });
  }
});

module.exports = router;
