const express = require('express');
const router = express.Router();
const db = require('../db');

// QR Code verification endpoint
router.post('/verify-delivery', async (req, res) => {
  try {
    const { verification_key, supermarket_id, order_id, timestamp } = req.body;

    // Debug logging
    console.log('QR Verification Request:', {
      verification_key,
      supermarket_id,
      order_id,
      timestamp,
      fullBody: req.body
    });

    // Validate required fields
    if (!verification_key || !supermarket_id || !order_id) {
      return res.status(400).json({
        success: false,
        message: 'Missing required verification data',
        error: 'verification_key, supermarket_id, and order_id are required'
      });
    }

    // Check if the order exists and get its delivery_code for verification
    const orderQuery = `
      SELECT o.*, u.name as supermarket_name 
      FROM orders o 
      JOIN users u ON o.buyer_id = u.id 
      WHERE o.id = $1 AND o.buyer_id = $2 AND LOWER(u.role) = 'supermarket'
    `;
    
    console.log('Executing query with params:', [order_id, supermarket_id]);
    const orderResult = await db.query(orderQuery, [order_id, supermarket_id]);
    const orderRows = orderResult.rows;
    console.log('Query result - rows found:', orderRows.length);
    if (orderRows.length > 0) {
      console.log('Order found:', orderRows[0]);
    }
    
    if (orderRows.length === 0) {
      // Let's also check if the order exists at all (without supermarket constraint)
      const debugQuery = 'SELECT id, buyer_id, status, delivery_code FROM orders WHERE id = $1';
      const debugResult = await db.query(debugQuery, [order_id]);
      console.log('Debug - Order exists check:', debugResult.rows);
      
      // Check if supermarket exists
      const supermarketQuery = 'SELECT id, name, role FROM users WHERE id = $1';
      const supermarketResult = await db.query(supermarketQuery, [supermarket_id]);
      console.log('Debug - Supermarket exists check:', supermarketResult.rows);
      
      return res.status(404).json({
        success: false,
        message: 'Order not found or does not belong to this supermarket',
        error: 'ORDER_NOT_FOUND'
      });
    }

    const order = orderRows[0];
    const expectedDeliveryCode = order.delivery_code || `DEL_${order_id}`;
    
    console.log('Verification key comparison:', {
      received_key: verification_key,
      expected_key: expectedDeliveryCode,
      order_id: order_id,
      match: verification_key === expectedDeliveryCode
    });
    
    // Verify the QR code using delivery_code as verification key
    if (verification_key !== expectedDeliveryCode) {
      console.log('❌ QR verification FAILED - key mismatch');
      return res.status(401).json({
        success: false,
        message: 'Invalid QR code: Verification key does not match order delivery code',
        error: 'QR_INVALID_KEY'
      });
    }
    
    console.log('✅ QR verification key MATCHED');

    // Check if order is in a valid state for delivery verification
    if (order.status === 'delivered') {
      return res.status(400).json({
        success: false,
        message: 'Order has already been delivered',
        error: 'ORDER_ALREADY_DELIVERED'
      });
    }

    // Only allow verification of accepted orders
    if (order.status !== 'Accepted') {
      console.log('❌ QR verification FAILED - order not accepted, status:', order.status);
      return res.status(400).json({
        success: false,
        message: `Order cannot be verified. Current status: ${order.status}. Only accepted orders can be delivered.`,
        error: 'ORDER_NOT_ACCEPTED'
      });
    }

    // Update order status to delivered
    const updateQuery = 'UPDATE orders SET status = $1, delivered_at = NOW() WHERE id = $2';
    await db.query(updateQuery, ['delivered', order_id]);

    // Log the verification event
    const logQuery = `
      INSERT INTO delivery_verifications (order_id, supermarket_id, verification_key, verified_at) 
      VALUES ($1, $2, $3, NOW())
    `;
    
    try {
      await db.query(logQuery, [order_id, supermarket_id, verification_key]);
    } catch (logError) {
      // If logging fails, continue - the main verification succeeded
      console.warn('Failed to log delivery verification:', logError);
    }

    return res.status(200).json({
      success: true,
      message: 'Delivery verified successfully',
      data: {
        order_id: order.id,
        supermarket_name: order.supermarket_name,
        total_amount: order.total_amount,
        verified_at: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('QR verification error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error during QR verification',
      error: 'SERVER_ERROR'
    });
  }
});

// Generate QR verification data for an order
router.post('/generate', async (req, res) => {
  try {
    const { order_id, supermarket_id } = req.body;

    if (!order_id || !supermarket_id) {
      return res.status(400).json({
        success: false,
        message: 'Missing required data: order_id and supermarket_id are required'
      });
    }

    // Verify the order exists and belongs to the supermarket
    const orderQuery = `
      SELECT o.*, u.name as supermarket_name 
      FROM orders o 
      JOIN users u ON o.buyer_id = u.id 
      WHERE o.id = $1 AND o.buyer_id = $2 AND u.role = 'supermarket'
    `;
    
    const orderResult = await db.query(orderQuery, [order_id, supermarket_id]);
    const orderRows = orderResult.rows;
    
    if (orderRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order not found or access denied'
      });
    }

    const order = orderRows[0];

    const deliveryCode = order.delivery_code || `DEL_${order_id}`;
    
    // Generate QR data
    const qrData = {
      type: 'delivery_verification',
      supermarket_id: supermarket_id,
      supermarket_name: order.supermarket_name,
      order_id: order_id,
      delivery_code: deliveryCode,
      verification_key: deliveryCode,
      created_at: new Date().toISOString(),
    };

    return res.status(200).json({
      success: true,
      message: 'QR code data generated successfully',
      data: qrData
    });

  } catch (error) {
    console.error('QR generation error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error during QR generation'
    });
  }
});

module.exports = router;
