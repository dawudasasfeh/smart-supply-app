const { DataTypes } = require('sequelize');
const { Sequelize } = require('sequelize');

// Create Sequelize instance using environment variables
const sequelize = new Sequelize(process.env.DATABASE_URL || 'postgresql://username:password@localhost:5432/smart_supply', {
  dialect: 'postgres',
  logging: false
});

const Message = sequelize.define('Message', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  sender_id: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  receiver_id: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  sender_role: {
    type: DataTypes.STRING,
    allowNull: false
  },
  receiver_role: {
    type: DataTypes.STRING,
    allowNull: false
  },
  message: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  timestamp: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  read: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  delivered: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  }
}, {
  tableName: 'messages',
  timestamps: false
});

module.exports = Message;
