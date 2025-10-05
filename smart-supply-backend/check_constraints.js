const pool = require('./db');

async function checkConstraints() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Checking foreign key constraints that reference users table...\n');
    
    const constraints = await client.query(`
      SELECT 
        tc.table_name, 
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name,
        tc.constraint_name
      FROM 
        information_schema.table_constraints AS tc 
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
      WHERE 
        tc.constraint_type = 'FOREIGN KEY' 
        AND ccu.table_name = 'users'
      ORDER BY tc.table_name;
    `);
    
    console.log('📋 Tables that reference users table:');
    constraints.rows.forEach(row => {
      console.log(`${row.table_name}.${row.column_name} -> ${row.foreign_table_name}.${row.foreign_column_name}`);
    });
    
    console.log(`\nTotal foreign key constraints: ${constraints.rows.length}`);
    
  } catch (error) {
    console.error('❌ Error checking constraints:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

checkConstraints();
