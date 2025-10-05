const pool = require('./db');

async function forceDeleteUser(emailOrId) {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    console.log(`🔍 Looking for user: ${emailOrId}`);
    
    // Find user by email or ID
    let userQuery;
    let userParams;
    
    if (isNaN(emailOrId)) {
      userQuery = 'SELECT * FROM users WHERE email = $1';
      userParams = [emailOrId];
    } else {
      userQuery = 'SELECT * FROM users WHERE id = $1';
      userParams = [parseInt(emailOrId)];
    }
    
    const userResult = await client.query(userQuery, userParams);
    
    if (userResult.rows.length === 0) {
      console.log('❌ User not found');
      await client.query('ROLLBACK');
      return;
    }
    
    const user = userResult.rows[0];
    console.log(`📋 Found user: ${user.name} (${user.email}) - Role: ${user.role}, ID: ${user.id}`);
    
    // Delete all related data that might have foreign key constraints
    console.log('🗑️ Deleting all related data...');
    
    // Delete from all possible tables that might reference this user
    const tablesToClean = [
      { table: 'user_activity_log', column: 'user_id' },
      { table: 'orders', column: 'user_id' },
      { table: 'orders', column: 'distributor_id' },
      { table: 'orders', column: 'delivery_man_id' },
      { table: 'offers', column: 'distributor_id' },
      { table: 'products', column: 'distributor_id' },
      { table: 'ratings', column: 'rater_id' },
      { table: 'ratings', column: 'rated_id' },
      { table: 'delivery_assignments', column: 'delivery_man_id' },
      { table: 'delivery_men', column: 'user_id' },
      { table: 'distributors', column: 'user_id' },
      { table: 'supermarkets', column: 'user_id' }
    ];
    
    for (const { table, column } of tablesToClean) {
      try {
        const result = await client.query(`DELETE FROM ${table} WHERE ${column} = $1`, [user.id]);
        if (result.rowCount > 0) {
          console.log(`   Deleted ${result.rowCount} record(s) from ${table}`);
        }
      } catch (error) {
        console.log(`   Note: Could not delete from ${table} (table might not exist): ${error.message}`);
      }
    }
    
    // Finally delete the user
    console.log('🗑️ Deleting user account...');
    const deleteResult = await client.query('DELETE FROM users WHERE id = $1', [user.id]);
    console.log(`   Deleted ${deleteResult.rowCount} user record(s)`);
    
    await client.query('COMMIT');
    console.log('✅ User account and all related data successfully deleted!');
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error deleting user:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

// Get email/ID from command line argument
const emailOrId = process.argv[2];

if (!emailOrId) {
  console.log('Usage: node force_delete_user.js <email_or_id>');
  console.log('Example: node force_delete_user.js user@example.com');
  console.log('Example: node force_delete_user.js 5');
  process.exit(1);
}

forceDeleteUser(emailOrId);
