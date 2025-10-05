const pool = require('./db');

async function cleanupOrphanedUsers() {
  const client = await pool.connect();
  
  try {
    console.log('🧹 Cleaning up orphaned user accounts...');
    
    // Find users without corresponding profile records
    const orphanedUsers = await client.query(`
      SELECT u.id, u.name, u.email, u.role, u.created_at
      FROM users u
      LEFT JOIN supermarkets s ON u.id = s.user_id AND u.role = 'supermarket'
      LEFT JOIN distributors d ON u.id = d.user_id AND u.role = 'distributor'
      LEFT JOIN delivery_men dm ON u.id = dm.user_id AND u.role = 'delivery'
      WHERE 
        (u.role = 'supermarket' AND s.user_id IS NULL) OR
        (u.role = 'distributor' AND d.user_id IS NULL) OR
        (u.role = 'delivery' AND dm.user_id IS NULL)
      ORDER BY u.created_at DESC;
    `);
    
    if (orphanedUsers.rows.length === 0) {
      console.log('✅ No orphaned users found. Database is clean!');
      return;
    }
    
    console.log(`\n📋 Found ${orphanedUsers.rows.length} orphaned user(s):`);
    orphanedUsers.rows.forEach((user, index) => {
      console.log(`${index + 1}. ${user.name} (${user.email}) - Role: ${user.role} - Created: ${user.created_at}`);
    });
    
    // Ask for confirmation (in a real scenario, you might want to prompt for user input)
    console.log('\n🗑️  Removing orphaned users...');
    
    let deletedCount = 0;
    for (const user of orphanedUsers.rows) {
      try {
        await client.query('DELETE FROM users WHERE id = $1', [user.id]);
        console.log(`   ✅ Deleted user: ${user.name} (${user.email})`);
        deletedCount++;
      } catch (error) {
        console.log(`   ❌ Failed to delete user: ${user.name} (${user.email}) - ${error.message}`);
      }
    }
    
    console.log(`\n🎉 Cleanup completed! Removed ${deletedCount} orphaned user(s).`);
    
    // Show remaining user count
    const remainingUsers = await client.query('SELECT COUNT(*) as count FROM users');
    console.log(`📊 Total users remaining: ${remainingUsers.rows[0].count}`);
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

// Run the cleanup
cleanupOrphanedUsers();
