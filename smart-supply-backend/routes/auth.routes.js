const express = require('express');
const bcrypt = require('bcryptjs');
const pool = require('../db');
const authenticate = require('../middleware/auth.middleware');
const router = express.Router();
const { signup, login, deleteAccount } = require('../controllers/auth.controller');

router.post('/signup', signup);
router.post('/login', login);

/**
 * Change user password
 * PUT /api/auth/change-password
 */
router.put('/change-password', authenticate, async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.id;

    // Validate input
    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Current password and new password are required'
      });
    }

    // Validate new password strength
    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        message: 'New password must be at least 8 characters long'
      });
    }

    // Check password complexity
    const hasUppercase = /[A-Z]/.test(newPassword);
    const hasLowercase = /[a-z]/.test(newPassword);
    const hasNumber = /[0-9]/.test(newPassword);
    const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(newPassword);

    if (!hasUppercase || !hasLowercase || !hasNumber || !hasSpecialChar) {
      return res.status(400).json({
        success: false,
        message: 'Password must contain uppercase, lowercase, number, and special character'
      });
    }

    // Get current user data
    const userResult = await client.query(
      'SELECT password FROM users WHERE id = $1',
      [userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const user = userResult.rows[0];

    // Verify current password
    const isCurrentPasswordValid = await bcrypt.compare(currentPassword, user.password);
    if (!isCurrentPasswordValid) {
      return res.status(400).json({
        success: false,
        message: 'Current password is incorrect'
      });
    }

    // Check if new password is different from current
    const isSamePassword = await bcrypt.compare(newPassword, user.password);
    if (isSamePassword) {
      return res.status(400).json({
        success: false,
        message: 'New password must be different from current password'
      });
    }

    // Hash new password
    const saltRounds = 12;
    const hashedNewPassword = await bcrypt.hash(newPassword, saltRounds);

    // Update password in database
    await client.query(
      'UPDATE users SET password = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [hashedNewPassword, userId]
    );

    // Try to log password change for security audit (ignore if table doesn't exist)
    try {
      await client.query(
        `INSERT INTO user_activity_log (user_id, action, details, ip_address, user_agent, created_at) 
         VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)`,
        [
          userId,
          'password_change',
          'User changed their password',
          req.ip || req.connection.remoteAddress,
          req.get('User-Agent') || 'Unknown'
        ]
      );
    } catch (logError) {
      // Ignore logging errors - table might not exist yet
      console.log('Note: Could not log password change (activity log table may not exist)');
    }

    res.json({
      success: true,
      message: 'Password changed successfully'
    });

  } catch (error) {
    console.error('Error changing password:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  } finally {
    client.release();
  }
});

/**
 * Validate password strength
 * POST /api/auth/validate-password
 */
router.post('/validate-password', (req, res) => {
  try {
    const { password } = req.body;

    if (!password) {
      return res.status(400).json({
        success: false,
        message: 'Password is required'
      });
    }

    const checks = {
      minLength: password.length >= 8,
      hasUppercase: /[A-Z]/.test(password),
      hasLowercase: /[a-z]/.test(password),
      hasNumber: /[0-9]/.test(password),
      hasSpecialChar: /[!@#$%^&*(),.?":{}|<>]/.test(password)
    };

    const score = Object.values(checks).filter(Boolean).length;
    const strength = score / 5;

    let strengthText = 'Weak';
    if (strength >= 0.8) strengthText = 'Strong';
    else if (strength >= 0.6) strengthText = 'Good';
    else if (strength >= 0.3) strengthText = 'Fair';

    res.json({
      success: true,
      data: {
        checks,
        score,
        strength,
        strengthText,
        isValid: score >= 4 // Require at least 4 out of 5 criteria
      }
    });

  } catch (error) {
    console.error('Error validating password:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

/**
 * Delete user account
 * DELETE /api/auth/delete-account
 */
router.delete('/delete-account', authenticate, deleteAccount);

module.exports = router;
