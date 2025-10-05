const axios = require('axios');

async function testWithLogin() {
  try {
    console.log('🔐 Testing login and orders API...');
    
    // First, login to get a valid token
    const loginResponse = await axios.post('http://localhost:5000/api/auth/login', {
      email: 's2', // Carrefour Maadi
      password: 's2'
    });
    
    console.log('✅ Login successful');
    const token = loginResponse.data.token;
    const userId = loginResponse.data.user.id;
    
    console.log('👤 User ID:', userId);
    console.log('🔑 Token:', token.substring(0, 20) + '...');
    
    // Now test orders API with valid token
    const ordersResponse = await axios.get(`http://localhost:5000/api/orders/buyer/${userId}`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    
    console.log('✅ Orders API Response Status:', ordersResponse.status);
    console.log('📦 Orders Count:', ordersResponse.data.length);
    
    if (ordersResponse.data.length > 0) {
      console.log('📋 Sample Order:');
      const order = ordersResponse.data[0];
      console.log(`- ID: ${order.id}`);
      console.log(`- Status: ${order.status}`);
      console.log(`- Total: $${order.total_amount}`);
      console.log(`- Created: ${order.created_at}`);
    } else {
      console.log('📭 No orders found for this user');
    }
    
  } catch (error) {
    console.error('❌ Test Failed:');
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Data:', error.response.data);
    } else {
      console.error('Error:', error.message);
    }
  }
}

testWithLogin();
