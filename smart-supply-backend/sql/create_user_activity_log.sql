-- User Activity Log Table for Security Auditing
-- Tracks important user actions like password changes, login attempts, etc.

CREATE TABLE IF NOT EXISTS user_activity_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(100) NOT NULL, -- login, logout, password_change, profile_update, etc.
    details TEXT, -- Additional details about the action
    ip_address INET, -- IP address of the user
    user_agent TEXT, -- Browser/device information
    success BOOLEAN DEFAULT true, -- Whether the action was successful
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_activity_log_user_id ON user_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_log_action ON user_activity_log(action);
CREATE INDEX IF NOT EXISTS idx_user_activity_log_created_at ON user_activity_log(created_at);
CREATE INDEX IF NOT EXISTS idx_user_activity_log_user_action ON user_activity_log(user_id, action);

-- Add some sample data for testing
INSERT INTO user_activity_log (user_id, action, details, ip_address, user_agent) 
SELECT 
    u.id,
    'account_created',
    'User account was created',
    '127.0.0.1'::INET,
    'Smart Supply App'
FROM users u 
WHERE NOT EXISTS (
    SELECT 1 FROM user_activity_log 
    WHERE user_id = u.id AND action = 'account_created'
)
LIMIT 10;
