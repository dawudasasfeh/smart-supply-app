const {
  createOffer,
  getAllOffers,
  deleteOffer,
} = require('../models/offer.model');

const addOffer = async (req, res) => {
  try {
    const offer = await createOffer({
      ...req.body,
      distributor_id: req.user.id,
    });
    res.status(201).json(offer);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const listOffers = async (req, res) => {
  try {
    const offers = await getAllOffers();
    res.json(offers);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const removeOffer = async (req, res) => {
  try {
    await deleteOffer(req.params.id);
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = {
  addOffer,
  listOffers,
  removeOffer,
};
