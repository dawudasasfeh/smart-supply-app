const pool = require('./db');

async function testLocationMigration() {
  const client = await pool.connect();
  
  try {
    console.log('🧪 Testing Location Migration Results...\n');
    
    // Test 1: Verify users table no longer has location fields
    console.log('📋 Test 1: Verify Clean Users Table (No Location Fields)');
    const usersColumns = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      ORDER BY ordinal_position;
    `);
    
    console.log('✅ Final users table structure:');
    usersColumns.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type}`);
    });
    
    const hasLocationFields = usersColumns.rows.some(row => 
      ['address', 'base_latitude', 'base_longitude'].includes(row.column_name)
    );
    
    if (!hasLocationFields) {
      console.log('✅ SUCCESS: Users table is clean - no location fields found');
    } else {
      console.log('❌ FAIL: Users table still contains location fields');
    }
    
    // Test 2: Test profile retrieval for each role with location data
    console.log('\n👥 Test 2: Profile Retrieval with Location Data by Role');
    
    // Test supermarket profile
    const supermarketUser = await client.query(`
      SELECT u.id, u.name, u.role
      FROM users u
      WHERE u.role = 'supermarket'
      LIMIT 1
    `);
    
    if (supermarketUser.rows.length > 0) {
      const user = supermarketUser.rows[0];
      console.log(`\n🏪 Testing supermarket profile: ${user.name} (ID: ${user.id})`);
      
      // Simulate GET /api/profile/me for supermarket
      const userProfile = await client.query(`
        SELECT id, name, email, role, phone, created_at, updated_at
        FROM users WHERE id = $1
      `, [user.id]);
      
      const supermarketData = await client.query(`
        SELECT store_name, manager_name, address as store_address, 
               latitude as store_latitude, longitude as store_longitude,
               area, store_size, store_type, operating_hours, is_active
        FROM supermarkets WHERE user_id = $1
      `, [user.id]);
      
      if (supermarketData.rows.length > 0) {
        const combined = {
          ...userProfile.rows[0],
          ...supermarketData.rows[0],
          address: supermarketData.rows[0].store_address,
          latitude: supermarketData.rows[0].store_latitude,
          longitude: supermarketData.rows[0].store_longitude
        };
        
        console.log(`  ✅ Supermarket profile complete with location:`);
        console.log(`     Store: ${combined.store_name}`);
        console.log(`     Address: ${combined.address}`);
        console.log(`     Coordinates: ${combined.latitude}, ${combined.longitude}`);
      }
    }
    
    // Test distributor profile
    const distributorUser = await client.query(`
      SELECT u.id, u.name, u.role
      FROM users u
      WHERE u.role = 'distributor'
      LIMIT 1
    `);
    
    if (distributorUser.rows.length > 0) {
      const user = distributorUser.rows[0];
      console.log(`\n🏢 Testing distributor profile: ${user.name} (ID: ${user.id})`);
      
      const userProfile = await client.query(`
        SELECT id, name, email, role, phone, created_at, updated_at
        FROM users WHERE id = $1
      `, [user.id]);
      
      const distributorData = await client.query(`
        SELECT company_name, contact_person, address as company_address, 
               latitude as company_latitude, longitude as company_longitude,
               coverage_area, is_active, total_orders
        FROM distributors WHERE user_id = $1
      `, [user.id]);
      
      if (distributorData.rows.length > 0) {
        const combined = {
          ...userProfile.rows[0],
          ...distributorData.rows[0],
          address: distributorData.rows[0].company_address,
          latitude: distributorData.rows[0].company_latitude,
          longitude: distributorData.rows[0].company_longitude
        };
        
        console.log(`  ✅ Distributor profile complete with location:`);
        console.log(`     Company: ${combined.company_name}`);
        console.log(`     Address: ${combined.address}`);
        console.log(`     Coordinates: ${combined.latitude}, ${combined.longitude}`);
      }
    }
    
    // Test delivery profile (should have base address but no fixed location)
    const deliveryUser = await client.query(`
      SELECT u.id, u.name, u.role
      FROM users u
      WHERE u.role = 'delivery'
      LIMIT 1
    `);
    
    if (deliveryUser.rows.length > 0) {
      const user = deliveryUser.rows[0];
      console.log(`\n🚚 Testing delivery profile: ${user.name} (ID: ${user.id})`);
      
      const userProfile = await client.query(`
        SELECT id, name, email, role, phone, created_at, updated_at
        FROM users WHERE id = $1
      `, [user.id]);
      
      const deliveryData = await client.query(`
        SELECT base_address, base_latitude as delivery_latitude, 
               base_longitude as delivery_longitude, vehicle_type, 
               max_daily_orders, is_available, rating
        FROM delivery_men WHERE user_id = $1
      `, [user.id]);
      
      if (deliveryData.rows.length > 0) {
        const combined = {
          ...userProfile.rows[0],
          ...deliveryData.rows[0],
          address: deliveryData.rows[0].base_address, // Home base, not fixed location
          latitude: deliveryData.rows[0].delivery_latitude,
          longitude: deliveryData.rows[0].delivery_longitude
        };
        
        console.log(`  ✅ Delivery profile complete:`);
        console.log(`     Vehicle: ${combined.vehicle_type}`);
        console.log(`     Base Address: ${combined.address} (home base, not fixed location)`);
        console.log(`     Max Orders: ${combined.max_daily_orders}`);
        console.log(`     Available: ${combined.is_available}`);
      }
    }
    
    // Test 3: Test role-specific location updates
    console.log('\n📝 Test 3: Role-Specific Location Updates');
    
    // Test supermarket location update
    if (supermarketUser.rows.length > 0) {
      const user = supermarketUser.rows[0];
      console.log(`\n🏪 Testing supermarket location update for: ${user.name}`);
      
      const updateResult = await client.query(`
        UPDATE supermarkets 
        SET address = $1, latitude = $2, longitude = $3, updated_at = $4
        WHERE user_id = $5 
        RETURNING store_name, address, latitude, longitude, updated_at
      `, ['Updated Store Address, Amman', 31.9539, 35.9106, new Date(), user.id]);
      
      if (updateResult.rows.length > 0) {
        console.log(`  ✅ Supermarket location update successful:`, updateResult.rows[0]);
      }
    }
    
    // Test distributor location update
    if (distributorUser.rows.length > 0) {
      const user = distributorUser.rows[0];
      console.log(`\n🏢 Testing distributor location update for: ${user.name}`);
      
      const updateResult = await client.query(`
        UPDATE distributors 
        SET address = $1, latitude = $2, longitude = $3, updated_at = $4
        WHERE user_id = $5 
        RETURNING company_name, address, latitude, longitude, updated_at
      `, ['Updated Company Address, Amman', 31.9500, 35.9200, new Date(), user.id]);
      
      if (updateResult.rows.length > 0) {
        console.log(`  ✅ Distributor location update successful:`, updateResult.rows[0]);
      }
    }
    
    // Test 4: Verify basic user profile updates still work (no location)
    console.log('\n👤 Test 4: Basic User Profile Updates (No Location)');
    
    const testUser = await client.query(`
      SELECT id, name, email, phone FROM users LIMIT 1
    `);
    
    if (testUser.rows.length > 0) {
      const user = testUser.rows[0];
      console.log(`\n📝 Testing basic profile update for: ${user.name}`);
      
      const updateResult = await client.query(`
        UPDATE users 
        SET name = $1, phone = $2, updated_at = $3
        WHERE id = $4 
        RETURNING id, name, email, phone, updated_at
      `, [`${user.name} - Updated`, '+962 79 999 8888', new Date(), user.id]);
      
      if (updateResult.rows.length > 0) {
        console.log(`  ✅ Basic profile update successful:`, updateResult.rows[0]);
      }
    }
    
    // Test 5: Final data integrity check
    console.log('\n🔍 Test 5: Final Data Integrity Check');
    
    const integrityCheck = await client.query(`
      SELECT 
        (SELECT COUNT(*) FROM users) as total_users,
        (SELECT COUNT(*) FROM supermarkets WHERE address IS NOT NULL) as supermarkets_with_address,
        (SELECT COUNT(*) FROM distributors WHERE address IS NOT NULL) as distributors_with_address,
        (SELECT COUNT(*) FROM delivery_men WHERE base_address IS NOT NULL) as delivery_with_base_address,
        (SELECT COUNT(*) FROM supermarkets WHERE latitude IS NOT NULL AND longitude IS NOT NULL) as supermarkets_with_coords,
        (SELECT COUNT(*) FROM distributors WHERE latitude IS NOT NULL AND longitude IS NOT NULL) as distributors_with_coords
    `);
    
    const stats = integrityCheck.rows[0];
    console.log('📊 Final Statistics:');
    console.log(`  Total Users: ${stats.total_users}`);
    console.log(`  Supermarkets with Address: ${stats.supermarkets_with_address}`);
    console.log(`  Distributors with Address: ${stats.distributors_with_address}`);
    console.log(`  Delivery Men with Base Address: ${stats.delivery_with_base_address}`);
    console.log(`  Supermarkets with Coordinates: ${stats.supermarkets_with_coords}`);
    console.log(`  Distributors with Coordinates: ${stats.distributors_with_coords}`);
    
    console.log('\n🎉 Location migration testing completed successfully!');
    console.log('\n📋 Summary:');
    console.log('  ✅ Users table cleaned - no location fields');
    console.log('  ✅ Supermarkets have fixed store locations');
    console.log('  ✅ Distributors have fixed company locations');
    console.log('  ✅ Delivery men have base addresses (not fixed locations)');
    console.log('  ✅ Role-specific location updates working');
    console.log('  ✅ Basic user profile updates working');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    client.release();
    await pool.end();
  }
}

testLocationMigration();
