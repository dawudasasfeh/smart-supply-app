const express = require('express');
const router = express.Router();
const deliveryAnalyticsController = require('../controllers/deliveryAnalyticsController');
const authenticate = require('../middleware/auth.middleware');

// Get delivery performance metrics for the authenticated distributor
router.get('/performance', authenticate, deliveryAnalyticsController.getDeliveryPerformanceMetrics);

// Create or update delivery analytics record
router.post('/create', authenticate, deliveryAnalyticsController.createDeliveryAnalytics);

// Get analytics for a specific order
router.get('/order/:orderId', authenticate, deliveryAnalyticsController.getOrderAnalytics);

// Update delivery analytics
router.post('/update', authenticate, deliveryAnalyticsController.createDeliveryAnalytics);

module.exports = router;
