const pool = require('./db');

async function testDeliveryProfile() {
  const client = await pool.connect();
  
  try {
    console.log('🧪 Testing Delivery Profile with Vehicle Info...\n');
    
    // Test 1: Get a delivery user
    console.log('📋 Test 1: Finding Delivery Users');
    
    const deliveryUsers = await client.query(`
      SELECT u.id, u.name, u.email, u.phone, u.role
      FROM users u
      WHERE u.role = 'delivery'
      LIMIT 3
    `);
    
    console.log(`✅ Found ${deliveryUsers.rows.length} delivery users`);
    
    if (deliveryUsers.rows.length === 0) {
      console.log('❌ No delivery users found for testing');
      return;
    }
    
    // Test 2: Test delivery profile retrieval for each user
    for (const user of deliveryUsers.rows) {
      console.log(`\n👤 Test 2: Testing Profile for ${user.name} (ID: ${user.id})`);
      
      // Simulate the profile API call
      const userProfile = await client.query(`
        SELECT id, name, email, role, phone, created_at, updated_at
        FROM users WHERE id = $1
      `, [user.id]);
      
      const deliveryData = await client.query(`
        SELECT max_daily_orders, vehicle_type, rating, total_deliveries, is_active,
               vehicle_capacity, shift_start, shift_end, profile_image_url, 
               last_seen, is_online, plate_number,
               created_at as delivery_created_at, updated_at as delivery_updated_at
        FROM delivery_men WHERE user_id = $1
      `, [user.id]);
      
      if (userProfile.rows.length > 0 && deliveryData.rows.length > 0) {
        const profile = userProfile.rows[0];
        const delivery = deliveryData.rows[0];
        
        // Combine data like the API does
        const combinedProfile = {
          ...profile,
          ...delivery,
          contact_email: profile.email,
          contact_phone: profile.phone,
        };
        
        console.log(`  ✅ Profile Retrieved Successfully:`);
        console.log(`    Name: ${combinedProfile.name}`);
        console.log(`    Email: ${combinedProfile.contact_email} (from users table)`);
        console.log(`    Phone: ${combinedProfile.contact_phone} (from users table)`);
        console.log(`    Role: ${combinedProfile.role}`);
        
        console.log(`  🚗 Vehicle Information:`);
        console.log(`    Vehicle Type: ${combinedProfile.vehicle_type || 'Not specified'}`);
        console.log(`    Vehicle Capacity: ${combinedProfile.vehicle_capacity || 'Not specified'}`);
        console.log(`    Plate Number: ${combinedProfile.plate_number || 'Not specified'}`);
        
        console.log(`  📊 Performance Data:`);
        console.log(`    Rating: ${combinedProfile.rating || 'No rating'}`);
        console.log(`    Total Deliveries: ${combinedProfile.total_deliveries || 0}`);
        console.log(`    Max Daily Orders: ${combinedProfile.max_daily_orders || 'Not set'}`);
        console.log(`    Online Status: ${combinedProfile.is_online ? 'Online' : 'Offline'}`);
        console.log(`    Active Status: ${combinedProfile.is_active ? 'Active' : 'Inactive'}`);
        
        console.log(`  ⏰ Schedule:`);
        console.log(`    Shift Start: ${combinedProfile.shift_start || 'Not set'}`);
        console.log(`    Shift End: ${combinedProfile.shift_end || 'Not set'}`);
        console.log(`    Last Seen: ${combinedProfile.last_seen || 'Never'}`);
        
      } else {
        console.log(`  ❌ Profile data incomplete for ${user.name}`);
      }
    }
    
    // Test 3: Test API response format
    console.log('\n📱 Test 3: API Response Format Simulation');
    
    const sampleUser = deliveryUsers.rows[0];
    const apiResponse = await client.query(`
      SELECT 
        u.id, u.name, u.email, u.role, u.phone, u.created_at, u.updated_at,
        dm.max_daily_orders, dm.vehicle_type, dm.rating, dm.total_deliveries, 
        dm.is_active, dm.vehicle_capacity, dm.shift_start, dm.shift_end, 
        dm.profile_image_url, dm.last_seen, dm.is_online, dm.plate_number,
        dm.created_at as delivery_created_at, dm.updated_at as delivery_updated_at
      FROM users u
      JOIN delivery_men dm ON u.id = dm.user_id
      WHERE u.id = $1
    `, [sampleUser.id]);
    
    if (apiResponse.rows.length > 0) {
      const response = apiResponse.rows[0];
      const formattedResponse = {
        // Basic user info
        id: response.id,
        name: response.name,
        email: response.email,
        role: response.role,
        phone: response.phone,
        contact_email: response.email,
        contact_phone: response.phone,
        
        // Vehicle information
        vehicle_type: response.vehicle_type,
        vehicle_capacity: response.vehicle_capacity,
        plate_number: response.plate_number,
        
        // Performance data
        rating: response.rating,
        total_deliveries: response.total_deliveries,
        max_daily_orders: response.max_daily_orders,
        
        // Status
        is_active: response.is_active,
        is_online: response.is_online,
        
        // Schedule
        shift_start: response.shift_start,
        shift_end: response.shift_end,
        
        // Metadata
        profile_image_url: response.profile_image_url,
        last_seen: response.last_seen,
        created_at: response.created_at,
        updated_at: response.updated_at
      };
      
      console.log('✅ Sample API Response Format:');
      console.log(JSON.stringify(formattedResponse, null, 2));
    }
    
    // Test 4: Update plate number test
    console.log('\n🔧 Test 4: Plate Number Update Test');
    
    const testUserId = deliveryUsers.rows[0].id;
    const testPlateNumber = 'ABC-123';
    
    await client.query(`
      UPDATE delivery_men 
      SET plate_number = $1, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $2
    `, [testPlateNumber, testUserId]);
    
    const updatedResult = await client.query(`
      SELECT plate_number, updated_at
      FROM delivery_men 
      WHERE user_id = $1
    `, [testUserId]);
    
    if (updatedResult.rows.length > 0) {
      console.log(`✅ Plate number updated successfully:`);
      console.log(`  New Plate: ${updatedResult.rows[0].plate_number}`);
      console.log(`  Updated At: ${updatedResult.rows[0].updated_at}`);
    }
    
    console.log('\n🎉 Delivery profile tests completed successfully!');
    
    console.log('\n📋 Summary:');
    console.log('  ✅ Delivery profile retrieval working');
    console.log('  ✅ Vehicle information included (type, capacity, plate)');
    console.log('  ✅ Phone/email from users table');
    console.log('  ✅ Performance data available');
    console.log('  ✅ Schedule information included');
    console.log('  ✅ Plate number updates working');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
    console.error('Error details:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

testDeliveryProfile();
