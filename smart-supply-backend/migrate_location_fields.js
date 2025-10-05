const pool = require('./db');

async function migrateLocationFields() {
  const client = await pool.connect();
  
  try {
    console.log('🔄 Starting location fields migration...\n');
    
    // Step 1: Analyze current structure
    console.log('📋 Current location fields in users table:');
    const usersLocationFields = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      AND column_name IN ('address', 'base_latitude', 'base_longitude')
      ORDER BY column_name;
    `);
    
    usersLocationFields.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type}`);
    });
    
    // Step 2: Check if supermarkets and distributors tables already have these fields
    console.log('\n🏪 Checking supermarkets table location fields:');
    const supermarketsLocationFields = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns 
      WHERE table_name = 'supermarkets' 
      AND column_name IN ('address', 'latitude', 'longitude')
      ORDER BY column_name;
    `);
    
    supermarketsLocationFields.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type}`);
    });
    
    console.log('\n🏢 Checking distributors table location fields:');
    const distributorsLocationFields = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns 
      WHERE table_name = 'distributors' 
      AND column_name IN ('address', 'latitude', 'longitude')
      ORDER BY column_name;
    `);
    
    distributorsLocationFields.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type}`);
    });
    
    // Step 3: Start transaction
    await client.query('BEGIN');
    
    // Step 4: Migrate supermarket location data
    console.log('\n🏪 Migrating supermarket location data...');
    
    const supermarketUsers = await client.query(`
      SELECT u.id, u.address, u.base_latitude, u.base_longitude
      FROM users u
      WHERE u.role = 'supermarket' 
      AND u.id IN (SELECT user_id FROM supermarkets)
      AND (u.address IS NOT NULL OR u.base_latitude IS NOT NULL OR u.base_longitude IS NOT NULL)
    `);
    
    console.log(`Found ${supermarketUsers.rows.length} supermarket users with location data`);
    
    for (const user of supermarketUsers.rows) {
      // Update supermarkets table with location data from users table
      // Only update if the supermarkets table doesn't already have better data
      await client.query(`
        UPDATE supermarkets 
        SET address = COALESCE(address, $1),
            latitude = COALESCE(latitude, $2),
            longitude = COALESCE(longitude, $3),
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = $4
      `, [user.address, user.base_latitude, user.base_longitude, user.id]);
      
      console.log(`  ✅ Updated supermarket for user ${user.id}`);
    }
    
    // Step 5: Migrate distributor location data
    console.log('\n🏢 Migrating distributor location data...');
    
    const distributorUsers = await client.query(`
      SELECT u.id, u.address, u.base_latitude, u.base_longitude
      FROM users u
      WHERE u.role = 'distributor' 
      AND u.id IN (SELECT user_id FROM distributors)
      AND (u.address IS NOT NULL OR u.base_latitude IS NOT NULL OR u.base_longitude IS NOT NULL)
    `);
    
    console.log(`Found ${distributorUsers.rows.length} distributor users with location data`);
    
    for (const user of distributorUsers.rows) {
      // Update distributors table with location data from users table
      await client.query(`
        UPDATE distributors 
        SET address = COALESCE(address, $1),
            latitude = COALESCE(latitude, $2),
            longitude = COALESCE(longitude, $3),
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = $4
      `, [user.address, user.base_latitude, user.base_longitude, user.id]);
      
      console.log(`  ✅ Updated distributor for user ${user.id}`);
    }
    
    // Step 6: Verify delivery men don't need fixed locations
    console.log('\n🚚 Checking delivery men location usage...');
    
    const deliveryUsers = await client.query(`
      SELECT u.id, u.address, u.base_latitude, u.base_longitude
      FROM users u
      WHERE u.role = 'delivery'
      AND (u.address IS NOT NULL OR u.base_latitude IS NOT NULL OR u.base_longitude IS NOT NULL)
    `);
    
    console.log(`Found ${deliveryUsers.rows.length} delivery users with location data (will be removed as they're mobile)`);
    
    // Step 7: Remove location fields from users table
    console.log('\n🗑️ Removing location fields from users table...');
    
    const locationFieldsToRemove = ['address', 'base_latitude', 'base_longitude'];
    
    for (const field of locationFieldsToRemove) {
      try {
        await client.query(`ALTER TABLE users DROP COLUMN IF EXISTS ${field}`);
        console.log(`  ✅ Removed column: ${field}`);
      } catch (error) {
        console.log(`  ⚠️ Could not remove ${field}: ${error.message}`);
      }
    }
    
    // Step 8: Verify final structure
    console.log('\n📊 Final users table structure:');
    const finalUsersColumns = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      ORDER BY ordinal_position;
    `);
    
    finalUsersColumns.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });
    
    // Step 9: Verify role tables have location data
    console.log('\n🔍 Verifying location data in role tables...');
    
    // Check supermarkets
    const supermarketLocationData = await client.query(`
      SELECT COUNT(*) as total,
             COUNT(address) as with_address,
             COUNT(latitude) as with_latitude,
             COUNT(longitude) as with_longitude
      FROM supermarkets
    `);
    
    const smData = supermarketLocationData.rows[0];
    console.log(`Supermarkets: ${smData.total} total, ${smData.with_address} with address, ${smData.with_latitude} with coordinates`);
    
    // Check distributors
    const distributorLocationData = await client.query(`
      SELECT COUNT(*) as total,
             COUNT(address) as with_address,
             COUNT(latitude) as with_latitude,
             COUNT(longitude) as with_longitude
      FROM distributors
    `);
    
    const distData = distributorLocationData.rows[0];
    console.log(`Distributors: ${distData.total} total, ${distData.with_address} with address, ${distData.with_latitude} with coordinates`);
    
    // Check delivery_men (should use base_address for their home base, not fixed location)
    const deliveryLocationData = await client.query(`
      SELECT COUNT(*) as total,
             COUNT(base_address) as with_base_address,
             COUNT(base_latitude) as with_base_coordinates
      FROM delivery_men
    `);
    
    const delData = deliveryLocationData.rows[0];
    console.log(`Delivery Men: ${delData.total} total, ${delData.with_base_address} with base address (home base)`);
    
    // Commit transaction
    await client.query('COMMIT');
    console.log('\n✅ Location fields migration completed successfully!');
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', error.message);
    console.error('Transaction rolled back');
  } finally {
    client.release();
    await pool.end();
  }
}

migrateLocationFields();
