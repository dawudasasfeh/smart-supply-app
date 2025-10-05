const pool = require('./db');

async function checkOrdersTable() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Checking orders table structure...\n');
    
    const columns = await client.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'orders' 
      ORDER BY ordinal_position;
    `);
    
    console.log('📋 Orders table columns:');
    columns.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });
    
  } catch (error) {
    console.error('❌ Error checking orders table:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

checkOrdersTable();
