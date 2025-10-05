const axios = require('axios');
const pool = require('../db');

class RouteOptimizationService {
  constructor() {
    this.googleMapsApiKey = process.env.GOOGLE_MAPS_API_KEY || 'YOUR_GOOGLE_MAPS_API_KEY';
    this.googleMapsBaseUrl = 'https://maps.googleapis.com/maps/api';
  }

  /**
   * Create a new route optimization session
   */
  async createOptimizationSession(sessionData) {
    const client = await pool.connect();
    try {
      const { sessionName, deliveryManId, distributorId, algorithm = 'nearest_neighbor' } = sessionData;
      
      const result = await client.query(
        `INSERT INTO route_optimization_sessions 
         (session_name, delivery_man_id, distributor_id, algorithm_used, status) 
         VALUES ($1, $2, $3, $4, 'pending') 
         RETURNING *`,
        [sessionName, deliveryManId, distributorId, algorithm]
      );

      return result.rows[0];
    } finally {
      client.release();
    }
  }

  /**
   * Get orders for a delivery man that need route optimization
   */
  async getOrdersForOptimization(deliveryManId, distributorId) {
    const client = await pool.connect();
    try {
      // Make distributor filter optional to avoid false negatives for delivery role
      let query = `
        SELECT 
          o.id,
          o.delivery_address,
          o.delivery_latitude as latitude,
          o.delivery_longitude as longitude,
          o.total_amount,
          o.status,
          o.created_at,
          dtw.preferred_start_time,
          dtw.preferred_end_time,
          dtw.earliest_delivery_time,
          dtw.latest_delivery_time,
          dtw.time_window_type
        FROM orders o
        LEFT JOIN delivery_assignments da ON o.id = da.order_id
        LEFT JOIN delivery_time_windows dtw ON o.id = dtw.order_id
        WHERE da.delivery_man_id = $1
          AND o.status IN ('accepted', 'assigned')
          AND da.delivery_status = 'assigned'
      `;

      const params = [deliveryManId];
      if (distributorId) {
        query += ` AND o.distributor_id = $2`;
        params.push(distributorId);
      }

      query += ` ORDER BY o.created_at ASC`;

      const result = await client.query(query, params);
      return result.rows;
    } finally {
      client.release();
    }
  }

  /**
   * Get delivery man's current location (depot/starting point)
   */
  async getDeliveryManLocation(deliveryManId) {
    const client = await pool.connect();
    try {
      const result = await client.query(`
        SELECT 
          base_latitude as latitude,
          base_longitude as longitude,
          base_address as address,
          name
        FROM delivery_men 
        WHERE id = $1 AND is_active = true
      `, [deliveryManId]);

      if (result.rows.length === 0) {
        throw new Error('Delivery man not found');
      }

      const deliveryMan = result.rows[0];
      return {
        latitude: deliveryMan.latitude || 30.0444, // Default Cairo coordinates
        longitude: deliveryMan.longitude || 31.2357,
        address: deliveryMan.address || 'Cairo, Egypt',
        name: deliveryMan.name
      };
    } finally {
      client.release();
    }
  }

  /**
   * Calculate distance and duration between two points using Google Maps API
   */
  async calculateDistanceMatrix(origins, destinations) {
    try {
      const originsStr = origins.map(coord => `${coord.lat},${coord.lng}`).join('|');
      const destinationsStr = destinations.map(coord => `${coord.lat},${coord.lng}`).join('|');

      const response = await axios.get(`${this.googleMapsBaseUrl}/distancematrix/json`, {
        params: {
          origins: originsStr,
          destinations: destinationsStr,
          key: this.googleMapsApiKey,
          units: 'metric',
          mode: 'driving',
          traffic_model: 'best_guess',
          departure_time: Math.floor(Date.now() / 1000) + 3600 // 1 hour from now
        }
      });

      if (response.data.status !== 'OK') {
        throw new Error(`Google Maps API error: ${response.data.status}`);
      }

      return response.data;
    } catch (error) {
      console.error('Error calculating distance matrix:', error);
      // Fallback to simple distance calculation
      return this.calculateSimpleDistanceMatrix(origins, destinations);
    }
  }

  /**
   * Fallback simple distance calculation (Haversine formula)
   */
  calculateSimpleDistanceMatrix(origins, destinations) {
    const elements = [];
    
    for (let i = 0; i < origins.length; i++) {
      const row = [];
      for (let j = 0; j < destinations.length; j++) {
        const distance = this.calculateHaversineDistance(origins[i], destinations[j]);
        const duration = Math.round(distance * 2); // Rough estimate: 2 minutes per km
        
        row.push({
          distance: { text: `${distance.toFixed(1)} km`, value: distance * 1000 },
          duration: { text: `${duration} mins`, value: duration * 60 },
          status: 'OK'
        });
      }
      elements.push(row);
    }

    return {
      status: 'OK',
      rows: elements.map(row => ({ elements: row }))
    };
  }

  /**
   * Calculate distance between two coordinates using Haversine formula
   */
  calculateHaversineDistance(coord1, coord2) {
    const R = 6371; // Earth's radius in kilometers
    // Normalize keys: accept {lat,lng} or {latitude,longitude}
    const c1 = {
      lat: coord1.lat ?? coord1.latitude,
      lng: coord1.lng ?? coord1.longitude,
    };
    const c2 = {
      lat: coord2.lat ?? coord2.latitude,
      lng: coord2.lng ?? coord2.longitude,
    };

    const dLat = this.toRadians(c2.lat - c1.lat);
    const dLon = this.toRadians(c2.lng - c1.lng);
    
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(this.toRadians(c1.lat)) * Math.cos(this.toRadians(c2.lat)) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  toRadians(degrees) {
    return degrees * (Math.PI / 180);
  }

  /**
   * Optimize route using Nearest Neighbor algorithm
   */
  async optimizeRouteNearestNeighbor(orders, startLocation) {
    const startTime = Date.now();
    const optimizedRoute = [];
    const unvisited = [...orders];
    let currentLocation = startLocation;
    let totalDistance = 0;
    let totalDuration = 0;

    // Add starting point
    optimizedRoute.push({
      orderId: null,
      sequence: 0,
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      address: currentLocation.address,
      type: 'depot',
      distanceFromPrevious: 0,
      durationFromPrevious: 0
    });

    let sequence = 1;

    while (unvisited.length > 0) {
      let nearestOrder = null;
      let nearestDistance = Infinity;
      let nearestIndex = -1;

      // Find nearest unvisited order
      for (let i = 0; i < unvisited.length; i++) {
        const order = unvisited[i];
        const distance = this.calculateHaversineDistance(
          { lat: currentLocation.latitude, lng: currentLocation.longitude },
          { 
            lat: order.latitude ?? order.delivery_latitude, 
            lng: order.longitude ?? order.delivery_longitude 
          }
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestOrder = order;
          nearestIndex = i;
        }
      }

      if (nearestOrder) {
        // Add to optimized route
        optimizedRoute.push({
          orderId: nearestOrder.id,
          sequence: sequence++,
          latitude: nearestOrder.latitude ?? nearestOrder.delivery_latitude,
          longitude: nearestOrder.longitude ?? nearestOrder.delivery_longitude,
          address: nearestOrder.delivery_address,
          type: 'delivery',
          distanceFromPrevious: nearestDistance,
          durationFromPrevious: Math.round(nearestDistance * 2),
          order: nearestOrder
        });

        totalDistance += nearestDistance;
        totalDuration += Math.round(nearestDistance * 2);

        // Update current location
        currentLocation = {
          latitude: nearestOrder.latitude ?? nearestOrder.delivery_latitude,
          longitude: nearestOrder.longitude ?? nearestOrder.delivery_longitude
        };

        // Remove from unvisited
        unvisited.splice(nearestIndex, 1);
      }
    }

    const executionTime = Date.now() - startTime;
    const optimizationScore = this.calculateOptimizationScore(orders.length, totalDistance, totalDuration);

    return {
      algorithm: 'nearest_neighbor',
      optimizedRoute,
      totalDistance: Math.round(totalDistance * 100) / 100,
      totalDuration,
      fuelCost: this.calculateFuelCost(totalDistance),
      optimizationScore,
      executionTime,
      waypointCount: optimizedRoute.length
    };
  }

  /**
   * Calculate optimization score (0-100)
   */
  calculateOptimizationScore(orderCount, totalDistance, totalDuration) {
    // Simple scoring based on efficiency
    const baseScore = 100;
    const distancePenalty = Math.min(totalDistance * 0.5, 30);
    const timePenalty = Math.min(totalDuration * 0.1, 20);
    const complexityBonus = Math.min(orderCount * 2, 10);
    
    return Math.max(0, Math.min(100, baseScore - distancePenalty - timePenalty + complexityBonus));
  }

  /**
   * Calculate fuel cost based on distance
   */
  calculateFuelCost(distanceKm) {
    const fuelPricePerLiter = 25; // Egyptian pounds per liter
    const fuelConsumptionPerKm = 0.08; // 8 liters per 100km
    return Math.round(distanceKm * fuelConsumptionPerKm * fuelPricePerLiter * 100) / 100;
  }

  /**
   * Save optimization results to database
   */
  async saveOptimizationResults(sessionId, results) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Update session status
      await client.query(
        `UPDATE route_optimization_sessions 
         SET status = 'completed', 
             total_distance_km = $1,
             total_duration_minutes = $2,
             fuel_cost = $3,
             optimization_score = $4,
             completed_at = CURRENT_TIMESTAMP
         WHERE id = $5`,
        [results.totalDistance, results.totalDuration, results.fuelCost, results.optimizationScore, sessionId]
      );

      // Save optimization results
      await client.query(
        `INSERT INTO route_optimization_results 
         (session_id, algorithm_name, total_distance_km, total_duration_minutes, 
          fuel_cost, optimization_score, waypoint_count, execution_time_ms, parameters) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [sessionId, results.algorithm, results.totalDistance, results.totalDuration,
         results.fuelCost, results.optimizationScore, results.waypointCount, 
         results.executionTime, JSON.stringify({})]
      );

      // Save waypoints
      for (const waypoint of results.optimizedRoute) {
        await client.query(
          `INSERT INTO route_optimization_waypoints 
           (session_id, waypoint_order, latitude, longitude, address, waypoint_type, 
            order_id, distance_from_previous_km, duration_from_previous_minutes) 
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [sessionId, waypoint.sequence, waypoint.latitude, waypoint.longitude,
           waypoint.address, waypoint.type, waypoint.orderId, 
           waypoint.distanceFromPrevious, waypoint.durationFromPrevious]
        );
      }

      // Save optimized order sequence
      for (const waypoint of results.optimizedRoute) {
        if (waypoint.orderId) {
          await client.query(
            `INSERT INTO route_optimization_orders 
             (session_id, order_id, sequence_order, distance_from_previous_km, 
              duration_from_previous_minutes) 
             VALUES ($1, $2, $3, $4, $5)`,
            [sessionId, waypoint.orderId, waypoint.sequence, 
             waypoint.distanceFromPrevious, waypoint.durationFromPrevious]
          );
        }
      }

      await client.query('COMMIT');
      return true;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get optimization session with results
   */
  async getOptimizationSession(sessionId) {
    const client = await pool.connect();
    try {
      // Get session details
      const sessionResult = await client.query(
        `SELECT * FROM route_optimization_sessions WHERE id = $1`,
        [sessionId]
      );

      if (sessionResult.rows.length === 0) {
        throw new Error('Session not found');
      }

      const session = sessionResult.rows[0];

      // Get waypoints
      const waypointsResult = await client.query(
        `SELECT * FROM route_optimization_waypoints 
         WHERE session_id = $1 
         ORDER BY waypoint_order ASC`,
        [sessionId]
      );

      // Get orders
      const ordersResult = await client.query(
        `SELECT ro.*, o.delivery_address, o.total_amount, o.status
         FROM route_optimization_orders ro
         JOIN orders o ON ro.order_id = o.id
         WHERE ro.session_id = $1 
         ORDER BY ro.sequence_order ASC`,
        [sessionId]
      );

      return {
        session,
        waypoints: waypointsResult.rows,
        orders: ordersResult.rows
      };
    } finally {
      client.release();
    }
  }

  /**
   * Generate Google Maps URL for the optimized route
   */
  generateGoogleMapsUrl(waypoints) {
    if (!Array.isArray(waypoints) || waypoints.length < 2) return null;

    // Normalize location objects and enforce order:
    const normalized = waypoints.map(wp => ({
      lat: wp.lat ?? wp.latitude,
      lng: wp.lng ?? wp.longitude,
    }));

    const origin = `${normalized[0].lat},${normalized[0].lng}`;
    const destination = `${normalized[normalized.length - 1].lat},${normalized[normalized.length - 1].lng}`;

    // Google Maps supports up to 25 locations total (origin + destination + waypoints) in consumer URLs
    // Keep at most 23 intermediate waypoints
    const intermediates = normalized.slice(1, -1).slice(0, 23);
    const waypointsParam = intermediates
      .map(wp => `${wp.lat},${wp.lng}`)
      .join('|');

    const base = 'https://www.google.com/maps/dir/';
    // Prefer API v1 style with query params to ensure "stops" are honored
    const url = waypointsParam
      ? `${base}?api=1&origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&waypoints=${encodeURIComponent(waypointsParam)}&travelmode=driving`
      : `${base}?api=1&origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&travelmode=driving`;

    return url;
  }
}

module.exports = new RouteOptimizationService();
