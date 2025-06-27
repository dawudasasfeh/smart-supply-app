const express = require('express');
const router = express.Router();
const authenticate = require('../middleware/auth.middleware');
const {
  addOffer,
  listOffers,
  listMyOffers,
  removeOffer
} = require('../controllers/offer.controller');

router.get('/', listOffers);                  // Public
router.get('/mine', authenticate, listMyOffers); // Authenticated
router.post('/', authenticate, addOffer);     // Authenticated
router.delete('/:id', authenticate, removeOffer); // Authenticated

module.exports = router;
