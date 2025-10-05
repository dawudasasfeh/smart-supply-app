const pool = require('./db');

async function checkUsers() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Checking users in database...\n');
    
    // Get all users
    const users = await client.query(`
      SELECT id, name, email, role, created_at 
      FROM users 
      ORDER BY created_at DESC
    `);
    
    console.log('📋 Current users in database:');
    users.rows.forEach(row => {
      console.log(`ID: ${row.id}, Name: ${row.name}, Email: ${row.email}, Role: ${row.role}, Created: ${row.created_at}`);
    });
    
    console.log(`\nTotal users: ${users.rows.length}`);
    
    // Check for any orphaned role data
    console.log('\n🔍 Checking for orphaned role data...');
    
    const supermarkets = await client.query('SELECT user_id FROM supermarkets');
    const distributors = await client.query('SELECT user_id FROM distributors');
    const deliveryMen = await client.query('SELECT user_id FROM delivery_men');
    
    console.log(`Supermarkets: ${supermarkets.rows.length}`);
    console.log(`Distributors: ${distributors.rows.length}`);
    console.log(`Delivery Men: ${deliveryMen.rows.length}`);
    
  } catch (error) {
    console.error('❌ Error checking users:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

checkUsers();
