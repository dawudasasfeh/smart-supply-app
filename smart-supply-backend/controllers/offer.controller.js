const pool = require('../db');
const {
  createOffer,
  getAllOffers,
  getOffersByDistributor,
  deleteOffer
} = require('../models/offer.model');

const addOffer = async (req, res) => {
  try {
    const distributor_id = req.user.id;
    const { product_id, discount_price, discount_percentage, expiration_date } = req.body;
    
    console.log('📝 Creating offer with data:', {
      product_id,
      distributor_id,
      discount_price,
      discount_percentage,
      expiration_date
    });
    
    const offer = await createOffer({ 
      product_id, 
      distributor_id, 
      discount_price, 
      discount_percentage,
      expiration_date 
    });
    
    console.log('✅ Offer created successfully:', offer);
    res.status(201).json(offer);
  } catch (err) {
    console.error('❌ Error creating offer:', err);
    res.status(500).json({ error: err.message });
  }
};

// Updated: Join products to get product_name in all offers and my offers
const listOffers = async (req, res) => {
  const { distributorId } = req.query;

  try {
    const query = distributorId
      ? `SELECT o.*, p.name AS product_name, p.price AS original_price, p.image_url, p.category,
                u.name AS distributor_name
         FROM offers o 
         JOIN products p ON o.product_id = p.id 
         JOIN users u ON o.distributor_id = u.id
         WHERE o.distributor_id = $1 AND o.expiration_date >= CURRENT_DATE 
         ORDER BY o.expiration_date ASC`
      : `SELECT o.*, p.name AS product_name, p.price AS original_price, p.image_url, p.category,
                u.name AS distributor_name
         FROM offers o 
         JOIN products p ON o.product_id = p.id 
         JOIN users u ON o.distributor_id = u.id
         WHERE o.expiration_date >= CURRENT_DATE 
         ORDER BY o.expiration_date ASC`;

    const values = distributorId ? [distributorId] : [];
    const result = await pool.query(query, values);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const listMyOffers = async (req, res) => {
  try {
    // Updated query to join products and include all necessary fields for user's offers
    const result = await pool.query(
      `SELECT o.*, p.name AS product_name, p.price AS original_price, p.image_url, p.category,
              u.name AS distributor_name
       FROM offers o
       JOIN products p ON o.product_id = p.id
       JOIN users u ON o.distributor_id = u.id
       WHERE o.distributor_id = $1
       ORDER BY o.expiration_date ASC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const removeOffer = async (req, res) => {
  try {
    await deleteOffer(req.params.id);
    res.sendStatus(204);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

module.exports = {
  addOffer,
  listOffers,
  listMyOffers,
  removeOffer,
};
