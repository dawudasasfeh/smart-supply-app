const {
  placeMultiProductOrder,
  getBuyerOrders,
  getDistributorOrders,
  updateStatus,
  getAllOrders,
} = require('../models/order.model');

const createOrder = async (req, res) => {
  try {
    const { distributor_id, items } = req.body; // items = [ { product_id, quantity, price } ]
    const order = await placeMultiProductOrder({
      buyer_id: req.user.id,
      distributor_id,
      items,
    });
    res.status(201).json(order);
  } catch (err) {
    console.error('Order error:', err);
    res.status(500).json({ message: err.message });
  }
};

const buyerOrders = async (req, res) => {
  try {
    const orders = await getBuyerOrders(req.user.id);
    res.json(orders);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const distributorOrders = async (req, res) => {
  try {
    const orders = await getDistributorOrders(req.user.id);
    res.json(orders);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const changeStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const updated = await updateStatus(req.params.id, status);
    res.json(updated);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const allOrders = async (req, res) => {
  try {
    const all = await getAllOrders();
    res.json(all);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = {
  createOrder,
  buyerOrders,
  distributorOrders,
  changeStatus,
  allOrders,
};
