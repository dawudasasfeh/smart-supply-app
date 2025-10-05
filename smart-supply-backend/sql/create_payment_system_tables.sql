-- Payment System Database Schema
-- This file creates all necessary tables for the payment system

-- 1. Payment Methods Table
CREATE TABLE IF NOT EXISTS payment_methods (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'card', 'bank_transfer', 'cash', 'digital_wallet'
    is_active BOOLEAN DEFAULT true,
    requires_verification BOOLEAN DEFAULT false,
    processing_fee_percentage DECIMAL(5,2) DEFAULT 0.00,
    min_amount DECIMAL(10,2) DEFAULT 0.00,
    max_amount DECIMAL(10,2) DEFAULT 999999.99,
    icon_url VARCHAR(255),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. User Payment Methods Table
CREATE TABLE IF NOT EXISTS user_payment_methods (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    payment_method_id INTEGER NOT NULL REFERENCES payment_methods(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT false,
    is_verified BOOLEAN DEFAULT false,
    card_last_four VARCHAR(4),
    card_brand VARCHAR(50),
    bank_name VARCHAR(100),
    account_number_masked VARCHAR(20),
    expiry_month INTEGER,
    expiry_year INTEGER,
    billing_address JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, payment_method_id)
);

-- 3. Payment Transactions Table
CREATE TABLE IF NOT EXISTS payment_transactions (
    id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(100) UNIQUE NOT NULL,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    payment_method_id INTEGER NOT NULL REFERENCES payment_methods(id),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EGP',
    status VARCHAR(50) NOT NULL, -- 'pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded'
    payment_gateway VARCHAR(50), -- 'stripe', 'paypal', 'fawry', 'bank_transfer'
    gateway_transaction_id VARCHAR(255),
    gateway_response JSONB,
    processing_fee DECIMAL(10,2) DEFAULT 0.00,
    net_amount DECIMAL(10,2) NOT NULL,
    failure_reason TEXT,
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Payment Refunds Table
CREATE TABLE IF NOT EXISTS payment_refunds (
    id SERIAL PRIMARY KEY,
    refund_id VARCHAR(100) UNIQUE NOT NULL,
    transaction_id VARCHAR(100) NOT NULL REFERENCES payment_transactions(transaction_id),
    amount DECIMAL(10,2) NOT NULL,
    reason TEXT,
    status VARCHAR(50) NOT NULL, -- 'pending', 'processing', 'completed', 'failed'
    gateway_refund_id VARCHAR(255),
    gateway_response JSONB,
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Payment Settings Table
CREATE TABLE IF NOT EXISTS payment_settings (
    id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    description TEXT,
    is_encrypted BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. Payment Analytics Table
CREATE TABLE IF NOT EXISTS payment_analytics (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    total_transactions INTEGER DEFAULT 0,
    total_amount DECIMAL(12,2) DEFAULT 0.00,
    successful_transactions INTEGER DEFAULT 0,
    failed_transactions INTEGER DEFAULT 0,
    refunded_transactions INTEGER DEFAULT 0,
    average_transaction_amount DECIMAL(10,2) DEFAULT 0.00,
    payment_method_breakdown JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(date)
);

-- Insert default payment methods
INSERT INTO payment_methods (name, type, is_active, requires_verification, processing_fee_percentage, min_amount, max_amount, description) VALUES
('Credit Card', 'card', true, true, 2.5, 10.00, 10000.00, 'Visa, MasterCard, American Express'),
('Debit Card', 'card', true, true, 1.5, 5.00, 5000.00, 'Local and international debit cards'),
('Bank Transfer', 'bank_transfer', true, false, 0.0, 50.00, 50000.00, 'Direct bank transfer'),
('Cash on Delivery', 'cash', true, false, 0.0, 0.00, 1000.00, 'Pay when order is delivered'),
('Fawry', 'digital_wallet', true, false, 1.0, 5.00, 2000.00, 'Fawry payment points'),
('Vodafone Cash', 'digital_wallet', true, false, 1.5, 5.00, 1000.00, 'Vodafone mobile wallet'),
('Orange Money', 'digital_wallet', true, false, 1.5, 5.00, 1000.00, 'Orange mobile wallet'),
('Etisalat Cash', 'digital_wallet', true, false, 1.5, 5.00, 1000.00, 'Etisalat mobile wallet');

-- Insert default payment settings
INSERT INTO payment_settings (setting_key, setting_value, description, is_encrypted) VALUES
('default_currency', 'EGP', 'Default currency for payments', false),
('payment_timeout_minutes', '30', 'Payment timeout in minutes', false),
('auto_refund_days', '7', 'Automatic refund after days', false),
('stripe_public_key', '', 'Stripe public key', true),
('stripe_secret_key', '', 'Stripe secret key', true),
('fawry_merchant_code', '', 'Fawry merchant code', true),
('fawry_security_key', '', 'Fawry security key', true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_payment_transactions_user_id ON payment_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_order_id ON payment_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_created_at ON payment_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_user_payment_methods_user_id ON user_payment_methods(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_refunds_transaction_id ON payment_refunds(transaction_id);

-- Create triggers for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_payment_methods_updated_at BEFORE UPDATE ON payment_methods FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_payment_methods_updated_at BEFORE UPDATE ON user_payment_methods FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payment_transactions_updated_at BEFORE UPDATE ON payment_transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payment_refunds_updated_at BEFORE UPDATE ON payment_refunds FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payment_settings_updated_at BEFORE UPDATE ON payment_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payment_analytics_updated_at BEFORE UPDATE ON payment_analytics FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

