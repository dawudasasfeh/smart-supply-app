const pool = require('../db');

function generateDeliveryCode(length = 8) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < length; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// Create multiple orders for payment flow - one per distributor
const createSingleOrder = async ({ buyer_id, total_amount, items, item_count, status = 'pending' }) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Group items by distributor to create separate orders
    const distributorGroups = {};
    
    if (items && items.length > 0) {
      // Get distributor info for all items
      for (const item of items) {
        try {
          const productQuery = await client.query(
            'SELECT distributor_id FROM products WHERE id = $1',
            [item.id]
          );
          
          const distributorId = productQuery.rows.length > 0 ? 
            productQuery.rows[0].distributor_id : 1; // Default to distributor 1
          
          if (!distributorGroups[distributorId]) {
            distributorGroups[distributorId] = [];
          }
          distributorGroups[distributorId].push(item);
        } catch (e) {
          // If can't find distributor, assign to default
          if (!distributorGroups[1]) {
            distributorGroups[1] = [];
          }
          distributorGroups[1].push(item);
        }
      }
    } else {
      // No items, create with default distributor
      distributorGroups[1] = [];
    }

    const createdOrders = [];
    
    // Create separate order for each distributor
    for (const [distributorId, distributorItems] of Object.entries(distributorGroups)) {
      const delivery_code = generateDeliveryCode();
      
      // Calculate total for this distributor
      const distributorTotal = parseFloat(distributorItems.reduce((sum, item) => {
        return sum + (parseFloat(item.price || 0) * parseInt(item.quantity || 1));
      }, 0).toFixed(2));

      // Create order for this distributor
      const result = await client.query(
        `INSERT INTO orders (buyer_id, distributor_id, delivery_code, delivery_address, status, total_amount, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW()) RETURNING id, delivery_code, created_at, total_amount, status`,
        [buyer_id, parseInt(distributorId), delivery_code, 'Default Address', status, distributorTotal]
      );
      
      const order = result.rows[0];
      const order_id = order.id;

      // Insert order items for this distributor
      for (const item of distributorItems) {
        const { id: product_id, name, price, quantity, total } = item;
        
        await client.query(
          `INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
           VALUES ($1, $2, $3, $4, $5)`,
          [order_id, product_id || 0, quantity || 1, price || 0, total || 0]
        );
      }

      // Add to created orders list
      createdOrders.push({
        id: order.id,
        buyer_id,
        distributor_id: parseInt(distributorId),
        delivery_code: order.delivery_code,
        status: order.status,
        total_amount: parseFloat(order.total_amount),
        created_at: order.created_at,
        items: distributorItems
      });
    }

    await client.query('COMMIT');
    
    // Return all created orders
    return {
      orders: createdOrders,
      total_orders: createdOrders.length,
      combined_total: parseFloat(total_amount)
    };
    
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

const placeMultiProductOrder = async ({ buyer_id, distributor_id, items }) => {
  const delivery_code = generateDeliveryCode();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Calculate total amount
    const total_amount = items.reduce((sum, item) => sum + (parseFloat(item.price) * item.quantity), 0);

    // Create base order
    // Order Lifecycle: Order Created (pending) → Accepted → Delivered
    const result = await client.query(
      `INSERT INTO orders (buyer_id, distributor_id, delivery_code, delivery_address, status, total_amount)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, delivery_code, created_at`,
      [buyer_id, distributor_id, delivery_code, 'Default Address', 'pending', total_amount]
    );
    const order_id = result.rows[0].id;

    // Insert order items + update stock
    for (const item of items) {
      const { product_id, quantity, price } = item;
      const total_price = parseFloat(price) * quantity;

      await client.query(
        `INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
         VALUES ($1, $2, $3, $4, $5)`,
        [order_id, product_id, quantity, price, total_price]
      );

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
      console.error('Order error:', err);
    throw err;
  } finally {
    client.release();
  }
};

const getBuyerOrders = async (buyer_id) => {
  const result = await pool.query(
    `SELECT 
      o.id,
      o.buyer_id,
      o.distributor_id,
      COALESCE(o.status, 'pending') as status,
      COALESCE(o.delivery_code, '') as delivery_code,
      o.created_at,
      o.updated_at,
      COALESCE(o.delivery_address, '') as delivery_address,
      o.delivery_latitude,
      o.delivery_longitude,
      COALESCE(o.priority_level, 1) as priority_level,
      COALESCE(SUM(oi.quantity * oi.unit_price), 0) as total_amount,
      json_build_object(
        'id', distributor.id,
        'name', COALESCE(distributor.name, ''),
        'email', COALESCE(distributor.email, ''),
        'role', COALESCE(distributor.role, '')
      ) as distributor,
      json_build_object(
        'street', COALESCE(o.delivery_address, ''),
        'city', '',
        'state', '',
        'postal_code', '',
        'country', '',
        'phone', '',
        'latitude', o.delivery_latitude,
        'longitude', o.delivery_longitude
      ) as shipping_address,
      json_agg(
        json_build_object(
          'id', oi.id,
          'product_id', oi.product_id,
          'quantity', oi.quantity,
          'price', oi.unit_price,
          'product', json_build_object(
            'id', p.id,
            'name', COALESCE(p.name, ''),
            'description', COALESCE(p.description, ''),
            'image', COALESCE(p.image_url, ''),
            'category', COALESCE(p.category, ''),
            'brand', COALESCE(p.brand, ''),
            'sku', COALESCE(p.sku, '')
          )
        )
      ) AS items
     FROM orders o
     JOIN order_items oi ON o.id = oi.order_id
     JOIN products p ON oi.product_id = p.id
     JOIN users buyer ON o.buyer_id = buyer.id
     JOIN users distributor ON o.distributor_id = distributor.id
     WHERE o.buyer_id = $1
     GROUP BY o.id, o.delivery_address, o.delivery_latitude, o.delivery_longitude, o.priority_level, buyer.id, buyer.name, buyer.email, distributor.id, distributor.name, distributor.email, distributor.role
     ORDER BY o.created_at DESC`,
    [buyer_id]
  );
  return result.rows;
};

const getDistributorOrders = async (distributor_id) => {
  try {
    console.log(`Fetching orders for distributor ${distributor_id}`);
    
    const result = await pool.query(
      `SELECT 
        o.id,
        o.buyer_id,
        o.distributor_id,
        COALESCE(o.status, 'pending') as status,
        COALESCE(o.delivery_code, '') as delivery_code,
        o.created_at,
        o.updated_at,
        COALESCE(o.delivery_address, '') as delivery_address,
        o.delivery_latitude,
        o.delivery_longitude,
        COALESCE(o.priority_level, 1) as priority_level,
        COALESCE(SUM(oi.quantity * oi.unit_price), 0) as total_amount,
        json_build_object(
          'id', buyer.id,
          'name', COALESCE(buyer.name, ''),
          'email', COALESCE(buyer.email, ''),
          'role', COALESCE(buyer.role, '')
        ) as buyer,
        json_build_object(
          'street', COALESCE(o.delivery_address, ''),
          'city', '',
          'state', '',
          'postal_code', '',
          'country', '',
          'phone', '',
          'latitude', o.delivery_latitude,
          'longitude', o.delivery_longitude
        ) as shipping_address,
        json_agg(
          json_build_object(
            'id', oi.id,
            'product_id', oi.product_id,
            'quantity', oi.quantity,
            'price', oi.unit_price,
            'product', json_build_object(
              'id', p.id,
              'name', COALESCE(p.name, ''),
              'description', COALESCE(p.description, ''),
              'image', COALESCE(p.image_url, ''),
              'category', COALESCE(p.category, ''),
              'brand', COALESCE(p.brand, ''),
              'sku', COALESCE(p.sku, '')
            )
          )
        ) AS items
       FROM orders o
       JOIN order_items oi ON o.id = oi.order_id
       JOIN products p ON oi.product_id = p.id
       JOIN users buyer ON o.buyer_id = buyer.id
       WHERE o.distributor_id = $1
       GROUP BY o.id, o.delivery_address, o.delivery_latitude, o.delivery_longitude, o.priority_level, buyer.id, buyer.name, buyer.email, buyer.role
       ORDER BY o.created_at DESC`,
      [distributor_id]
    );
    
    console.log(`Found ${result.rows.length} orders for distributor ${distributor_id}`);
    return result.rows;
  } catch (error) {
    console.error('Error in getDistributorOrders:', error);
    throw error;
  }
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
    `SELECT o.*, json_agg(row_to_json(oi)) AS items
     FROM orders o
     JOIN order_items oi ON o.id = oi.order_id
     GROUP BY o.id
     ORDER BY o.created_at DESC`
  );
  return result.rows;
};

const getOrderItems = async (orderId) => {
  const result = await pool.query(
    `SELECT 
       oi.id,
       oi.product_id,
       oi.quantity,
       oi.unit_price,
       oi.total_price,
       p.name as product_name,
       p.description as product_description,
       p.image_url as product_image
     FROM order_items oi
     LEFT JOIN products p ON oi.product_id = p.id
     WHERE oi.order_id = $1
     ORDER BY oi.id`,
    [orderId]
  );
  return result.rows;
};

const getOrderDeliveryInfo = async (orderId) => {
  try {
    console.log('🔍 Backend: Fetching delivery info for order:', orderId);
    
    // First check if the order exists
    const orderCheck = await pool.query('SELECT id, status, delivery_code FROM orders WHERE id = $1', [orderId]);
    console.log('🔍 Backend: Order exists check:', orderCheck.rows);
    
    // Check if there are any delivery assignments for this order
    const assignmentCheck = await pool.query('SELECT * FROM delivery_assignments WHERE order_id = $1', [orderId]);
    console.log('🔍 Backend: Delivery assignments for order:', assignmentCheck.rows);
    
    // Check if there are any delivery men in the system
    const deliveryMenCheck = await pool.query('SELECT COUNT(*) as count FROM delivery_men');
    console.log('🔍 Backend: Total delivery men in system:', deliveryMenCheck.rows[0]);
    
    const result = await pool.query(
      `SELECT 
         o.id as order_id,
         o.status as delivery_status,
         COALESCE(o.delivery_code, CONCAT('DEL_', o.id, '_', EXTRACT(EPOCH FROM o.created_at)::bigint)) as delivery_code,
         da.id as assignment_id,
         da.assigned_at,
         da.estimated_delivery_time,
         dm.id as delivery_man_id,
         u.name as delivery_man_name,
         u.phone as delivery_man_phone,
         u.email as delivery_man_email,
         dm.vehicle_type,
         dm.vehicle_capacity,
         COALESCE(dm.plate_number, 'Not assigned') as plate_number,
         COALESCE(dm.plate_number, 'Not assigned') as vehicle_plate,
         dm.rating,
         dm.is_online,
         dm.shift_start,
         dm.shift_end,
         CONCAT('TRK-', o.id, '-', EXTRACT(EPOCH FROM o.created_at)::bigint) as tracking_number
       FROM orders o
       LEFT JOIN delivery_assignments da ON o.id = da.order_id
       LEFT JOIN delivery_men dm ON da.delivery_man_id = dm.id
       LEFT JOIN users u ON dm.user_id = u.id
       WHERE o.id = $1`,
      [orderId]
    );
    
    console.log('🔍 Backend: Query result rows:', result.rows.length);
    if (result.rows.length > 0) {
      console.log('🔍 Backend: First row data:', result.rows[0]);
    }
    
    if (result.rows.length > 0) {
      const orderData = result.rows[0];
      
      console.log('🔍 Backend: Raw order data before processing:', orderData);
      
      // If the original delivery_code was null, update it in the database
      if (!orderData.delivery_code || orderData.delivery_code.startsWith('DEL_')) {
        const newDeliveryCode = `DEL_${orderId}_${Math.floor(Date.now() / 1000)}`;
        await pool.query(
          'UPDATE orders SET delivery_code = $1 WHERE id = $2 AND (delivery_code IS NULL OR delivery_code = \'\')',
          [newDeliveryCode, orderId]
        );
        orderData.delivery_code = newDeliveryCode;
      }
      
      console.log('✅ Backend: Returning order data:', orderData);
      return orderData;
    }
    
    console.log('❌ Backend: No rows found for order:', orderId);
    return null;
  } catch (error) {
    console.error('Error fetching order delivery info:', error);
    return null;
  }
};


module.exports = {
  createSingleOrder,
  placeMultiProductOrder,
  getBuyerOrders,
  getDistributorOrders,
  updateStatus,
  getAllOrders,
  getOrderItems,
  getOrderDeliveryInfo,
};
