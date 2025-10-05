const express = require('express');
const router = express.Router();
const orderController = require('../controllers/order.controller');
const authMiddleware = require('../middleware/auth.middleware'); // If you have auth

// Create single order (for payment flow)
router.post('/', authMiddleware, orderController.createOrder);

// Place multi-product order
router.post('/multi', authMiddleware, orderController.placeMultiProductOrder);

// Get buyer orders
router.get('/buyer/:buyerId', authMiddleware, orderController.getBuyerOrders);

// Get distributor orders
router.get('/distributor/:distributorId', authMiddleware, orderController.getDistributorOrders);

// Update order status
router.put('/:id/status', authMiddleware, orderController.updateOrderStatus);

// Get order items/products
router.get('/:id/items', authMiddleware, orderController.getOrderItems);

// Get order delivery information
router.get('/:id/delivery', authMiddleware, orderController.getOrderDeliveryInfo);

// Get all orders
router.get('/', authMiddleware, orderController.getAllOrders);


module.exports = router;
