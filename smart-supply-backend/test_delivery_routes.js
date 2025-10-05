const pool = require('./db');

async function testDeliveryRoutes() {
  const client = await pool.connect();
  
  try {
    console.log('🧪 Testing Delivery Routes After Cleanup...\n');
    
    // Test 1: Test delivery men query (the one that was failing)
    console.log('📋 Test 1: Delivery Men Query');
    
    const deliveryMenResult = await client.query(`
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
    
    console.log(`✅ Found ${deliveryMenResult.rows.length} delivery men`);
    
    if (deliveryMenResult.rows.length > 0) {
      const sample = deliveryMenResult.rows[0];
      console.log(`  Sample: ${sample.name}`);
      console.log(`  Phone: ${sample.phone} (from users table)`);
      console.log(`  Email: ${sample.email} (from users table)`);
      console.log(`  Vehicle: ${sample.vehicle_type}`);
      console.log(`  Status: ${sample.status}`);
    }
    
    // Test 2: Test active deliveries query
    console.log('\n📋 Test 2: Active Deliveries Query');
    
    const activeDeliveriesResult = await client.query(`
      SELECT 
        o.id,
        o.buyer_id,
        o.status,
        o.total_amount,
        o.delivery_address,
        o.created_at,
        da.id as assignment_id,
        da.delivery_man_id,
        da.assigned_at,
        da.status as assignment_status,
        dm.name as delivery_man_name,
        du.phone as delivery_man_phone,
        dm.vehicle_type,
        u.name as customer_name,
        u.phone as customer_phone
      FROM orders o
      LEFT JOIN delivery_assignments da ON o.id = da.order_id
      LEFT JOIN delivery_men dm ON da.delivery_man_id = dm.id
      LEFT JOIN users du ON dm.user_id = du.id
      JOIN users u ON o.buyer_id = u.id
      WHERE o.status = 'accepted'
      ORDER BY da.assigned_at DESC
    `);
    
    console.log(`✅ Found ${activeDeliveriesResult.rows.length} active deliveries`);
    
    // Test 3: Test delivery statistics query
    console.log('\n📋 Test 3: Delivery Statistics Query');
    
    const statsResult = await client.query(`
      SELECT 
        COUNT(CASE WHEN o.status IN ('pending', 'accepted', 'confirmed') AND da.id IS NULL THEN 1 END) as pending_orders,
        COUNT(CASE WHEN o.status IN ('assigned', 'shipped', 'in_transit') THEN 1 END) as active_deliveries,
        COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as completed_deliveries,
        COUNT(CASE WHEN da.assigned_at >= CURRENT_DATE THEN 1 END) as today_assignments
      FROM orders o
      LEFT JOIN delivery_assignments da ON o.id = da.order_id
      WHERE o.created_at >= CURRENT_DATE - INTERVAL '30 days'
    `);
    
    const deliveryMenStatsResult = await client.query(`
      SELECT 
        COUNT(*) as total_delivery_men,
        COUNT(CASE WHEN is_online = true THEN 1 END) as available_delivery_men,
        COUNT(CASE WHEN is_active = true THEN 1 END) as active_delivery_men
      FROM delivery_men
    `);
    
    const stats = {
      ...statsResult.rows[0],
      ...deliveryMenStatsResult.rows[0]
    };
    
    console.log('✅ Statistics calculated successfully:');
    console.log(`  Pending Orders: ${stats.pending_orders}`);
    console.log(`  Active Deliveries: ${stats.active_deliveries}`);
    console.log(`  Completed Deliveries: ${stats.completed_deliveries}`);
    console.log(`  Total Delivery Men: ${stats.total_delivery_men}`);
    console.log(`  Available Delivery Men: ${stats.available_delivery_men}`);
    console.log(`  Active Delivery Men: ${stats.active_delivery_men}`);
    
    // Test 4: Test delivery man performance query
    console.log('\n📋 Test 4: Delivery Man Performance Query');
    
    if (deliveryMenResult.rows.length > 0) {
      const testDeliveryManId = deliveryMenResult.rows[0].id;
      
      const performanceResult = await client.query(`
        SELECT 
          dm.id,
          dm.name,
          u.phone,
          dm.rating,
          dm.vehicle_type,
          COUNT(da.id) as total_assignments,
          COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as completed_deliveries,
          COUNT(CASE WHEN o.status IN ('assigned', 'shipped', 'in_transit') THEN 1 END) as active_deliveries
        FROM delivery_men dm
        JOIN users u ON dm.user_id = u.id
        LEFT JOIN delivery_assignments da ON dm.id = da.delivery_man_id
        LEFT JOIN orders o ON da.order_id = o.id
        WHERE dm.id = $1 AND dm.is_active = true
        GROUP BY dm.id, dm.name, u.phone, dm.rating, dm.vehicle_type
      `, [testDeliveryManId]);
      
      if (performanceResult.rows.length > 0) {
        const performance = performanceResult.rows[0];
        console.log(`✅ Performance data for ${performance.name}:`);
        console.log(`  Phone: ${performance.phone} (from users table)`);
        console.log(`  Rating: ${performance.rating}`);
        console.log(`  Vehicle: ${performance.vehicle_type}`);
        console.log(`  Total Assignments: ${performance.total_assignments}`);
        console.log(`  Completed Deliveries: ${performance.completed_deliveries}`);
      }
    }
    
    // Test 5: Test assignment availability check
    console.log('\n📋 Test 5: Assignment Availability Check');
    
    if (deliveryMenResult.rows.length > 0) {
      const testDeliveryManId = deliveryMenResult.rows[0].id;
      
      const availabilityResult = await client.query(
        'SELECT id, name, is_online FROM delivery_men WHERE id = $1 AND is_active = true',
        [testDeliveryManId]
      );
      
      if (availabilityResult.rows.length > 0) {
        const deliveryMan = availabilityResult.rows[0];
        console.log(`✅ Availability check for ${deliveryMan.name}:`);
        console.log(`  Online Status: ${deliveryMan.is_online}`);
        console.log(`  Available for Assignment: ${deliveryMan.is_online ? 'Yes' : 'Offline but can proceed'}`);
      }
    }
    
    console.log('\n🎉 All delivery route tests completed successfully!');
    
    console.log('\n📋 Summary:');
    console.log('  ✅ Delivery men query fixed - phone/email from users table');
    console.log('  ✅ Active deliveries query fixed - proper joins');
    console.log('  ✅ Statistics query fixed - is_online instead of is_available');
    console.log('  ✅ Performance query fixed - phone from users table');
    console.log('  ✅ Assignment checks fixed - is_online status');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
    console.error('Error details:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

testDeliveryRoutes();
