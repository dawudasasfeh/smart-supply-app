/**
 * Smart Delivery Assignment Service
 * 
 * Automatically assigns orders to delivery personnel based on:
 * 1. Geographic proximity (closest delivery person to order location)
 * 2. Workload balancing (ensure fair distribution of orders)
 * 3. Capacity constraints (respect max_daily_orders limit)
 * 
 * Business Rules:
 * - All assignments happen in batch before delivery fleet leaves
 * - Use database transactions for atomicity
 * - Balance workload within threshold (≤2 order difference)
 * - Prioritize closest delivery person when workload is balanced
 */

const pool = require('../db');

class AssignmentService {
  
  /**
   * Calculate distance between two points using Haversine formula
   * @param {number} lat1 - Latitude of first point
   * @param {number} lon1 - Longitude of first point  
   * @param {number} lat2 - Latitude of second point
   * @param {number} lon2 - Longitude of second point
   * @returns {number} Distance in kilometers
   */
  static calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in kilometers
    const dLat = this.toRadians(lat2 - lat1);
    const dLon = this.toRadians(lon2 - lon1);
    
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(this.toRadians(lat1)) * Math.cos(this.toRadians(lat2)) *
              Math.sin(dLon/2) * Math.sin(dLon/2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }
  
  /**
   * Convert degrees to radians
   * @param {number} degrees 
   * @returns {number} Radians
   */
  static toRadians(degrees) {
    return degrees * (Math.PI / 180);
  }
  
  /**
   * Get all available delivery personnel for a distributor
   * @param {number} distributorId - ID of the distributor
   * @returns {Array} Array of delivery personnel with their current workload
   */
  static async getAvailableDeliveryPersonnel(distributorId) {
    const query = `
      SELECT 
        dm.id,
        u.name,
        u.email,
        u.phone,
        u.base_latitude,
        u.base_longitude,
        u.max_daily_orders,
        dm.is_active,
        dm.is_online,
        COALESCE(today_assignments.assignment_count, 0) as current_assignments
      FROM delivery_men dm
      JOIN users u ON dm.user_id = u.id
      LEFT JOIN (
        SELECT 
          da.delivery_man_id,
          COUNT(*) as assignment_count
        FROM delivery_assignments da
        WHERE DATE(da.assigned_at) = CURRENT_DATE
        AND da.status NOT IN ('delivered')
        GROUP BY da.delivery_man_id
      ) today_assignments ON dm.id = today_assignments.delivery_man_id
      WHERE u.role = 'delivery'
      AND u.base_latitude IS NOT NULL 
      AND u.base_longitude IS NOT NULL
      AND COALESCE(today_assignments.assignment_count, 0) < u.max_daily_orders
      AND dm.is_active = true
      AND dm.is_online = true
      ORDER BY current_assignments ASC, u.name ASC
    `;
    
    const result = await pool.query(query);
    console.log('🔍 Available delivery personnel:', result.rows);
    return result.rows;
  }
  
  /**
   * Get all unassigned orders for a distributor
   * @param {number} distributorId - ID of the distributor
   * @returns {Array} Array of unassigned orders with location data
   */
  static async getUnassignedOrders(distributorId) {
    const query = `
      SELECT 
        o.id,
        o.buyer_id,
        o.distributor_id,
        o.delivery_address,
        o.delivery_latitude,
        o.delivery_longitude,
        o.priority_level,
        o.created_at,
        o.total_amount
      FROM orders o
      WHERE o.distributor_id = $1
      AND o.status = 'pending'
      ORDER BY o.priority_level DESC, o.created_at ASC
    `;
    
    const result = await pool.query(query, [distributorId]);
    return result.rows;
  }
  
  /**
   * Find the best delivery person for an order based on distance and workload
   * @param {Object} order - Order object with location data
   * @param {Array} deliveryPersonnel - Available delivery personnel
   * @param {number} workloadThreshold - Maximum difference in assignments allowed
   * @returns {Object} Best delivery person with distance and reasoning
   */
  static findBestDeliveryPerson(order, deliveryPersonnel, workloadThreshold = 2) {
    if (!deliveryPersonnel.length) {
      throw new Error('No available delivery personnel');
    }
    
    // Calculate distances for all delivery personnel
    const candidates = deliveryPersonnel.map(person => ({
      ...person,
      distance: this.calculateDistance(
        parseFloat(order.delivery_latitude),
        parseFloat(order.delivery_longitude),
        parseFloat(person.base_latitude),
        parseFloat(person.base_longitude)
      )
    }));
    
    // Sort by distance first
    candidates.sort((a, b) => a.distance - b.distance);
    
    // Find minimum current assignments
    const minAssignments = Math.min(...candidates.map(c => c.current_assignments));
    
    // Filter candidates within workload threshold
    const balancedCandidates = candidates.filter(
      c => c.current_assignments <= minAssignments + workloadThreshold
    );
    
    // Among balanced candidates, choose the closest one
    const bestCandidate = balancedCandidates[0];
    
    return {
      deliveryPerson: bestCandidate,
      distance: bestCandidate.distance,
      reasoning: `Selected based on distance (${bestCandidate.distance.toFixed(2)}km) and workload balance (${bestCandidate.current_assignments} current assignments)`,
      alternatives: candidates.slice(1, 4).map(c => ({
        id: c.id,
        name: c.name,
        distance: c.distance,
        current_assignments: c.current_assignments
      }))
    };
  }
  
  /**
   * Perform automatic assignment of all unassigned orders
   * @param {number} distributorId - ID of the distributor making assignments
   * @returns {Object} Assignment results with statistics
   */
  static async performAutoAssignment(distributorId) {
    const client = await pool.connect();
    const startTime = Date.now();
    
    try {
      await client.query('BEGIN');
      
      // Get unassigned orders and available delivery personnel
      const [orders, deliveryPersonnel] = await Promise.all([
        this.getUnassignedOrders(distributorId),
        this.getAvailableDeliveryPersonnel(distributorId)
      ]);
      
      if (orders.length === 0) {
        await client.query('ROLLBACK');
        return {
          success: true,
          message: 'No unassigned orders found',
          statistics: {
            totalOrders: 0,
            assignedOrders: 0,
            failedAssignments: 0,
            deliveryPersonnelUsed: 0,
            executionTimeMs: Date.now() - startTime
          }
        };
      }
      
      if (deliveryPersonnel.length === 0) {
        await client.query('ROLLBACK');
        return {
          success: false,
          message: 'No available delivery personnel found',
          statistics: {
            totalOrders: orders.length,
            assignedOrders: 0,
            failedAssignments: orders.length,
            deliveryPersonnelUsed: 0,
            executionTimeMs: Date.now() - startTime
          }
        };
      }
      
      // Create assignment batch record
      const batchQuery = `
        INSERT INTO assignment_batches (
          distributor_id, total_orders, assigned_orders, assignment_algorithm
        ) VALUES ($1, $2, 0, 'proximity_balanced')
        RETURNING id
      `;
      const batchResult = await client.query(batchQuery, [distributorId, orders.length]);
      const batchId = batchResult.rows[0].id;
      
      const assignments = [];
      const failedAssignments = [];
      const distances = [];
      
      // Track current assignments for workload balancing
      const currentWorkload = {};
      deliveryPersonnel.forEach(person => {
        currentWorkload[person.id] = person.current_assignments;
      });
      
      // Process each order
      for (let i = 0; i < orders.length; i++) {
        const order = orders[i];
        
        try {
          // Update delivery personnel workload for this iteration
          const updatedPersonnel = deliveryPersonnel.map(person => ({
            ...person,
            current_assignments: currentWorkload[person.id] || 0
          }));
          
          // Find best delivery person
          const assignment = this.findBestDeliveryPerson(order, updatedPersonnel);
          const deliveryPerson = assignment.deliveryPerson;
          
          // Check capacity constraint
          if (currentWorkload[deliveryPerson.id] >= deliveryPerson.max_daily_orders) {
            throw new Error(`Delivery person ${deliveryPerson.name} has reached maximum capacity`);
          }
          
          // Create assignment record
          const assignmentQuery = `
            INSERT INTO delivery_assignments (
              order_id, delivery_man_id, assigned_by, distance_km, 
              estimated_delivery_time, status
            ) VALUES ($1, $2, $3, $4, $5, 'accepted')
            RETURNING id
          `;
          
          const estimatedTime = Math.ceil(assignment.distance * 3 + 15); // 3 min/km + 15 min handling
          
          const assignmentResult = await client.query(assignmentQuery, [
            order.id,
            deliveryPerson.id,
            distributorId,
            assignment.distance,
            estimatedTime
          ]);
          
          const assignmentId = assignmentResult.rows[0].id;
          
          // Update order status from pending to accepted
          await client.query(
            'UPDATE orders SET status = $1 WHERE id = $2',
            ['accepted', order.id]
          );
          
          // Create batch detail record
          const batchDetailQuery = `
            INSERT INTO assignment_batch_details (
              batch_id, assignment_id, assignment_rank, alternative_options
            ) VALUES ($1, $2, $3, $4)
          `;
          
          await client.query(batchDetailQuery, [
            batchId,
            assignmentId,
            i + 1,
            JSON.stringify(assignment.alternatives)
          ]);
          
          // Update workload tracking
          currentWorkload[deliveryPerson.id]++;
          distances.push(assignment.distance);
          
          assignments.push({
            orderId: order.id,
            deliveryPersonId: deliveryPerson.id,
            deliveryPersonName: deliveryPerson.name,
            distance: assignment.distance,
            estimatedTime: estimatedTime,
            reasoning: assignment.reasoning
          });
          
        } catch (error) {
          console.error(`Failed to assign order ${order.id}:`, error.message);
          failedAssignments.push({
            orderId: order.id,
            error: error.message
          });
        }
      }
      
      // Update batch statistics
      const avgDistance = distances.length > 0 ? distances.reduce((a, b) => a + b, 0) / distances.length : 0;
      const minDistance = distances.length > 0 ? Math.min(...distances) : 0;
      const maxDistance = distances.length > 0 ? Math.max(...distances) : 0;
      const deliveryPersonnelUsed = new Set(assignments.map(a => a.deliveryPersonId)).size;
      
      const updateBatchQuery = `
        UPDATE assignment_batches 
        SET 
          assigned_orders = $1,
          failed_assignments = $2,
          execution_time_ms = $3,
          avg_distance_km = $4,
          min_distance_km = $5,
          max_distance_km = $6,
          total_delivery_personnel = $7
        WHERE id = $8
      `;
      
      await client.query(updateBatchQuery, [
        assignments.length,
        failedAssignments.length,
        Date.now() - startTime,
        avgDistance,
        minDistance,
        maxDistance,
        deliveryPersonnelUsed,
        batchId
      ]);
      
      await client.query('COMMIT');
      
      return {
        success: true,
        message: `Successfully assigned ${assignments.length} orders to ${deliveryPersonnelUsed} delivery personnel`,
        batchId: batchId,
        assignments: assignments,
        failedAssignments: failedAssignments,
        statistics: {
          totalOrders: orders.length,
          assignedOrders: assignments.length,
          failedAssignments: failedAssignments.length,
          deliveryPersonnelUsed: deliveryPersonnelUsed,
          avgDistanceKm: avgDistance,
          minDistanceKm: minDistance,
          maxDistanceKm: maxDistance,
          executionTimeMs: Date.now() - startTime
        }
      };
      
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Auto-assignment failed:', error);
      
      return {
        success: false,
        message: `Assignment failed: ${error.message}`,
        statistics: {
          totalOrders: 0,
          assignedOrders: 0,
          failedAssignments: 0,
          deliveryPersonnelUsed: 0,
          executionTimeMs: Date.now() - startTime
        }
      };
      
    } finally {
      client.release();
    }
  }
  
  /**
   * Get assignment analytics for a distributor
   * @param {number} distributorId - ID of the distributor
   * @param {number} days - Number of days to look back (default: 7)
   * @returns {Object} Assignment analytics and performance metrics
   */
  static async getAssignmentAnalytics(distributorId, days = 7) {
    const query = `
      SELECT 
        ab.id as batch_id,
        ab.total_orders,
        ab.assigned_orders,
        ab.failed_assignments,
        ab.avg_distance_km,
        ab.execution_time_ms,
        ab.total_delivery_personnel,
        ab.created_at,
        COUNT(da.id) as actual_assignments,
        AVG(CASE WHEN da.status = 'delivered' THEN 1.0 ELSE 0.0 END) as success_rate
      FROM assignment_batches ab
      LEFT JOIN assignment_batch_details abd ON ab.id = abd.batch_id
      LEFT JOIN delivery_assignments da ON abd.assignment_id = da.id
      WHERE ab.distributor_id = $1
      AND ab.created_at >= CURRENT_DATE - INTERVAL '${days} days'
      GROUP BY ab.id, ab.total_orders, ab.assigned_orders, ab.failed_assignments, 
               ab.avg_distance_km, ab.execution_time_ms, ab.total_delivery_personnel, ab.created_at
      ORDER BY ab.created_at DESC
    `;
    
    const result = await pool.query(query, [distributorId]);
    
    // Calculate summary statistics
    const batches = result.rows;
    const totalOrders = batches.reduce((sum, batch) => sum + batch.total_orders, 0);
    const totalAssigned = batches.reduce((sum, batch) => sum + batch.assigned_orders, 0);
    const avgSuccessRate = batches.length > 0 
      ? batches.reduce((sum, batch) => sum + (batch.success_rate || 0), 0) / batches.length 
      : 0;
    const avgDistance = batches.length > 0
      ? batches.reduce((sum, batch) => sum + (batch.avg_distance_km || 0), 0) / batches.length
      : 0;
    
    return {
      summary: {
        totalBatches: batches.length,
        totalOrders: totalOrders,
        totalAssigned: totalAssigned,
        assignmentRate: totalOrders > 0 ? (totalAssigned / totalOrders) : 0,
        avgSuccessRate: avgSuccessRate,
        avgDistanceKm: avgDistance
      },
      batches: batches
    };
  }
  
  /**
   * Get current assignment status for dashboard
   * @param {number} distributorId - ID of the distributor
   * @returns {Object} Current assignment status and metrics
   */
  static async getAssignmentStatus(distributorId) {
    const queries = {
      unassignedOrders: `
        SELECT COUNT(*) as count
        FROM orders o
        LEFT JOIN delivery_assignments da ON o.id = da.order_id
        WHERE o.distributor_id = $1
        AND o.status = 'pending'
        AND da.id IS NULL
      `,
      activeAssignments: `
        SELECT COUNT(*) as count
        FROM delivery_assignments da
        JOIN orders o ON da.order_id = o.id
        WHERE o.distributor_id = $1
        AND da.status IN ('accepted')
      `,
      availableDrivers: `
        SELECT COUNT(*) as count
        FROM delivery_men dm
        JOIN users u ON dm.user_id = u.id
        LEFT JOIN (
          SELECT delivery_man_id, COUNT(*) as assignment_count
          FROM delivery_assignments
          WHERE DATE(assigned_at) = CURRENT_DATE
          AND status NOT IN ('delivered')
          GROUP BY delivery_man_id
        ) today_assignments ON dm.id = today_assignments.delivery_man_id
        WHERE u.role = 'delivery'
        AND u.base_latitude IS NOT NULL
        AND u.base_longitude IS NOT NULL
        AND COALESCE(today_assignments.assignment_count, 0) < u.max_daily_orders
        AND dm.is_active = true
        AND dm.is_available = true
      `,
      todayStats: `
        SELECT 
          COUNT(da.id) as assignments_today,
          AVG(da.distance_km) as avg_distance,
          COUNT(CASE WHEN da.status = 'delivered' THEN 1 END) as completed_today
        FROM delivery_assignments da
        JOIN orders o ON da.order_id = o.id
        WHERE o.distributor_id = $1
        AND DATE(da.assigned_at) = CURRENT_DATE
      `
    };
    
    const results = await Promise.all([
      pool.query(queries.unassignedOrders, [distributorId]),
      pool.query(queries.activeAssignments, [distributorId]),
      pool.query(queries.availableDrivers),
      pool.query(queries.todayStats, [distributorId])
    ]);
    
    return {
      unassignedOrders: parseInt(results[0].rows[0].count),
      activeAssignments: parseInt(results[1].rows[0].count),
      availableDrivers: parseInt(results[2].rows[0].count),
      todayAssignments: parseInt(results[3].rows[0].assignments_today || 0),
      todayCompleted: parseInt(results[3].rows[0].completed_today || 0),
      avgDistanceKm: parseFloat(results[3].rows[0].avg_distance || 0),
      canAutoAssign: parseInt(results[0].rows[0].count) > 0 && parseInt(results[2].rows[0].count) > 0
    };
  }
}

module.exports = AssignmentService;
