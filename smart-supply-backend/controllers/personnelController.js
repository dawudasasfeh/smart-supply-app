const pool = require('../db');

class PersonnelController {
  
  // Get all delivery personnel with detailed information
  static async getAllPersonnel(req, res) {
    try {
      const distributorId = req.user.id;
      
      const query = `
        SELECT 
          u.id,
          u.name,
          u.phone,
          u.email,
          COALESCE(u.vehicle_type, 'motorcycle') as vehicle_type,
          COALESCE(u.vehicle_capacity, 5) as vehicle_capacity,
          'N/A' as license_number,
          COALESCE(u.is_available, true) as is_available,
          true as is_active,
          COALESCE(u.rating, 4.5) as rating,
          u.base_latitude as latitude,
          u.base_longitude as longitude,
          u.updated_at as last_location_update,
          COALESCE(u.emergency_contact, 'N/A') as emergency_contact,
          COALESCE(u.emergency_phone, 'N/A') as emergency_phone,
          COALESCE(u.shift_start, '08:00:00') as shift_start,
          COALESCE(u.shift_end, '18:00:00') as shift_end,
          u.created_at,
          u.updated_at,
          COUNT(da.id) FILTER (WHERE da.status IN ('assigned', 'picked_up', 'in_transit')) as active_deliveries,
          COUNT(da.id) FILTER (WHERE da.status = 'delivered' AND da.assigned_at >= CURRENT_DATE) as today_deliveries,
          COUNT(da.id) FILTER (WHERE da.status = 'delivered' AND da.assigned_at >= CURRENT_DATE - INTERVAL '7 days') as week_deliveries,
          COUNT(da.id) FILTER (WHERE da.status = 'delivered' AND da.assigned_at >= CURRENT_DATE - INTERVAL '30 days') as month_deliveries,
          AVG(da.estimated_delivery_time) FILTER (WHERE da.status = 'delivered' AND da.assigned_at >= CURRENT_DATE - INTERVAL '30 days') as avg_delivery_time,
          COUNT(da.id) FILTER (WHERE da.status = 'delivered' AND da.assigned_at >= CURRENT_DATE - INTERVAL '30 days' AND da.estimated_delivery_time <= 120) as on_time_deliveries,
          CASE 
            WHEN COALESCE(u.is_online, false) = false THEN 'off_duty'
            WHEN COALESCE(u.is_available, true) = false THEN 'off_duty'
            WHEN COALESCE(u.is_available, true) = true AND COUNT(da.id) FILTER (WHERE da.status IN ('assigned', 'picked_up', 'in_transit')) > 0 THEN 'busy'
            WHEN COALESCE(u.is_available, true) = true AND COUNT(da.id) FILTER (WHERE da.status IN ('assigned', 'picked_up', 'in_transit')) = 0 THEN 'available'
            ELSE 'off_duty'
          END as status,
          CASE 
            WHEN COALESCE(u.is_online, false) = true THEN 'online'
            WHEN u.last_seen > CURRENT_TIMESTAMP - INTERVAL '15 minutes' THEN 'recently_active'
            ELSE 'offline'
          END as online_status,
          CASE 
            WHEN CURRENT_TIME BETWEEN '08:00:00' AND '18:00:00' THEN 'on_shift'
            ELSE 'off_shift'
          END as shift_status,
          u.last_seen,
          u.is_online,
          u.current_location_lat,
          u.current_location_lng,
          u.last_location_update
        FROM delivery_men u
        LEFT JOIN delivery_assignments da ON u.id = da.delivery_man_id
        WHERE u.is_active = true
        GROUP BY u.id, u.name, u.phone, u.email, u.vehicle_type, u.vehicle_capacity, 
                 u.is_available, u.rating, u.base_latitude, 
                 u.base_longitude, u.emergency_contact, u.emergency_phone,
                 u.shift_start, u.shift_end, u.created_at, u.updated_at,
                 u.last_seen, u.is_online, u.current_location_lat, u.current_location_lng, u.last_location_update
        ORDER BY u.name ASC
      `;
      
      const result = await pool.query(query);
      
      // Calculate additional metrics
      const personnel = result.rows.map(person => {
        const totalDeliveries = person.month_deliveries || 0;
        const onTimeDeliveries = person.on_time_deliveries || 0;
        const onTimeRate = totalDeliveries > 0 ? Math.round((onTimeDeliveries / totalDeliveries) * 100) : 0;
        const avgDeliveryTime = person.avg_delivery_time || 0;
        const efficiencyScore = totalDeliveries > 0 ? Math.min(10, Math.max(0, 10 - (avgDeliveryTime - 60) / 30)) : 0;
        
        return {
          ...person,
          on_time_rate: onTimeRate,
          efficiency_score: Math.round(efficiencyScore * 10) / 10,
          performance_level: efficiencyScore >= 8 ? 'excellent' : efficiencyScore >= 6 ? 'good' : efficiencyScore >= 4 ? 'average' : 'needs_improvement'
        };
      });
      
      res.json({
        success: true,
        data: personnel,
        count: personnel.length,
        message: 'Delivery personnel retrieved successfully'
      });
      
    } catch (error) {
      console.error('Error fetching personnel:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch delivery personnel',
        error: error.message
      });
    }
  }
  
  // Get personnel statistics
  static async getPersonnelStats(req, res) {
    try {
      const distributorId = req.user.id;
      
      const query = `
        SELECT 
          COUNT(DISTINCT u.id) as total_personnel,
          COUNT(DISTINCT u.id) FILTER (WHERE COALESCE(u.is_online, false) = true AND COALESCE(u.is_available, true) = true AND NOT EXISTS (
            SELECT 1 FROM delivery_assignments da2 
            WHERE da2.delivery_man_id = u.id 
            AND da2.status IN ('assigned', 'picked_up', 'in_transit')
          )) as available_personnel,
          COUNT(DISTINCT u.id) FILTER (WHERE COALESCE(u.is_available, true) = false OR COALESCE(u.is_online, false) = false) as off_duty_personnel,
          COUNT(DISTINCT u.id) FILTER (WHERE COALESCE(u.is_online, false) = false) as offline_personnel,
          COUNT(DISTINCT u.id) FILTER (WHERE COALESCE(u.is_online, false) = true AND COALESCE(u.is_available, true) = true AND EXISTS (
            SELECT 1 FROM delivery_assignments da2 
            WHERE da2.delivery_man_id = u.id 
            AND da2.status IN ('assigned', 'picked_up', 'in_transit')
          )) as busy_personnel,
          COUNT(DISTINCT u.id) FILTER (WHERE COALESCE(u.is_online, false) = true) as online_personnel,
          AVG(COALESCE(u.rating, 4.5)) as avg_rating,
          COUNT(DISTINCT u.id) FILTER (WHERE COALESCE(u.rating, 4.5) >= 4.5) as high_rated_personnel,
          COUNT(DISTINCT u.id) FILTER (WHERE COALESCE(u.rating, 4.5) < 3.0) as low_rated_personnel
        FROM delivery_men u
        WHERE u.is_active = true
      `;
      
      const result = await pool.query(query);
      const stats = result.rows[0];
      
      res.json({
        success: true,
        data: {
          total: parseInt(stats.total_personnel) || 0,
          available: parseInt(stats.available_personnel) || 0,
          busy: parseInt(stats.busy_personnel) || 0,
          off_duty: parseInt(stats.off_duty_personnel) || 0,
          offline: parseInt(stats.offline_personnel) || 0,
          online: parseInt(stats.online_personnel) || 0,
          avg_rating: parseFloat(stats.avg_rating) || 0,
          high_rated: parseInt(stats.high_rated_personnel) || 0,
          low_rated: parseInt(stats.low_rated_personnel) || 0
        },
        message: 'Personnel statistics retrieved successfully'
      });
      
    } catch (error) {
      console.error('Error fetching personnel stats:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch personnel statistics',
        error: error.message
      });
    }
  }
  
  // Get detailed personnel information
  static async getPersonnelDetails(req, res) {
    try {
      const { personnelId } = req.params;
      const distributorId = req.user.id;
      
      const query = `
        SELECT 
          dm.*,
          COUNT(da.id) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE - INTERVAL '30 days') as month_deliveries,
          COUNT(da.id) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE - INTERVAL '7 days') as week_deliveries,
          COUNT(da.id) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE) as today_deliveries,
          AVG(da.delivery_time_minutes) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE - INTERVAL '30 days') as avg_delivery_time,
          COUNT(da.id) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE - INTERVAL '30 days' AND da.delivery_time_minutes <= 120) as on_time_deliveries,
          COUNT(da.id) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE - INTERVAL '30 days') as total_deliveries
        FROM delivery_men dm
        LEFT JOIN delivery_assignments da ON dm.id = da.delivery_man_id
        LEFT JOIN orders o ON da.order_id = o.id
        WHERE dm.id = $2 AND dm.is_active = true
        GROUP BY dm.id
      `;
      
      const result = await pool.query(query, [distributorId, personnelId]);
      
      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Personnel not found'
        });
      }
      
      const person = result.rows[0];
      const totalDeliveries = person.total_deliveries || 0;
      const onTimeDeliveries = person.on_time_deliveries || 0;
      const onTimeRate = totalDeliveries > 0 ? Math.round((onTimeDeliveries / totalDeliveries) * 100) : 0;
      const avgDeliveryTime = person.avg_delivery_time || 0;
      const efficiencyScore = totalDeliveries > 0 ? Math.min(10, Math.max(0, 10 - (avgDeliveryTime - 60) / 30)) : 0;
      
      const detailedInfo = {
        ...person,
        performance: {
          month_deliveries: person.month_deliveries || 0,
          week_deliveries: person.week_deliveries || 0,
          today_deliveries: person.today_deliveries || 0,
          avg_delivery_time: Math.round(avgDeliveryTime),
          on_time_rate: onTimeRate,
          efficiency_score: Math.round(efficiencyScore * 10) / 10,
          performance_level: efficiencyScore >= 8 ? 'excellent' : efficiencyScore >= 6 ? 'good' : efficiencyScore >= 4 ? 'average' : 'needs_improvement'
        }
      };
      
      res.json({
        success: true,
        data: detailedInfo,
        message: 'Personnel details retrieved successfully'
      });
      
    } catch (error) {
      console.error('Error fetching personnel details:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch personnel details',
        error: error.message
      });
    }
  }
  
  // Add new personnel
  static async addPersonnel(req, res) {
    try {
      const {
        name,
        phone,
        email,
        vehicle_type,
        vehicle_capacity,
        emergency_contact,
        emergency_phone,
        shift_start,
        shift_end
      } = req.body;
      
      const query = `
        INSERT INTO delivery_men 
        (name, phone, email, vehicle_type, vehicle_capacity, license_number, 
         emergency_contact, emergency_phone, shift_start, shift_end, 
         is_available, is_active, rating, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, true, true, 5.0, NOW(), NOW())
        RETURNING *
      `;
      
      const result = await pool.query(query, [
        name, phone, email, vehicle_type, vehicle_capacity, license_number,
        emergency_contact, emergency_phone, shift_start, shift_end
      ]);
      
      res.status(201).json({
        success: true,
        data: result.rows[0],
        message: 'Personnel added successfully'
      });
      
    } catch (error) {
      console.error('Error adding personnel:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to add personnel',
        error: error.message
      });
    }
  }
  
  // Update personnel information
  static async updatePersonnel(req, res) {
    try {
      const { personnelId } = req.params;
      const updates = req.body;
      
      const allowedFields = [
        'name', 'phone', 'email', 'vehicle_type', 'vehicle_capacity', 
        'license_number', 'emergency_contact', 'emergency_phone', 
        'shift_start', 'shift_end', 'is_available'
      ];
      
      const updateFields = [];
      const values = [];
      let paramCount = 1;
      
      Object.keys(updates).forEach(key => {
        if (allowedFields.includes(key) && updates[key] !== undefined) {
          updateFields.push(`${key} = $${paramCount}`);
          values.push(updates[key]);
          paramCount++;
        }
      });
      
      if (updateFields.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'No valid fields to update'
        });
      }
      
      updateFields.push(`updated_at = NOW()`);
      values.push(personnelId);
      
      const query = `
        UPDATE delivery_men 
        SET ${updateFields.join(', ')}
        WHERE id = $${paramCount} AND is_active = true
        RETURNING *
      `;
      
      const result = await pool.query(query, values);
      
      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Personnel not found'
        });
      }
      
      res.json({
        success: true,
        data: result.rows[0],
        message: 'Personnel updated successfully'
      });
      
    } catch (error) {
      console.error('Error updating personnel:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update personnel',
        error: error.message
      });
    }
  }
  
  // Toggle personnel availability
  static async toggleAvailability(req, res) {
    try {
      const { personnelId } = req.params;
      const { is_available } = req.body;
      
      const query = `
        UPDATE delivery_men 
        SET is_available = $1, updated_at = NOW()
        WHERE id = $2 AND is_active = true
        RETURNING *
      `;
      
      const result = await pool.query(query, [is_available, personnelId]);
      
      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Personnel not found'
        });
      }
      
      res.json({
        success: true,
        data: result.rows[0],
        message: `Personnel ${is_available ? 'activated' : 'deactivated'} successfully`
      });
      
    } catch (error) {
      console.error('Error toggling availability:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to toggle availability',
        error: error.message
      });
    }
  }
  
  // Deactivate personnel
  static async deactivatePersonnel(req, res) {
    try {
      const { personnelId } = req.params;
      
      const query = `
        UPDATE delivery_men 
        SET is_active = false, is_available = false, updated_at = NOW()
        WHERE id = $1
        RETURNING *
      `;
      
      const result = await pool.query(query, [personnelId]);
      
      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Personnel not found'
        });
      }
      
      res.json({
        success: true,
        data: result.rows[0],
        message: 'Personnel deactivated successfully'
      });
      
    } catch (error) {
      console.error('Error deactivating personnel:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to deactivate personnel',
        error: error.message
      });
    }
  }
  
  // Get personnel performance analytics
  static async getPersonnelAnalytics(req, res) {
    try {
      const { personnelId } = req.params;
      const { period = 30 } = req.query;
      const distributorId = req.user.id;
      
      const query = `
        SELECT 
          dm.name,
          dm.rating,
          COUNT(da.id) as total_deliveries,
          COUNT(da.id) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE - INTERVAL '${period} days') as period_deliveries,
          AVG(da.delivery_time_minutes) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE - INTERVAL '${period} days') as avg_delivery_time,
          COUNT(da.id) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE - INTERVAL '${period} days' AND da.delivery_time_minutes <= 120) as on_time_deliveries,
          COUNT(da.id) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE - INTERVAL '${period} days') as period_total,
          AVG(da.delivery_time_minutes) FILTER (WHERE o.status = 'delivered' AND o.delivered_at >= CURRENT_DATE - INTERVAL '${period} days') as period_avg_time
        FROM delivery_men dm
        LEFT JOIN delivery_assignments da ON dm.id = da.delivery_man_id
        LEFT JOIN orders o ON da.order_id = o.id
        WHERE dm.id = $2 AND dm.is_active = true
        GROUP BY dm.id, dm.name, dm.rating
      `;
      
      const result = await pool.query(query, [distributorId, personnelId]);
      
      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Personnel not found'
        });
      }
      
      const data = result.rows[0];
      const periodDeliveries = data.period_deliveries || 0;
      const onTimeDeliveries = data.on_time_deliveries || 0;
      const onTimeRate = periodDeliveries > 0 ? Math.round((onTimeDeliveries / periodDeliveries) * 100) : 0;
      const avgDeliveryTime = data.period_avg_time || 0;
      const efficiencyScore = periodDeliveries > 0 ? Math.min(10, Math.max(0, 10 - (avgDeliveryTime - 60) / 30)) : 0;
      
      const analytics = {
        personnel_name: data.name,
        rating: parseFloat(data.rating) || 0,
        total_deliveries: parseInt(data.total_deliveries) || 0,
        period_deliveries: periodDeliveries,
        avg_delivery_time: Math.round(avgDeliveryTime),
        on_time_rate: onTimeRate,
        efficiency_score: Math.round(efficiencyScore * 10) / 10,
        performance_level: efficiencyScore >= 8 ? 'excellent' : efficiencyScore >= 6 ? 'good' : efficiencyScore >= 4 ? 'average' : 'needs_improvement',
        period: `${period} days`
      };
      
      res.json({
        success: true,
        data: analytics,
        message: 'Personnel analytics retrieved successfully'
      });
      
    } catch (error) {
      console.error('Error fetching personnel analytics:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch personnel analytics',
        error: error.message
      });
    }
  }

  // Update online status (heartbeat)
  static async updateOnlineStatus(req, res) {
    try {
      const { personnelId } = req.params;
      const { latitude, longitude, device_token } = req.body;
      
      const query = `
        UPDATE delivery_men 
        SET 
          is_online = true,
          last_seen = CURRENT_TIMESTAMP,
          current_location_lat = COALESCE($2, current_location_lat),
          current_location_lng = COALESCE($3, current_location_lng),
          last_location_update = CASE 
            WHEN $2 IS NOT NULL AND $3 IS NOT NULL THEN CURRENT_TIMESTAMP
            ELSE last_location_update
          END,
          device_token = COALESCE($4, device_token)
        WHERE id = $1 AND is_active = true
        RETURNING id, name, is_online, last_seen
      `;
      
      const result = await pool.query(query, [personnelId, latitude, longitude, device_token]);
      
      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Personnel not found'
        });
      }
      
      res.json({
        success: true,
        data: result.rows[0],
        message: 'Online status updated successfully'
      });
      
    } catch (error) {
      console.error('Error updating online status:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update online status',
        error: error.message
      });
    }
  }

  // Mark personnel as offline
  static async markOffline(req, res) {
    try {
      const { personnelId } = req.params;
      
      const query = `
        UPDATE delivery_men 
        SET 
          is_online = false,
          last_seen = CURRENT_TIMESTAMP
        WHERE id = $1 AND is_active = true
        RETURNING id, name, is_online, last_seen
      `;
      
      const result = await pool.query(query, [personnelId]);
      
      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Personnel not found'
        });
      }
      
      res.json({
        success: true,
        data: result.rows[0],
        message: 'Personnel marked as offline'
      });
      
    } catch (error) {
      console.error('Error marking offline:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to mark offline',
        error: error.message
      });
    }
  }
}

module.exports = PersonnelController;
