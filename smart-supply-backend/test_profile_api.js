const pool = require('./db');

async function testProfileAPI() {
  const client = await pool.connect();
  
  try {
    console.log('🧪 Testing Profile API Endpoints...\n');
    
    // 1. Test if we have users to work with
    const usersResult = await client.query(`
      SELECT id, name, email, phone, address, role, created_at, updated_at
      FROM users 
      ORDER BY id 
      LIMIT 3;
    `);
    
    console.log('👥 Available test users:');
    usersResult.rows.forEach(user => {
      console.log(`  ID: ${user.id}, Name: ${user.name}, Email: ${user.email}, Role: ${user.role}`);
    });
    
    if (usersResult.rows.length === 0) {
      console.log('❌ No users found for testing');
      return;
    }
    
    const testUser = usersResult.rows[0];
    console.log(`\n🎯 Using test user: ${testUser.name} (ID: ${testUser.id})\n`);
    
    // 2. Test profile retrieval (simulate GET /api/profile/me)
    console.log('📋 Test 1: Profile Retrieval');
    const profileQuery = await client.query(`
      SELECT id, name, email, role, phone, address,
             base_latitude as latitude, base_longitude as longitude,
             created_at, updated_at
      FROM users WHERE id = $1
    `, [testUser.id]);
    
    if (profileQuery.rows.length > 0) {
      console.log('✅ Profile retrieval successful:', profileQuery.rows[0]);
    } else {
      console.log('❌ Profile retrieval failed');
    }
    
    // 3. Test profile update - Name
    console.log('\n📝 Test 2: Update Name');
    const newName = `${testUser.name} Updated`;
    const nameUpdateResult = await client.query(`
      UPDATE users SET name = $1, updated_at = $2 
      WHERE id = $3 
      RETURNING id, name, updated_at
    `, [newName, new Date(), testUser.id]);
    
    if (nameUpdateResult.rows.length > 0) {
      console.log('✅ Name update successful:', nameUpdateResult.rows[0]);
    } else {
      console.log('❌ Name update failed');
    }
    
    // 4. Test profile update - Email
    console.log('\n📧 Test 3: Update Email');
    const newEmail = `updated_${testUser.email}`;
    const emailUpdateResult = await client.query(`
      UPDATE users SET email = $1, updated_at = $2 
      WHERE id = $3 
      RETURNING id, email, updated_at
    `, [newEmail, new Date(), testUser.id]);
    
    if (emailUpdateResult.rows.length > 0) {
      console.log('✅ Email update successful:', emailUpdateResult.rows[0]);
    } else {
      console.log('❌ Email update failed');
    }
    
    // 5. Test profile update - Phone
    console.log('\n📱 Test 4: Update Phone');
    const newPhone = '+962 79 123 4567';
    const phoneUpdateResult = await client.query(`
      UPDATE users SET phone = $1, updated_at = $2 
      WHERE id = $3 
      RETURNING id, phone, updated_at
    `, [newPhone, new Date(), testUser.id]);
    
    if (phoneUpdateResult.rows.length > 0) {
      console.log('✅ Phone update successful:', phoneUpdateResult.rows[0]);
    } else {
      console.log('❌ Phone update failed');
    }
    
    // 6. Test profile update - Address with coordinates
    console.log('\n🏠 Test 5: Update Address with Coordinates');
    const newAddress = 'Amman, Jordan - Updated Location';
    const newLat = 31.9539;
    const newLng = 35.9106;
    
    const addressUpdateResult = await client.query(`
      UPDATE users SET address = $1, base_latitude = $2, base_longitude = $3, updated_at = $4 
      WHERE id = $5 
      RETURNING id, address, base_latitude as latitude, base_longitude as longitude, updated_at
    `, [newAddress, newLat, newLng, new Date(), testUser.id]);
    
    if (addressUpdateResult.rows.length > 0) {
      console.log('✅ Address update successful:', addressUpdateResult.rows[0]);
    } else {
      console.log('❌ Address update failed');
    }
    
    // 7. Test complete profile retrieval after updates
    console.log('\n🔍 Test 6: Final Profile State');
    const finalProfileQuery = await client.query(`
      SELECT id, name, email, role, phone, address,
             base_latitude as latitude, base_longitude as longitude,
             created_at, updated_at
      FROM users WHERE id = $1
    `, [testUser.id]);
    
    if (finalProfileQuery.rows.length > 0) {
      console.log('✅ Final profile state:', finalProfileQuery.rows[0]);
    }
    
    // 8. Test validation scenarios
    console.log('\n⚠️ Test 7: Validation Tests');
    
    // Test invalid email format
    try {
      const invalidEmailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      const testEmail = 'invalid-email';
      const isValidEmail = invalidEmailRegex.test(testEmail);
      console.log(`Email validation for "${testEmail}": ${isValidEmail ? '✅ Valid' : '❌ Invalid'}`);
    } catch (e) {
      console.log('Email validation test failed:', e.message);
    }
    
    // Test phone validation
    const testPhone = '123'; // Too short
    const isValidPhone = testPhone.length >= 10;
    console.log(`Phone validation for "${testPhone}": ${isValidPhone ? '✅ Valid' : '❌ Invalid (too short)'}`);
    
    console.log('\n🎉 Profile API testing completed!');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    client.release();
    await pool.end();
  }
}

testProfileAPI();
