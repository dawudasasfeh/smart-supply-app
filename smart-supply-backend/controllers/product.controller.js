const {
  createProduct,
  getAllProducts,
  getProductById,
  updateProduct,
  deleteProduct,
  getProductsWithOffers,
  getProductsByDistributor,
} = require('../models/product.model');

const addProduct = async (req, res) => {
  try {
    const product = { ...req.body, distributor_id: req.user.id };
    const newProduct = await createProduct(product);
    res.status(201).json(newProduct);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const getProducts = async (req, res) => {
  try {
    const distributorId = req.query.distributorId;
    const withOffers = req.query.withOffers;

    if (withOffers === 'true') {
      const products = await getProductsWithOffers();
      return res.json(products);
    }

    if (distributorId) {
      const filtered = await getProductsByDistributor(distributorId);
      return res.json(filtered);
    }

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


// ✅ Add to stock from AI
const restockProduct = async (req, res) => {
  const { product_id, quantity } = req.body;
  if (!product_id || !quantity || quantity <= 0) {
    return res.status(400).json({ message: 'Invalid input' });
  }
  try {
    await pool.query(
      `UPDATE products SET stock = stock + $1 WHERE id = $2`,
      [quantity, product_id]
    );
    res.status(200).json({ message: 'Product restocked' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = {
  addProduct,
  getProducts,
  getProduct,
  restockProduct, 
  update,
  remove,
};
