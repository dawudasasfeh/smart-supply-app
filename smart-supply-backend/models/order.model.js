const pool = require('../db');

function generateDeliveryCode(length = 8) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < length; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

const placeMultiProductOrder = async ({ buyer_id, distributor_id, items }) => {
  const delivery_code = generateDeliveryCode();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Create base order
    const result = await client.query(
      `INSERT INTO orders (buyer_id, distributor_id, delivery_code)
       VALUES ($1, $2, $3) RETURNING id, delivery_code, created_at`,
      [buyer_id, distributor_id, delivery_code]
    );
    const order_id = result.rows[0].id;

    // Insert order items + update stock
    for (const item of items) {
      const { product_id, quantity, price } = item;

      // Insert item
      await client.query(
        `INSERT INTO order_items (order_id, product_id, quantity, price)
         VALUES ($1, $2, $3, $4)`,
        [order_id, product_id, quantity, price]
      );

      // Update stock
      await client.query(
        `UPDATE products SET stock = stock - $1
         WHERE id = $2 AND stock >= $1`,
        [quantity, product_id]
      );
    }

    await client.query('COMMIT');
    return result.rows[0];
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const getBuyerOrders = async (buyer_id) => {
  const result = await pool.query(
    `SELECT o.*, json_agg(oi.*) AS items
     FROM orders o
     JOIN order_items oi ON o.id = oi.order_id
     WHERE o.buyer_id = $1
     GROUP BY o.id
     ORDER BY o.created_at DESC`,
    [buyer_id]
  );
  return result.rows;
};

const getDistributorOrders = async (distributor_id) => {
  const result = await pool.query(
    `SELECT o.*, json_agg(oi.*) AS items
     FROM orders o
     JOIN order_items oi ON o.id = oi.order_id
     WHERE o.distributor_id = $1
     GROUP BY o.id
     ORDER BY o.created_at DESC`,
    [distributor_id]
  );
  return result.rows;
};

const updateStatus = async (id, status) => {
  let result;

  if (status.toLowerCase() === 'delivered') {
    result = await pool.query(
      `UPDATE orders 
       SET status = $1, delivered_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [status, id]
    );
  } else {
    result = await pool.query(
      `UPDATE orders 
       SET status = $1
       WHERE id = $2
       RETURNING *`,
      [status, id]
    );
  }

  return result.rows[0];
};

const getAllOrders = async () => {
  const result = await pool.query(
    `SELECT o.*, json_agg(oi.*) AS items
     FROM orders o
     JOIN order_items oi ON o.id = oi.order_id
     GROUP BY o.id
     ORDER BY o.created_at DESC`
  );
  return result.rows;
};

module.exports = {
  placeMultiProductOrder,
  getBuyerOrders,
  getDistributorOrders,
  updateStatus,
  getAllOrders,
};
