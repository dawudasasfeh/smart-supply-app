const express = require('express');
const router = express.Router();
const pool = require('../db');
const authenticate = require('../middleware/auth.middleware');

// GET /api/profile/me
router.get('/me', authenticate, async (req, res) => {
  const userId = req.user.id;
  const role = req.user.role;

  try {
    let query;
    switch (role.toLowerCase()) {
      case 'supermarket':
        query = await pool.query(
          `SELECT store_name AS name, address, license_number, tax_id,
                  opening_hours, contact_person, contact_phone, website, description, created_at
           FROM supermarkets WHERE user_id = $1`,
          [userId]
        );
        break;

      case 'distributor':
        query = await pool.query(
          `SELECT company_name AS name, address, phone, email, tax_id,
                  license_number, description, created_at
           FROM distributors WHERE user_id = $1`,
          [userId]
        );
        break;

      case 'delivery':
        query = await pool.query(
          `SELECT full_name AS name, phone, vehicle_type, license_plate,
                  address, created_at
           FROM deliveries WHERE user_id = $1`,
          [userId]
        );
        break;

      default:
        return res.status(400).json({ message: 'Invalid role' });
    }

    if (query.rows.length === 0) {
      return res.status(404).json({ message: 'Profile not found' });
    }

    res.json(query.rows[0]);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
