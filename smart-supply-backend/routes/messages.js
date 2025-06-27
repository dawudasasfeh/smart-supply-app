const express = require('express');
const router = express.Router();
const pool = require('../db');

// ✅ Send message
router.post('/', async (req, res) => {
  const { sender_id, receiver_id, sender_role, receiver_role, message } = req.body;
  try {
    await pool.query(
      `INSERT INTO messages (sender_id, receiver_id, sender_role, receiver_role, message)
       VALUES ($1, $2, $3, $4, $5)`,
      [sender_id, receiver_id, sender_role, receiver_role, message]
    );
    res.status(201).json({ status: 'Message sent' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ✅ Fetch conversation between two users
router.get('/', async (req, res) => {
  const { senderId, receiverId } = req.query;
  try {
    const result = await pool.query(
      `SELECT * FROM messages
       WHERE (sender_id = $1 AND receiver_id = $2)
          OR (sender_id = $2 AND receiver_id = $1)
       ORDER BY timestamp`,
      [senderId, receiverId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ✅ Fetch chat partners
router.get('/partners', async (req, res) => {
  const { userId, role } = req.query;
  try {
    const result = await pool.query(
      `SELECT DISTINCT ON (other_id) other_id AS id, name, MAX(message) AS lastMessage
       FROM (
         SELECT m.receiver_id AS other_id, u.name, m.message, m.timestamp
         FROM messages m JOIN users u ON u.id = m.receiver_id
         WHERE m.sender_id = $1 AND m.sender_role = $2

         UNION

         SELECT m.sender_id AS other_id, u.name, m.message, m.timestamp
         FROM messages m JOIN users u ON u.id = m.sender_id
         WHERE m.receiver_id = $1 AND m.receiver_role = $2
       ) AS sub
       GROUP BY other_id, name
       ORDER BY other_id, MAX(timestamp) DESC`,
      [userId, role]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ✅ Start chat
router.post('/start', async (req, res) => {
  const { sender_id, receiver_id, sender_role, receiver_role, message } = req.body;
  if (!sender_id || !receiver_id || !message) {
    return res.status(400).json({ error: 'Missing fields' });
  }
  try {
    await pool.query(
      `INSERT INTO messages (sender_id, receiver_id, sender_role, receiver_role, message)
       VALUES ($1, $2, $3, $4, $5)`,
      [sender_id, receiver_id, sender_role, receiver_role, message]
    );
    res.json({ status: 'Chat started' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
