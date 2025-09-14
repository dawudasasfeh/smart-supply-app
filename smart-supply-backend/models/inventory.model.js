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

const getAllInventory = async (supermarket_id) => {
  const result = await pool.query(
    `
    SELECT ss.*, p.name AS product_name, p.description, p.price
    FROM supermarket_stock ss
    JOIN products p ON ss.product_id = p.id
    WHERE ss.supermarket_id = $1
    ORDER BY p.name ASC
    `,
    [supermarket_id]
  );
  return result.rows;
};

const getSupermarketStats = async (supermarket_id) => {
  try {
    // Get total products count
    const totalProductsResult = await pool.query(
      `SELECT COUNT(*) as total_products FROM supermarket_stock WHERE supermarket_id = $1`,
      [supermarket_id]
    );

    // Get low stock count (threshold = 10)
    const lowStockResult = await pool.query(
      `SELECT COUNT(*) as low_stock_count FROM supermarket_stock WHERE supermarket_id = $1 AND stock < 10`,
      [supermarket_id]
    );

    // Get total stock value
    const stockValueResult = await pool.query(
      `SELECT COALESCE(SUM(ss.stock * p.price), 0) as total_stock_value 
       FROM supermarket_stock ss 
       JOIN products p ON ss.product_id = p.id 
       WHERE ss.supermarket_id = $1`,
      [supermarket_id]
    );

    // Get recent orders count (last 30 days)
    const recentOrdersResult = await pool.query(
      `SELECT COUNT(*) as recent_orders 
       FROM orders o 
       WHERE o.buyer_id = $1 
       AND o.created_at >= NOW() - INTERVAL '30 days'`,
      [supermarket_id]
    );

    return {
      totalProducts: parseInt(totalProductsResult.rows[0].total_products) || 0,
      lowStockItems: parseInt(lowStockResult.rows[0].low_stock_count) || 0,
      totalStockValue: parseFloat(stockValueResult.rows[0].total_stock_value) || 0,
      recentOrders: parseInt(recentOrdersResult.rows[0].recent_orders) || 0,
    };
  } catch (error) {
    console.error('Error in getSupermarketStats:', error);
    // Return default stats if there's an error
    return {
      totalProducts: 0,
      lowStockItems: 0,
      totalStockValue: 0,
      recentOrders: 0,
    };
  }
};

module.exports = {
  getLowStockInventory,
  restockProduct,
  getAllInventory,
  getSupermarketStats,
};
