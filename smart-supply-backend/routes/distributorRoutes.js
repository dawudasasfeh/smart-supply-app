/**
 * Distributor Routes for Smart Delivery Assignment System
 * 
 * Provides endpoints for distributors to:
 * - Perform automatic order assignments
 * - View assignment analytics
 * - Monitor assignment status
 * - Manage delivery assignments
 */

const express = require('express');
const router = express.Router();
const pool = require('../db');
const AssignmentService = require('../services/assignmentService');
const authenticate = require('../middleware/auth.middleware');

/**
 * POST /api/distributor/auto-assign
 * Automatically assign all unassigned orders to delivery personnel
 * 
 * Body: {
 *   distributorId: number (optional, will use authenticated user's ID if not provided)
 * }
 * 
 * Returns: {
 *   success: boolean,
 *   message: string,
 *   batchId: number,
 *   assignments: Array,
 *   statistics: Object
 * }
 */
router.post('/auto-assign', authenticate, async (req, res) => {
  try {
    // Use authenticated user's ID or provided distributorId
    const distributorId = req.body.distributorId || req.user.id;
    
    // Verify the authenticated user can access this distributor's data
    if (req.user.role === 'distributor' && req.user.id !== distributorId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot assign orders for another distributor'
      });
    }
    
    console.log(`🤖 Starting auto-assignment for distributor ${distributorId}`);
    
    const result = await AssignmentService.performAutoAssignment(distributorId);
    
    if (result.success) {
      console.log(`✅ Auto-assignment completed: ${result.statistics.assignedOrders}/${result.statistics.totalOrders} orders assigned`);
      
      res.status(200).json({
        success: true,
        message: result.message,
        batchId: result.batchId,
        assignments: result.assignments,
        failedAssignments: result.failedAssignments,
        statistics: result.statistics
      });
    } else {
      console.log(`❌ Auto-assignment failed: ${result.message}`);
      
      res.status(400).json({
        success: false,
        message: result.message,
        statistics: result.statistics
      });
    }
    
  } catch (error) {
    console.error('Auto-assignment endpoint error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error during auto-assignment',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * GET /api/distributor/assignment-status
 * Get current assignment status and metrics for dashboard
 * 
 * Query params:
 *   distributorId: number (optional, will use authenticated user's ID if not provided)
 * 
 * Returns: {
 *   unassignedOrders: number,
 *   activeAssignments: number,
 *   availableDrivers: number,
 *   todayAssignments: number,
 *   todayCompleted: number,
 *   avgDistanceKm: number,
 *   canAutoAssign: boolean
 * }
 */
router.get('/assignment-status', authenticate, async (req, res) => {
  try {
    const distributorId = req.query.distributorId || req.user.id;
    
    // Verify access permissions
    if (req.user.role === 'distributor' && req.user.id !== parseInt(distributorId)) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot view another distributor\'s assignment status'
      });
    }
    
    const status = await AssignmentService.getAssignmentStatus(distributorId);
    
    res.status(200).json({
      success: true,
      data: status
    });
    
  } catch (error) {
    console.error('Assignment status endpoint error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve assignment status',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * GET /api/distributor/assignment-analytics
 * Get assignment analytics and performance metrics
 * 
 * Query params:
 *   distributorId: number (optional, will use authenticated user's ID if not provided)
 *   days: number (optional, default: 7) - Number of days to look back
 * 
 * Returns: {
 *   summary: Object,
 *   batches: Array
 * }
 */
router.get('/assignment-analytics', authenticate, async (req, res) => {
  try {
    const distributorId = req.query.distributorId || req.user.id;
    const days = parseInt(req.query.days) || 7;
    
    // Verify access permissions
    if (req.user.role === 'distributor' && req.user.id !== parseInt(distributorId)) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot view another distributor\'s analytics'
      });
    }
    
    // Validate days parameter
    if (days < 1 || days > 365) {
      return res.status(400).json({
        success: false,
        message: 'Days parameter must be between 1 and 365'
      });
    }
    
    const analytics = await AssignmentService.getAssignmentAnalytics(distributorId, days);
    
    res.status(200).json({
      success: true,
      data: analytics
    });
    
  } catch (error) {
    console.error('Assignment analytics endpoint error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve assignment analytics',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * GET /api/distributor/delivery-personnel
 * Get available delivery personnel for the distributor
 * 
 * Query params:
 *   distributorId: number (optional, will use authenticated user's ID if not provided)
 * 
 * Returns: Array of delivery personnel with current workload
 */
router.get('/delivery-personnel', authenticate, async (req, res) => {
  try {
    const distributorId = req.query.distributorId || req.user.id;
    
    // Verify access permissions
    if (req.user.role === 'distributor' && req.user.id !== parseInt(distributorId)) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot view another distributor\'s delivery personnel'
      });
    }
    
    const personnel = await AssignmentService.getAvailableDeliveryPersonnel(distributorId);
    
    res.status(200).json({
      success: true,
      data: personnel
    });
    
  } catch (error) {
    console.error('Delivery personnel endpoint error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve delivery personnel',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * GET /api/distributor/unassigned-orders
 * Get all unassigned orders for the distributor
 * 
 * Query params:
 *   distributorId: number (optional, will use authenticated user's ID if not provided)
 * 
 * Returns: Array of unassigned orders with location data
 */
router.get('/unassigned-orders', authenticate, async (req, res) => {
  try {
    const distributorId = req.query.distributorId || req.user.id;
    
    // Verify access permissions
    if (req.user.role === 'distributor' && req.user.id !== parseInt(distributorId)) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot view another distributor\'s orders'
      });
    }
    
    const orders = await AssignmentService.getUnassignedOrders(distributorId);
    
    res.status(200).json({
      success: true,
      data: orders
    });
    
  } catch (error) {
    console.error('Unassigned orders endpoint error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve unassigned orders',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * PUT /api/distributor/assignment/:assignmentId
 * Update a specific assignment (for manual overrides)
 * 
 * Body: {
 *   deliveryId: number (optional) - New delivery person ID
 *   status: string (optional) - New assignment status
 *   notes: string (optional) - Assignment notes
 * }
 */
router.put('/assignment/:assignmentId', authenticate, async (req, res) => {
  try {
    const { assignmentId } = req.params;
    const { deliveryId, status, notes } = req.body;
    
    // Validate assignment exists and belongs to this distributor
    const checkQuery = `
      SELECT da.*, o.distributor_id
      FROM delivery_assignments da
      JOIN orders o ON da.order_id = o.id
      WHERE da.id = $1
    `;
    
    const checkResult = await pool.query(checkQuery, [assignmentId]);
    
    if (checkResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Assignment not found'
      });
    }
    
    const assignment = checkResult.rows[0];
    
    // Verify access permissions
    if (req.user.role === 'distributor' && req.user.id !== assignment.distributor_id) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot modify another distributor\'s assignments'
      });
    }
    
    // Build update query dynamically
    const updates = [];
    const values = [];
    let paramCount = 1;
    
    if (deliveryId) {
      // Verify delivery person exists and has delivery role
      const deliveryCheck = await pool.query(
        'SELECT id FROM users WHERE id = $1 AND role = \'delivery\'',
        [deliveryId]
      );
      
      if (deliveryCheck.rows.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Invalid delivery person ID'
        });
      }
      
      updates.push(`delivery_man_id = $${paramCount++}`);
      values.push(deliveryId);
    }
    
    if (status) {
      const validStatuses = ['assigned', 'picked_up', 'in_transit', 'delivered', 'failed'];
      if (!validStatuses.includes(status)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid status. Must be one of: ' + validStatuses.join(', ')
        });
      }
      
      updates.push(`status = $${paramCount++}`);
      values.push(status);
      
      // Set actual delivery time if status is delivered
      if (status === 'delivered') {
        updates.push(`actual_delivery_time = CURRENT_TIMESTAMP`);
      }
    }
    
    if (notes !== undefined) {
      updates.push(`notes = $${paramCount++}`);
      values.push(notes);
    }
    
    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No valid updates provided'
      });
    }
    
    updates.push(`updated_at = CURRENT_TIMESTAMP`);
    values.push(assignmentId);
    
    const updateQuery = `
      UPDATE delivery_assignments 
      SET ${updates.join(', ')}
      WHERE id = $${paramCount}
      RETURNING *
    `;
    
    const result = await pool.query(updateQuery, values);
    
    res.status(200).json({
      success: true,
      message: 'Assignment updated successfully',
      data: result.rows[0]
    });
    
  } catch (error) {
    console.error('Assignment update endpoint error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update assignment',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

module.exports = router;
