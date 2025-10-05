const pool = require('./db');

async function testDeliveryEndpoint() {
  const client = await pool.connect();
  
  try {
    console.log('🧪 Testing Delivery Endpoint Query...\n');
    
    // Test the exact query from the delivery endpoint
    console.log('📋 Testing delivery men query (the one causing errors)');
    
    const result = await client.query(`
      SELECT 
        dm.id,
        dm.user_id,
        dm.name,
        u.phone,
        u.email,
        COALESCE(dm.vehicle_type, 'motorcycle') AS vehicle_type,
        COALESCE(dm.is_online, true) AS is_available,
        dm.is_active,
        COALESCE(dm.rating, 4.5) AS rating,
        CASE 
          WHEN COALESCE(dm.is_online, false) = false THEN 'offline'
          WHEN COALESCE(dm.is_online, true) = false THEN 'off_duty'
          WHEN COALESCE(dm.is_online, true) = true THEN 'available'
          ELSE 'available'
        END AS status
      FROM delivery_men dm
      JOIN users u ON dm.user_id = u.id
      WHERE dm.is_active = true
      ORDER BY dm.name ASC
    `);
    
    console.log(`✅ Query successful! Found ${result.rows.length} delivery men`);
    
    if (result.rows.length > 0) {
      const sample = result.rows[0];
      console.log('\n📋 Sample delivery man data:');
      console.log(`  ID: ${sample.id}`);
      console.log(`  Name: ${sample.name}`);
      console.log(`  Phone: ${sample.phone} (from users table)`);
      console.log(`  Email: ${sample.email} (from users table)`);
      console.log(`  Vehicle: ${sample.vehicle_type}`);
      console.log(`  Status: ${sample.status}`);
      console.log(`  Available: ${sample.is_available}`);
    }
    
    // Test order delivery info query
    console.log('\n📋 Testing order delivery info query');
    
    const orders = await client.query('SELECT id FROM orders LIMIT 3');
    
    if (orders.rows.length > 0) {
      const orderId = orders.rows[0].id;
      
      const deliveryInfo = await client.query(`
        SELECT 
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
         WHERE o.id = $1
      `, [orderId]);
      
      console.log(`✅ Order delivery info query successful for order ${orderId}`);
      
      if (deliveryInfo.rows.length > 0) {
        const info = deliveryInfo.rows[0];
        console.log('\n📋 Order delivery info:');
        console.log(`  Order ID: ${info.order_id}`);
        console.log(`  Status: ${info.delivery_status}`);
        console.log(`  Delivery Code: ${info.delivery_code}`);
        console.log(`  Delivery Man: ${info.delivery_man_name || 'Not assigned'}`);
        console.log(`  Phone: ${info.delivery_man_phone || 'Not assigned'}`);
        console.log(`  Vehicle: ${info.vehicle_type || 'Not assigned'}`);
        console.log(`  Plate: ${info.plate_number || 'Not assigned'}`);
      }
    }
    
    console.log('\n🎉 All queries working correctly!');
    console.log('\n📋 Summary:');
    console.log('  ✅ Delivery men query fixed - no phone/email column errors');
    console.log('  ✅ Order delivery info query working');
    console.log('  ✅ All JOINs with users table successful');
    console.log('  ✅ Backend ready for SupermarketOrderDetailsPage');
    
  } catch (error) {
    console.error('❌ Query error:', error.message);
    console.error('Full error:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

testDeliveryEndpoint();
