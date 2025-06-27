const pool = require('../db');

const createOffer = async ({ product_id, distributor_id, discount_price, expiration_date }) => {
  const result = await pool.query(
    `INSERT INTO offers (product_id, distributor_id, discount_price, expiration_date)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [product_id, distributor_id, discount_price, expiration_date]
  );
  return result.rows[0];
};

const getAllOffers = async () => {
  const result = await pool.query(
    `SELECT o.*, p.name AS product_name, p.price AS original_price
     FROM offers o
     JOIN products p ON o.product_id = p.id
     WHERE o.expiration_date >= CURRENT_DATE
     ORDER BY o.expiration_date`
  );
  return result.rows;
};

const getOffersByDistributor = async (distributor_id) => {
  const result = await pool.query(
    `SELECT * FROM offers WHERE distributor_id = $1`,
    [distributor_id]
  );
  return result.rows;
};

const deleteOffer = async (id) => {
  await pool.query(`DELETE FROM offers WHERE id = $1`, [id]);
};

module.exports = {
  createOffer,
  getAllOffers,
  getOffersByDistributor,
  deleteOffer,
};
