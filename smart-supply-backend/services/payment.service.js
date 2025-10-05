const crypto = require('crypto');
const axios = require('axios');

// Payment Gateway Services
class PaymentService {
  constructor() {
    this.stripe = null;
    this.fawryConfig = {
      merchantCode: process.env.FAWRY_MERCHANT_CODE,
      securityKey: process.env.FAWRY_SECURITY_KEY,
      baseUrl: process.env.FAWRY_BASE_URL || 'https://atfawry.fawrystaging.com'
    };
  }

  // Initialize Stripe
  initializeStripe() {
    if (!this.stripe && process.env.STRIPE_SECRET_KEY) {
      const stripe = require('stripe');
      this.stripe = stripe(process.env.STRIPE_SECRET_KEY);
    }
    return this.stripe;
  }

  // ============================================================================
  // STRIPE PAYMENT METHODS
  // ============================================================================

  // Create Stripe payment intent
  async createStripePaymentIntent(amount, currency, metadata = {}) {
    try {
      const stripe = this.initializeStripe();
      if (!stripe) {
        throw new Error('Stripe not configured');
      }

      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(amount * 100), // Convert to cents
        currency: currency.toLowerCase(),
        metadata,
        automatic_payment_methods: {
          enabled: true,
        },
      });

      return {
        success: true,
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        data: paymentIntent
      };
    } catch (error) {
      console.error('Stripe payment intent creation failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // Confirm Stripe payment
  async confirmStripePayment(paymentIntentId) {
    try {
      const stripe = this.initializeStripe();
      if (!stripe) {
        throw new Error('Stripe not configured');
      }

      const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
      
      return {
        success: true,
        status: paymentIntent.status,
        data: paymentIntent
      };
    } catch (error) {
      console.error('Stripe payment confirmation failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ============================================================================
  // FAWRY PAYMENT METHODS
  // ============================================================================

  // Create Fawry payment
  async createFawryPayment(transaction) {
    try {
      const { amount, currency, transaction_id, user_id } = transaction;
      
      const paymentData = {
        merchantCode: this.fawryConfig.merchantCode,
        merchantRefNumber: transaction_id,
        customerMobile: '01234567890', // This should come from user profile
        customerEmail: 'customer@example.com', // This should come from user profile
        amount: amount,
        currencyCode: currency,
        language: 'ar',
        description: `Payment for Order ${transaction.order_id}`,
        chargeItems: [{
          itemId: transaction_id,
          description: `Payment for Order ${transaction.order_id}`,
          price: amount,
          quantity: 1
        }]
      };

      // Generate signature
      const signature = this.generateFawrySignature(paymentData);
      paymentData.signature = signature;

      const response = await axios.post(
        `${this.fawryConfig.baseUrl}/ECommerceWeb/Fawry/payments/charge`,
        paymentData,
        {
          headers: {
            'Content-Type': 'application/json'
          }
        }
      );

      if (response.data.statusCode === 200) {
        return {
          success: true,
          fawryRefNumber: response.data.referenceNumber,
          paymentUrl: response.data.paymentUrl,
          data: response.data
        };
      } else {
        throw new Error(response.data.statusDescription || 'Fawry payment creation failed');
      }
    } catch (error) {
      console.error('Fawry payment creation failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // Verify Fawry payment
  async verifyFawryPayment(merchantRefNumber) {
    try {
      const verificationData = {
        merchantCode: this.fawryConfig.merchantCode,
        merchantRefNumber: merchantRefNumber,
        signature: this.generateFawryVerificationSignature(merchantRefNumber)
      };

      const response = await axios.post(
        `${this.fawryConfig.baseUrl}/ECommerceWeb/Fawry/payments/status`,
        verificationData,
        {
          headers: {
            'Content-Type': 'application/json'
          }
        }
      );

      return {
        success: true,
        status: response.data.paymentStatus,
        data: response.data
      };
    } catch (error) {
      console.error('Fawry payment verification failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // Generate Fawry signature
  generateFawrySignature(data) {
    const { merchantCode, merchantRefNumber, customerMobile, customerEmail, amount, currencyCode, language, description, chargeItems } = data;
    
    const chargeItemsString = chargeItems.map(item => 
      `${item.itemId},${item.description},${item.price},${item.quantity}`
    ).join('|');
    
    const signatureString = `${merchantCode}|${merchantRefNumber}|${customerMobile}|${customerEmail}|${amount}|${currencyCode}|${language}|${description}|${chargeItemsString}|${this.fawryConfig.securityKey}`;
    
    return crypto.createHash('sha256').update(signatureString).digest('hex');
  }

  // Generate Fawry verification signature
  generateFawryVerificationSignature(merchantRefNumber) {
    const signatureString = `${this.fawryConfig.merchantCode}|${merchantRefNumber}|${this.fawryConfig.securityKey}`;
    return crypto.createHash('sha256').update(signatureString).digest('hex');
  }

  // Verify Fawry webhook signature
  verifyFawrySignature(data, signature) {
    const { merchantCode, merchantRefNumber, fawryRefNumber, status, amount } = data;
    const signatureString = `${merchantCode}|${merchantRefNumber}|${fawryRefNumber}|${status}|${amount}|${this.fawryConfig.securityKey}`;
    const expectedSignature = crypto.createHash('sha256').update(signatureString).digest('hex');
    
    return signature === expectedSignature;
  }

  // ============================================================================
  // BANK TRANSFER METHODS
  // ============================================================================

  // Generate bank transfer details
  async generateBankTransferDetails(transaction) {
    try {
      const bankDetails = {
        bankName: 'National Bank of Egypt',
        accountNumber: '12345678901234567890',
        accountName: 'Smart Supply Chain Ltd',
        iban: 'EG12345678901234567890123456',
        swiftCode: 'NBELEGCX',
        amount: transaction.amount,
        currency: transaction.currency,
        reference: transaction.transaction_id,
        instructions: 'Please include the reference number in your transfer description'
      };

      return {
        success: true,
        data: bankDetails
      };
    } catch (error) {
      console.error('Bank transfer details generation failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ============================================================================
  // CASH PAYMENT METHODS
  // ============================================================================

  // Generate cash payment details
  async generateCashPaymentDetails(transaction) {
    try {
      const cashDetails = {
        amount: transaction.amount,
        currency: transaction.currency,
        reference: transaction.transaction_id,
        instructions: 'Payment will be collected upon delivery',
        deliveryInstructions: 'Please have the exact amount ready for the delivery person',
        contactInfo: 'For questions about cash payment, contact us at +20 123 456 7890'
      };

      return {
        success: true,
        data: cashDetails
      };
    } catch (error) {
      console.error('Cash payment details generation failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ============================================================================
  // DIGITAL WALLET METHODS
  // ============================================================================

  // Generate digital wallet payment details
  async generateDigitalWalletDetails(transaction, walletType) {
    try {
      const walletDetails = {
        walletType: walletType,
        amount: transaction.amount,
        currency: transaction.currency,
        reference: transaction.transaction_id,
        instructions: this.getWalletInstructions(walletType),
        contactInfo: this.getWalletContactInfo(walletType)
      };

      return {
        success: true,
        data: walletDetails
      };
    } catch (error) {
      console.error('Digital wallet details generation failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // Get wallet-specific instructions
  getWalletInstructions(walletType) {
    const instructions = {
      'vodafone_cash': 'Send money to Vodafone Cash number: 01234567890',
      'orange_money': 'Send money to Orange Money number: 01234567890',
      'etisalat_cash': 'Send money to Etisalat Cash number: 01234567890',
      'fawry': 'Pay at any Fawry outlet using the reference number'
    };
    return instructions[walletType] || 'Follow the payment instructions for your selected wallet';
  }

  // Get wallet-specific contact info
  getWalletContactInfo(walletType) {
    const contactInfo = {
      'vodafone_cash': 'Vodafone Cash: *878# or call 1234',
      'orange_money': 'Orange Money: *999# or call 1234',
      'etisalat_cash': 'Etisalat Cash: *999# or call 1234',
      'fawry': 'Fawry: Call 1234 or visit any Fawry outlet'
    };
    return contactInfo[walletType] || 'Contact customer service for assistance';
  }

  // ============================================================================
  // PAYMENT PROCESSING METHODS
  // ============================================================================

  // Process payment based on method type
  async processPayment(transaction, paymentMethod) {
    try {
      switch (paymentMethod.type) {
        case 'card':
          return await this.processCardPayment(transaction);
        case 'digital_wallet':
          return await this.processDigitalWalletPayment(transaction, paymentMethod);
        case 'bank_transfer':
          return await this.processBankTransferPayment(transaction);
        case 'cash':
          return await this.processCashPayment(transaction);
        default:
          throw new Error(`Unsupported payment method type: ${paymentMethod.type}`);
      }
    } catch (error) {
      console.error('Payment processing failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // Process card payment
  async processCardPayment(transaction) {
    const result = await this.createStripePaymentIntent(
      transaction.amount,
      transaction.currency,
      {
        transaction_id: transaction.transaction_id,
        order_id: transaction.order_id,
        user_id: transaction.user_id
      }
    );

    return {
      status: result.success ? 'processing' : 'failed',
      gateway_response: result,
      gateway_transaction_id: result.payment_intent_id,
      failure_reason: result.success ? null : result.error
    };
  }

  // Process digital wallet payment
  async processDigitalWalletPayment(transaction, paymentMethod) {
    const result = await this.createFawryPayment(transaction);

    return {
      status: result.success ? 'processing' : 'failed',
      gateway_response: result,
      gateway_transaction_id: result.fawryRefNumber,
      failure_reason: result.success ? null : result.error
    };
  }

  // Process bank transfer payment
  async processBankTransferPayment(transaction) {
    const result = await this.generateBankTransferDetails(transaction);

    return {
      status: 'pending',
      gateway_response: result,
      gateway_transaction_id: null,
      failure_reason: null
    };
  }

  // Process cash payment
  async processCashPayment(transaction) {
    const result = await this.generateCashPaymentDetails(transaction);

    return {
      status: 'pending',
      gateway_response: result,
      gateway_transaction_id: null,
      failure_reason: null
    };
  }

  // ============================================================================
  // REFUND METHODS
  // ============================================================================

  // Process refund
  async processRefund(transaction, refundAmount, reason) {
    try {
      const paymentMethod = transaction.payment_method_type;
      
      switch (paymentMethod) {
        case 'card':
          return await this.processStripeRefund(transaction, refundAmount, reason);
        case 'digital_wallet':
          return await this.processFawryRefund(transaction, refundAmount, reason);
        case 'bank_transfer':
          return await this.processBankTransferRefund(transaction, refundAmount, reason);
        case 'cash':
          return await this.processCashRefund(transaction, refundAmount, reason);
        default:
          throw new Error(`Unsupported payment method for refund: ${paymentMethod}`);
      }
    } catch (error) {
      console.error('Refund processing failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // Process Stripe refund
  async processStripeRefund(transaction, refundAmount, reason) {
    try {
      const stripe = this.initializeStripe();
      if (!stripe) {
        throw new Error('Stripe not configured');
      }

      const refund = await stripe.refunds.create({
        payment_intent: transaction.gateway_transaction_id,
        amount: Math.round(refundAmount * 100), // Convert to cents
        reason: reason || 'requested_by_customer'
      });

      return {
        success: true,
        refund_id: refund.id,
        status: refund.status,
        data: refund
      };
    } catch (error) {
      console.error('Stripe refund failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // Process Fawry refund
  async processFawryRefund(transaction, refundAmount, reason) {
    // Fawry refunds are typically processed manually
    return {
      success: true,
      refund_id: `REF_${Date.now()}`,
      status: 'pending',
      data: {
        message: 'Refund request submitted. Will be processed within 3-5 business days.',
        amount: refundAmount,
        reason: reason
      }
    };
  }

  // Process bank transfer refund
  async processBankTransferRefund(transaction, refundAmount, reason) {
    return {
      success: true,
      refund_id: `REF_${Date.now()}`,
      status: 'pending',
      data: {
        message: 'Refund will be processed via bank transfer within 3-5 business days.',
        amount: refundAmount,
        reason: reason
      }
    };
  }

  // Process cash refund
  async processCashRefund(transaction, refundAmount, reason) {
    return {
      success: true,
      refund_id: `REF_${Date.now()}`,
      status: 'pending',
      data: {
        message: 'Refund will be processed during next delivery or visit to our office.',
        amount: refundAmount,
        reason: reason
      }
    };
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  // Generate unique transaction ID
  generateTransactionId() {
    return `TXN_${Date.now()}_${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
  }

  // Generate unique refund ID
  generateRefundId() {
    return `REF_${Date.now()}_${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
  }

  // Calculate processing fee
  calculateProcessingFee(amount, feePercentage) {
    return (amount * feePercentage) / 100;
  }

  // Validate payment amount
  validatePaymentAmount(amount, minAmount = 0, maxAmount = 999999.99) {
    if (amount < minAmount) {
      throw new Error(`Payment amount must be at least ${minAmount}`);
    }
    if (amount > maxAmount) {
      throw new Error(`Payment amount cannot exceed ${maxAmount}`);
    }
    return true;
  }

  // Format currency
  formatCurrency(amount, currency = 'EGP') {
    const formatter = new Intl.NumberFormat('en-EG', {
      style: 'currency',
      currency: currency
    });
    return formatter.format(amount);
  }
}

// Export singleton instance
module.exports = new PaymentService();

