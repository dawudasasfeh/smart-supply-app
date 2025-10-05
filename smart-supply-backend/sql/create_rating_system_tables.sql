-- =====================================================
-- SMART SUPPLY CHAIN - COMPREHENSIVE RATING SYSTEM
-- =====================================================
-- This file creates all tables required for the rating system
-- Run this file to set up the complete rating infrastructure

-- Drop existing tables if they exist (in correct order due to foreign keys)
DROP TABLE IF EXISTS rating_criteria_scores CASCADE;
DROP TABLE IF EXISTS rating_criteria CASCADE;
DROP TABLE IF EXISTS ratings CASCADE;
DROP TABLE IF EXISTS rating_summaries CASCADE;
DROP TABLE IF EXISTS supplier_ratings CASCADE;
DROP TABLE IF EXISTS distributor_detailed_averages CASCADE;

-- =====================================================
-- 1. MAIN RATINGS TABLE
-- =====================================================
CREATE TABLE ratings (
    id SERIAL PRIMARY KEY,
    rater_id INTEGER NOT NULL,
    rated_id INTEGER NOT NULL,
    rater_role VARCHAR(50) NOT NULL CHECK (rater_role IN ('supermarket', 'distributor', 'delivery')),
    rated_role VARCHAR(50) NOT NULL CHECK (rated_role IN ('supermarket', 'distributor', 'delivery')),
    rating_type VARCHAR(100) NOT NULL DEFAULT 'supplier_rating',
    overall_rating DECIMAL(3,2) NOT NULL CHECK (overall_rating >= 1.0 AND overall_rating <= 5.0),
    comment TEXT,
    order_id INTEGER,
    is_anonymous BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
       -- Foreign key constraints
    FOREIGN KEY (rater_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (rated_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    -- Unique constraint to prevent duplicate ratings for same order
    UNIQUE(rater_id, rated_id, order_id, rating_type)
);

-- =====================================================
-- 2. RATING CRITERIA TABLE
-- =====================================================
CREATE TABLE rating_criteria (
    id SERIAL PRIMARY KEY,
    criteria_name VARCHAR(100) NOT NULL,
    rating_type VARCHAR(100) NOT NULL,
    description TEXT,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
       -- Unique constraint for criteria per rating type
    UNIQUE(criteria_name, rating_type)
);

-- =====================================================
-- 3. RATING CRITERIA SCORES TABLE
-- =====================================================
CREATE TABLE rating_criteria_scores (
    id SERIAL PRIMARY KEY,
    rating_id INTEGER NOT NULL,
    criteria_id INTEGER NOT NULL,
    score DECIMAL(3,2) NOT NULL CHECK (score >= 1.0 AND score <= 5.0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        -- Foreign key constraints
    FOREIGN KEY (rating_id) REFERENCES ratings(id) ON DELETE CASCADE,
    FOREIGN KEY (criteria_id) REFERENCES rating_criteria(id) ON DELETE CASCADE,
        -- Unique constraint to prevent duplicate scores for same criteria
    UNIQUE(rating_id, criteria_id)
);

-- =====================================================
-- 4. RATING SUMMARIES TABLE (for performance)
-- =====================================================
CREATE TABLE rating_summaries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    user_role VARCHAR(50) NOT NULL,
    rating_type VARCHAR(100) NOT NULL,
    total_ratings INTEGER DEFAULT 0,
    average_rating DECIMAL(3,2) DEFAULT 0.00,
    total_score DECIMAL(10,2) DEFAULT 0.00,
    last_rating_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,   
    -- Foreign key constraints
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
       -- Unique constraint for user and rating type
    UNIQUE(user_id, rating_type)
);

-- =====================================================
-- 5. SUPPLIER RATINGS TABLE (specialized for supermarket->distributor)
-- =====================================================
CREATE TABLE supplier_ratings (
    id SERIAL PRIMARY KEY,
    distributor_id INTEGER NOT NULL,
    supermarket_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    overall_rating DECIMAL(3,2) NOT NULL CHECK (overall_rating >= 1.0 AND overall_rating <= 5.0),
    quality_rating DECIMAL(3,2) NOT NULL CHECK (quality_rating >= 1.0 AND quality_rating <= 5.0),
    delivery_rating DECIMAL(3,2) NOT NULL CHECK (delivery_rating >= 1.0 AND delivery_rating <= 5.0),
    service_rating DECIMAL(3,2) NOT NULL CHECK (service_rating >= 1.0 AND service_rating <= 5.0),
    pricing_rating DECIMAL(3,2) NOT NULL CHECK (pricing_rating >= 1.0 AND pricing_rating <= 5.0),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
       -- Foreign key constraints
    FOREIGN KEY (distributor_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (supermarket_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    -- Unique constraint to prevent duplicate ratings for same order
    UNIQUE(supermarket_id, order_id)
);

-- =====================================================
-- 6. DISTRIBUTOR DETAILED AVERAGES TABLE (cached performance)
-- =====================================================
CREATE TABLE distributor_detailed_averages (
    distributor_id INTEGER PRIMARY KEY,
    total_ratings INTEGER DEFAULT 0,
    avg_overall DECIMAL(3,2) DEFAULT 0.00,
    avg_quality DECIMAL(3,2) DEFAULT 0.00,
    avg_delivery DECIMAL(3,2) DEFAULT 0.00,
    avg_service DECIMAL(3,2) DEFAULT 0.00,
    avg_pricing DECIMAL(3,2) DEFAULT 0.00,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  
    -- Foreign key constraint
    FOREIGN KEY (distributor_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Ratings table indexes
CREATE INDEX idx_ratings_rater ON ratings(rater_id);
CREATE INDEX idx_ratings_rated ON ratings(rated_id, rated_role);
CREATE INDEX idx_ratings_type ON ratings(rating_type);
CREATE INDEX idx_ratings_order ON ratings(order_id);
CREATE INDEX idx_ratings_created ON ratings(created_at DESC);

-- Rating criteria indexes
CREATE INDEX idx_criteria_type ON rating_criteria(rating_type);
CREATE INDEX idx_criteria_active ON rating_criteria(is_active);

-- Rating criteria scores indexes
CREATE INDEX idx_scores_rating ON rating_criteria_scores(rating_id);
CREATE INDEX idx_scores_criteria ON rating_criteria_scores(criteria_id);

-- Rating summaries indexes
CREATE INDEX idx_summaries_user ON rating_summaries(user_id, user_role);
CREATE INDEX idx_summaries_type ON rating_summaries(rating_type);

-- Supplier ratings indexes
CREATE INDEX idx_supplier_ratings_distributor ON supplier_ratings(distributor_id);
CREATE INDEX idx_supplier_ratings_supermarket ON supplier_ratings(supermarket_id);
CREATE INDEX idx_supplier_ratings_order ON supplier_ratings(order_id);
CREATE INDEX idx_supplier_ratings_created ON supplier_ratings(created_at DESC);

-- =====================================================
-- INSERT DEFAULT RATING CRITERIA
-- =====================================================

-- Supplier rating criteria (supermarket -> distributor)
INSERT INTO rating_criteria (criteria_name, rating_type, description, display_order) VALUES
('Product Quality', 'supplier_rating', 'Quality of products delivered', 1),
('Delivery Time', 'supplier_rating', 'Timeliness of deliveries', 2),
('Customer Service', 'supplier_rating', 'Communication and support quality', 3),
('Pricing', 'supplier_rating', 'Competitive pricing and value', 4);

-- General rating criteria for other rating types
INSERT INTO rating_criteria (criteria_name, rating_type, description, display_order) VALUES
('reliability', 'supermarket-distributor', 'Reliability of the distributor', 1),
('product_quality', 'supermarket-distributor', 'Quality of products', 2),
('delivery_speed', 'supermarket-distributor', 'Speed of delivery', 3),
('communication', 'supermarket-distributor', 'Communication quality', 4),
('pricing', 'supermarket-distributor', 'Pricing competitiveness', 5),

('punctuality', 'supermarket-delivery', 'Punctuality of delivery', 1),
('product_handling', 'supermarket-delivery', 'Care in handling products', 2),
('professionalism', 'supermarket-delivery', 'Professional behavior', 3),
('communication', 'supermarket-delivery', 'Communication during delivery', 4),

('payment_reliability', 'distributor-supermarket', 'Reliability of payments', 1),
('order_accuracy', 'distributor-supermarket', 'Accuracy of orders placed', 2),
('communication', 'distributor-supermarket', 'Communication quality', 3),
('business_relationship', 'distributor-supermarket', 'Overall business relationship', 4),

('order_clarity', 'delivery-supermarket', 'Clarity of delivery instructions', 1),
('location_accessibility', 'delivery-supermarket', 'Accessibility of delivery location', 2),
('payment_reliability', 'delivery-supermarket', 'Reliability of payments', 3),
('cooperation', 'delivery-supermarket', 'Cooperation during delivery', 4);

-- =====================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- =====================================================

-- Function to update rating summaries when ratings are inserted/updated
CREATE OR REPLACE FUNCTION update_rating_summaries()
RETURNS TRIGGER AS $$
BEGIN
    -- Update or insert rating summary
    INSERT INTO rating_summaries (
        user_id, 
        user_role, 
        rating_type, 
        total_ratings, 
        average_rating, 
        total_score,
        last_rating_date,
        updated_at
    )
    SELECT 
        NEW.rated_id,
        NEW.rated_role,
        NEW.rating_type,
        COUNT(*),
        AVG(overall_rating),
        SUM(overall_rating),
        MAX(created_at),
        CURRENT_TIMESTAMP
    FROM ratings 
    WHERE rated_id = NEW.rated_id 
      AND rated_role = NEW.rated_role 
      AND rating_type = NEW.rating_type
    GROUP BY rated_id, rated_role, rating_type
    ON CONFLICT (user_id, rating_type) 
    DO UPDATE SET
        total_ratings = EXCLUDED.total_ratings,
        average_rating = EXCLUDED.average_rating,
        total_score = EXCLUDED.total_score,
        last_rating_date = EXCLUDED.last_rating_date,
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for ratings table
CREATE TRIGGER trigger_update_rating_summaries
    AFTER INSERT OR UPDATE ON ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_rating_summaries();

-- Function to update distributor detailed averages when supplier ratings change
CREATE OR REPLACE FUNCTION update_distributor_averages()
RETURNS TRIGGER AS $$
BEGIN
    -- Update distributor detailed averages
    INSERT INTO distributor_detailed_averages (
        distributor_id,
        total_ratings,
        avg_overall,
        avg_quality,
        avg_delivery,
        avg_service,
        avg_pricing,
        updated_at
    )
    SELECT 
        NEW.distributor_id,
        COUNT(*),
        ROUND(AVG(overall_rating), 2),
        ROUND(AVG(quality_rating), 2),
        ROUND(AVG(delivery_rating), 2),
        ROUND(AVG(service_rating), 2),
        ROUND(AVG(pricing_rating), 2),
        CURRENT_TIMESTAMP
    FROM supplier_ratings 
    WHERE distributor_id = NEW.distributor_id
    GROUP BY distributor_id
    ON CONFLICT (distributor_id) 
    DO UPDATE SET
        total_ratings = EXCLUDED.total_ratings,
        avg_overall = EXCLUDED.avg_overall,
        avg_quality = EXCLUDED.avg_quality,
        avg_delivery = EXCLUDED.avg_delivery,
        avg_service = EXCLUDED.avg_service,
        avg_pricing = EXCLUDED.avg_pricing,
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for supplier_ratings table
CREATE TRIGGER trigger_update_distributor_averages
    AFTER INSERT OR UPDATE ON supplier_ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_distributor_averages();

-- =====================================================
-- SAMPLE DATA FOR TESTING
-- =====================================================

-- Insert some sample ratings (assuming users with IDs 1-6 exist)
-- Note: Adjust user IDs based on your actual user data

-- Sample supplier ratings (supermarket rating distributors)
INSERT INTO supplier_ratings (distributor_id, supermarket_id, order_id, overall_rating, quality_rating, delivery_rating, service_rating, pricing_rating, comment) VALUES
(2, 1, 1, 4.5, 4.0, 5.0, 4.5, 4.0, 'Great service and fast delivery!'),
(2, 3, 2, 4.0, 4.0, 4.0, 4.0, 4.0, 'Good overall experience'),
(4, 1, 3, 3.5, 3.0, 4.0, 3.5, 3.5, 'Average service, room for improvement'),
(4, 3, 4, 5.0, 5.0, 5.0, 5.0, 4.5, 'Excellent distributor! Highly recommended'),
(6, 1, 5, 4.2, 4.0, 4.5, 4.0, 4.5, 'Reliable and professional');

-- Sample general ratings (for compatibility)
INSERT INTO ratings (rater_id, rated_id, rater_role, rated_role, rating_type, overall_rating, comment, order_id) VALUES
(1, 2, 'supermarket', 'distributor', 'supplier_rating', 4.5, 'Great service and fast delivery!', 1),
(3, 2, 'supermarket', 'distributor', 'supplier_rating', 4.0, 'Good overall experience', 2),
(1, 4, 'supermarket', 'distributor', 'supplier_rating', 3.5, 'Average service, room for improvement', 3),
(3, 4, 'supermarket', 'distributor', 'supplier_rating', 5.0, 'Excellent distributor! Highly recommended', 4),
(1, 6, 'supermarket', 'distributor', 'supplier_rating', 4.2, 'Reliable and professional', 5);

-- Sample criteria scores for the ratings
INSERT INTO rating_criteria_scores (rating_id, criteria_id, score) VALUES
-- Rating 1 (ID 1) - criteria scores
(1, 1, 4.0), -- Product Quality
(1, 2, 5.0), -- Delivery Time
(1, 3, 4.5), -- Customer Service
(1, 4, 4.0), -- Pricing
-- Rating 2 (ID 2) - criteria scores
(2, 1, 4.0), -- Product Quality
(2, 2, 4.0), -- Delivery Time
(2, 3, 4.0), -- Customer Service
(2, 4, 4.0), -- Pricing
-- Rating 3 (ID 3) - criteria scores
(3, 1, 3.0), -- Product Quality
(3, 2, 4.0), -- Delivery Time
(3, 3, 3.5), -- Customer Service
(3, 4, 3.5), -- Pricing
-- Rating 4 (ID 4) - criteria scores
(4, 1, 5.0), -- Product Quality
(4, 2, 5.0), -- Delivery Time
(4, 3, 5.0), -- Customer Service
(4, 4, 4.5), -- Pricing
-- Rating 5 (ID 5) - criteria scores
(5, 1, 4.0), -- Product Quality
(5, 2, 4.5), -- Delivery Time
(5, 3, 4.0), -- Customer Service
(5, 4, 4.5); -- Pricing

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check if all tables were created successfully
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE tablename IN (
    'ratings', 
    'rating_criteria', 
    'rating_criteria_scores', 
    'rating_summaries', 
    'supplier_ratings', 
    'distributor_detailed_averages'
)
ORDER BY tablename;

-- Check rating criteria
SELECT * FROM rating_criteria ORDER BY rating_type, display_order;

-- Check sample ratings
SELECT 
    r.id,
    r.overall_rating,
    r.rating_type,
    rater.name as rater_name,
    rated.name as rated_name
FROM ratings r
JOIN users rater ON r.rater_id = rater.id
JOIN users rated ON r.rated_id = rated.id
ORDER BY r.created_at DESC;

-- Check rating summaries (should be auto-populated by triggers)
SELECT * FROM rating_summaries ORDER BY user_id;

-- Check distributor detailed averages (should be auto-populated by triggers)
SELECT * FROM distributor_detailed_averages ORDER BY distributor_id;

-- =====================================================
-- RATING SYSTEM SETUP COMPLETE!
-- =====================================================
-- 
-- This script has created:
-- ✅ 6 rating system tables with proper relationships
-- ✅ Performance indexes for fast queries
-- ✅ Default rating criteria for all rating types
-- ✅ Automatic triggers for summary updates
-- ✅ Sample data for testing
-- ✅ Verification queries
--
-- The rating system is now ready for use!
-- =====================================================
