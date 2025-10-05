const pool = require('./db');

async function cleanupRoleTables() {
  const client = await pool.connect();
  
  try {
    console.log('🔄 Starting role tables cleanup...\n');
    
    // Step 1: Analyze current structures
    console.log('📋 Current table structures:');
    
    const tables = ['supermarkets', 'distributors', 'delivery_men'];
    
    for (const table of tables) {
      const columns = await client.query(`
        SELECT column_name, data_type
        FROM information_schema.columns 
        WHERE table_name = $1 
        ORDER BY ordinal_position;
      `, [table]);
      
      console.log(`\n${table.toUpperCase()} (${columns.rows.length} columns):`);
      columns.rows.forEach(row => {
        console.log(`  ${row.column_name}: ${row.data_type}`);
      });
    }
    
    // Step 2: Start transaction
    await client.query('BEGIN');
    
    // Step 3: Clean up SUPERMARKETS table
    console.log('\n🏪 Cleaning up SUPERMARKETS table...');
    
    // Remove email column
    try {
      await client.query(`ALTER TABLE supermarkets DROP COLUMN IF EXISTS email`);
      console.log(`  ✅ Removed email column`);
    } catch (error) {
      console.log(`  ⚠️ Error removing email: ${error.message}`);
    }
    
    // Add image_url column
    try {
      await client.query(`ALTER TABLE supermarkets ADD COLUMN IF NOT EXISTS image_url TEXT`);
      console.log(`  ✅ Added image_url column`);
    } catch (error) {
      console.log(`  ⚠️ Error adding image_url: ${error.message}`);
    }
    
    // Step 4: Clean up DISTRIBUTORS table
    console.log('\n🏢 Cleaning up DISTRIBUTORS table...');
    
    // Remove columns
    const distributorColumnsToRemove = ['email', 'coverage_area', 'license_number'];
    
    for (const column of distributorColumnsToRemove) {
      try {
        await client.query(`ALTER TABLE distributors DROP COLUMN IF EXISTS ${column}`);
        console.log(`  ✅ Removed ${column} column`);
      } catch (error) {
        console.log(`  ⚠️ Error removing ${column}: ${error.message}`);
      }
    }
    
    // Add image_url column
    try {
      await client.query(`ALTER TABLE distributors ADD COLUMN IF NOT EXISTS image_url TEXT`);
      console.log(`  ✅ Added image_url column`);
    } catch (error) {
      console.log(`  ⚠️ Error adding image_url: ${error.message}`);
    }
    
    // Step 5: Clean up DELIVERY_MEN table (most complex)
    console.log('\n🚚 Cleaning up DELIVERY_MEN table...');
    
    // Remove columns that are not needed
    const deliveryColumnsToRemove = [
      'email',
      'base_address', 
      'base_latitude', 
      'base_longitude',
      'current_latitude', 
      'current_longitude', 
      'last_location_update',
      'emergency_contact', 
      'emergency_phone',
      'is_available', // keeping is_online
      'current_location_lat', 
      'current_location_lng',
      'device_token',
      'app_version',
      'license_number',
      'license_plate',
      'max_capacity' // keeping vehicle_capacity
    ];
    
    for (const column of deliveryColumnsToRemove) {
      try {
        await client.query(`ALTER TABLE delivery_men DROP COLUMN IF EXISTS ${column}`);
        console.log(`  ✅ Removed ${column} column`);
      } catch (error) {
        console.log(`  ⚠️ Error removing ${column}: ${error.message}`);
      }
    }
    
    // Add plate_number column (replacement for license_plate)
    try {
      await client.query(`ALTER TABLE delivery_men ADD COLUMN IF NOT EXISTS plate_number VARCHAR(20)`);
      console.log(`  ✅ Added plate_number column (replacement for license_plate)`);
    } catch (error) {
      console.log(`  ⚠️ Error adding plate_number: ${error.message}`);
    }
    
    // Step 6: Verify final structures
    console.log('\n📊 Final table structures:');
    
    for (const table of tables) {
      const finalColumns = await client.query(`
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns 
        WHERE table_name = $1 
        ORDER BY ordinal_position;
      `, [table]);
      
      console.log(`\n${table.toUpperCase()} (${finalColumns.rows.length} columns):`);
      finalColumns.rows.forEach(row => {
        console.log(`  ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
      });
    }
    
    // Step 7: Test data retrieval with new structure
    console.log('\n🧪 Testing data retrieval with new structure:');
    
    // Test supermarket data
    const supermarketTest = await client.query(`
      SELECT u.id, u.name, u.email, u.phone,
             s.store_name, s.address, s.image_url, s.is_active
      FROM users u
      JOIN supermarkets s ON u.id = s.user_id
      WHERE u.role = 'supermarket'
      LIMIT 1;
    `);
    
    if (supermarketTest.rows.length > 0) {
      const profile = supermarketTest.rows[0];
      console.log(`\n🏪 Supermarket profile test:`);
      console.log(`  Name: ${profile.name}`);
      console.log(`  Email: ${profile.email} (from users table)`);
      console.log(`  Phone: ${profile.phone} (from users table)`);
      console.log(`  Store: ${profile.store_name}`);
      console.log(`  Address: ${profile.address}`);
      console.log(`  Image URL: ${profile.image_url || 'NULL (ready for future use)'}`);
    }
    
    // Test distributor data
    const distributorTest = await client.query(`
      SELECT u.id, u.name, u.email, u.phone,
             d.company_name, d.address, d.image_url, d.is_active
      FROM users u
      JOIN distributors d ON u.id = d.user_id
      WHERE u.role = 'distributor'
      LIMIT 1;
    `);
    
    if (distributorTest.rows.length > 0) {
      const profile = distributorTest.rows[0];
      console.log(`\n🏢 Distributor profile test:`);
      console.log(`  Name: ${profile.name}`);
      console.log(`  Email: ${profile.email} (from users table)`);
      console.log(`  Phone: ${profile.phone} (from users table)`);
      console.log(`  Company: ${profile.company_name}`);
      console.log(`  Address: ${profile.address}`);
      console.log(`  Image URL: ${profile.image_url || 'NULL (ready for future use)'}`);
    }
    
    // Test delivery data
    const deliveryTest = await client.query(`
      SELECT u.id, u.name, u.email, u.phone,
             dm.vehicle_type, dm.vehicle_capacity, dm.plate_number, 
             dm.is_online, dm.rating, dm.total_deliveries
      FROM users u
      JOIN delivery_men dm ON u.id = dm.user_id
      WHERE u.role = 'delivery'
      LIMIT 1;
    `);
    
    if (deliveryTest.rows.length > 0) {
      const profile = deliveryTest.rows[0];
      console.log(`\n🚚 Delivery profile test:`);
      console.log(`  Name: ${profile.name}`);
      console.log(`  Email: ${profile.email} (from users table)`);
      console.log(`  Phone: ${profile.phone} (from users table)`);
      console.log(`  Vehicle: ${profile.vehicle_type}`);
      console.log(`  Capacity: ${profile.vehicle_capacity}`);
      console.log(`  Plate: ${profile.plate_number || 'NULL (ready for future use)'}`);
      console.log(`  Online: ${profile.is_online}`);
      console.log(`  Rating: ${profile.rating}`);
    }
    
    // Step 8: Column count comparison
    console.log('\n📈 Column count changes:');
    
    const finalCounts = {};
    for (const table of tables) {
      const count = await client.query(`
        SELECT COUNT(*) as count
        FROM information_schema.columns 
        WHERE table_name = $1;
      `, [table]);
      finalCounts[table] = parseInt(count.rows[0].count);
    }
    
    console.log(`  Supermarkets: ${finalCounts.supermarkets} columns (removed email, added image_url)`);
    console.log(`  Distributors: ${finalCounts.distributors} columns (removed email/coverage_area/license_number, added image_url)`);
    console.log(`  Delivery Men: ${finalCounts.delivery_men} columns (major cleanup, added plate_number)`);
    
    // Commit transaction
    await client.query('COMMIT');
    console.log('\n✅ Role tables cleanup completed successfully!');
    
    console.log('\n📋 Summary of changes:');
    console.log('\n🏪 SUPERMARKETS:');
    console.log('  ❌ Removed: email (use users.email)');
    console.log('  ✅ Added: image_url (for store images)');
    
    console.log('\n🏢 DISTRIBUTORS:');
    console.log('  ❌ Removed: email, coverage_area, license_number');
    console.log('  ✅ Added: image_url (for company logos)');
    
    console.log('\n🚚 DELIVERY_MEN:');
    console.log('  ❌ Removed: email, base_address, base_latitude, base_longitude,');
    console.log('             current_latitude, current_longitude, last_location_update,');
    console.log('             emergency_contact, emergency_phone, is_available,');
    console.log('             current_location_lat, current_location_lng, device_token,');
    console.log('             app_version, license_number, license_plate, max_capacity');
    console.log('  ✅ Added: plate_number (replacement for license_plate)');
    console.log('  ✅ Kept: vehicle_capacity (instead of max_capacity)');
    console.log('  ✅ Kept: is_online (instead of is_available)');
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Role tables cleanup failed:', error.message);
    console.error('Transaction rolled back');
  } finally {
    client.release();
    await pool.end();
  }
}

cleanupRoleTables();
