const express = require('express');
const router = express.Router();
const TrackingController = require('../controllers/tracking.controller');

// Order Tracking Routes

// Get order tracking by order ID
router.get('/order/:orderId', TrackingController.getOrderTracking);

// Get tracking by tracking number
router.get('/track/:trackingNumber', TrackingController.getTrackingByNumber);

// Update order tracking status
router.post('/order/:orderId/status', TrackingController.updateTrackingStatus);

// Update delivery location (real-time tracking)
router.post('/delivery/:deliveryAssignmentId/location', TrackingController.updateDeliveryLocation);

// Get delivery man's current orders
router.get('/delivery-man/:deliveryManId/orders', TrackingController.getDeliveryManOrders);

// Get recent orders for quick tracking
router.get('/recent-orders', TrackingController.getRecentOrders);

// Get delivery analytics
router.get('/analytics', TrackingController.getDeliveryAnalytics);

// Health check for tracking service
router.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Tracking service is running',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;
