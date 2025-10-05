const pool = require('./db');

async function fixDistributorsTable() {
  const client = await pool.connect();
  
  try {
    console.log('🔧 Fixing distributors table structure...');
    
    // Check current table structure
    const columns = await client.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'distributors' 
      ORDER BY ordinal_position;
    `);
    
    console.log('\n📋 Current distributors table columns:');
    columns.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });
    
    const existingColumns = columns.rows.map(row => row.column_name);
    
    // Add missing columns
    const requiredColumns = [
      // license_number removed
      { name: 'tax_id', type: 'VARCHAR(100)', default: null },
      { name: 'description', type: 'TEXT', default: null }
    ];
    
    console.log('\n🔧 Adding missing columns...');
    
    for (const column of requiredColumns) {
      if (!existingColumns.includes(column.name)) {
        const alterQuery = `ALTER TABLE distributors ADD COLUMN ${column.name} ${column.type}`;
        await client.query(alterQuery);
        console.log(`✅ Added column: ${column.name} (${column.type})`);
      } else {
        console.log(`✓ Column already exists: ${column.name}`);
      }
    }
    
    // Verify final structure
    const finalColumns = await client.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'distributors' 
      ORDER BY ordinal_position;
    `);
    
    console.log('\n📋 Final distributors table structure:');
    finalColumns.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });
    
    console.log('\n🎉 Distributors table structure updated successfully!');
    
  } catch (error) {
    console.error('❌ Error fixing distributors table:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

fixDistributorsTable();
