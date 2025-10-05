const express = require('express');
const router = express.Router();
const supplierRatingController = require('../controllers/supplierRating.controller');
const authMiddleware = require('../middleware/auth.middleware');

// Apply auth middleware to all routes
router.use(authMiddleware);

// POST /api/ratings/distributor/:distributorId - Submit rating for a distributor
router.post('/distributor/:distributorId', supplierRatingController.submitSupplierRating);

// GET /api/ratings/distributor/:distributorId/order/:orderId/check - Check if order has been rated
router.get('/distributor/:distributorId/order/:orderId/check', supplierRatingController.checkOrderRating);

// GET /api/ratings/distributor/:distributorId/stats - Get distributor rating statistics
router.get('/distributor/:distributorId/stats', supplierRatingController.getDistributorStats);

// POST /api/supplier-ratings/distributor/:distributorId/update-averages - Manually update averages (for testing)
router.post('/distributor/:distributorId/update-averages', supplierRatingController.updateDistributorAverages);

module.exports = router;
