-- Create delivery_analytics table for performance metrics (PostgreSQL version)
CREATE TABLE IF NOT EXISTS delivery_analytics (
    id SERIAL PRIMARY KEY,
    distributor_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    delivery_person_id INTEGER,
    delivery_start_time TIMESTAMP,
    delivery_end_time TIMESTAMP,
    delivery_duration_minutes INTEGER,
    is_on_time BOOLEAN DEFAULT FALSE,
    delivery_cost DECIMAL(10,2) DEFAULT 0.00,
    distance_km DECIMAL(8,2) DEFAULT 0.00,
    efficiency_score DECIMAL(3,1) DEFAULT 0.0,
    customer_rating DECIMAL(2,1) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_delivery_analytics_distributor_id ON delivery_analytics(distributor_id);
CREATE INDEX IF NOT EXISTS idx_delivery_analytics_order_id ON delivery_analytics(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_analytics_delivery_person_id ON delivery_analytics(delivery_person_id);
CREATE INDEX IF NOT EXISTS idx_delivery_analytics_delivery_date ON delivery_analytics(delivery_start_time);
CREATE INDEX IF NOT EXISTS idx_delivery_analytics_distributor_date ON delivery_analytics(distributor_id, delivery_start_time);
CREATE INDEX IF NOT EXISTS idx_delivery_analytics_performance_metrics ON delivery_analytics(distributor_id, is_on_time, efficiency_score);

-- Add foreign key constraints (if the referenced tables exist)
-- ALTER TABLE delivery_analytics ADD CONSTRAINT fk_distributor_id FOREIGN KEY (distributor_id) REFERENCES users(id) ON DELETE CASCADE;
-- ALTER TABLE delivery_analytics ADD CONSTRAINT fk_order_id FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;
-- ALTER TABLE delivery_analytics ADD CONSTRAINT fk_delivery_person_id FOREIGN KEY (delivery_person_id) REFERENCES users(id) ON DELETE SET NULL;
