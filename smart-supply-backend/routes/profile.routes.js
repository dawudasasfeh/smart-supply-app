const express = require('express');
const router = express.Router();
const pool = require('../db');
const authenticate = require('../middleware/auth.middleware');

// GET /api/profile/me
router.get('/me', authenticate, async (req, res) => {
  const userId = req.user.id;
  const role = req.user.role;

  console.log(`🔍 [PROFILE] Fetching profile for user ${userId} with role ${role}`);

  try {
    // Get basic user info first
    const userQuery = await pool.query(
      `SELECT id, name, email, role, phone, created_at, updated_at
       FROM users WHERE id = $1`,
      [userId]
    );

    if (userQuery.rows.length === 0) {
      console.log(`❌ [PROFILE] User not found for id=${userId}`);
      return res.status(404).json({ message: 'User not found' });
    }

    const user = userQuery.rows[0];
    console.log(`✅ [PROFILE] Found user:`, user);

    // Try to get additional info based on role
    let additionalData = {};
    
    if (role.toLowerCase() === 'supermarket') {
      try {
        const supermarketQuery = await pool.query(
          `SELECT store_name, manager_name, address as store_address, latitude as store_latitude, 
                  longitude as store_longitude, area, store_size, store_type, operating_hours,
                  total_orders, total_spent, average_order_value, is_active, membership_level,
                  created_at as store_created_at, updated_at as store_updated_at
           FROM supermarkets WHERE user_id = $1`,
          [userId]
        );
        
        if (supermarketQuery.rows.length > 0) {
          additionalData = supermarketQuery.rows[0];
          console.log(`✅ [PROFILE] Found supermarket data:`, additionalData);
        }
      } catch (err) {
        console.log(`⚠️ [PROFILE] Supermarket table query failed:`, err.message);
      }
    } else if (role.toLowerCase() === 'distributor') {
      try {
        const distributorQuery = await pool.query(
          `SELECT company_name, contact_person, address as company_address, 
                  business_license, tax_id, latitude as company_latitude, 
                  longitude as company_longitude, total_orders,
                  total_revenue, average_rating, is_active, is_verified,
                  description, image_url, created_at as company_created_at, updated_at as company_updated_at
           FROM distributors WHERE user_id = $1`,
          [userId]
        );
        
        if (distributorQuery.rows.length > 0) {
          additionalData = distributorQuery.rows[0];
          console.log(`✅ [PROFILE] Found distributor data:`, additionalData);
        }
      } catch (err) {
        console.log(`⚠️ [PROFILE] Distributor table query failed:`, err.message);
      }
    } else if (role.toLowerCase() === 'delivery') {
      try {
        const deliveryQuery = await pool.query(
          `SELECT max_daily_orders, vehicle_type, rating, total_deliveries, is_active,
                  vehicle_capacity, shift_start, shift_end, profile_image_url, 
                  last_seen, is_online, plate_number,
                  created_at as delivery_created_at, updated_at as delivery_updated_at
           FROM delivery_men WHERE user_id = $1`,
          [userId]
        );
        
        if (deliveryQuery.rows.length > 0) {
          additionalData = deliveryQuery.rows[0];
          console.log(`✅ [PROFILE] Found delivery data:`, additionalData);
        }
      } catch (err) {
        console.log(`⚠️ [PROFILE] Delivery table query failed:`, err.message);
      }
    }

    // Combine user data with additional data
    // Role tables now contain the location data, phone comes from users table
    const profileData = {
      ...user,
      ...additionalData,
      contact_email: user.email,
      contact_phone: user.phone, // Phone always comes from users table
      // Address and location data comes from role-specific tables
      address: additionalData.address || additionalData.store_address || additionalData.company_address || additionalData.base_address,
      latitude: additionalData.latitude || additionalData.store_latitude || additionalData.company_latitude || additionalData.delivery_latitude,
      longitude: additionalData.longitude || additionalData.store_longitude || additionalData.company_longitude || additionalData.delivery_longitude,
    };

    console.log(`✅ [PROFILE] Returning combined profile data:`, profileData);
    res.json(profileData);
    
  } catch (err) {
    console.error(`❌ [PROFILE] Error for user ${userId}:`, err.message);
    res.status(500).json({ message: err.message });
  }
});

// GET /api/profile/:id - Get profile for any user by ID
router.get('/:id', async (req, res) => {
  const userId = req.params.id;
  console.log(`[PROFILE ROUTE] GET /api/profile/${userId}`);
  try {
    // Always get user name from users table
    const userResult = await pool.query(
      'SELECT id, name, role, email FROM users WHERE id = $1',
      [userId]
    );
    console.log(`[PROFILE ROUTE] Query result for id=${userId}:`, userResult.rows);
    if (userResult.rows.length === 0) {
      console.log(`[PROFILE ROUTE] User not found for id=${userId}`);
      return res.status(404).json({ message: 'User not found' });
    }
    const user = userResult.rows[0];
    res.json(user);
  } catch (err) {
    console.log(`[PROFILE ROUTE] ERROR for id=${userId}:`, err);
    res.status(500).json({ message: err.message });
  }
});

// PUT /api/profile/me - update basic user profile information (no location data)
router.put('/me', authenticate, async (req, res) => {
  const userId = req.user.id;
  const { name, email, phone } = req.body || {};
  
  console.log(`🔧 [PROFILE UPDATE] User ${userId} updating basic info:`, { name, email, phone });
  
  try {
    // Check if at least one field is provided
    if (!name && !email && !phone) {
      console.log(`⚠️ [PROFILE UPDATE] Nothing to update for user ${userId}`);
      return res.status(400).json({ message: 'Nothing to update' });
    }

    // Validate email format if provided
    if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ message: 'Invalid email format' });
    }

    // Validate phone format if provided (basic validation)
    if (phone && phone.length < 10) {
      return res.status(400).json({ message: 'Phone number must be at least 10 digits' });
    }

    // Build dynamic update query - only basic user fields
    const fields = [];
    const values = [];
    let idx = 1;
    
    if (name) {
      fields.push(`name = $${idx++}`);
      values.push(name.trim());
    }
    if (email) {
      fields.push(`email = $${idx++}`);
      values.push(email.toLowerCase().trim());
    }
    if (phone) {
      fields.push(`phone = $${idx++}`);
      values.push(phone.trim());
    }
    
    // Add updated_at timestamp
    fields.push(`updated_at = $${idx++}`);
    values.push(new Date());
    
    values.push(userId);

    const sql = `UPDATE users SET ${fields.join(', ')} WHERE id = $${idx} 
                 RETURNING id, name, email, phone, updated_at`;
    
    console.log(`🔧 [PROFILE UPDATE] Executing SQL:`, sql);
    console.log(`🔧 [PROFILE UPDATE] With values:`, values);
    
    const result = await pool.query(sql, values);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    console.log(`✅ [PROFILE UPDATE] Update successful for user ${userId}:`, result.rows[0]);
    return res.json({ success: true, data: result.rows[0], message: 'Basic profile updated. Use /role-data endpoint for location updates.' });
  } catch (e) {
    console.error(`❌ [PROFILE UPDATE] Error for user ${userId}:`, e.message);
    
    // Handle specific database errors
    if (e.code === '23505') { // Unique constraint violation
      if (e.constraint && e.constraint.includes('email')) {
        return res.status(400).json({ message: 'Email already exists' });
      }
    }
    
    return res.status(500).json({ message: 'Failed to update profile: ' + e.message });
  }
});

// PUT /api/profile/me/role-data - update role-specific profile information
router.put('/me/role-data', authenticate, async (req, res) => {
  const userId = req.user.id;
  const role = req.user.role;
  const roleData = req.body || {};
  
  console.log(`🔧 [ROLE DATA UPDATE] User ${userId} (${role}) updating:`, roleData);
  
  try {
    let result;
    
    if (role.toLowerCase() === 'supermarket') {
      // Update supermarkets table
      const fields = [];
      const values = [];
      let idx = 1;
      
      const allowedFields = ['store_name', 'manager_name', 'area', 'store_size', 'store_type', 
                           'operating_hours', 'membership_level', 'latitude', 'longitude', 'address'];
      
      allowedFields.forEach(field => {
        if (roleData[field] !== undefined) {
          fields.push(`${field} = $${idx++}`);
          values.push(roleData[field]);
        }
      });
      
      if (fields.length > 0) {
        fields.push(`updated_at = $${idx++}`);
        values.push(new Date());
        values.push(userId);
        
        const sql = `UPDATE supermarkets SET ${fields.join(', ')} WHERE user_id = $${idx} 
                     RETURNING *`;
        
        result = await pool.query(sql, values);
      }
      
    } else if (role.toLowerCase() === 'distributor') {
      // Update distributors table
      const fields = [];
      const values = [];
      let idx = 1;
      
      const allowedFields = ['company_name', 'contact_person', 'business_license', 'tax_id',
                           'description', 'latitude', 'longitude', 'address', 'image_url'];
      
      allowedFields.forEach(field => {
        if (roleData[field] !== undefined) {
          fields.push(`${field} = $${idx++}`);
          values.push(roleData[field]);
        }
      });
      
      if (fields.length > 0) {
        fields.push(`updated_at = $${idx++}`);
        values.push(new Date());
        values.push(userId);
        
        const sql = `UPDATE distributors SET ${fields.join(', ')} WHERE user_id = $${idx} 
                     RETURNING *`;
        
        result = await pool.query(sql, values);
      }
      
    } else if (role.toLowerCase() === 'delivery') {
      // Update delivery_men table
      const fields = [];
      const values = [];
      let idx = 1;
      
      const allowedFields = ['max_daily_orders', 'vehicle_type', 'vehicle_capacity',
                           'shift_start', 'shift_end', 'plate_number'];
      
      allowedFields.forEach(field => {
        if (roleData[field] !== undefined) {
          fields.push(`${field} = $${idx++}`);
          values.push(roleData[field]);
        }
      });
      
      if (fields.length > 0) {
        fields.push(`updated_at = $${idx++}`);
        values.push(new Date());
        values.push(userId);
        
        const sql = `UPDATE delivery_men SET ${fields.join(', ')} WHERE user_id = $${idx} 
                     RETURNING *`;
        
        result = await pool.query(sql, values);
      }
    }
    
    if (!result || result.rows.length === 0) {
      return res.status(400).json({ message: 'No valid fields to update or user not found in role table' });
    }
    
    console.log(`✅ [ROLE DATA UPDATE] Update successful for user ${userId}:`, result.rows[0]);
    return res.json({ success: true, data: result.rows[0] });
    
  } catch (e) {
    console.error(`❌ [ROLE DATA UPDATE] Error for user ${userId}:`, e.message);
    return res.status(500).json({ message: 'Failed to update role data: ' + e.message });
  }
});

// POST /api/profile/me/avatar - upload profile picture (placeholder)
router.post('/me/avatar', authenticate, async (req, res) => {
  const userId = req.user.id;
  
  console.log(`🔧 [PROFILE AVATAR] User ${userId} attempting to upload avatar`);
  
  try {
    // For now, return a placeholder response
    // In the future, this would handle file upload with multer
    console.log(`⚠️ [PROFILE AVATAR] Avatar upload not yet implemented for user ${userId}`);
    
    return res.status(501).json({ 
      success: false, 
      message: 'Avatar upload functionality coming soon',
      feature: 'profile_picture_upload'
    });
  } catch (e) {
    console.error(`❌ [PROFILE AVATAR] Error for user ${userId}:`, e.message);
    return res.status(500).json({ message: 'Failed to upload avatar: ' + e.message });
  }
});

// GET /api/profile/me/avatar - get profile picture URL (placeholder)
router.get('/me/avatar', authenticate, async (req, res) => {
  const userId = req.user.id;
  
  console.log(`🔍 [PROFILE AVATAR] User ${userId} requesting avatar`);
  
  try {
    // For now, return a default avatar or null
    // In the future, this would return the actual avatar URL
    return res.json({ 
      success: true, 
      avatar_url: null, // No avatar uploaded yet
      default_avatar: true
    });
  } catch (e) {
    console.error(`❌ [PROFILE AVATAR] Error for user ${userId}:`, e.message);
    return res.status(500).json({ message: 'Failed to get avatar: ' + e.message });
  }
});

module.exports = router;
