const pool = require('../db');

// Payment Methods Model
const PaymentMethod = {
  // Get all active payment methods
  async getAllActive() {
    const result = await pool.query(
      'SELECT * FROM payment_methods WHERE is_active = true ORDER BY name'
    );
    return result.rows;
  },

  // Get payment method by ID
  async getById(id) {
    const result = await pool.query(
      'SELECT * FROM payment_methods WHERE id = $1',
      [id]
    );
    return result.rows[0];
  },

  // Create new payment method
  async create(paymentMethod) {
    const { name, type, is_active, requires_verification, processing_fee_percentage, min_amount, max_amount, icon_url, description } = paymentMethod;
    const result = await pool.query(
      `INSERT INTO payment_methods (name, type, is_active, requires_verification, processing_fee_percentage, min_amount, max_amount, icon_url, description)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [name, type, is_active, requires_verification, processing_fee_percentage, min_amount, max_amount, icon_url, description]
    );
    return result.rows[0];
  },

  // Update payment method
  async update(id, updates) {
    const fields = Object.keys(updates);
    const values = Object.values(updates);
    const setClause = fields.map((field, index) => `${field} = $${index + 2}`).join(', ');
    
    const result = await pool.query(
      `UPDATE payment_methods SET ${setClause}, updated_at = CURRENT_TIMESTAMP WHERE id = $1 RETURNING *`,
      [id, ...values]
    );
    return result.rows[0];
  },

  // Delete payment method
  async delete(id) {
    const result = await pool.query(
      'DELETE FROM payment_methods WHERE id = $1 RETURNING *',
      [id]
    );
    return result.rows[0];
  }
};

// User Payment Methods Model
const UserPaymentMethod = {
  // Get user's payment methods
  async getByUserId(userId) {
    const result = await pool.query(
      `SELECT upm.*, pm.name, pm.type, pm.icon_url, pm.description, pm.processing_fee_percentage
       FROM user_payment_methods upm
       JOIN payment_methods pm ON upm.payment_method_id = pm.id
       WHERE upm.user_id = $1 AND pm.is_active = true
       ORDER BY upm.is_default DESC, upm.created_at DESC`,
      [userId]
    );
    return result.rows;
  },

  // Get user's default payment method
  async getDefaultByUserId(userId) {
    const result = await pool.query(
      `SELECT upm.*, pm.name, pm.type, pm.icon_url, pm.description, pm.processing_fee_percentage
       FROM user_payment_methods upm
       JOIN payment_methods pm ON upm.payment_method_id = pm.id
       WHERE upm.user_id = $1 AND upm.is_default = true AND pm.is_active = true`,
      [userId]
    );
    return result.rows[0];
  },

  // Add payment method for user
  async create(userPaymentMethod) {
    const { user_id, payment_method_id, is_default, card_last_four, card_brand, bank_name, account_number_masked, expiry_month, expiry_year, billing_address } = userPaymentMethod;
    
    // If this is set as default, unset other defaults
    if (is_default) {
      await pool.query(
        'UPDATE user_payment_methods SET is_default = false WHERE user_id = $1',
        [user_id]
      );
    }

    const result = await pool.query(
      `INSERT INTO user_payment_methods (user_id, payment_method_id, is_default, card_last_four, card_brand, bank_name, account_number_masked, expiry_month, expiry_year, billing_address)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *`,
      [user_id, payment_method_id, is_default, card_last_four, card_brand, bank_name, account_number_masked, expiry_month, expiry_year, billing_address]
    );
    return result.rows[0];
  },

  // Update user payment method
  async update(id, updates) {
    const fields = Object.keys(updates);
    const values = Object.values(updates);
    const setClause = fields.map((field, index) => `${field} = $${index + 2}`).join(', ');
    
    const result = await pool.query(
      `UPDATE user_payment_methods SET ${setClause}, updated_at = CURRENT_TIMESTAMP WHERE id = $1 RETURNING *`,
      [id, ...values]
    );
    return result.rows[0];
  },

  // Set default payment method
  async setDefault(userId, paymentMethodId) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      // Unset all defaults for user
      await client.query(
        'UPDATE user_payment_methods SET is_default = false WHERE user_id = $1',
        [userId]
      );
      
      // Set new default
      const result = await client.query(
        'UPDATE user_payment_methods SET is_default = true, updated_at = CURRENT_TIMESTAMP WHERE user_id = $1 AND payment_method_id = $2 RETURNING *',
        [userId, paymentMethodId]
      );
      
      await client.query('COMMIT');
      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  // Delete user payment method
  async delete(id) {
    const result = await pool.query(
      'DELETE FROM user_payment_methods WHERE id = $1 RETURNING *',
      [id]
    );
    return result.rows[0];
  }
};

// Payment Transactions Model
const PaymentTransaction = {
  // Create new transaction
  async create(transaction) {
    const { transaction_id, order_id, user_id, payment_method_id, amount, currency, status, payment_gateway, gateway_transaction_id, gateway_response, processing_fee, net_amount } = transaction;
    
    const result = await pool.query(
      `INSERT INTO payment_transactions (transaction_id, order_id, user_id, payment_method_id, amount, currency, status, payment_gateway, gateway_transaction_id, gateway_response, processing_fee, net_amount)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING *`,
      [transaction_id, order_id, user_id, payment_method_id, amount, currency, status, payment_gateway, gateway_transaction_id, gateway_response, processing_fee, net_amount]
    );
    return result.rows[0];
  },

  // Get transaction by ID
  async getById(id) {
    const result = await pool.query(
      `SELECT pt.*, pm.name as payment_method_name, pm.type as payment_method_type,
              u.name as user_name, u.email as user_email
       FROM payment_transactions pt
       JOIN payment_methods pm ON pt.payment_method_id = pm.id
       JOIN users u ON pt.user_id = u.id
       WHERE pt.id = $1`,
      [id]
    );
    return result.rows[0];
  },

  // Get transaction by transaction ID
  async getByTransactionId(transactionId) {
    const result = await pool.query(
      `SELECT pt.*, pm.name as payment_method_name, pm.type as payment_method_type,
              u.name as user_name, u.email as user_email
       FROM payment_transactions pt
       JOIN payment_methods pm ON pt.payment_method_id = pm.id
       JOIN users u ON pt.user_id = u.id
       WHERE pt.transaction_id = $1`,
      [transactionId]
    );
    return result.rows[0];
  },

  // Get transactions by user ID
  async getByUserId(userId, limit = 50, offset = 0) {
    const result = await pool.query(
      `SELECT pt.*, pm.name as payment_method_name, pm.type as payment_method_type
       FROM payment_transactions pt
       JOIN payment_methods pm ON pt.payment_method_id = pm.id
       WHERE pt.user_id = $1
       ORDER BY pt.created_at DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset]
    );
    return result.rows;
  },

  // Get transactions by order ID
  async getByOrderId(orderId) {
    const result = await pool.query(
      `SELECT pt.*, pm.name as payment_method_name, pm.type as payment_method_type
       FROM payment_transactions pt
       JOIN payment_methods pm ON pt.payment_method_id = pm.id
       WHERE pt.order_id = $1
       ORDER BY pt.created_at DESC`,
      [orderId]
    );
    return result.rows;
  },

  // Update transaction status
  async updateStatus(transactionId, status, gatewayResponse = null, failureReason = null) {
    const updates = {
      status,
      updated_at: new Date()
    };

    if (gatewayResponse) {
      updates.gateway_response = gatewayResponse;
    }

    if (failureReason) {
      updates.failure_reason = failureReason;
    }

    if (status === 'completed') {
      updates.processed_at = new Date();
    }

    const fields = Object.keys(updates);
    const values = Object.values(updates);
    const setClause = fields.map((field, index) => `${field} = $${index + 2}`).join(', ');

    const result = await pool.query(
      `UPDATE payment_transactions SET ${setClause} WHERE transaction_id = $1 RETURNING *`,
      [transactionId, ...values]
    );
    return result.rows[0];
  },

  // Get transaction statistics
  async getStats(userId = null, startDate = null, endDate = null) {
    let query = `
      SELECT 
        COUNT(*) as total_transactions,
        SUM(amount) as total_amount,
        SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END) as successful_amount,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as successful_transactions,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_transactions,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_transactions,
        AVG(amount) as average_amount
      FROM payment_transactions
      WHERE 1=1
    `;
    
    const params = [];
    let paramCount = 0;

    if (userId) {
      paramCount++;
      query += ` AND user_id = $${paramCount}`;
      params.push(userId);
    }

    if (startDate) {
      paramCount++;
      query += ` AND created_at >= $${paramCount}`;
      params.push(startDate);
    }

    if (endDate) {
      paramCount++;
      query += ` AND created_at <= $${paramCount}`;
      params.push(endDate);
    }

    const result = await pool.query(query, params);
    return result.rows[0];
  }
};

// Payment Refunds Model
const PaymentRefund = {
  // Create refund
  async create(refund) {
    const { refund_id, transaction_id, amount, reason, status, gateway_refund_id, gateway_response } = refund;
    
    const result = await pool.query(
      `INSERT INTO payment_refunds (refund_id, transaction_id, amount, reason, status, gateway_refund_id, gateway_response)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [refund_id, transaction_id, amount, reason, status, gateway_refund_id, gateway_response]
    );
    return result.rows[0];
  },

  // Get refunds by transaction ID
  async getByTransactionId(transactionId) {
    const result = await pool.query(
      'SELECT * FROM payment_refunds WHERE transaction_id = $1 ORDER BY created_at DESC',
      [transactionId]
    );
    return result.rows;
  },

  // Update refund status
  async updateStatus(refundId, status, gatewayResponse = null) {
    const updates = {
      status,
      updated_at: new Date()
    };

    if (gatewayResponse) {
      updates.gateway_response = gatewayResponse;
    }

    if (status === 'completed') {
      updates.processed_at = new Date();
    }

    const fields = Object.keys(updates);
    const values = Object.values(updates);
    const setClause = fields.map((field, index) => `${field} = $${index + 2}`).join(', ');

    const result = await pool.query(
      `UPDATE payment_refunds SET ${setClause} WHERE refund_id = $1 RETURNING *`,
      [refundId, ...values]
    );
    return result.rows[0];
  }
};

// Payment Settings Model
const PaymentSettings = {
  // Get all settings
  async getAll() {
    const result = await pool.query('SELECT * FROM payment_settings ORDER BY setting_key');
    return result.rows;
  },

  // Get setting by key
  async getByKey(key) {
    const result = await pool.query(
      'SELECT * FROM payment_settings WHERE setting_key = $1',
      [key]
    );
    return result.rows[0];
  },

  // Update setting
  async update(key, value) {
    const result = await pool.query(
      'UPDATE payment_settings SET setting_value = $1, updated_at = CURRENT_TIMESTAMP WHERE setting_key = $2 RETURNING *',
      [value, key]
    );
    return result.rows[0];
  }
};

module.exports = {
  PaymentMethod,
  UserPaymentMethod,
  PaymentTransaction,
  PaymentRefund,
  PaymentSettings
};

