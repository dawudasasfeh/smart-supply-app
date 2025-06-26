const pool = require('../db');

const createOffer = async (data) => {
  const { product_id, distributor_id, discount_price, valid_until } = data;
  const result = await pool.query(
    `INSERT INTO offers (product_id, distributor_id, discount_price, valid_until)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [product_id, distributor_id, discount_price, valid_until]
  );
  return result.rows[0];
};

const getAllOffers = async () => {
  const result = await pool.query(
    `SELECT o.*, p.name as product_name, p.price as original_price
     FROM offers o
     JOIN products p ON o.product_id = p.id
     WHERE o.valid_until >= CURRENT_DATE
     ORDER BY o.valid_until`
  );
  return result.rows;
};

const deleteOffer = async (id) => {
  await pool.query('DELETE FROM offers WHERE id = $1', [id]);
};

module.exports = {
  createOffer,
  getAllOffers,
  deleteOffer,
};
