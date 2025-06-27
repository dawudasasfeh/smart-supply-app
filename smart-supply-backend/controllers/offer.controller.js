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
    const offer = await createOffer({ ...req.body, distributor_id });
    res.status(201).json(offer);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const listOffers = async (req, res) => {
  const { distributorId } = req.query;

  try {
    const query = distributorId
      ? `SELECT o.*, p.name AS product_name 
         FROM offers o 
         JOIN products p ON o.product_id = p.id 
         WHERE o.distributor_id = $1 AND o.expiration_date >= CURRENT_DATE 
         ORDER BY o.expiration_date ASC`
      : `SELECT o.*, p.name AS product_name 
         FROM offers o 
         JOIN products p ON o.product_id = p.id 
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
    const offers = await getOffersByDistributor(req.user.id);
    res.json(offers);
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
