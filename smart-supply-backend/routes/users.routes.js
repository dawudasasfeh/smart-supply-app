const express = require('express');
const router = express.Router();
const pool = require('../db');

// Get all users with a specific role (e.g., delivery), excluding a specific ID (optional)
router.get('/', async (req, res) => {
  const { role, exclude } = req.query;
  if (!role) return res.status(400).json({ error: 'Missing role' });

  try {
    const result = await pool.query(
      `SELECT id, name FROM users WHERE LOWER(role) = LOWER($1) AND id != $2`,
      [role, exclude || 0]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


module.exports = router;
