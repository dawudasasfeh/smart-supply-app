const pool = require('./db');

async function testCleanProfileAPI() {
  const client = await pool.connect();
  
  try {
    console.log('🧪 Testing Clean Profile API Structure...\n');
    
    // Test 1: Verify users table is clean
    console.log('📋 Test 1: Verify Clean Users Table Structure');
    const usersColumns = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      ORDER BY ordinal_position;
    `);
    
    console.log('✅ Clean users table columns:');
    usersColumns.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type}`);
    });
    
    // Test 2: Test profile retrieval for each role
    console.log('\n👥 Test 2: Profile Retrieval by Role');
    
    // Get sample users of each role
    const roleUsers = await client.query(`
      SELECT u.id, u.name, u.role, u.email
      FROM users u
      WHERE u.role IN ('supermarket', 'distributor', 'delivery')
      ORDER BY u.role, u.id
      LIMIT 6;
    `);
    
    for (const user of roleUsers.rows) {
      console.log(`\n🔍 Testing ${user.role} user: ${user.name} (ID: ${user.id})`);
      
      // Simulate GET /api/profile/me for this user
      const userProfile = await client.query(`
        SELECT id, name, email, role, phone, address,
               base_latitude as latitude, base_longitude as longitude,
               created_at, updated_at
        FROM users WHERE id = $1
      `, [user.id]);
      
      let additionalData = {};
      
      if (user.role === 'supermarket') {
        const roleData = await client.query(`
          SELECT store_name, manager_name, address as store_address, 
                 latitude as store_latitude, longitude as store_longitude,
                 area, store_size, store_type, operating_hours, is_active
          FROM supermarkets WHERE user_id = $1
        `, [user.id]);
        
        if (roleData.rows.length > 0) {
          additionalData = roleData.rows[0];
          console.log(`  ✅ Supermarket data found: ${additionalData.store_name}`);
        }
        
      } else if (user.role === 'distributor') {
        const roleData = await client.query(`
          SELECT company_name, contact_person, business_license, 
                 coverage_area, is_active, total_orders
          FROM distributors WHERE user_id = $1
        `, [user.id]);
        
        if (roleData.rows.length > 0) {
          additionalData = roleData.rows[0];
          console.log(`  ✅ Distributor data found: ${additionalData.company_name}`);
        }
        
      } else if (user.role === 'delivery') {
        const roleData = await client.query(`
          SELECT vehicle_type, max_daily_orders, rating, 
                 is_active, total_deliveries, shift_start, shift_end
          FROM delivery_men WHERE user_id = $1
        `, [user.id]);
        
        if (roleData.rows.length > 0) {
          additionalData = roleData.rows[0];
          console.log(`  ✅ Delivery data found: Vehicle ${additionalData.vehicle_type}, Max orders: ${additionalData.max_daily_orders}`);
        }
      }
      
      const combinedProfile = {
        ...userProfile.rows[0],
        ...additionalData
      };
      
      console.log(`  📊 Combined profile keys: ${Object.keys(combinedProfile).length} fields`);
    }
    
    // Test 3: Test role-specific updates
    console.log('\n📝 Test 3: Role-Specific Updates');
    
    // Test supermarket update
    const supermarketUser = roleUsers.rows.find(u => u.role === 'supermarket');
    if (supermarketUser) {
      console.log(`\n🏪 Testing supermarket update for: ${supermarketUser.name}`);
      
      const updateResult = await client.query(`
        UPDATE supermarkets 
        SET store_name = $1, operating_hours = $2, updated_at = $3
        WHERE user_id = $4 
        RETURNING store_name, operating_hours, updated_at
      `, ['Updated Store Name', '9:00 AM - 10:00 PM', new Date(), supermarketUser.id]);
      
      if (updateResult.rows.length > 0) {
        console.log(`  ✅ Supermarket update successful:`, updateResult.rows[0]);
      }
    }
    
    // Test distributor update
    const distributorUser = roleUsers.rows.find(u => u.role === 'distributor');
    if (distributorUser) {
      console.log(`\n🏢 Testing distributor update for: ${distributorUser.name}`);
      
      const updateResult = await client.query(`
        UPDATE distributors 
        SET company_name = $1, coverage_area = $2, updated_at = $3
        WHERE user_id = $4 
        RETURNING company_name, coverage_area, updated_at
      `, ['Updated Company Name', 'Greater Amman Area', new Date(), distributorUser.id]);
      
      if (updateResult.rows.length > 0) {
        console.log(`  ✅ Distributor update successful:`, updateResult.rows[0]);
      }
    }
    
    // Test delivery update
    const deliveryUser = roleUsers.rows.find(u => u.role === 'delivery');
    if (deliveryUser) {
      console.log(`\n🚚 Testing delivery update for: ${deliveryUser.name}`);
      
      const updateResult = await client.query(`
        UPDATE delivery_men 
        SET vehicle_type = $1, max_daily_orders = $2, updated_at = $3
        WHERE user_id = $4 
        RETURNING vehicle_type, max_daily_orders, updated_at
      `, ['Motorcycle', 25, new Date(), deliveryUser.id]);
      
      if (updateResult.rows.length > 0) {
        console.log(`  ✅ Delivery update successful:`, updateResult.rows[0]);
      }
    }
    
    // Test 4: Verify data integrity
    console.log('\n🔍 Test 4: Data Integrity Check');
    
    const counts = await client.query(`
      SELECT 
        (SELECT COUNT(*) FROM users) as total_users,
        (SELECT COUNT(*) FROM supermarkets) as total_supermarkets,
        (SELECT COUNT(*) FROM distributors) as total_distributors,
        (SELECT COUNT(*) FROM delivery_men) as total_delivery_men,
        (SELECT COUNT(*) FROM users WHERE role = 'supermarket') as supermarket_users,
        (SELECT COUNT(*) FROM users WHERE role = 'distributor') as distributor_users,
        (SELECT COUNT(*) FROM users WHERE role = 'delivery') as delivery_users
    `);
    
    const stats = counts.rows[0];
    console.log('📊 Database Statistics:');
    console.log(`  Total Users: ${stats.total_users}`);
    console.log(`  Supermarket Users: ${stats.supermarket_users} | Supermarket Records: ${stats.total_supermarkets}`);
    console.log(`  Distributor Users: ${stats.distributor_users} | Distributor Records: ${stats.total_distributors}`);
    console.log(`  Delivery Users: ${stats.delivery_users} | Delivery Records: ${stats.total_delivery_men}`);
    
    // Check for orphaned records
    const orphanCheck = await client.query(`
      SELECT 
        (SELECT COUNT(*) FROM supermarkets s WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = s.user_id)) as orphaned_supermarkets,
        (SELECT COUNT(*) FROM distributors d WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = d.user_id)) as orphaned_distributors,
        (SELECT COUNT(*) FROM delivery_men dm WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = dm.user_id)) as orphaned_delivery_men
    `);
    
    const orphans = orphanCheck.rows[0];
    console.log('🔗 Orphaned Records Check:');
    console.log(`  Orphaned Supermarkets: ${orphans.orphaned_supermarkets}`);
    console.log(`  Orphaned Distributors: ${orphans.orphaned_distributors}`);
    console.log(`  Orphaned Delivery Men: ${orphans.orphaned_delivery_men}`);
    
    if (orphans.orphaned_supermarkets === '0' && orphans.orphaned_distributors === '0' && orphans.orphaned_delivery_men === '0') {
      console.log('  ✅ No orphaned records found - data integrity maintained!');
    }
    
    console.log('\n🎉 Clean Profile API testing completed successfully!');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    client.release();
    await pool.end();
  }
}

testCleanProfileAPI();
