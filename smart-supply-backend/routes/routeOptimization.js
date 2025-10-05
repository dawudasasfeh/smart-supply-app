const express = require('express');
const router = express.Router();
const routeOptimizationController = require('../controllers/routeOptimizationController');
const authMiddleware = require('../middleware/auth.middleware');

// Apply authentication middleware to all routes
router.use(authMiddleware);

/**
 * @route   POST /api/route-optimization/sessions
 * @desc    Create a new route optimization session
 * @access  Private (Distributor, Admin)
 */
router.post('/sessions', routeOptimizationController.createOptimizationSession);

/**
 * @route   GET /api/route-optimization/orders/:deliveryManId/:distributorId
 * @desc    Get orders for route optimization
 * @access  Private (Delivery Man, Distributor, Admin)
 */
router.get('/orders/:deliveryManId/:distributorId', routeOptimizationController.getOrdersForOptimization);

/**
 * @route   POST /api/route-optimization/optimize
 * @desc    Optimize route for a delivery man
 * @access  Private (Delivery Man, Distributor, Admin)
 */
router.post('/optimize', routeOptimizationController.optimizeRoute);

/**
 * @route   GET /api/route-optimization/sessions/:sessionId
 * @desc    Get optimization session details
 * @access  Private (Delivery Man, Distributor, Admin)
 */
router.get('/sessions/:sessionId', routeOptimizationController.getOptimizationSession);

/**
 * @route   GET /api/route-optimization/sessions
 * @desc    Get all optimization sessions for a user
 * @access  Private (Delivery Man, Distributor, Admin)
 */
router.get('/sessions', routeOptimizationController.getOptimizationSessions);

/**
 * @route   DELETE /api/route-optimization/sessions/:sessionId
 * @desc    Delete optimization session
 * @access  Private (Delivery Man, Distributor, Admin)
 */
router.delete('/sessions/:sessionId', routeOptimizationController.deleteOptimizationSession);

/**
 * @route   GET /api/route-optimization/analytics
 * @desc    Get route optimization analytics
 * @access  Private (Delivery Man, Distributor, Admin)
 */
router.get('/analytics', routeOptimizationController.getOptimizationAnalytics);

module.exports = router;
