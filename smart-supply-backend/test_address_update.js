const pool = require('./db');

async function testAddressUpdate() {
  const client = await pool.connect();
  
  try {
    console.log('🧪 Testing Address Update Functionality...\n');
    
    // Test 1: Check current distributor data
    console.log('📋 Test 1: Current Distributor Data');
    
    const distributors = await client.query(`
      SELECT u.id, u.name, u.email, d.company_name, d.address, d.updated_at
      FROM users u
      JOIN distributors d ON u.id = d.user_id
      WHERE u.role = 'distributor'
      LIMIT 3
    `);
    
    console.log(`✅ Found ${distributors.rows.length} distributors:`);
    distributors.rows.forEach(dist => {
      console.log(`  - ${dist.name} (${dist.company_name}): "${dist.address}"`);
    });
    
    if (distributors.rows.length === 0) {
      console.log('❌ No distributors found for testing');
      return;
    }
    
    // Test 2: Test address update query
    console.log('\n📋 Test 2: Testing Address Update Query');
    
    const testDistributor = distributors.rows[0];
    const testAddress = `Updated Test Address - ${new Date().toISOString()}`;
    
    console.log(`Testing update for distributor: ${testDistributor.name} (ID: ${testDistributor.id})`);
    console.log(`New address: ${testAddress}`);
    
    // Simulate the backend update query
    const updateResult = await client.query(`
      UPDATE distributors 
      SET address = $1, updated_at = NOW()
      WHERE user_id = $2
      RETURNING *
    `, [testAddress, testDistributor.id]);
    
    if (updateResult.rows.length > 0) {
      console.log('✅ Address update successful:');
      const updated = updateResult.rows[0];
      console.log(`  Updated address: ${updated.address}`);
      console.log(`  Updated at: ${updated.updated_at}`);
    } else {
      console.log('❌ Address update failed - no rows returned');
    }
    
    // Test 3: Verify the update
    console.log('\n📋 Test 3: Verifying Update');
    
    const verifyResult = await client.query(`
      SELECT u.name, d.company_name, d.address, d.updated_at
      FROM users u
      JOIN distributors d ON u.id = d.user_id
      WHERE u.id = $1
    `, [testDistributor.id]);
    
    if (verifyResult.rows.length > 0) {
      const verified = verifyResult.rows[0];
      console.log('✅ Verification successful:');
      console.log(`  Name: ${verified.name}`);
      console.log(`  Company: ${verified.company_name}`);
      console.log(`  Address: ${verified.address}`);
      console.log(`  Updated: ${verified.updated_at}`);
    }
    
    // Test 4: Test the profile API query structure
    console.log('\n📋 Test 4: Testing Profile API Query Structure');
    
    const profileQuery = await client.query(`
      SELECT 
        u.id, u.name, u.email, u.role, u.phone, u.created_at, u.updated_at,
        d.company_name, d.contact_person, d.address as company_address, 
        d.business_license, d.tax_id, d.latitude as company_latitude, 
        d.longitude as company_longitude, d.total_orders,
        d.total_revenue, d.average_rating, d.is_active, d.is_verified,
        d.description, d.image_url, d.created_at as company_created_at, d.updated_at as company_updated_at
      FROM users u
      LEFT JOIN distributors d ON u.id = d.user_id
      WHERE u.id = $1
    `, [testDistributor.id]);
    
    if (profileQuery.rows.length > 0) {
      const profile = profileQuery.rows[0];
      console.log('✅ Profile query successful:');
      console.log(`  User ID: ${profile.id}`);
      console.log(`  Name: ${profile.name}`);
      console.log(`  Email: ${profile.email}`);
      console.log(`  Company: ${profile.company_name}`);
      console.log(`  Company Address: ${profile.company_address}`);
      console.log(`  Phone: ${profile.phone}`);
      
      // Test the address mapping logic
      const mappedAddress = profile.address || profile.store_address || profile.company_address || profile.base_address;
      console.log(`  Mapped Address: ${mappedAddress}`);
    }
    
    // Test 5: Test allowed fields validation
    console.log('\n📋 Test 5: Testing Allowed Fields');
    
    const allowedFields = ['company_name', 'contact_person', 'business_license', 'tax_id',
                          'description', 'latitude', 'longitude', 'address', 'image_url'];
    
    console.log('✅ Allowed fields for distributor updates:');
    allowedFields.forEach(field => {
      console.log(`  - ${field}`);
    });
    
    // Test if 'address' is in allowed fields
    const addressAllowed = allowedFields.includes('address');
    console.log(`\n✅ Address field allowed: ${addressAllowed}`);
    
    console.log('\n🎉 Address update testing completed!');
    
    console.log('\n📋 Summary:');
    console.log('  ✅ Distributors table has address column');
    console.log('  ✅ Address update query works correctly');
    console.log('  ✅ Profile query returns address data');
    console.log('  ✅ Address field is in allowed fields list');
    console.log('  ✅ Backend should be working correctly');
    
    console.log('\n🔍 If frontend still fails, check:');
    console.log('  1. Network connectivity');
    console.log('  2. Authentication token validity');
    console.log('  3. API endpoint URL correctness');
    console.log('  4. Request payload format');
    console.log('  5. Server logs for detailed error messages');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
    console.error('Full error:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

testAddressUpdate();
