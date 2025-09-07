const express = require('express');
const router = express.Router();
const inventoryController = require('../controllers/inventory.controller');
const authMiddleware = require('../middleware/auth.middleware');

router.get('/low-stock', authMiddleware, inventoryController.getLowStock);
router.post('/restock', authMiddleware, inventoryController.restock);

module.exports = router;
