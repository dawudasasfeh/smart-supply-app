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

router.get('/', getProducts);
router.get('/:id', getProduct);

// Distributor only (protected routes)
router.post('/', authenticate, addProduct);
router.put('/:id', authenticate, update);
router.delete('/:id', authenticate, remove);

module.exports = router;
