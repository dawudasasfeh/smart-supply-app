// backend/models/product.model.js
const pool = require('../db');

const createProduct = async (product) => {
  const {
    name,
    price,
    stock,
    description,
    distributor_id,
  } = product;

  const res = await pool.query(
    `INSERT INTO products (name, price, stock, description, distributor_id)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [name, price, stock, description, distributor_id]
  );
  return res.rows[0];
};

const getAllProducts = async () => {
  const result = await pool.query('SELECT * FROM products');
  return result.rows;
};

const getProductById = async (id) => {
  const res = await pool.query('SELECT * FROM products WHERE id = $1', [id]);
  return res.rows[0];
};

const updateProduct = async (id, data) => {
  const { name, price, stock, description } = data;
  const res = await pool.query(
    `UPDATE products
     SET name = $1, price = $2, stock = $3, description = $4
     WHERE id = $5
     RETURNING *`,
    [name, price, stock, description, id]
  );
  return res.rows[0];
};

const deleteProduct = async (id) => {
  await pool.query('DELETE FROM products WHERE id = $1', [id]);
};

const getProductsWithOffers = async () => {
  const res = await pool.query(`
    SELECT 
      p.*, 
      o.discount_price,
      o.expiration_date
    FROM products p
    LEFT JOIN offers o ON o.product_id = p.id AND o.expiration_date >= CURRENT_DATE
  `);
  return res.rows;
};

const getProductsByDistributor = async (distributorId) => {
  const res = await pool.query(
    'SELECT * FROM products WHERE distributor_id = $1',
    [distributorId]
  );
  return res.rows;
};

module.exports = {
  createProduct,
  getAllProducts,
  getProductById,
  updateProduct,
  deleteProduct,
  getProductsWithOffers,
  getProductsByDistributor,
};
