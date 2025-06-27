// backend/routes/product.routes.js
const express = require('express');
const router = express.Router();
const {
  addProduct,
  getProducts,
  getProduct,
  update,
  remove,
} = require('../controllers/product.controller');

const authenticate = require('../middleware/auth.middleware');

router.get('/', getProducts);                  // Get all or with offers or filtered
router.get('/:id', getProduct);                // Get product by ID

router.post('/', authenticate, addProduct);    // Add product
router.put('/:id', authenticate, update);      // Update product
router.delete('/:id', authenticate, remove);   // Delete product

module.exports = router;
