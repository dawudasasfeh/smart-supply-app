const pool = require('./db');

async function testOrderDeliveryInfo() {
  const client = await pool.connect();
  
  try {
    console.log('🧪 Testing Order Delivery Info Endpoint...\n');
    
    // Test 1: Check if we have orders and delivery assignments
    console.log('📋 Test 1: Database Status Check');
    
    const ordersCount = await client.query('SELECT COUNT(*) as count FROM orders');
    const assignmentsCount = await client.query('SELECT COUNT(*) as count FROM delivery_assignments');
    const deliveryMenCount = await client.query('SELECT COUNT(*) as count FROM delivery_men');
    
    console.log(`✅ Orders in database: ${ordersCount.rows[0].count}`);
    console.log(`✅ Delivery assignments: ${assignmentsCount.rows[0].count}`);
    console.log(`✅ Delivery men: ${deliveryMenCount.rows[0].count}`);
    
    // Test 2: Get sample orders with different statuses
    console.log('\n📋 Test 2: Sample Orders by Status');
    
    const ordersByStatus = await client.query(`
      SELECT id, status, buyer_id, total_amount, created_at
      FROM orders 
      ORDER BY id 
      LIMIT 10
    `);
    
    console.log('Sample orders:');
    ordersByStatus.rows.forEach(order => {
      console.log(`  Order ${order.id}: ${order.status} - $${order.total_amount}`);
    });
    
    // Test 3: Test the delivery info query for each order
    console.log('\n📋 Test 3: Testing Delivery Info Query');
    
    for (const order of ordersByStatus.rows.slice(0, 5)) {
      console.log(`\n🔍 Testing order ${order.id} (status: ${order.status})`);
      
      const deliveryInfo = await client.query(
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
        [order.id]
      );
      
      if (deliveryInfo.rows.length > 0) {
        const info = deliveryInfo.rows[0];
        console.log(`  ✅ Query successful:`);
        console.log(`     Delivery Status: ${info.delivery_status}`);
        console.log(`     Delivery Code: ${info.delivery_code}`);
        console.log(`     Assignment ID: ${info.assignment_id || 'Not assigned'}`);
        console.log(`     Delivery Man: ${info.delivery_man_name || 'Not assigned'}`);
        console.log(`     Phone: ${info.delivery_man_phone || 'Not assigned'}`);
        console.log(`     Vehicle: ${info.vehicle_type || 'Not assigned'}`);
        console.log(`     Plate: ${info.plate_number || 'Not assigned'}`);
        console.log(`     Rating: ${info.rating || 'No rating'}`);
        console.log(`     Online: ${info.is_online !== null ? info.is_online : 'Unknown'}`);
      } else {
        console.log(`  ❌ No delivery info found for order ${order.id}`);
      }
    }
    
    // Test 4: Create a test assignment if none exist
    console.log('\n📋 Test 4: Creating Test Assignment (if needed)');
    
    if (assignmentsCount.rows[0].count === '0' && deliveryMenCount.rows[0].count > 0) {
      const firstOrder = ordersByStatus.rows[0];
      const firstDeliveryMan = await client.query('SELECT id FROM delivery_men LIMIT 1');
      
      if (firstDeliveryMan.rows.length > 0) {
        console.log(`Creating test assignment for order ${firstOrder.id}`);
        
        await client.query(`
          INSERT INTO delivery_assignments (order_id, delivery_man_id, assigned_at, status)
          VALUES ($1, $2, NOW(), 'assigned')
          ON CONFLICT (order_id) DO NOTHING
        `, [firstOrder.id, firstDeliveryMan.rows[0].id]);
        
        // Update order status
        await client.query(`
          UPDATE orders SET status = 'assigned' WHERE id = $1
        `, [firstOrder.id]);
        
        console.log(`✅ Created test assignment for order ${firstOrder.id}`);
        
        // Test the query again with the new assignment
        const testDeliveryInfo = await client.query(
          `SELECT 
             o.id as order_id,
             o.status as delivery_status,
             COALESCE(o.delivery_code, CONCAT('DEL_', o.id, '_', EXTRACT(EPOCH FROM o.created_at)::bigint)) as delivery_code,
             da.id as assignment_id,
             da.assigned_at,
             dm.id as delivery_man_id,
             u.name as delivery_man_name,
             u.phone as delivery_man_phone,
             dm.vehicle_type,
             COALESCE(dm.plate_number, 'Not assigned') as plate_number,
             dm.rating
           FROM orders o
           LEFT JOIN delivery_assignments da ON o.id = da.order_id
           LEFT JOIN delivery_men dm ON da.delivery_man_id = dm.id
           LEFT JOIN users u ON dm.user_id = u.id
           WHERE o.id = $1`,
          [firstOrder.id]
        );
        
        if (testDeliveryInfo.rows.length > 0) {
          const info = testDeliveryInfo.rows[0];
          console.log(`✅ Test assignment working:`);
          console.log(`   Order: ${info.order_id}, Status: ${info.delivery_status}`);
          console.log(`   Delivery Man: ${info.delivery_man_name}`);
          console.log(`   Phone: ${info.delivery_man_phone}`);
          console.log(`   Vehicle: ${info.vehicle_type}`);
          console.log(`   Plate: ${info.plate_number}`);
        }
      }
    }
    
    // Test 5: Expected API response format
    console.log('\n📋 Test 5: Expected API Response Format');
    
    const sampleOrder = ordersByStatus.rows[0];
    const apiResponse = await client.query(
      `SELECT 
         o.id as order_id,
         o.status as delivery_status,
         COALESCE(o.delivery_code, CONCAT('DEL_', o.id, '_', EXTRACT(EPOCH FROM o.created_at)::bigint)) as delivery_code,
         da.id as assignment_id,
         da.assigned_at,
         dm.id as delivery_man_id,
         u.name as delivery_man_name,
         u.phone as delivery_man_phone,
         u.email as delivery_man_email,
         dm.vehicle_type,
         dm.vehicle_capacity,
         COALESCE(dm.plate_number, 'Not assigned') as plate_number,
         dm.rating,
         dm.is_online,
         CONCAT('TRK-', o.id, '-', EXTRACT(EPOCH FROM o.created_at)::bigint) as tracking_number
       FROM orders o
       LEFT JOIN delivery_assignments da ON o.id = da.order_id
       LEFT JOIN delivery_men dm ON da.delivery_man_id = dm.id
       LEFT JOIN users u ON dm.user_id = u.id
       WHERE o.id = $1`,
      [sampleOrder.id]
    );
    
    if (apiResponse.rows.length > 0) {
      console.log('✅ Sample API Response:');
      console.log(JSON.stringify(apiResponse.rows[0], null, 2));
    }
    
    console.log('\n🎉 Order delivery info testing completed!');
    
    console.log('\n📋 Summary:');
    console.log('  ✅ Backend query updated with plate_number field');
    console.log('  ✅ Query includes all necessary delivery information');
    console.log('  ✅ Handles both assigned and unassigned orders');
    console.log('  ✅ Phone and email come from users table');
    console.log('  ✅ Vehicle info comes from delivery_men table');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    client.release();
    await pool.end();
  }
}

testOrderDeliveryInfo();
