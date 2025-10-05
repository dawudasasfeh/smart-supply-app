-- Create delivery_analytics table for performance metrics
CREATE TABLE IF NOT EXISTS delivery_analytics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    distributor_id INT NOT NULL,
    order_id INT NOT NULL,
    delivery_person_id INT,
    delivery_start_time DATETIME,
    delivery_end_time DATETIME,
    delivery_duration_minutes INT,
    is_on_time BOOLEAN DEFAULT FALSE,
    delivery_cost DECIMAL(10,2) DEFAULT 0.00,
    distance_km DECIMAL(8,2) DEFAULT 0.00,
    efficiency_score DECIMAL(3,1) DEFAULT 0.0,
    customer_rating DECIMAL(2,1) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_distributor_id (distributor_id),
    INDEX idx_order_id (order_id),
    INDEX idx_delivery_person_id (delivery_person_id),
    INDEX idx_delivery_date (delivery_start_time),
    
    FOREIGN KEY (distributor_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (delivery_person_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Create index for performance queries
CREATE INDEX idx_distributor_date ON delivery_analytics(distributor_id, delivery_start_time);
CREATE INDEX idx_performance_metrics ON delivery_analytics(distributor_id, is_on_time, efficiency_score);
