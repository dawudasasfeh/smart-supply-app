const pool = require('../db');

// 🔁 Random delivery code generator
function generateDeliveryCode(length = 8) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < length; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

const placeOrder = async ({ buyer_id, distributor_id, product_id, quantity }) => {
  const delivery_code = generateDeliveryCode();

  const result = await pool.query(
    `INSERT INTO orders (buyer_id, distributor_id, product_id, quantity, delivery_code)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, delivery_code`, // return only needed fields
    [buyer_id, distributor_id, product_id, quantity, delivery_code]
  );

  return result.rows[0]; // { id, delivery_code }
};

const getBuyerOrders = async (buyer_id) => {
  const result = await pool.query(
    'SELECT * FROM orders WHERE buyer_id = $1 ORDER BY created_at DESC',
    [buyer_id]
  );
  return result.rows;
};

const getDistributorOrders = async (distributor_id) => {
  const result = await pool.query(
    'SELECT * FROM orders WHERE distributor_id = $1 ORDER BY created_at DESC',
    [distributor_id]
  );
  return result.rows;
};

const updateStatus = async (id, status) => {
  const result = await pool.query(
    'UPDATE orders SET status = $1 WHERE id = $2 RETURNING *',
    [status, id]
  );
  return result.rows[0];
};

const getAllOrders = async () => {
  const result = await pool.query('SELECT * FROM orders ORDER BY created_at DESC');
  return result.rows;
};

module.exports = {
  placeOrder,
  getBuyerOrders,
  getDistributorOrders,
  updateStatus,
  getAllOrders,
};
