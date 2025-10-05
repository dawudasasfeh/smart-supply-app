const express = require('express');
const router = express.Router();
const authenticate = require('../middleware/auth.middleware');
const {
  PaymentMethodsController,
  UserPaymentMethodsController,
  PaymentTransactionsController,
  PaymentRefundsController,
  PaymentSettingsController
} = require('../controllers/payment.controller');

// Middleware to check admin role
const requireAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({
      success: false,
      message: 'Admin access required'
    });
  }
  next();
};

// ============================================================================
// PAYMENT METHODS ROUTES
// ============================================================================

// Get all active payment methods (Public)
router.get('/methods', PaymentMethodsController.getAllActive);

// Get payment method by ID (Public)
router.get('/methods/:id', PaymentMethodsController.getById);

// Create payment method (Admin only)
router.post('/methods', authenticate, requireAdmin, PaymentMethodsController.create);

// Update payment method (Admin only)
router.put('/methods/:id', authenticate, requireAdmin, PaymentMethodsController.update);

// ============================================================================
// USER PAYMENT METHODS ROUTES
// ============================================================================

// Get user's payment methods
router.get('/user/methods', authenticate, UserPaymentMethodsController.getUserPaymentMethods);

// Get user's default payment method
router.get('/user/methods/default', authenticate, UserPaymentMethodsController.getDefaultPaymentMethod);

// Add payment method for user
router.post('/user/methods', authenticate, UserPaymentMethodsController.addPaymentMethod);

// Set default payment method
router.put('/user/methods/default', authenticate, UserPaymentMethodsController.setDefaultPaymentMethod);

// Delete user payment method
router.delete('/user/methods/:id', authenticate, UserPaymentMethodsController.deletePaymentMethod);

// ============================================================================
// PAYMENT TRANSACTIONS ROUTES
// ============================================================================

// Create payment transaction
router.post('/transactions', authenticate, PaymentTransactionsController.createTransaction);

// Process payment (alias for create transaction with auto-completion)
router.post('/process', authenticate, PaymentTransactionsController.createTransaction);

// Get transaction by ID
router.get('/transactions/:id', authenticate, PaymentTransactionsController.getTransaction);

// Get user's transactions
router.get('/user/transactions', authenticate, PaymentTransactionsController.getUserTransactions);

// Get transactions by order ID
router.get('/orders/:orderId/transactions', authenticate, PaymentTransactionsController.getOrderTransactions);

// Update transaction status (Admin or Payment Gateway)
router.put('/transactions/:transactionId/status', authenticate, PaymentTransactionsController.updateTransactionStatus);

// Get transaction statistics
router.get('/transactions/stats', authenticate, PaymentTransactionsController.getTransactionStats);

// ============================================================================
// PAYMENT REFUNDS ROUTES
// ============================================================================

// Create refund
router.post('/refunds', authenticate, PaymentRefundsController.createRefund);

// Get refunds by transaction ID
router.get('/transactions/:transactionId/refunds', authenticate, PaymentRefundsController.getRefundsByTransaction);

// Update refund status (Admin or Payment Gateway)
router.put('/refunds/:refundId/status', authenticate, PaymentRefundsController.updateRefundStatus);

// ============================================================================
// PAYMENT SETTINGS ROUTES
// ============================================================================

// Get all payment settings
router.get('/settings', authenticate, PaymentSettingsController.getAllSettings);

// Update payment setting (Admin only)
router.put('/settings/:key', authenticate, requireAdmin, PaymentSettingsController.updateSetting);

// ============================================================================
// PAYMENT PROCESSING ROUTES
// ============================================================================

// Process payment (Main payment processing endpoint)
router.post('/process', authenticate, async (req, res) => {
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
    const { PaymentMethod } = require('../models/payment.model');
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
    const crypto = require('crypto');
    const transactionId = `TXN_${Date.now()}_${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

    // Create transaction
    const { PaymentTransaction } = require('../models/payment.model');
    const transaction = await PaymentTransaction.create({
      transaction_id: transactionId,
      order_id,
      user_id: userId,
      payment_method_id,
      amount,
      currency,
      status: 'pending',
      payment_gateway: paymentMethod.type === 'card' ? 'stripe' : 'fawry',
      processing_fee: processingFee,
      net_amount: netAmount
    });

    // Simulate payment processing based on payment method type
    let paymentResult;
    switch (paymentMethod.type) {
      case 'card':
        paymentResult = await processCardPayment(transaction);
        break;
      case 'digital_wallet':
        paymentResult = await processDigitalWalletPayment(transaction);
        break;
      case 'bank_transfer':
        paymentResult = await processBankTransferPayment(transaction);
        break;
      case 'cash':
        paymentResult = await processCashPayment(transaction);
        break;
      default:
        throw new Error('Unsupported payment method type');
    }

    // Update transaction status
    await PaymentTransaction.updateStatus(transactionId, paymentResult.status, paymentResult.gateway_response, paymentResult.failure_reason);

    res.json({
      success: true,
      data: {
        transaction,
        payment_result: paymentResult
      }
    });

  } catch (error) {
    console.error('Error processing payment:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to process payment',
      error: error.message
    });
  }
});

// ============================================================================
// PAYMENT GATEWAY WEBHOOKS
// ============================================================================

// Stripe webhook
router.post('/webhooks/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
  try {
    const sig = req.headers['stripe-signature'];
    const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;

    // Verify webhook signature
    const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
    let event;

    try {
      event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
    } catch (err) {
      console.error('Webhook signature verification failed:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    // Handle the event
    switch (event.type) {
      case 'payment_intent.succeeded':
        const paymentIntent = event.data.object;
        await handleStripePaymentSuccess(paymentIntent);
        break;
      case 'payment_intent.payment_failed':
        const failedPayment = event.data.object;
        await handleStripePaymentFailure(failedPayment);
        break;
      default:
        console.log(`Unhandled event type ${event.type}`);
    }

    res.json({ received: true });

  } catch (error) {
    console.error('Stripe webhook error:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

// Fawry webhook
router.post('/webhooks/fawry', async (req, res) => {
  try {
    const { merchantRefNumber, fawryRefNumber, status, amount } = req.body;
    
    // Verify webhook signature
    const { verifyFawrySignature } = require('../services/payment.service');
    const isValid = verifyFawrySignature(req.body, req.headers['x-fawry-signature']);
    
    if (!isValid) {
      return res.status(400).json({ error: 'Invalid signature' });
    }

    // Update transaction status
    const { PaymentTransaction } = require('../models/payment.model');
    const transaction = await PaymentTransaction.getByTransactionId(merchantRefNumber);
    
    if (transaction) {
      const status = status === 'SUCCESS' ? 'completed' : 'failed';
      await PaymentTransaction.updateStatus(merchantRefNumber, status, req.body);
    }

    res.json({ received: true });

  } catch (error) {
    console.error('Fawry webhook error:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Process card payment (Stripe simulation)
async function processCardPayment(transaction) {
  // Simulate Stripe payment processing
  const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
  
  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(transaction.amount * 100), // Convert to cents
      currency: transaction.currency.toLowerCase(),
      metadata: {
        transaction_id: transaction.transaction_id,
        order_id: transaction.order_id
      }
    });

    return {
      status: 'completed',
      gateway_response: paymentIntent,
      gateway_transaction_id: paymentIntent.id
    };
  } catch (error) {
    return {
      status: 'failed',
      failure_reason: error.message,
      gateway_response: { error: error.message }
    };
  }
}

// Process digital wallet payment (Fawry simulation)
async function processDigitalWalletPayment(transaction) {
  // Simulate Fawry payment processing
  const { createFawryPayment } = require('../services/payment.service');
  
  try {
    const fawryPayment = await createFawryPayment(transaction);
    
    return {
      status: 'completed',
      gateway_response: fawryPayment,
      gateway_transaction_id: fawryPayment.fawryRefNumber
    };
  } catch (error) {
    return {
      status: 'failed',
      failure_reason: error.message,
      gateway_response: { error: error.message }
    };
  }
}

// Process bank transfer payment
async function processBankTransferPayment(transaction) {
  // Bank transfer is always pending until manually confirmed
  return {
    status: 'pending',
    gateway_response: {
      message: 'Bank transfer initiated. Payment will be confirmed manually.',
      instructions: 'Please transfer the amount to the provided bank account.'
    }
  };
}

// Process cash payment
async function processCashPayment(transaction) {
  // Cash on delivery is always pending until delivery
  return {
    status: 'pending',
    gateway_response: {
      message: 'Cash on delivery. Payment will be collected upon delivery.',
      instructions: 'Please have the exact amount ready for the delivery person.'
    }
  };
}

// Handle Stripe payment success
async function handleStripePaymentSuccess(paymentIntent) {
  const { PaymentTransaction } = require('../models/payment.model');
  const transaction = await PaymentTransaction.getByTransactionId(paymentIntent.metadata.transaction_id);
  
  if (transaction) {
    await PaymentTransaction.updateStatus(transaction.transaction_id, 'completed', paymentIntent);
    
    // Update order status if needed
    const { Order } = require('../models/order.model');
    await Order.updateStatus(transaction.order_id, 'accepted');
  }
}

// Handle Stripe payment failure
async function handleStripePaymentFailure(paymentIntent) {
  const { PaymentTransaction } = require('../models/payment.model');
  const transaction = await PaymentTransaction.getByTransactionId(paymentIntent.metadata.transaction_id);
  
  if (transaction) {
    await PaymentTransaction.updateStatus(transaction.transaction_id, 'failed', paymentIntent, 'Payment failed');
  }
}

module.exports = router;

