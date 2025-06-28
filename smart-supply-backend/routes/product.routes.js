// routes/product.routes.js
const express = require('express');
const router = express.Router();
const {
  addProduct,
  getProducts,
  getProduct,
  update,
  remove,
  restockProduct
} = require('../controllers/product.controller');
const authenticate = require('../middleware/auth.middleware');

router.get('/', getProducts);
router.get('/:id', getProduct);

router.post('/', authenticate, addProduct);
router.put('/:id', authenticate, update);
router.delete('/:id', authenticate, remove);

// ✅ AI Auto-Restock Endpoint
router.post('/restock', restockProduct);

module.exports = router;
