const pool = require('../db');

const createOffer = async ({ product_id, distributor_id, discount_price, discount_percentage, expiration_date }) => {
  // Calculate discount_percentage if not provided
  let calculatedPercentage = discount_percentage;
  
  if (!calculatedPercentage && discount_price) {
    // Get original price to calculate percentage
    const productResult = await pool.query('SELECT price FROM products WHERE id = $1', [product_id]);
    if (productResult.rows.length > 0) {
      const originalPrice = parseFloat(productResult.rows[0].price);
      const discountAmount = originalPrice - parseFloat(discount_price);
      calculatedPercentage = originalPrice > 0 ? (discountAmount / originalPrice) * 100 : 0;
    } else {
      calculatedPercentage = 0; // Default if product not found
    }
  }
  
  const result = await pool.query(
    `INSERT INTO offers (product_id, distributor_id, discount_price, discount_percentage, expiration_date)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [product_id, distributor_id, discount_price, calculatedPercentage || 0, expiration_date]
  );
  return result.rows[0];
};

const getAllOffers = async () => {
  const result = await pool.query(
    `SELECT o.*, p.name AS product_name, p.price AS original_price, p.image_url,
            u.name AS distributor_name
     FROM offers o
     JOIN products p ON o.product_id = p.id
     JOIN users u ON o.distributor_id = u.id
     WHERE o.expiration_date >= CURRENT_DATE
     ORDER BY o.expiration_date`
  );
  return result.rows;
};

// You can remove or keep this, but if keeping, update as below:
const getOffersByDistributor = async (distributor_id) => {
  const result = await pool.query(
    `SELECT o.*, p.name AS product_name
     FROM offers o
     JOIN products p ON o.product_id = p.id
     WHERE o.distributor_id = $1
     ORDER BY o.expiration_date ASC`,
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
