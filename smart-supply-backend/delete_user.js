const pool = require('./db');

async function deleteUser(emailOrId) {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    console.log(`🔍 Looking for user: ${emailOrId}`);
    
    // Find user by email or ID
    let userQuery;
    let userParams;
    
    if (isNaN(emailOrId)) {
      // It's an email
      userQuery = 'SELECT * FROM users WHERE email = $1';
      userParams = [emailOrId];
    } else {
      // It's an ID
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
    console.log(`📋 Found user: ${user.name} (${user.email}) - Role: ${user.role}`);
    
    // Delete role-specific data first
    console.log('🗑️ Deleting role-specific data...');
    
    switch (user.role) {
      case 'supermarket':
        const supermarketResult = await client.query('DELETE FROM supermarkets WHERE user_id = $1', [user.id]);
        console.log(`   Deleted ${supermarketResult.rowCount} supermarket record(s)`);
        break;
      case 'distributor':
        const distributorResult = await client.query('DELETE FROM distributors WHERE user_id = $1', [user.id]);
        console.log(`   Deleted ${distributorResult.rowCount} distributor record(s)`);
        break;
      case 'delivery':
        const deliveryResult = await client.query('DELETE FROM delivery_men WHERE user_id = $1', [user.id]);
        console.log(`   Deleted ${deliveryResult.rowCount} delivery_men record(s)`);
        break;
    }
    
    // Delete user account
    console.log('🗑️ Deleting user account...');
    const deleteResult = await client.query('DELETE FROM users WHERE id = $1', [user.id]);
    console.log(`   Deleted ${deleteResult.rowCount} user record(s)`);
    
    await client.query('COMMIT');
    console.log('✅ User account successfully deleted!');
    
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
  console.log('Usage: node delete_user.js <email_or_id>');
  console.log('Example: node delete_user.js user@example.com');
  console.log('Example: node delete_user.js 5');
  process.exit(1);
}

deleteUser(emailOrId);
