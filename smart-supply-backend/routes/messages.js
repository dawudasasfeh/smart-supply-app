const express = require('express');
const router = express.Router();
const pool = require('../db');

// Add new endpoints for Socket.IO compatibility
router.post('/conversation', async (req, res) => {
  const { sender_id, receiver_id, sender_role, receiver_role } = req.body;
  try {
    // Check if conversation already exists
    const existing = await pool.query(
      `SELECT id FROM messages 
       WHERE (sender_id = $1 AND receiver_id = $2) 
          OR (sender_id = $2 AND receiver_id = $1) 
       LIMIT 1`,
      [sender_id, receiver_id]
    );
    
    if (existing.rows.length === 0) {
      // Create initial conversation entry (empty message to establish relationship)
      await pool.query(
        `INSERT INTO messages (sender_id, receiver_id, sender_role, receiver_role, message)
         VALUES ($1, $2, $3, $4, '')`,
        [sender_id, receiver_id, sender_role, receiver_role]
      );
    }
    
    res.status(201).json({ status: 'Conversation ready' });
  } catch (err) {
    console.error('Error creating conversation:', err);
    res.status(500).json({ error: err.message });
  }
});

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
      `WITH chat_partners AS (
         SELECT DISTINCT
           CASE 
             WHEN m.sender_id = $1 THEN m.receiver_id 
             ELSE m.sender_id 
           END AS other_id
         FROM messages m
         WHERE (m.sender_id = $1 OR m.receiver_id = $1)
           AND m.message != ''
       ),
       latest_messages AS (
         SELECT 
           cp.other_id,
           u.name,
           m.message AS lastmessage,
           m.timestamp AS last_message_time,
           COALESCE((SELECT COUNT(*)::INTEGER FROM messages 
            WHERE sender_id = cp.other_id 
              AND receiver_id = $1 
              AND read = false), 0) AS unread_count,
           ROW_NUMBER() OVER (PARTITION BY cp.other_id ORDER BY m.timestamp DESC) AS rn
         FROM chat_partners cp
         JOIN users u ON u.id = cp.other_id
         JOIN messages m ON (
           (m.sender_id = $1 AND m.receiver_id = cp.other_id) OR
           (m.sender_id = cp.other_id AND m.receiver_id = $1)
         )
         WHERE m.message != ''
       )
       SELECT other_id AS id, name, lastmessage, last_message_time, unread_count
       FROM latest_messages
       WHERE rn = 1
       ORDER BY last_message_time DESC`,
      [userId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching chat partners:', err);
    res.status(500).json({ error: err.message });
  }
});

// Mark all messages as read between two users
router.post('/mark-all-read', async (req, res) => {
  try {
    const { user_id, partner_id } = req.body;
    
    if (!user_id || !partner_id) {
      return res.status(400).json({ error: 'user_id and partner_id are required' });
    }

    // Mark all messages from partner to user as read
    await pool.query(
      'UPDATE messages SET read = true WHERE sender_id = $1 AND receiver_id = $2 AND read = false',
      [partner_id, user_id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Error marking messages as read:', err);
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
