const pool = require('./db');

async function checkUsersTableStructure() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Checking users table structure...\n');
    
    // Get table structure
    const result = await client.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      ORDER BY ordinal_position;
    `);
    
    console.log('📋 Users table columns:');
    result.rows.forEach(row => {
      console.log(`${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });
    
    // Check if latitude/longitude columns exist
    const hasLatitude = result.rows.some(row => row.column_name === 'base_latitude' || row.column_name === 'latitude');
    const hasLongitude = result.rows.some(row => row.column_name === 'base_longitude' || row.column_name === 'longitude');
    
    console.log(`\n📍 Location columns:`);
    console.log(`Has latitude column: ${hasLatitude}`);
    console.log(`Has longitude column: ${hasLongitude}`);
    
    if (!hasLatitude || !hasLongitude) {
      console.log('\n⚠️ Missing location columns! Need to add them.');
      console.log('SQL to add columns:');
      console.log('ALTER TABLE users ADD COLUMN base_latitude DECIMAL(10, 8);');
      console.log('ALTER TABLE users ADD COLUMN base_longitude DECIMAL(11, 8);');
    }
    
  } catch (error) {
    console.error('❌ Error checking table structure:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

checkUsersTableStructure();
