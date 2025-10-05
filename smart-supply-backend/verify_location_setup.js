const pool = require('./db');

async function verifyLocationSetup() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Verifying location setup...\n');
    
    // 1. Check if location columns exist
    const columnsResult = await client.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      AND column_name IN ('base_latitude', 'base_longitude', 'address')
      ORDER BY column_name;
    `);
    
    console.log('📋 Location columns in users table:');
    columnsResult.rows.forEach(row => {
      console.log(`✅ ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });
    
    // 2. Check if we have any users to test with
    const usersResult = await client.query(`
      SELECT id, name, email, role, address, base_latitude, base_longitude
      FROM users 
      ORDER BY id 
      LIMIT 5;
    `);
    
    console.log(`\n👥 Sample users (${usersResult.rows.length} found):`);
    usersResult.rows.forEach(user => {
      console.log(`ID: ${user.id}, Name: ${user.name}, Role: ${user.role}`);
      console.log(`   Address: ${user.address || 'Not set'}`);
      console.log(`   Coordinates: ${user.base_latitude || 'Not set'}, ${user.base_longitude || 'Not set'}`);
    });
    
    // 3. Test update query syntax
    if (usersResult.rows.length > 0) {
      const testUserId = usersResult.rows[0].id;
      console.log(`\n🧪 Testing update query for user ${testUserId}...`);
      
      const updateResult = await client.query(`
        UPDATE users 
        SET address = $1, base_latitude = $2, base_longitude = $3 
        WHERE id = $4 
        RETURNING id, address, base_latitude, base_longitude;
      `, ['Test Address - Amman, Jordan', 31.9539, 35.9106, testUserId]);
      
      if (updateResult.rows.length > 0) {
        console.log('✅ Update test successful:', updateResult.rows[0]);
      }
    }
    
    console.log('\n🎉 Location setup verification complete!');
    
  } catch (error) {
    console.error('❌ Error during verification:', error.message);
  } finally {
    client.release();
    await pool.end();
  }
}

verifyLocationSetup();
