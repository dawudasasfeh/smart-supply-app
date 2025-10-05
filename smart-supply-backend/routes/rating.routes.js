const express = require('express');
const router = express.Router();
const ratingController = require('../controllers/rating.controller');
const authMiddleware = require('../middleware/auth.middleware');

// All rating routes require authentication
router.use(authMiddleware);

// GET /api/ratings/criteria/:ratingType - Get rating criteria for a specific type
router.get('/criteria/:ratingType', ratingController.getRatingCriteria);

// POST /api/ratings - Submit a new rating
router.post('/', ratingController.submitRating);

// GET /api/ratings/analytics - Get rating analytics for current user
router.get('/analytics', ratingController.getRatingAnalytics);

// GET /api/ratings/entities - Get entities that can be rated by current user
router.get('/entities', ratingController.getRatableEntities);

// GET /api/ratings/user/:userId/:role - Get user's rating history
router.get('/user/:userId/:role', ratingController.getUserRatings);

// GET /api/ratings/stats - Get rating statistics for dashboard
router.get('/stats', ratingController.getRatingStats);

// GET /api/ratings/summary/:userId/:userRole - Get rating summary for any user/role
router.get('/summary/:userId/:userRole', ratingController.getRatingSummary);

// GET /api/ratings/detailed/:userId/:userRole - Get detailed ratings with individual reviews
router.get('/detailed/:userId/:userRole', ratingController.getDetailedRatings);

module.exports = router;
