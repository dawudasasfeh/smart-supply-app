const pool = require('./db');
const fs = require('fs');
const path = require('path');

async function setupPaymentSystem() {
  console.log('🚀 Setting up Payment System...');
  
  try {
    // Read and execute the SQL file
    const sqlPath = path.join(__dirname, 'sql', 'create_payment_system_tables.sql');
    const sqlContent = fs.readFileSync(sqlPath, 'utf8');
    
    // Split SQL content by semicolons and execute each statement
    const statements = sqlContent
      .split(';')
      .map(stmt => stmt.trim())
      .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));
    
    console.log(`📝 Executing ${statements.length} SQL statements...`);
    
    for (const statement of statements) {
      if (statement.trim()) {
        try {
          await pool.query(statement);
          console.log('✅ Executed SQL statement');
        } catch (error) {
          console.log(`⚠️  SQL statement failed (may already exist): ${error.message}`);
        }
      }
    }
    
    console.log('✅ Payment system database setup completed!');
    
    // Verify tables were created
    const tables = [
      'payment_methods',
      'user_payment_methods', 
      'payment_transactions',
      'payment_refunds',
      'payment_settings',
      'payment_analytics'
    ];
    
    console.log('🔍 Verifying tables...');
    for (const table of tables) {
      try {
        const result = await pool.query(`SELECT COUNT(*) FROM ${table}`);
        console.log(`✅ Table ${table} exists with ${result.rows[0].count} records`);
      } catch (error) {
        console.log(`❌ Table ${table} not found: ${error.message}`);
      }
    }
    
    console.log('🎉 Payment system setup completed successfully!');
    console.log('');
    console.log('📋 Next steps:');
    console.log('1. Configure payment gateway credentials in environment variables');
    console.log('2. Test payment methods in the application');
    console.log('3. Set up webhook endpoints for payment gateways');
    console.log('');
    console.log('🔧 Environment variables needed:');
    console.log('- STRIPE_SECRET_KEY');
    console.log('- STRIPE_PUBLIC_KEY');
    console.log('- STRIPE_WEBHOOK_SECRET');
    console.log('- FAWRY_MERCHANT_CODE');
    console.log('- FAWRY_SECURITY_KEY');
    console.log('- FAWRY_BASE_URL');
    
  } catch (error) {
    console.error('❌ Error setting up payment system:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run the setup
setupPaymentSystem();

