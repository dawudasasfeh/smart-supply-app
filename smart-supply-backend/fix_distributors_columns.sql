-- Fix distributors table by adding missing columns
-- Run this SQL script in your PostgreSQL database

-- Add missing columns to distributors table
ALTER TABLE distributors 
ADD COLUMN IF NOT EXISTS license_number VARCHAR(100),
ADD COLUMN IF NOT EXISTS tax_id VARCHAR(100),
ADD COLUMN IF NOT EXISTS description TEXT;

-- Verify the table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'distributors' 
ORDER BY ordinal_position;
