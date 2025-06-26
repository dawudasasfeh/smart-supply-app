const pool = require('../db');

const createProduct = async (product) => {
  const { name, price, stock, description, distributor_id } = product;
  const result = await pool.query(
    'INSERT INTO products (name, price, stock, description, distributor_id) VALUES ($1, $2, $3, $4, $5) RETURNING *',
    [name, price, stock, description, distributor_id]
  );
  return result.rows[0];
};

const getAllProducts = async () => {
  const result = await pool.query('SELECT * FROM products');
  return result.rows;
};

const getProductById = async (id) => {
  const result = await pool.query('SELECT * FROM products WHERE id = $1', [id]);
  return result.rows[0];
};

const updateProduct = async (id, updated) => {
  const { name, price, stock, description } = updated;
  const result = await pool.query(
    'UPDATE products SET name = $1, price = $2, stock = $3, description = $4 WHERE id = $5 RETURNING *',
    [name, price, stock, description, id]
  );
  return result.rows[0];
};

const deleteProduct = async (id) => {
  await pool.query('DELETE FROM products WHERE id = $1', [id]);
};

module.exports = {
  createProduct,
  getAllProducts,
  getProductById,
  updateProduct,
  deleteProduct,
};
