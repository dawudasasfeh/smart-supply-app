-- Add location columns to users table if they don't exist
ALTER TABLE users ADD COLUMN IF NOT EXISTS base_latitude DECIMAL(10, 8);
ALTER TABLE users ADD COLUMN IF NOT EXISTS base_longitude DECIMAL(11, 8);

-- Check the table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('base_latitude', 'base_longitude', 'latitude', 'longitude', 'address')
ORDER BY column_name;
