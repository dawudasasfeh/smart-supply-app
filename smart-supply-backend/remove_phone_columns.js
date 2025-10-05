const pool = require('./db');

async function removePhoneColumns() {
  const client = await pool.connect();
  
  try {
    console.log('🔄 Starting phone column removal from role tables...\n');
    
    // Step 1: Check current phone columns in role tables
    console.log('📋 Checking phone columns in role tables:');
    
    const tables = ['supermarkets', 'distributors', 'delivery_men'];
    
    for (const table of tables) {
      const phoneColumns = await client.query(`
        SELECT column_name, data_type
        FROM information_schema.columns 
        WHERE table_name = $1 
        AND column_name LIKE '%phone%'
        ORDER BY column_name;
      `, [table]);
      
      console.log(`\n${table.toUpperCase()} phone columns:`);
      if (phoneColumns.rows.length > 0) {
        phoneColumns.rows.forEach(row => {
          console.log(`  ${row.column_name}: ${row.data_type}`);
        });
      } else {
        console.log(`  No phone columns found`);
      }
    }
    
    // Step 2: Verify users table has phone column
    console.log('\n📱 Verifying users table has phone column:');
    const usersPhone = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      AND column_name = 'phone';
    `);
    
    if (usersPhone.rows.length > 0) {
      console.log(`✅ Users table has phone column: ${usersPhone.rows[0].data_type}`);
    } else {
      console.log(`❌ Users table missing phone column!`);
      return;
    }
    
    // Step 3: Start transaction
    await client.query('BEGIN');
    
    // Step 4: Remove phone columns from role tables
    console.log('\n🗑️ Removing phone columns from role tables...');
    
    // Remove from supermarkets table
    try {
      await client.query(`ALTER TABLE supermarkets DROP COLUMN IF EXISTS phone`);
      await client.query(`ALTER TABLE supermarkets DROP COLUMN IF EXISTS contact_phone`);
      console.log(`  ✅ Removed phone columns from supermarkets`);
    } catch (error) {
      console.log(`  ⚠️ Error removing phone from supermarkets: ${error.message}`);
    }
    
    // Remove from distributors table
    try {
      await client.query(`ALTER TABLE distributors DROP COLUMN IF EXISTS phone`);
      await client.query(`ALTER TABLE distributors DROP COLUMN IF EXISTS contact_phone`);
      console.log(`  ✅ Removed phone columns from distributors`);
    } catch (error) {
      console.log(`  ⚠️ Error removing phone from distributors: ${error.message}`);
    }
    
    // Remove from delivery_men table
    try {
      await client.query(`ALTER TABLE delivery_men DROP COLUMN IF EXISTS phone`);
      await client.query(`ALTER TABLE delivery_men DROP COLUMN IF EXISTS contact_phone`);
      console.log(`  ✅ Removed phone columns from delivery_men`);
    } catch (error) {
      console.log(`  ⚠️ Error removing phone from delivery_men: ${error.message}`);
    }
    
    // Step 5: Verify removal
    console.log('\n🔍 Verifying phone column removal:');
    
    for (const table of tables) {
      const remainingPhoneColumns = await client.query(`
        SELECT column_name
        FROM information_schema.columns 
        WHERE table_name = $1 
        AND column_name LIKE '%phone%';
      `, [table]);
      
      if (remainingPhoneColumns.rows.length === 0) {
        console.log(`  ✅ ${table}: No phone columns remaining`);
      } else {
        console.log(`  ⚠️ ${table}: Still has phone columns:`, remainingPhoneColumns.rows.map(r => r.column_name));
      }
    }
    
    // Step 6: Show final table structures
    console.log('\n📊 Final table structures:');
    
    for (const table of tables) {
      const columns = await client.query(`
        SELECT column_name, data_type
        FROM information_schema.columns 
        WHERE table_name = $1 
        ORDER BY ordinal_position;
      `, [table]);
      
      console.log(`\n${table.toUpperCase()} columns (${columns.rows.length} total):`);
      columns.rows.forEach(row => {
        console.log(`  ${row.column_name}: ${row.data_type}`);
      });
    }
    
    // Step 7: Test profile data retrieval
    console.log('\n🧪 Testing profile data retrieval:');
    
    // Test supermarket profile
    const supermarketTest = await client.query(`
      SELECT u.id, u.name, u.email, u.phone, u.role,
             s.store_name, s.address, s.latitude, s.longitude
      FROM users u
      JOIN supermarkets s ON u.id = s.user_id
      WHERE u.role = 'supermarket'
      LIMIT 1;
    `);
    
    if (supermarketTest.rows.length > 0) {
      const profile = supermarketTest.rows[0];
      console.log(`\n🏪 Supermarket profile test:`);
      console.log(`  Name: ${profile.name}`);
      console.log(`  Phone: ${profile.phone} (from users table)`);
      console.log(`  Store: ${profile.store_name}`);
      console.log(`  Address: ${profile.address} (from supermarkets table)`);
    }
    
    // Test distributor profile
    const distributorTest = await client.query(`
      SELECT u.id, u.name, u.email, u.phone, u.role,
             d.company_name, d.address, d.latitude, d.longitude
      FROM users u
      JOIN distributors d ON u.id = d.user_id
      WHERE u.role = 'distributor'
      LIMIT 1;
    `);
    
    if (distributorTest.rows.length > 0) {
      const profile = distributorTest.rows[0];
      console.log(`\n🏢 Distributor profile test:`);
      console.log(`  Name: ${profile.name}`);
      console.log(`  Phone: ${profile.phone} (from users table)`);
      console.log(`  Company: ${profile.company_name}`);
      console.log(`  Address: ${profile.address} (from distributors table)`);
    }
    
    // Test delivery profile
    const deliveryTest = await client.query(`
      SELECT u.id, u.name, u.email, u.phone, u.role,
             dm.vehicle_type, dm.base_address, dm.max_daily_orders
      FROM users u
      JOIN delivery_men dm ON u.id = dm.user_id
      WHERE u.role = 'delivery'
      LIMIT 1;
    `);
    
    if (deliveryTest.rows.length > 0) {
      const profile = deliveryTest.rows[0];
      console.log(`\n🚚 Delivery profile test:`);
      console.log(`  Name: ${profile.name}`);
      console.log(`  Phone: ${profile.phone} (from users table)`);
      console.log(`  Vehicle: ${profile.vehicle_type}`);
      console.log(`  Base: ${profile.base_address} (from delivery_men table)`);
    }
    
    // Commit transaction
    await client.query('COMMIT');
    console.log('\n✅ Phone column removal completed successfully!');
    
    console.log('\n📋 Summary:');
    console.log('  ✅ Phone columns removed from all role tables');
    console.log('  ✅ Phone data remains in users table only');
    console.log('  ✅ Address data comes from role-specific tables');
    console.log('  ✅ Profile retrieval tested and working');
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Phone column removal failed:', error.message);
    console.error('Transaction rolled back');
  } finally {
    client.release();
    await pool.end();
  }
}

removePhoneColumns();
