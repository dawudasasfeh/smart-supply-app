const { PaymentMethod, UserPaymentMethod, PaymentTransaction, PaymentRefund, PaymentSettings } = require('../models/payment.model');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');

// Payment Methods Controller
const PaymentMethodsController = {
  // Get all active payment methods
  async getAllActive(req, res) {
    try {
      const paymentMethods = await PaymentMethod.getAllActive();
      res.json({
        success: true,
        data: paymentMethods
      });
    } catch (error) {
      console.error('Error fetching payment methods:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch payment methods',
        error: error.message
      });
    }
  },

  // Get payment method by ID
  async getById(req, res) {
    try {
      const { id } = req.params;
      const paymentMethod = await PaymentMethod.getById(id);
      
      if (!paymentMethod) {
        return res.status(404).json({
          success: false,
          message: 'Payment method not found'
        });
      }

      res.json({
        success: true,
        data: paymentMethod
      });
    } catch (error) {
      console.error('Error fetching payment method:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch payment method',
        error: error.message
      });
    }
  },

  // Create new payment method (Admin only)
  async create(req, res) {
    try {
      const paymentMethod = await PaymentMethod.create(req.body);
      res.status(201).json({
        success: true,
        data: paymentMethod
      });
    } catch (error) {
      console.error('Error creating payment method:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to create payment method',
        error: error.message
      });
    }
  },

  // Update payment method (Admin only)
  async update(req, res) {
    try {
      const { id } = req.params;
      const paymentMethod = await PaymentMethod.update(id, req.body);
      
      if (!paymentMethod) {
        return res.status(404).json({
          success: false,
          message: 'Payment method not found'
        });
      }

      res.json({
        success: true,
        data: paymentMethod
      });
    } catch (error) {
      console.error('Error updating payment method:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update payment method',
        error: error.message
      });
    }
  }
};

// User Payment Methods Controller
const UserPaymentMethodsController = {
  // Get user's payment methods
  async getUserPaymentMethods(req, res) {
    try {
      const userId = req.user.id;
      const paymentMethods = await UserPaymentMethod.getByUserId(userId);
      
      res.json({
        success: true,
        data: paymentMethods
      });
    } catch (error) {
      console.error('Error fetching user payment methods:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch payment methods',
        error: error.message
      });
    }
  },

  // Get user's default payment method
  async getDefaultPaymentMethod(req, res) {
    try {
      const userId = req.user.id;
      const defaultMethod = await UserPaymentMethod.getDefaultByUserId(userId);
      
      res.json({
        success: true,
        data: defaultMethod
      });
    } catch (error) {
      console.error('Error fetching default payment method:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch default payment method',
        error: error.message
      });
    }
  },

  // Add payment method for user
  async addPaymentMethod(req, res) {
    try {
      const userId = req.user.id;
      const { payment_method_id, is_default, card_last_four, card_brand, bank_name, account_number_masked, expiry_month, expiry_year, billing_address } = req.body;

      // Validate required fields
      if (!payment_method_id) {
        return res.status(400).json({
          success: false,
          message: 'Payment method ID is required'
        });
      }

      const userPaymentMethod = await UserPaymentMethod.create({
        user_id: userId,
        payment_method_id,
        is_default: is_default || false,
        card_last_four,
        card_brand,
        bank_name,
        account_number_masked,
        expiry_month,
        expiry_year,
        billing_address
      });

      res.status(201).json({
        success: true,
        data: userPaymentMethod
      });
    } catch (error) {
      console.error('Error adding payment method:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to add payment method',
        error: error.message
      });
    }
  },

  // Set default payment method
  async setDefaultPaymentMethod(req, res) {
    try {
      const userId = req.user.id;
      const { payment_method_id } = req.body;

      if (!payment_method_id) {
        return res.status(400).json({
          success: false,
          message: 'Payment method ID is required'
        });
      }

      const defaultMethod = await UserPaymentMethod.setDefault(userId, payment_method_id);
      
      if (!defaultMethod) {
        return res.status(404).json({
          success: false,
          message: 'Payment method not found for user'
        });
      }

      res.json({
        success: true,
        data: defaultMethod
      });
    } catch (error) {
      console.error('Error setting default payment method:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to set default payment method',
        error: error.message
      });
    }
  },

  // Delete user payment method
  async deletePaymentMethod(req, res) {
    try {
      const { id } = req.params;
      const userId = req.user.id;

      // Verify the payment method belongs to the user
      const userPaymentMethods = await UserPaymentMethod.getByUserId(userId);
      const paymentMethod = userPaymentMethods.find(pm => pm.id == id);

      if (!paymentMethod) {
        return res.status(404).json({
          success: false,
          message: 'Payment method not found'
        });
      }

      await UserPaymentMethod.delete(id);

      res.json({
        success: true,
        message: 'Payment method deleted successfully'
      });
    } catch (error) {
      console.error('Error deleting payment method:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to delete payment method',
        error: error.message
      });
    }
  }
};

// Payment Transactions Controller
const PaymentTransactionsController = {
  // Create payment transaction
  async createTransaction(req, res) {
    try {
      const { order_id, payment_method_id, amount, currency = 'EGP' } = req.body;
      const userId = req.user.id;

      // Validate required fields
      if (!order_id || !payment_method_id || !amount) {
        return res.status(400).json({
          success: false,
          message: 'Order ID, payment method ID, and amount are required'
        });
      }

      // Validate amount
      if (amount <= 0) {
        return res.status(400).json({
          success: false,
          message: 'Amount must be greater than 0'
        });
      }

      // Get payment method details
      const paymentMethod = await PaymentMethod.getById(payment_method_id);
      if (!paymentMethod) {
        return res.status(404).json({
          success: false,
          message: 'Payment method not found'
        });
      }

      // Calculate processing fee
      const processingFee = (amount * paymentMethod.processing_fee_percentage) / 100;
      const netAmount = amount - processingFee;

      // Generate unique transaction ID
      const transactionId = `TXN_${Date.now()}_${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

      // Create transaction with completed status (simplified for demo)
      // In production, this would integrate with actual payment gateways
      const transaction = await PaymentTransaction.create({
        transaction_id: transactionId,
        order_id,
        user_id: userId,
        payment_method_id,
        amount,
        currency,
        status: 'completed', // Auto-complete for demo purposes
        payment_gateway: paymentMethod.type === 'card' ? 'stripe' : 'fawry',
        processing_fee: processingFee,
        net_amount: netAmount,
        gateway_response: JSON.stringify({
          success: true,
          payment_id: transactionId,
          timestamp: new Date().toISOString(),
          message: 'Payment processed successfully'
        })
      });

      // Update order status to 'paid'
      try {
        const db = require('../config/db');
        await db.query(
          'UPDATE orders SET status = $1, payment_status = $2 WHERE id = $3',
          ['confirmed', 'paid', order_id]
        );
      } catch (orderUpdateError) {
        console.error('Error updating order status:', orderUpdateError);
        // Don't fail the transaction if order update fails
      }

      res.status(201).json({
        success: true,
        data: transaction,
        message: 'Payment processed successfully'
      });
    } catch (error) {
      console.error('Error creating payment transaction:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to create payment transaction',
        error: error.message
      });
    }
  },

  // Get transaction by ID
  async getTransaction(req, res) {
    try {
      const { id } = req.params;
      const transaction = await PaymentTransaction.getById(id);
      
      if (!transaction) {
        return res.status(404).json({
          success: false,
          message: 'Transaction not found'
        });
      }

      // Check if user owns this transaction
      if (transaction.user_id !== req.user.id && req.user.role !== 'admin') {
        return res.status(403).json({
          success: false,
          message: 'Access denied'
        });
      }

      res.json({
        success: true,
        data: transaction
      });
    } catch (error) {
      console.error('Error fetching transaction:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch transaction',
        error: error.message
      });
    }
  },

  // Get user's transactions
  async getUserTransactions(req, res) {
    try {
      const userId = req.user.id;
      const { limit = 50, offset = 0 } = req.query;
      
      const transactions = await PaymentTransaction.getByUserId(userId, parseInt(limit), parseInt(offset));
      
      res.json({
        success: true,
        data: transactions
      });
    } catch (error) {
      console.error('Error fetching user transactions:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch transactions',
        error: error.message
      });
    }
  },

  // Get transactions by order ID
  async getOrderTransactions(req, res) {
    try {
      const { orderId } = req.params;
      const transactions = await PaymentTransaction.getByOrderId(orderId);
      
      res.json({
        success: true,
        data: transactions
      });
    } catch (error) {
      console.error('Error fetching order transactions:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch order transactions',
        error: error.message
      });
    }
  },

  // Update transaction status
  async updateTransactionStatus(req, res) {
    try {
      const { transactionId } = req.params;
      const { status, gateway_response, failure_reason } = req.body;

      const validStatuses = ['pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded'];
      if (!validStatuses.includes(status)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid status'
        });
      }

      const transaction = await PaymentTransaction.updateStatus(transactionId, status, gateway_response, failure_reason);
      
      if (!transaction) {
        return res.status(404).json({
          success: false,
          message: 'Transaction not found'
        });
      }

      res.json({
        success: true,
        data: transaction
      });
    } catch (error) {
      console.error('Error updating transaction status:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update transaction status',
        error: error.message
      });
    }
  },

  // Get transaction statistics
  async getTransactionStats(req, res) {
    try {
      const userId = req.user.role === 'admin' ? null : req.user.id;
      const { startDate, endDate } = req.query;
      
      const stats = await PaymentTransaction.getStats(userId, startDate, endDate);
      
      res.json({
        success: true,
        data: stats
      });
    } catch (error) {
      console.error('Error fetching transaction stats:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch transaction statistics',
        error: error.message
      });
    }
  }
};

// Payment Refunds Controller
const PaymentRefundsController = {
  // Create refund
  async createRefund(req, res) {
    try {
      const { transaction_id, amount, reason } = req.body;
      const userId = req.user.id;

      // Validate required fields
      if (!transaction_id || !amount) {
        return res.status(400).json({
          success: false,
          message: 'Transaction ID and amount are required'
        });
      }

      // Get transaction details
      const transaction = await PaymentTransaction.getByTransactionId(transaction_id);
      if (!transaction) {
        return res.status(404).json({
          success: false,
          message: 'Transaction not found'
        });
      }

      // Check if user owns this transaction
      if (transaction.user_id !== userId && req.user.role !== 'admin') {
        return res.status(403).json({
          success: false,
          message: 'Access denied'
        });
      }

      // Validate refund amount
      if (amount > transaction.amount) {
        return res.status(400).json({
          success: false,
          message: 'Refund amount cannot exceed transaction amount'
        });
      }

      // Generate unique refund ID
      const refundId = `REF_${Date.now()}_${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

      // Create refund
      const refund = await PaymentRefund.create({
        refund_id: refundId,
        transaction_id,
        amount,
        reason: reason || 'Customer request',
        status: 'pending'
      });

      res.status(201).json({
        success: true,
        data: refund
      });
    } catch (error) {
      console.error('Error creating refund:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to create refund',
        error: error.message
      });
    }
  },

  // Get refunds by transaction ID
  async getRefundsByTransaction(req, res) {
    try {
      const { transactionId } = req.params;
      const refunds = await PaymentRefund.getByTransactionId(transactionId);
      
      res.json({
        success: true,
        data: refunds
      });
    } catch (error) {
      console.error('Error fetching refunds:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch refunds',
        error: error.message
      });
    }
  },

  // Update refund status
  async updateRefundStatus(req, res) {
    try {
      const { refundId } = req.params;
      const { status, gateway_response } = req.body;

      const validStatuses = ['pending', 'processing', 'completed', 'failed'];
      if (!validStatuses.includes(status)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid status'
        });
      }

      const refund = await PaymentRefund.updateStatus(refundId, status, gateway_response);
      
      if (!refund) {
        return res.status(404).json({
          success: false,
          message: 'Refund not found'
        });
      }

      res.json({
        success: true,
        data: refund
      });
    } catch (error) {
      console.error('Error updating refund status:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update refund status',
        error: error.message
      });
    }
  }
};

// Payment Settings Controller
const PaymentSettingsController = {
  // Get all settings
  async getAllSettings(req, res) {
    try {
      const settings = await PaymentSettings.getAll();
      
      // Filter out sensitive settings for non-admin users
      const filteredSettings = settings.map(setting => ({
        ...setting,
        setting_value: setting.is_encrypted && req.user.role !== 'admin' ? '***' : setting.setting_value
      }));
      
      res.json({
        success: true,
        data: filteredSettings
      });
    } catch (error) {
      console.error('Error fetching payment settings:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch payment settings',
        error: error.message
      });
    }
  },

  // Update setting (Admin only)
  async updateSetting(req, res) {
    try {
      const { key } = req.params;
      const { value } = req.body;

      const setting = await PaymentSettings.update(key, value);
      
      if (!setting) {
        return res.status(404).json({
          success: false,
          message: 'Setting not found'
        });
      }

      res.json({
        success: true,
        data: setting
      });
    } catch (error) {
      console.error('Error updating payment setting:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update payment setting',
        error: error.message
      });
    }
  }
};

module.exports = {
  PaymentMethodsController,
  UserPaymentMethodsController,
  PaymentTransactionsController,
  PaymentRefundsController,
  PaymentSettingsController
};

