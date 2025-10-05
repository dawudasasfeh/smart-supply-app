const pool = require('./db');

async function migrateUsersTable() {
  const client = await pool.connect();
  
  try {
    console.log('🔄 Starting users table migration...\n');
    
    // Step 1: Identify columns to move
    const columnsToMove = {
      delivery_men: [
        'max_daily_orders',
        'vehicle_type', 
        'vehicle_capacity',
        'license_number',
        'is_available',
        'rating',
        'emergency_contact',
        'emergency_phone',
        'shift_start',
        'shift_end'
      ],
      distributors: [
        'license_number',
        'is_active'
      ],
      supermarkets: [
        'is_active'
      ]
    };
    
    console.log('📋 Columns to migrate:');
    Object.entries(columnsToMove).forEach(([table, columns]) => {
      console.log(`  ${table.toUpperCase()}:`);
      columns.forEach(col => console.log(`    - ${col}`));
    });
    
    // Step 2: Start transaction
    await client.query('BEGIN');
    
    // Step 3: Migrate delivery_men specific data
    console.log('\n🚚 Migrating delivery_men data...');
    
    // Get delivery users from users table
    const deliveryUsers = await client.query(`
      SELECT id, max_daily_orders, vehicle_type, vehicle_capacity, license_number, 
             is_available, rating, emergency_contact, emergency_phone, shift_start, shift_end
      FROM users 
      WHERE role = 'delivery' AND id IN (SELECT user_id FROM delivery_men)
    `);
    
    console.log(`Found ${deliveryUsers.rows.length} delivery users to migrate`);
    
    for (const user of deliveryUsers.rows) {
      // Update delivery_men table with data from users table
      await client.query(`
        UPDATE delivery_men 
        SET max_daily_orders = COALESCE($1, max_daily_orders),
            vehicle_type = COALESCE($2, vehicle_type),
            vehicle_capacity = COALESCE($3, vehicle_capacity),
            license_number = COALESCE($4, license_number),
            is_available = COALESCE($5, is_available),
            rating = COALESCE($6, rating),
            emergency_contact = COALESCE($7, emergency_contact),
            emergency_phone = COALESCE($8, emergency_phone),
            shift_start = COALESCE($9, shift_start),
            shift_end = COALESCE($10, shift_end),
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = $11
      `, [
        user.max_daily_orders, user.vehicle_type, user.vehicle_capacity,
        user.license_number, user.is_available, user.rating,
        user.emergency_contact, user.emergency_phone, user.shift_start,
        user.shift_end, user.id
      ]);
    }
    
    // Step 4: Migrate distributors specific data
    console.log('\n🏢 Migrating distributors data...');
    
    const distributorUsers = await client.query(`
      SELECT id, license_number, is_active
      FROM users 
      WHERE role = 'distributor' AND id IN (SELECT user_id FROM distributors)
    `);
    
    console.log(`Found ${distributorUsers.rows.length} distributor users to migrate`);
    
    for (const user of distributorUsers.rows) {
      await client.query(`
        UPDATE distributors 
        SET license_number = COALESCE($1, license_number),
            is_active = COALESCE($2, is_active),
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = $3
      `, [user.license_number, user.is_active, user.id]);
    }
    
    // Step 5: Migrate supermarkets specific data
    console.log('\n🏪 Migrating supermarkets data...');
    
    const supermarketUsers = await client.query(`
      SELECT id, is_active
      FROM users 
      WHERE role = 'supermarket' AND id IN (SELECT user_id FROM supermarkets)
    `);
    
    console.log(`Found ${supermarketUsers.rows.length} supermarket users to migrate`);
    
    for (const user of supermarketUsers.rows) {
      await client.query(`
        UPDATE supermarkets 
        SET is_active = COALESCE($1, is_active),
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = $2
      `, [user.is_active, user.id]);
    }
    
    // Step 6: Remove role-specific columns from users table
    console.log('\n🗑️ Removing role-specific columns from users table...');
    
    const columnsToRemove = [
      'max_daily_orders',
      'vehicle_type',
      'vehicle_capacity', 
      'license_number',
      'is_available',
      'rating',
      'emergency_contact',
      'emergency_phone',
      'shift_start',
      'shift_end',
      'is_active'
    ];
    
    for (const column of columnsToRemove) {
      try {
        await client.query(`ALTER TABLE users DROP COLUMN IF EXISTS ${column}`);
        console.log(`  ✅ Removed column: ${column}`);
      } catch (error) {
        console.log(`  ⚠️ Could not remove ${column}: ${error.message}`);
      }
    }
    
    // Step 7: Verify final users table structure
    console.log('\n📊 Final users table structure:');
    const finalColumns = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      ORDER BY ordinal_position;
    `);
    
    finalColumns.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });
    
    // Commit transaction
    await client.query('COMMIT');
    console.log('\n✅ Migration completed successfully!');
    
    // Step 8: Verify data integrity
    console.log('\n🔍 Verifying data integrity...');
    
    const userCount = await client.query('SELECT COUNT(*) FROM users');
    const deliveryCount = await client.query('SELECT COUNT(*) FROM delivery_men');
    const distributorCount = await client.query('SELECT COUNT(*) FROM distributors');
    const supermarketCount = await client.query('SELECT COUNT(*) FROM supermarkets');
    
    console.log(`Users: ${userCount.rows[0].count}`);
    console.log(`Delivery Men: ${deliveryCount.rows[0].count}`);
    console.log(`Distributors: ${distributorCount.rows[0].count}`);
    console.log(`Supermarkets: ${supermarketCount.rows[0].count}`);
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', error.message);
    console.error('Transaction rolled back');
  } finally {
    client.release();
    await pool.end();
  }
}

migrateUsersTable();
