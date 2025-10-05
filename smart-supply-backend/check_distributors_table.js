const pool = require('./db');

async function checkDistributorsTable() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Checking distributors table structure...\n');
    
    // Get table structure
    const tableInfo = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'distributors'
      ORDER BY ordinal_position
    `);
    
    console.log('📋 Distributors table columns:');
    tableInfo.rows.forEach(col => {
      console.log(`  - ${col.column_name} (${col.data_type}) ${col.is_nullable === 'YES' ? 'NULL' : 'NOT NULL'}`);
    });
    
    // Get sample data
    const sampleData = await client.query(`
      SELECT * FROM distributors LIMIT 1
    `);
    
    if (sampleData.rows.length > 0) {
      console.log('\n📋 Sample distributor data:');
      const sample = sampleData.rows[0];
      Object.keys(sample).forEach(key => {
        console.log(`  ${key}: ${sample[key]}`);
      });
    }
    
    // Test simple profile query
    console.log('\n📋 Testing simple profile query:');
    
    const simpleProfile = await client.query(`
      SELECT 
        u.id, u.name, u.email, u.phone, u.role,
        d.company_name, d.address
      FROM users u
      LEFT JOIN distributors d ON u.id = d.user_id
      WHERE u.role = 'distributor'
      LIMIT 1
    `);
    
    if (simpleProfile.rows.length > 0) {
      const profile = simpleProfile.rows[0];
      console.log('✅ Simple profile query successful:');
      console.log(`  Name: ${profile.name}`);
      console.log(`  Email: ${profile.email}`);
      console.log(`  Phone: ${profile.phone}`);
      console.log(`  Company: ${profile.company_name || 'Not set'}`);
      console.log(`  Address: ${profile.address || 'Not set'}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    client.release();
    await pool.end();
  }
}

checkDistributorsTable();
