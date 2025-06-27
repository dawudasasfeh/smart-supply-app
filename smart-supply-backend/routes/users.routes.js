// routes/users.routes.js
const express = require('express');
const router = express.Router();
const pool = require('../db');

// ✅ Get all users with a specific role (e.g., distributor), excluding a specific ID (optional)
router.get('/', async (req, res) => {
  const { role, exclude } = req.query;

  if (!role) {
    return res.status(400).json({ error: 'Missing role' });
  }

  try {
    // If exclude is provided, exclude that ID from results
    const result = exclude
      ? await pool.query(
          'SELECT id, name FROM users WHERE LOWER(role) = LOWER($1) AND id != $2',
          [role, exclude]
        )
      : await pool.query(
          'SELECT id, name FROM users WHERE LOWER(role) = LOWER($1)',
          [role]
        );

    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
