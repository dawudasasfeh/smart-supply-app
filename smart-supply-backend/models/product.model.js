const pool = require('../db');

const createProduct = async (product) => {
  const { name, price, stock, description, distributor_id, category, brand, sku, image_url } = product;

  const res = await pool.query(
    `INSERT INTO products (name, price, stock, description, distributor_id, category, brand, sku, image_url)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
    [name, price, stock, description, distributor_id, category || '', brand || '', sku || '', image_url]
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
  const { name, price, stock, description, category, brand, sku, image_url } = data;
  
  // Build dynamic query based on provided fields
  const fields = [];
  const values = [];
  let paramCount = 1;
  
  if (name !== undefined) {
    fields.push(`name = $${paramCount}`);
    values.push(name);
    paramCount++;
  }
  if (price !== undefined) {
    fields.push(`price = $${paramCount}`);
    values.push(price);
    paramCount++;
  }
  if (stock !== undefined) {
    fields.push(`stock = $${paramCount}`);
    values.push(stock);
    paramCount++;
  }
  if (description !== undefined) {
    fields.push(`description = $${paramCount}`);
    values.push(description || '');
    paramCount++;
  }
  if (category !== undefined) {
    fields.push(`category = $${paramCount}`);
    values.push(category || '');
    paramCount++;
  }
  if (brand !== undefined) {
    fields.push(`brand = $${paramCount}`);
    values.push(brand || '');
    paramCount++;
  }
  if (sku !== undefined) {
    fields.push(`sku = $${paramCount}`);
    values.push(sku || '');
    paramCount++;
  }
  if (image_url !== undefined) {
    fields.push(`image_url = $${paramCount}`);
    values.push(image_url);
    paramCount++;
  }
  
  if (fields.length === 0) {
    throw new Error('No fields to update');
  }
  
  values.push(id);
  
  const query = `UPDATE products SET ${fields.join(', ')} WHERE id = $${paramCount} RETURNING *`;
  
  try {
    const res = await pool.query(query, values);
    return res.rows[0];
  } catch (error) {
    // If columns don't exist, provide helpful error message
    if (error.message.includes('column') && error.message.includes('does not exist')) {
      throw new Error('Database schema needs to be updated. Please run the migration script: add_product_image_fields.sql');
    }
    throw error;
  }
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

const reduceStock = async (productId, quantity) => {
  const res = await pool.query(
    `UPDATE products
     SET stock = stock - $1
     WHERE id = $2 AND stock >= $1
     RETURNING *`,
    [quantity, productId]
  );
  if (res.rowCount === 0) {
    throw new Error('Insufficient stock or product not found');
  }
  return res.rows[0];
};

module.exports = {
  createProduct,
  getAllProducts,
  getProductById,
  updateProduct,
  deleteProduct,
  getProductsWithOffers,
  getProductsByDistributor,
  reduceStock,
};
