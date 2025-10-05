const pool = require('./db');

async function analyzeUsersTable() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Analyzing users table structure...\n');
    
    // Get all columns in users table
    const columnsResult = await client.query(`
      SELECT column_name, data_type, is_nullable, column_default, character_maximum_length
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      ORDER BY ordinal_position;
    `);
    
    console.log('📋 Current users table columns:');
    columnsResult.rows.forEach(row => {
      const length = row.character_maximum_length ? `(${row.character_maximum_length})` : '';
      console.log(`  ${row.column_name}: ${row.data_type}${length} (nullable: ${row.is_nullable})`);
    });
    
    // Check what role-specific tables exist
    console.log('\n🏢 Checking role-specific tables...');
    
    const tablesResult = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name IN ('supermarkets', 'distributors', 'delivery_men')
      ORDER BY table_name;
    `);
    
    console.log('Available role tables:');
    tablesResult.rows.forEach(row => {
      console.log(`  ✅ ${row.table_name}`);
    });
    
    // Check structure of each role table
    for (const table of tablesResult.rows) {
      console.log(`\n📊 ${table.table_name.toUpperCase()} table structure:`);
      
      const tableColumns = await client.query(`
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns 
        WHERE table_name = $1 
        ORDER BY ordinal_position;
      `, [table.table_name]);
      
      tableColumns.rows.forEach(row => {
        console.log(`  ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
      });
    }
    
    // Sample some users to see what data exists
    console.log('\n👥 Sample users data:');
    const usersData = await client.query(`
      SELECT id, name, email, role, phone, address, created_at
      FROM users 
      ORDER BY id 
      LIMIT 5;
    `);
    
    usersData.rows.forEach(user => {
      console.log(`  ID: ${user.id}, Name: ${user.name}, Role: ${user.role}, Email: ${user.email}`);
    });
    
    console.log('\n📝 Analysis complete!');
    
  } catch (error) {
    console.error('❌ Error analyzing table:', error.message);
  } finally {
    client.release();
    await pool.end();
  }
}

analyzeUsersTable();
