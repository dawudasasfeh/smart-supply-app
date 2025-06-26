const {
  createProduct,
  getAllProducts,
  getProductById,
  updateProduct,
  deleteProduct,
} = require('../models/product.model');

const addProduct = async (req, res) => {
  try {
    const product = { ...req.body, distributor_id: req.user.id }; // user.id from JWT
    const newProduct = await createProduct(product);
    res.status(201).json(newProduct);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const getProducts = async (req, res) => {
  try {
    const products = await getAllProducts();
    res.json(products);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const getProduct = async (req, res) => {
  try {
    const product = await getProductById(req.params.id);
    if (!product) return res.status(404).json({ message: 'Not found' });
    res.json(product);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const update = async (req, res) => {
  try {
    const updated = await updateProduct(req.params.id, req.body);
    res.json(updated);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const remove = async (req, res) => {
  try {
    await deleteProduct(req.params.id);
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { addProduct, getProducts, getProduct, update, remove };
