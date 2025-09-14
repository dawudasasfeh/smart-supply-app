-- Rating System Database Schema
-- Smart Supply Chain Management System

-- 1. Rating Criteria Table
CREATE TABLE rating_criteria (
    id SERIAL PRIMARY KEY,
    criteria_name VARCHAR(100) NOT NULL,
    rating_type VARCHAR(50) NOT NULL, -- 'supplier_rating', 'delivery_rating', 'retailer_rating'
    description TEXT,
    weight DECIMAL(3,2) DEFAULT 1.00, -- Weight for calculating overall rating
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Main Ratings Table
CREATE TABLE ratings (
    id SERIAL PRIMARY KEY,
    rater_id INTEGER NOT NULL, -- ID of user giving the rating
    rated_id INTEGER NOT NULL, -- ID of user/entity being rated
    rater_role VARCHAR(20) NOT NULL, -- 'supermarket', 'distributor', 'delivery'
    rated_role VARCHAR(20) NOT NULL, -- 'supermarket', 'distributor', 'delivery'
    rating_type VARCHAR(50) NOT NULL, -- 'supplier_rating', 'delivery_rating', 'retailer_rating'
    overall_rating DECIMAL(3,2) NOT NULL CHECK (overall_rating >= 1.0 AND overall_rating <= 5.0),
    comment TEXT,
    order_id INTEGER, -- Optional: Link to specific order/transaction
    is_anonymous BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key constraints (assuming users table exists)
    FOREIGN KEY (rater_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (rated_id) REFERENCES users(id) ON DELETE CASCADE,
    
    -- Prevent duplicate ratings for same transaction
    UNIQUE(rater_id, rated_id, order_id, rating_type)
);

-- 3. Rating Criteria Scores Table (detailed breakdown)
CREATE TABLE rating_criteria_scores (
    id SERIAL PRIMARY KEY,
    rating_id INTEGER NOT NULL,
    criteria_id INTEGER NOT NULL,
    score DECIMAL(3,2) NOT NULL CHECK (score >= 1.0 AND score <= 5.0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (rating_id) REFERENCES ratings(id) ON DELETE CASCADE,
    FOREIGN KEY (criteria_id) REFERENCES rating_criteria(id) ON DELETE CASCADE,
    
    -- Prevent duplicate criteria scores for same rating
    UNIQUE(rating_id, criteria_id)
);

-- 4. Rating Summary/Analytics Table (for performance)
CREATE TABLE rating_summaries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    user_role VARCHAR(20) NOT NULL,
    rating_type VARCHAR(50) NOT NULL,
    total_ratings INTEGER DEFAULT 0,
    average_rating DECIMAL(3,2) DEFAULT 0.00,
    total_score DECIMAL(10,2) DEFAULT 0.00,
    last_rating_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    -- One summary per user per rating type
    UNIQUE(user_id, rating_type)
);

-- Insert default rating criteria
INSERT INTO rating_criteria (criteria_name, rating_type, description, weight) VALUES
-- Supplier Rating Criteria (Supermarket -> Distributor)
('Product Quality', 'supplier_rating', 'Quality of products delivered', 1.2),
('Delivery Time', 'supplier_rating', 'Timeliness of deliveries', 1.1),
('Pricing', 'supplier_rating', 'Competitive and fair pricing', 1.0),
('Customer Service', 'supplier_rating', 'Responsiveness and support', 1.0),
('Reliability', 'supplier_rating', 'Consistency in service delivery', 1.1),

-- Delivery Rating Criteria (Supermarket -> Delivery)
('Punctuality', 'delivery_rating', 'On-time delivery performance', 1.2),
('Package Condition', 'delivery_rating', 'Condition of delivered items', 1.1),
('Communication', 'delivery_rating', 'Updates and communication during delivery', 1.0),
('Professionalism', 'delivery_rating', 'Professional behavior and appearance', 1.0),

-- Retailer Rating Criteria (Distributor/Delivery -> Supermarket)
('Payment Timeliness', 'retailer_rating', 'Prompt payment of invoices', 1.2),
('Communication', 'retailer_rating', 'Clear communication of requirements', 1.0),
('Order Consistency', 'retailer_rating', 'Consistency in order patterns', 1.0),
('Relationship', 'retailer_rating', 'Overall business relationship', 1.0);

-- Create indexes for better performance
CREATE INDEX idx_ratings_rater_id ON ratings(rater_id);
CREATE INDEX idx_ratings_rated_id ON ratings(rated_id);
CREATE INDEX idx_ratings_rating_type ON ratings(rating_type);
CREATE INDEX idx_ratings_created_at ON ratings(created_at);
CREATE INDEX idx_rating_summaries_user_id ON rating_summaries(user_id);
CREATE INDEX idx_rating_criteria_type ON rating_criteria(rating_type);

-- Create triggers to update rating summaries automatically
CREATE OR REPLACE FUNCTION update_rating_summary()
RETURNS TRIGGER AS $$
BEGIN
    -- Update or insert rating summary for the rated user
    INSERT INTO rating_summaries (user_id, user_role, rating_type, total_ratings, average_rating, total_score, last_rating_date)
    VALUES (
        NEW.rated_id,
        NEW.rated_role,
        NEW.rating_type,
        1,
        NEW.overall_rating,
        NEW.overall_rating,
        NEW.created_at
    )
    ON CONFLICT (user_id, rating_type)
    DO UPDATE SET
        total_ratings = rating_summaries.total_ratings + 1,
        total_score = rating_summaries.total_score + NEW.overall_rating,
        average_rating = (rating_summaries.total_score + NEW.overall_rating) / (rating_summaries.total_ratings + 1),
        last_rating_date = NEW.created_at,
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_rating_summary
    AFTER INSERT ON ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_rating_summary();
