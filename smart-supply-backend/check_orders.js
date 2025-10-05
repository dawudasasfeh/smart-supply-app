const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'GP',
  password: 'dawud',
  port: 5432,
});

async function checkOrders() {
  try {
    // Check total orders
    const totalOrders = await pool.query('SELECT COUNT(*) as count FROM orders');
    console.log('📊 Total orders in database:', totalOrders.rows[0].count);
    
    // Check orders table structure
    const structure = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'orders'
    `);
    console.log('📋 Orders table columns:');
    structure.rows.forEach(col => {
      console.log(`  - ${col.column_name}: ${col.data_type}`);
    });
    
    // Check sample orders
    const sampleOrders = await pool.query('SELECT * FROM orders LIMIT 3');
    console.log('📦 Sample orders:', sampleOrders.rows);
    
    // Check users with supermarket role
    const supermarkets = await pool.query(`
      SELECT id, name, email, role 
      FROM users 
      WHERE role = 'supermarket'
    `);
    console.log('🏪 Supermarket users:', supermarkets.rows);
    
    // If we have supermarket users, check their orders
    if (supermarkets.rows.length > 0) {
      const buyerId = supermarkets.rows[0].id;
      console.log(`\n🔍 Checking orders for supermarket user ID: ${buyerId}`);
      
      const buyerOrders = await pool.query(`
        SELECT id, buyer_id, status, total_amount, created_at 
        FROM orders 
        WHERE buyer_id = $1
      `, [buyerId]);
      
      console.log(`📦 Orders for buyer ${buyerId}:`, buyerOrders.rows.length);
      if (buyerOrders.rows.length > 0) {
        console.log('Sample order:', buyerOrders.rows[0]);
      }
    }
    
    await pool.end();
  } catch (err) {
    console.error('❌ Error:', err.message);
    await pool.end();
    process.exit(1);
  }
}

checkOrders();
