const pool = require('./db');

async function listUsers() {
  const client = await pool.connect();
  
  try {
    const users = await client.query('SELECT id, name, email, role FROM users ORDER BY id');
    
    console.log('Users in database:');
    users.rows.forEach(row => {
      console.log(`${row.id}: ${row.email} (${row.name}) - ${row.role}`);
    });
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

listUsers();
