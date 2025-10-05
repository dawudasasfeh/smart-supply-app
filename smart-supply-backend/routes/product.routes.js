// routes/product.routes.js
const express = require('express');
const router = express.Router();
const {
  addProduct,
  addProductWithImage,
  getProducts,
  getProduct,
  restockProduct,
  update,
  updateProductWithImage,
  remove
} = require('../controllers/product.controller');
const authenticate = require('../middleware/auth.middleware');
const upload = require('../middleware/upload');

router.get('/', getProducts);
router.get('/:id', getProduct);

router.post('/', authenticate, addProduct);
router.post('/with-image', authenticate, upload.single('image'), addProductWithImage);
router.put('/:id', authenticate, update);
router.put('/:id/with-image', authenticate, upload.single('image'), updateProductWithImage);
router.delete('/:id', authenticate, remove);

// ✅ AI Auto-Restock Endpoint
router.post('/restock', restockProduct);

module.exports = router;
