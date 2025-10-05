-- Route Optimization System Database Tables
-- Created for Smart Supply Chain Management App

-- 1. Route Optimization Sessions Table
CREATE TABLE IF NOT EXISTS route_optimization_sessions (
    id SERIAL PRIMARY KEY,
    session_name VARCHAR(255) NOT NULL,
    delivery_man_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    distributor_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'pending', -- pending, optimizing, completed, failed
    algorithm_used VARCHAR(100) DEFAULT 'nearest_neighbor', -- nearest_neighbor, genetic, simulated_annealing
    total_distance_km DECIMAL(10, 2),
    total_duration_minutes INTEGER,
    fuel_cost DECIMAL(10, 2),
    optimization_score DECIMAL(5, 2), -- 0-100 score
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    notes TEXT
);

-- 2. Route Optimization Orders Table
CREATE TABLE IF NOT EXISTS route_optimization_orders (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES route_optimization_sessions(id) ON DELETE CASCADE,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    sequence_order INTEGER NOT NULL, -- Order in the optimized route (1, 2, 3, etc.)
    estimated_arrival_time TIMESTAMP,
    estimated_departure_time TIMESTAMP,
    distance_from_previous_km DECIMAL(8, 2),
    duration_from_previous_minutes INTEGER,
    delivery_priority VARCHAR(20) DEFAULT 'normal', -- high, normal, low
    delivery_time_window_start TIME,
    delivery_time_window_end TIME,
    special_instructions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Route Optimization Waypoints Table
CREATE TABLE IF NOT EXISTS route_optimization_waypoints (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES route_optimization_sessions(id) ON DELETE CASCADE,
    waypoint_order INTEGER NOT NULL, -- Order in the route
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    address TEXT,
    waypoint_type VARCHAR(50) NOT NULL, -- pickup, delivery, depot
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    estimated_arrival_time TIMESTAMP,
    estimated_departure_time TIMESTAMP,
    distance_from_previous_km DECIMAL(8, 2),
    duration_from_previous_minutes INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Route Optimization Results Table
CREATE TABLE IF NOT EXISTS route_optimization_results (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES route_optimization_sessions(id) ON DELETE CASCADE,
    algorithm_name VARCHAR(100) NOT NULL,
    total_distance_km DECIMAL(10, 2) NOT NULL,
    total_duration_minutes INTEGER NOT NULL,
    fuel_cost DECIMAL(10, 2),
    optimization_score DECIMAL(5, 2),
    waypoint_count INTEGER NOT NULL,
    execution_time_ms INTEGER, -- Time taken to optimize in milliseconds
    parameters JSONB, -- Algorithm-specific parameters
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Route Optimization History Table
CREATE TABLE IF NOT EXISTS route_optimization_history (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES route_optimization_sessions(id) ON DELETE CASCADE,
    action VARCHAR(100) NOT NULL, -- optimize, recalculate, update_waypoint, complete
    performed_by INTEGER REFERENCES users(id),
    details JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. Delivery Time Windows Table
CREATE TABLE IF NOT EXISTS delivery_time_windows (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    preferred_start_time TIME,
    preferred_end_time TIME,
    earliest_delivery_time TIME,
    latest_delivery_time TIME,
    time_window_type VARCHAR(50) DEFAULT 'flexible', -- flexible, strict, preferred
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_route_sessions_delivery_man ON route_optimization_sessions(delivery_man_id);
CREATE INDEX IF NOT EXISTS idx_route_sessions_distributor ON route_optimization_sessions(distributor_id);
CREATE INDEX IF NOT EXISTS idx_route_sessions_status ON route_optimization_sessions(status);
CREATE INDEX IF NOT EXISTS idx_route_orders_session ON route_optimization_orders(session_id);
CREATE INDEX IF NOT EXISTS idx_route_orders_sequence ON route_optimization_orders(session_id, sequence_order);
CREATE INDEX IF NOT EXISTS idx_route_waypoints_session ON route_optimization_waypoints(session_id);
CREATE INDEX IF NOT EXISTS idx_route_waypoints_order ON route_optimization_waypoints(session_id, waypoint_order);
CREATE INDEX IF NOT EXISTS idx_route_results_session ON route_optimization_results(session_id);
CREATE INDEX IF NOT EXISTS idx_delivery_time_windows_order ON delivery_time_windows(order_id);

-- Add constraints
ALTER TABLE route_optimization_orders 
ADD CONSTRAINT unique_session_sequence UNIQUE (session_id, sequence_order);

ALTER TABLE route_optimization_waypoints 
ADD CONSTRAINT unique_session_waypoint_order UNIQUE (session_id, waypoint_order);

-- Insert sample data for testing
INSERT INTO delivery_time_windows (order_id, preferred_start_time, preferred_end_time, earliest_delivery_time, latest_delivery_time, time_window_type) 
SELECT 
    o.id,
    '09:00:00'::TIME,
    '17:00:00'::TIME,
    '08:00:00'::TIME,
    '18:00:00'::TIME,
    'flexible'
FROM orders o 
WHERE o.status IN ('accepted', 'pending')
LIMIT 10;
