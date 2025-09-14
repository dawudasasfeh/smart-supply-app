const express = require('express');
const router = express.Router();
const inventoryController = require('../controllers/inventory.controller');
const authMiddleware = require('../middleware/auth.middleware');

// Get supermarket dashboard statistics
router.get('/stats', authMiddleware, inventoryController.getSupermarketStats);

// Restock product endpoint
router.post('/restock', authMiddleware, inventoryController.restock);

module.exports = router;
