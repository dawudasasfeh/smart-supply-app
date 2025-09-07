const pool = require('../db');

const getLowStockInventory = async (supermarket_id, threshold = 10) => {
  const result = await pool.query(
    `
    SELECT ss.*, p.name AS product_name
    FROM supermarket_stock ss
    JOIN products p ON ss.product_id = p.id
    WHERE ss.supermarket_id = $1 AND ss.stock < $2
    ORDER BY ss.stock ASC
    `,
    [supermarket_id, threshold]
  );
  return result.rows;
};

const restockProduct = async ({ supermarket_id, product_id, distributor_id, quantity }) => {
  const result = await pool.query(
    `
    UPDATE supermarket_stock
    SET stock = stock + $1
    WHERE supermarket_id = $2 AND product_id = $3 AND distributor_id = $4
    RETURNING *;
    `,
    [quantity, supermarket_id, product_id, distributor_id]
  );
  return result.rows[0];
};

module.exports = {
  getLowStockInventory,
  restockProduct,
};
