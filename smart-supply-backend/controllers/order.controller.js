const {
  placeOrder,
  getBuyerOrders,
  getDistributorOrders,
  updateStatus,
  getAllOrders,
} = require('../models/order.model');

const createOrder = async (req, res) => {
  try {
    const { product_id, distributor_id, quantity } = req.body;
    const order = await placeOrder({
      buyer_id: req.user.id,
      distributor_id,
      product_id,
      quantity,
    });
    res.status(201).json(order);
  } catch (err) {
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
