-- Create delivery_verifications table for QR verification logging
CREATE TABLE IF NOT EXISTS delivery_verifications (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id),
    supermarket_id INTEGER NOT NULL REFERENCES users(id),
    delivery_man_id INTEGER REFERENCES users(id),
    verification_key VARCHAR(255) NOT NULL,
    verification_method VARCHAR(50) DEFAULT 'qr_code',
    verified_at TIMESTAMP DEFAULT NOW(),
    verification_location TEXT,
    device_info TEXT,
    ip_address INET,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_delivery_verifications_order_id ON delivery_verifications(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_verifications_supermarket_id ON delivery_verifications(supermarket_id);
CREATE INDEX IF NOT EXISTS idx_delivery_verifications_verified_at ON delivery_verifications(verified_at);
CREATE INDEX IF NOT EXISTS idx_delivery_verifications_verification_key ON delivery_verifications(verification_key);

-- Add comments for documentation
COMMENT ON TABLE delivery_verifications IS 'Logs all QR code delivery verifications for audit trail';
COMMENT ON COLUMN delivery_verifications.order_id IS 'Reference to the verified order';
COMMENT ON COLUMN delivery_verifications.supermarket_id IS 'Supermarket that generated the QR code';
COMMENT ON COLUMN delivery_verifications.delivery_man_id IS 'Delivery person who scanned the QR code';
COMMENT ON COLUMN delivery_verifications.verification_key IS 'The delivery code used for verification';
COMMENT ON COLUMN delivery_verifications.verification_method IS 'Method used for verification (qr_code, manual, etc.)';
COMMENT ON COLUMN delivery_verifications.verified_at IS 'When the verification occurred';
COMMENT ON COLUMN delivery_verifications.verification_location IS 'GPS coordinates or location info if available';
COMMENT ON COLUMN delivery_verifications.device_info IS 'Device information of the scanner';
COMMENT ON COLUMN delivery_verifications.ip_address IS 'IP address of the verification request';

-- Insert some sample data for testing (optional)
-- INSERT INTO delivery_verifications (order_id, supermarket_id, delivery_man_id, verification_key, verification_method)
-- VALUES 
--     (4, 2, 1, 'DEL004', 'qr_code'),
--     (13, 2, 1, 'DEL013', 'qr_code'),
--     (18, 2, 1, 'DEL018', 'qr_code');

SELECT 'delivery_verifications table created successfully' as result;
