const pool = require('./db');

async function addUpdatedAtColumn() {
  const client = await pool.connect();
  
  try {
    console.log('🔧 Adding updated_at column to users table...\n');
    
    // Check if updated_at column exists
    const checkColumn = await client.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'users' AND column_name = 'updated_at';
    `);
    
    if (checkColumn.rows.length === 0) {
      // Add updated_at column
      await client.query(`
        ALTER TABLE users ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
      `);
      
      // Update existing records to have updated_at = created_at
      await client.query(`
        UPDATE users SET updated_at = created_at WHERE updated_at IS NULL;
      `);
      
      console.log('✅ updated_at column added successfully!');
    } else {
      console.log('✅ updated_at column already exists!');
    }
    
    // Verify the column exists
    const result = await client.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      AND column_name IN ('created_at', 'updated_at')
      ORDER BY column_name;
    `);
    
    console.log('\n📋 Timestamp columns in users table:');
    result.rows.forEach(row => {
      console.log(`${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    client.release();
    await pool.end();
  }
}

addUpdatedAtColumn();
