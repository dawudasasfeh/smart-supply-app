const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { createUser, findUserByEmail } = require('../models/user.model');
const pool = require('../db');

const signup = async (req, res) => {
  const { name, email, password, role, profile } = req.body; // note 'profile' not 'profileData'
  const client = await pool.connect();

  try {
    // Start transaction
    await client.query('BEGIN');

    if (!profile) {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'Profile data is required' });
    }

    const existing = await findUserByEmail(email);
    if (existing) {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'User already exists' });
    }

    const hashed = await bcrypt.hash(password, 10);
    // Create user within the current transaction to ensure rollback on failure
    const userInsert = await client.query(
      'INSERT INTO users (name, email, password, role) VALUES ($1, $2, $3, $4) RETURNING *',
      [name, email, hashed, role]
    );
    const user = userInsert.rows[0];
    const userId = user.id;

    // Persist common address/coordinates to users table when provided
    try {
      const address = profile.address || null;
      const latitude = (profile.latitude !== undefined) ? profile.latitude : null;
      const longitude = (profile.longitude !== undefined) ? profile.longitude : null;
      await client.query(
        `UPDATE users SET address = $1, base_latitude = $2, base_longitude = $3 WHERE id = $4`,
        [address, latitude, longitude, userId]
      );
    } catch (e) {
      console.log('Note: could not update users address/coords at signup:', e.message);
    }

    switch (role) {
      case 'supermarket':
        // Validate required supermarket fields (relaxed for testing)
        if (!profile.store_name || !profile.address) {
          await client.query('ROLLBACK');
          return res.status(400).json({ message: 'Store name and address are required' });
        }
        // Insert only columns guaranteed by signup
        await client.query(
          `INSERT INTO supermarkets (user_id, store_name, address, email)
           VALUES ($1, $2, $3, $4)`,
          [
            userId,
            profile.store_name,
            profile.address,
            email,
          ]
        );
        break;

      case 'distributor':
        if (!profile.company_name || !profile.address) {
          await client.query('ROLLBACK');
          return res.status(400).json({ message: 'Company name and address are required' });
        }
        // Insert minimal distributor data only
        await client.query(
          `INSERT INTO distributors (user_id, company_name, address, phone, email)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            userId,
            profile.company_name,
            profile.address,
            profile.phone || '1234567890',
            profile.email || email,
          ]
        );
        break;

      case 'delivery':
        if (!profile.full_name || !profile.address) {
          await client.query('ROLLBACK');
          return res.status(400).json({ message: 'Full name and address are required' });
        }
        await client.query(
          `INSERT INTO delivery_men 
            (name, phone, email, vehicle_type, license_plate, max_capacity, is_available, is_active, created_at)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())`,
          [
            profile.full_name,
            profile.phone || '1234567890',
            profile.email || email,
            profile.vehicle_type || 'Motorcycle',
            profile.license_plate || 'ABC123',
            profile.max_capacity ?? 5,
            true,
            true,
          ]
        );
        break;

      default:
        await client.query('ROLLBACK');
        return res.status(400).json({ message: 'Invalid role specified' });
    }

    // Commit transaction
    await client.query('COMMIT');
    res.status(201).json({ user });
  } catch (err) {
    // Rollback transaction on error
    try {
      await client.query('ROLLBACK');
    } catch (rollbackErr) {
      console.error('Error rolling back transaction:', rollbackErr);
    }
    
    console.error('Signup error:', err);
    res.status(500).json({ message: err.message });
  } finally {
    // Release client back to pool
    client.release();
  }
};

const login = async (req, res) => {
  const { email, password } = req.body;

  try {
    const user = await findUserByEmail(email);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.status(401).json({ message: 'Invalid password' });

    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: '1d' });
    res.json({ 
      success: true, 
      token, 
      user: { id: user.id, name: user.name, role: user.role } 
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const deleteAccount = async (req, res) => {
  const { password } = req.body;
  const userId = req.user.id;
  const userRole = req.user.role;

  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');

    // Get user details for password verification
    const userResult = await client.query('SELECT * FROM users WHERE id = $1', [userId]);
    if (userResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ message: 'User not found' });
    }

    const user = userResult.rows[0];

    // Verify password
    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      await client.query('ROLLBACK');
      return res.status(401).json({ message: 'Invalid password' });
    }

    // Log the account deletion BEFORE deleting anything (due to foreign key constraint)
    try {
      await client.query(
        `INSERT INTO user_activity_log (user_id, action, details, ip_address, user_agent, success, created_at) 
         VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
        [
          userId,
          'account_deleted',
          `Account deleted by user`,
          req.ip || 'unknown',
          req.get('User-Agent') || 'unknown',
          true
        ]
      );
    } catch (logError) {
      console.error('Error logging account deletion:', logError);
      // Continue with deletion even if logging fails
    }

    // Delete all related data that might have foreign key constraints
    // Order matters - delete child records before parent records
    
    // Delete user activity logs first
    try {
      await client.query('DELETE FROM user_activity_log WHERE user_id = $1', [userId]);
    } catch (err) {
      console.log('Note: Could not delete from user_activity_log:', err.message);
    }
    
    // Delete orders where user is involved (as buyer, distributor, or delivery person)
    try {
      await client.query('DELETE FROM orders WHERE buyer_id = $1 OR distributor_id = $1 OR delivery_person_id = $1', [userId]);
    } catch (err) {
      console.log('Note: Could not delete from orders:', err.message);
    }
    
    // Delete ratings given by or received by this user
    try {
      await client.query('DELETE FROM ratings WHERE rater_id = $1 OR rated_id = $1', [userId]);
    } catch (err) {
      console.log('Note: Could not delete from ratings:', err.message);
    }
    
    // Delete role-specific data
    switch (userRole) {
      case 'supermarket':
        try {
          await client.query('DELETE FROM supermarkets WHERE user_id = $1', [userId]);
        } catch (err) {
          console.log('Note: Could not delete from supermarkets:', err.message);
        }
        break;
      case 'distributor':
        // Delete distributor-related data first
        try {
          await client.query('DELETE FROM products WHERE distributor_id = $1', [userId]);
        } catch (err) {
          console.log('Note: Could not delete from products:', err.message);
        }
        try {
          await client.query('DELETE FROM offers WHERE distributor_id = $1', [userId]);
        } catch (err) {
          console.log('Note: Could not delete from offers:', err.message);
        }
        try {
          await client.query('DELETE FROM distributors WHERE user_id = $1', [userId]);
        } catch (err) {
          console.log('Note: Could not delete from distributors:', err.message);
        }
        break;
      case 'delivery':
        // Delete delivery-related data first
        try {
          await client.query('DELETE FROM delivery_assignments WHERE delivery_man_id = $1', [userId]);
        } catch (err) {
          console.log('Note: Could not delete from delivery_assignments:', err.message);
        }
        try {
          await client.query('DELETE FROM delivery_men WHERE user_id = $1', [userId]);
        } catch (err) {
          console.log('Note: Could not delete from delivery_men:', err.message);
        }
        break;
    }

    // Finally delete the user account
    await client.query('DELETE FROM users WHERE id = $1', [userId]);

    await client.query('COMMIT');
    res.json({ message: 'Account deleted successfully' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Delete account error:', err);
    res.status(500).json({ message: 'Failed to delete account' });
  } finally {
    client.release();
  }
};

module.exports = { signup, login, deleteAccount };
