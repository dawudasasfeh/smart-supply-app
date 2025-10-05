-- Order Tracking System Database Tables
-- Created for Smart Supply Chain Management App

-- 1. Order Tracking History Table
CREATE TABLE IF NOT EXISTS order_tracking_history (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    location_address TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by INTEGER REFERENCES users(id),
    estimated_delivery TIMESTAMP,
    actual_delivery TIMESTAMP
);

-- 2. Delivery Assignments Table (Enhanced)
CREATE TABLE IF NOT EXISTS delivery_assignments (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    delivery_man_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigned_by INTEGER REFERENCES users(id),
    status VARCHAR(50) DEFAULT 'assigned',
    pickup_location_lat DECIMAL(10, 8),
    pickup_location_lng DECIMAL(11, 8),
    pickup_address TEXT,
    delivery_location_lat DECIMAL(10, 8),
    delivery_location_lng DECIMAL(11, 8),
    delivery_address TEXT,
    estimated_pickup_time TIMESTAMP,
    actual_pickup_time TIMESTAMP,
    estimated_delivery_time TIMESTAMP,
    actual_delivery_time TIMESTAMP,
    distance_km DECIMAL(8, 2),
    estimated_duration_minutes INTEGER,
    delivery_fee DECIMAL(10, 2),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Delivery Status History Table
CREATE TABLE IF NOT EXISTS delivery_status_history (
    id SERIAL PRIMARY KEY,
    delivery_assignment_id INTEGER NOT NULL REFERENCES delivery_assignments(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    location_address TEXT,
    notes TEXT,
    photo_url TEXT,
    signature_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by INTEGER REFERENCES users(id)
);

-- 4. Delivery Men Table (Enhanced)
CREATE TABLE IF NOT EXISTS delivery_men (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_type VARCHAR(50),
    vehicle_number VARCHAR(100),
    license_number VARCHAR(100),
    phone VARCHAR(20),
    emergency_contact VARCHAR(20),
    current_location_lat DECIMAL(10, 8),
    current_location_lng DECIMAL(11, 8),
    last_location_update TIMESTAMP,
    status VARCHAR(50) DEFAULT 'available', -- available, busy, offline, on_break
    max_capacity INTEGER DEFAULT 10,
    current_load INTEGER DEFAULT 0,
    rating DECIMAL(3, 2) DEFAULT 5.0,
    total_deliveries INTEGER DEFAULT 0,
    successful_deliveries INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Real-time Location Tracking Table
CREATE TABLE IF NOT EXISTS delivery_location_tracking (
    id SERIAL PRIMARY KEY,
    delivery_assignment_id INTEGER NOT NULL REFERENCES delivery_assignments(id) ON DELETE CASCADE,
    delivery_man_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy DECIMAL(8, 2),
    speed DECIMAL(8, 2),
    heading DECIMAL(5, 2),
    altitude DECIMAL(8, 2),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    battery_level INTEGER,
    is_active BOOLEAN DEFAULT true
);

-- 6. Delivery Ratings Table
CREATE TABLE IF NOT EXISTS delivery_ratings (
    id SERIAL PRIMARY KEY,
    delivery_assignment_id INTEGER NOT NULL REFERENCES delivery_assignments(id) ON DELETE CASCADE,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    customer_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delivery_man_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    review TEXT,
    delivery_time_rating INTEGER CHECK (delivery_time_rating >= 1 AND delivery_time_rating <= 5),
    packaging_rating INTEGER CHECK (packaging_rating >= 1 AND packaging_rating <= 5),
    communication_rating INTEGER CHECK (communication_rating >= 1 AND communication_rating <= 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add tracking columns to existing orders table if they don't exist
DO $$ 
BEGIN
    -- Add delivery tracking columns to orders table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'tracking_number') THEN
        ALTER TABLE orders ADD COLUMN tracking_number VARCHAR(100) UNIQUE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'delivery_status') THEN
        ALTER TABLE orders ADD COLUMN delivery_status VARCHAR(50) DEFAULT 'pending';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'estimated_delivery_date') THEN
        ALTER TABLE orders ADD COLUMN estimated_delivery_date TIMESTAMP;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'actual_delivery_date') THEN
        ALTER TABLE orders ADD COLUMN actual_delivery_date TIMESTAMP;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'delivery_address') THEN
        ALTER TABLE orders ADD COLUMN delivery_address TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'delivery_lat') THEN
        ALTER TABLE orders ADD COLUMN delivery_lat DECIMAL(10, 8);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'delivery_lng') THEN
        ALTER TABLE orders ADD COLUMN delivery_lng DECIMAL(11, 8);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'delivery_instructions') THEN
        ALTER TABLE orders ADD COLUMN delivery_instructions TEXT;
    END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_order_tracking_order_id ON order_tracking_history(order_id);
CREATE INDEX IF NOT EXISTS idx_order_tracking_status ON order_tracking_history(status);
CREATE INDEX IF NOT EXISTS idx_order_tracking_created_at ON order_tracking_history(created_at);

CREATE INDEX IF NOT EXISTS idx_delivery_assignments_order_id ON delivery_assignments(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_assignments_delivery_man_id ON delivery_assignments(delivery_man_id);
CREATE INDEX IF NOT EXISTS idx_delivery_assignments_status ON delivery_assignments(status);

CREATE INDEX IF NOT EXISTS idx_delivery_status_history_assignment_id ON delivery_status_history(delivery_assignment_id);
CREATE INDEX IF NOT EXISTS idx_delivery_status_history_status ON delivery_status_history(status);

CREATE INDEX IF NOT EXISTS idx_delivery_location_tracking_assignment_id ON delivery_location_tracking(delivery_assignment_id);
CREATE INDEX IF NOT EXISTS idx_delivery_location_tracking_timestamp ON delivery_location_tracking(timestamp);

CREATE INDEX IF NOT EXISTS idx_delivery_men_user_id ON delivery_men(user_id);
CREATE INDEX IF NOT EXISTS idx_delivery_men_status ON delivery_men(status);

CREATE INDEX IF NOT EXISTS idx_orders_tracking_number ON orders(tracking_number);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_status ON orders(delivery_status);

-- Create triggers for automatic tracking number generation
CREATE OR REPLACE FUNCTION generate_tracking_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tracking_number IS NULL THEN
        NEW.tracking_number := 'TRK' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD') || LPAD(NEW.id::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for orders table
DROP TRIGGER IF EXISTS trigger_generate_tracking_number ON orders;
CREATE TRIGGER trigger_generate_tracking_number
    BEFORE INSERT OR UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION generate_tracking_number();

-- Create trigger for updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update trigger to relevant tables
DROP TRIGGER IF EXISTS trigger_update_delivery_assignments_updated_at ON delivery_assignments;
CREATE TRIGGER trigger_update_delivery_assignments_updated_at
    BEFORE UPDATE ON delivery_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_delivery_men_updated_at ON delivery_men;
CREATE TRIGGER trigger_update_delivery_men_updated_at
    BEFORE UPDATE ON delivery_men
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert sample delivery men data
INSERT INTO delivery_men (user_id, vehicle_type, plate_number, is_online, max_daily_orders, rating, total_deliveries, is_active)
SELECT 
    u.id,
    CASE 
        WHEN u.id % 3 = 0 THEN 'motorcycle'
        WHEN u.id % 3 = 1 THEN 'bicycle'
        ELSE 'van'
    END,
    'VH' || LPAD(u.id::TEXT, 4, '0'),
    true,
    CASE 
        WHEN u.id % 3 = 0 THEN 15
        WHEN u.id % 3 = 1 THEN 10
        ELSE 25
    END,
    4.0 + (RANDOM() * 1.0),
    FLOOR(RANDOM() * 100) + 10,
    true
FROM users u 
WHERE u.role = 'Delivery' 
AND NOT EXISTS (SELECT 1 FROM delivery_men dm WHERE dm.user_id = u.id);

-- Insert sample tracking history for existing orders
INSERT INTO order_tracking_history (order_id, status, location_address, notes)
SELECT 
    o.id,
    'order_placed',
    'Distribution Center - Main Warehouse',
    'Order received and processing started'
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM order_tracking_history oth WHERE oth.order_id = o.id);

COMMIT;
