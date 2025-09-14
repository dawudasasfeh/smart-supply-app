const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const { createServer } = require('http');
const { Server } = require('socket.io');

dotenv.config();

const app = express();
const server = createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

// Routes
app.use('/api/users', require('./routes/users.routes'));
app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/products', require('./routes/product.routes'));
app.use('/api/orders', require('./routes/order.routes'));
app.use('/api/offers', require('./routes/offer.routes'));
app.use('/api/messages', require('./routes/messages'));
app.use('/api/delivery', require('./routes/delivery'));
app.use('/api/profile',require('./routes/profile.routes'))
app.use('/api/ai', require('./routes/ai.routes'));
app.use('/api/inventory', require('./routes/inventory.routes'));
app.use('/api/supermarket', require('./routes/supermarket.routes'));
app.use('/api/ratings', require('./routes/rating.routes'));
app.use('/api/qr', require('./routes/qr.routes'));


// Socket.IO connection handling
const connectedUsers = new Map();

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // User joins with their ID and role
  socket.on('join', (userData) => {
    const { userId, role, name } = userData;
    connectedUsers.set(userId, {
      socketId: socket.id,
      role,
      name,
      online: true
    });
    socket.userId = userId;
    socket.join(`user_${userId}`);
    
    // Notify others about online status
    socket.broadcast.emit('user_online', { userId, name, role });
    console.log(`User ${name} (${role}) joined with ID: ${userId}`);
  });

  // Handle sending messages
  socket.on('send_message', async (messageData) => {
    try {
      const { senderId, receiverId, message, senderRole, receiverRole } = messageData;
      
      // Save message to database using pool
      const pool = require('./db');
      const result = await pool.query(
        `INSERT INTO messages (sender_id, receiver_id, sender_role, receiver_role, message, delivered)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
        [senderId, receiverId, senderRole, receiverRole, message, true]
      );

      const newMessage = result.rows[0];

      // Send to receiver if online
      const messageWithTimestamp = {
        id: newMessage.id,
        sender_id: senderId,
        receiver_id: receiverId,
        message: message,
        sender_role: senderRole,
        receiver_role: receiverRole,
        timestamp: newMessage.timestamp,
        delivered: true,
        read: false
      };

      // Send to receiver
      io.to(`user_${receiverId}`).emit('receive_message', messageWithTimestamp);
      
      // Send confirmation to sender with proper structure
      socket.emit('message_sent', messageWithTimestamp);

      console.log(`Message sent from ${senderId} to ${receiverId}: ${message}`);

    } catch (error) {
      console.error('Error sending message:', error);
      socket.emit('message_error', { error: 'Failed to send message' });
    }
  });

  // Handle message read status
  socket.on('mark_read', async (messageId) => {
    try {
      const pool = require('./db');
      
      // Update message as read
      await pool.query(
        'UPDATE messages SET read = true WHERE id = $1',
        [messageId]
      );
      
      // Get message details to notify sender
      const result = await pool.query(
        'SELECT sender_id FROM messages WHERE id = $1',
        [messageId]
      );
      
      if (result.rows.length > 0) {
        const senderId = result.rows[0].sender_id;
        io.to(`user_${senderId}`).emit('message_read', { messageId });
      }
    } catch (error) {
      console.error('Error marking message as read:', error);
    }
  });

  // Handle typing indicators
  socket.on('typing', (data) => {
    const { receiverId, isTyping } = data;
    io.to(`user_${receiverId}`).emit('user_typing', {
      userId: socket.userId,
      isTyping
    });
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    if (socket.userId) {
      connectedUsers.delete(socket.userId);
      socket.broadcast.emit('user_offline', { userId: socket.userId });
      console.log(`User ${socket.userId} disconnected`);
    }
  });
});

// Make io available to routes
app.set('io', io);

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server running on port ${PORT} with Socket.IO`));
