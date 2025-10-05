const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');
const { createServer } = require('http');
const { Server } = require('socket.io');
const pool = require('./db');
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

// Serve static files for uploaded images
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.use('/api/users', require('./routes/users.routes'));
app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/products', require('./routes/product.routes'));
app.use('/api/orders', require('./routes/order.routes'));
app.use('/api/offers', require('./routes/offer.routes'));
app.use('/api/messages', require('./routes/messages'));
app.use('/api/delivery', require('./routes/delivery'));
app.use('/api/tracking', require('./routes/tracking'));
app.use('/api/profile',require('./routes/profile.routes'))
app.use('/api/ai', require('./routes/ai.routes'));
app.use('/api/inventory', require('./routes/inventory.routes'));
app.use('/api/supermarket', require('./routes/supermarket.routes'));
app.use('/api/ratings', require('./routes/rating.routes'));
app.use('/api/supplier-ratings', require('./routes/supplierRating.routes'));
app.use('/api/qr', require('./routes/qr.routes'));
app.use('/api/distributor', require('./routes/distributorRoutes'));
app.use('/api/dashboard', require('./routes/dashboard.routes'));
app.use('/api/analytics', require('./routes/deliveryAnalytics'));
app.use('/api/personnel', require('./routes/personnelRoutes'));
app.use('/api/route-optimization', require('./routes/routeOptimization'));
app.use('/api/payment', require('./routes/payment.routes'));


// Socket.IO connection handling
const connectedUsers = new Map();
const userSockets = new Map();

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // Handle user joining with their info
  socket.on('join', (userData) => {
    socket.userData = userData;
    console.log(`User ${userData.name} (${userData.role}) joined with ID: ${userData.id}`);
    
    // Join room based on role
    socket.join(userData.role);
    
    // Join delivery-specific rooms
    if (userData.role === 'distributor') {
      socket.join(`distributor_${userData.id}`);
      socket.join('delivery_updates');
    } else if (userData.role === 'delivery') {
      socket.join(`delivery_man_${userData.id}`);
      socket.join('delivery_updates');
    } else if (userData.role === 'supermarket') {
      socket.join(`supermarket_${userData.id}`);
    }
    
    // Store socket reference for this user
    userSockets.set(userData.id, socket);
  });

  // Handle delivery status updates
  socket.on('delivery_status_update', (data) => {
    console.log('📦 Delivery status update received:', data);
    
    // Broadcast to relevant parties
    if (data.order_id && data.status) {
      // Notify distributor
      socket.to('distributor').emit('delivery_status_changed', {
        order_id: data.order_id,
        status: data.status,
        delivery_man_id: data.delivery_man_id,
        location: data.location,
        timestamp: new Date().toISOString()
      });
      
      // Notify supermarket (customer)
      socket.to('supermarket').emit('order_status_update', {
        order_id: data.order_id,
        status: data.status,
        estimated_arrival: data.estimated_arrival,
        timestamp: new Date().toISOString()
      });
    }
  });

  // Handle new delivery assignment
  socket.on('delivery_assigned', (data) => {
    console.log('📋 New delivery assignment:', data);
    
    // Notify the assigned delivery man
    if (data.delivery_man_id) {
      socket.to(`delivery_man_${data.delivery_man_id}`).emit('new_assignment', {
        order_id: data.order_id,
        customer_name: data.customer_name,
        delivery_address: data.delivery_address,
        priority: data.priority,
        timestamp: new Date().toISOString()
      });
    }
    
    // Notify distributor
    socket.to('delivery_updates').emit('assignment_created', {
      order_id: data.order_id,
      delivery_man_id: data.delivery_man_id,
      delivery_man_name: data.delivery_man_name,
      timestamp: new Date().toISOString()
    });
  });

  // Handle delivery location updates
  socket.on('location_update', (data) => {
    console.log('📍 Location update received:', data);
    
    // Broadcast location to distributors and customers
    socket.to('delivery_updates').emit('delivery_location_update', {
      delivery_man_id: data.delivery_man_id,
      order_id: data.order_id,
      latitude: data.latitude,
      longitude: data.longitude,
      timestamp: new Date().toISOString()
    });
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

// Helper function to emit order events to distributors
const emitToDistributors = (event, data) => {
  connectedUsers.forEach((user, userId) => {
    if (user.role === 'distributor') {
      io.to(`user_${userId}`).emit(event, data);
    }
  });
};

// Helper function to emit delivery events
const emitToDeliveryPersonnel = (event, data) => {
  connectedUsers.forEach((user, userId) => {
    if (user.role === 'delivery') {
      io.to(`user_${userId}`).emit(event, data);
    }
  });
};

// Make helper functions available to routes
app.set('emitToDistributors', emitToDistributors);
app.set('emitToDeliveryPersonnel', emitToDeliveryPersonnel);

// Make io available to routes
app.set('io', io);

// Add a test endpoint for debugging
app.get('/test/orders/:buyerId', async (req, res) => {
  try {
    const buyerId = parseInt(req.params.buyerId, 10);
    const db = require('./db');
    
    // Simple test query
    const result = await db.query('SELECT * FROM orders WHERE buyer_id = $1', [buyerId]);
    
    res.json({
      message: 'Orders test endpoint',
      buyerId: buyerId,
      ordersFound: result.rows.length,
      orders: result.rows
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT} with Socket.IO`);
  console.log(`🌐 Server accessible at:`);
  console.log(`   - http://localhost:${PORT} (local)`);
  console.log(`   - http://127.0.0.1:${PORT} (local)`);
  console.log(`   - http://10.0.2.2:${PORT} (Android emulator)`);
  console.log(`🚀 BRAND NEW Delivery System Ready - Built from scratch for your database!`);
});
