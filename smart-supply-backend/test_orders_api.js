const axios = require('axios');

async function testOrdersAPI() {
  try {
    console.log('🔍 Testing orders API...');
    
    // Test with buyer ID 2 (Carrefour Maadi)
    const response = await axios.get('http://localhost:5000/api/orders/buyer/2', {
      headers: {
        'Authorization': 'Bearer test-token',
        'Content-Type': 'application/json'
      }
    });
    
    console.log('✅ API Response Status:', response.status);
    console.log('📦 Orders Count:', response.data.length);
    
    if (response.data.length > 0) {
      console.log('📋 Sample Order:');
      console.log(JSON.stringify(response.data[0], null, 2));
    }
    
  } catch (error) {
    console.error('❌ API Test Failed:');
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Data:', error.response.data);
    } else if (error.request) {
      console.error('No response received:', error.message);
    } else {
      console.error('Error:', error.message);
    }
  }
}

testOrdersAPI();
