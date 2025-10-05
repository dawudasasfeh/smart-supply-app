const pool = require('./db');

async function fixLocationColumns() {
  const client = await pool.connect();
  
  try {
    console.log('🔧 Adding location columns to users table...\n');
    
    // Add columns if they don't exist
    await client.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS base_latitude DECIMAL(10, 8);
    `);
    
    await client.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS base_longitude DECIMAL(11, 8);
    `);
    
    console.log('✅ Location columns added successfully!');
    
    // Check the columns now exist
    const result = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      AND column_name IN ('base_latitude', 'base_longitude', 'address')
      ORDER BY column_name;
    `);
    
    console.log('\n📋 Location-related columns in users table:');
    result.rows.forEach(row => {
      console.log(`${row.column_name}: ${row.data_type}`);
    });
    
    // Test update query
    console.log('\n🧪 Testing update query...');
    const testResult = await client.query(`
      UPDATE users SET address = 'Test Address', base_latitude = 31.9539, base_longitude = 35.9106 
      WHERE id = 1 
      RETURNING id, address, base_latitude, base_longitude;
    `);
    
    if (testResult.rows.length > 0) {
      console.log('✅ Update test successful:', testResult.rows[0]);
    } else {
      console.log('⚠️ No user with ID 1 found for testing');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    client.release();
    await pool.end();
  }
}

fixLocationColumns();
