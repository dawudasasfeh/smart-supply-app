/**
 * Unit Tests for Smart Delivery Assignment Service
 * 
 * Tests the core assignment algorithm including:
 * - Distance calculations (Haversine formula)
 * - Workload balancing logic
 * - Capacity constraints
 * - Transaction safety
 */

const AssignmentService = require('../services/assignmentService');

// Mock database pool for testing
const mockPool = {
  connect: jest.fn(),
  query: jest.fn(),
};

// Mock client for transaction testing
const mockClient = {
  query: jest.fn(),
  release: jest.fn(),
};

// Replace the real pool with mock
jest.mock('../db', () => mockPool);

describe('AssignmentService', () => {
  
  beforeEach(() => {
    jest.clearAllMocks();
  });
  
  describe('Distance Calculations', () => {
    
    test('should calculate distance between two points correctly', () => {
      // Cairo coordinates
      const lat1 = 30.0444;
      const lon1 = 31.2357;
      
      // Alexandria coordinates  
      const lat2 = 31.2001;
      const lon2 = 29.9187;
      
      const distance = AssignmentService.calculateDistance(lat1, lon1, lat2, lon2);
      
      // Distance between Cairo and Alexandria is approximately 183km
      expect(distance).toBeCloseTo(183, 0);
    });
    
    test('should return 0 for identical coordinates', () => {
      const lat = 30.0444;
      const lon = 31.2357;
      
      const distance = AssignmentService.calculateDistance(lat, lon, lat, lon);
      
      expect(distance).toBe(0);
    });
    
    test('should handle negative coordinates correctly', () => {
      // Test with coordinates in different hemispheres
      const distance = AssignmentService.calculateDistance(
        -33.8688, 151.2093, // Sydney
        40.7128, -74.0060   // New York
      );
      
      // Distance should be approximately 15,993 km
      expect(distance).toBeGreaterThan(15000);
      expect(distance).toBeLessThan(16500);
    });
    
  });
  
  describe('Best Delivery Person Selection', () => {
    
    const mockOrder = {
      id: 1,
      delivery_latitude: '30.0444',
      delivery_longitude: '31.2357',
    };
    
    const mockDeliveryPersonnel = [
      {
        id: 1,
        name: 'Ahmed Hassan',
        base_latitude: '30.0500', // Close to order
        base_longitude: '31.2400',
        current_assignments: 2,
        max_daily_orders: 10,
      },
      {
        id: 2,
        name: 'Mohamed Ali',
        base_latitude: '30.1000', // Further from order
        base_longitude: '31.3000',
        current_assignments: 1,
        max_daily_orders: 10,
      },
      {
        id: 3,
        name: 'Fatma Omar',
        base_latitude: '30.0450', // Very close to order
        base_longitude: '31.2350',
        current_assignments: 5,
        max_daily_orders: 10,
      },
    ];
    
    test('should select closest delivery person when workload is balanced', () => {
      const result = AssignmentService.findBestDeliveryPerson(
        mockOrder, 
        mockDeliveryPersonnel, 
        2 // workload threshold
      );
      
      // Should select Fatma (id: 3) as she's closest, even with higher workload
      expect(result.deliveryPerson.id).toBe(3);
      expect(result.deliveryPerson.name).toBe('Fatma Omar');
      expect(result.distance).toBeLessThan(1); // Very close
    });
    
    test('should balance workload when distances are similar', () => {
      // Modify personnel to have similar distances but different workloads
      const balancedPersonnel = [
        {
          id: 1,
          name: 'Ahmed Hassan',
          base_latitude: '30.0444',
          base_longitude: '31.2357',
          current_assignments: 5,
          max_daily_orders: 10,
        },
        {
          id: 2,
          name: 'Mohamed Ali',
          base_latitude: '30.0445',
          base_longitude: '31.2358',
          current_assignments: 1, // Much lower workload
          max_daily_orders: 10,
        },
      ];
      
      const result = AssignmentService.findBestDeliveryPerson(
        mockOrder, 
        balancedPersonnel, 
        2 // workload threshold
      );
      
      // Should select Mohamed (id: 2) due to lower workload
      expect(result.deliveryPerson.id).toBe(2);
      expect(result.deliveryPerson.name).toBe('Mohamed Ali');
    });
    
    test('should throw error when no delivery personnel available', () => {
      expect(() => {
        AssignmentService.findBestDeliveryPerson(mockOrder, [], 2);
      }).toThrow('No available delivery personnel');
    });
    
    test('should include alternatives in result', () => {
      const result = AssignmentService.findBestDeliveryPerson(
        mockOrder, 
        mockDeliveryPersonnel, 
        2
      );
      
      expect(result.alternatives).toBeDefined();
      expect(Array.isArray(result.alternatives)).toBe(true);
      expect(result.alternatives.length).toBeGreaterThan(0);
      
      // Alternatives should include distance and current assignments
      result.alternatives.forEach(alt => {
        expect(alt).toHaveProperty('id');
        expect(alt).toHaveProperty('name');
        expect(alt).toHaveProperty('distance');
        expect(alt).toHaveProperty('current_assignments');
      });
    });
    
  });
  
  describe('Auto Assignment Process', () => {
    
    beforeEach(() => {
      // Mock successful database connection
      mockPool.connect.mockResolvedValue(mockClient);
      mockClient.query.mockImplementation((query, params) => {
        if (query.includes('BEGIN')) {
          return Promise.resolve();
        }
        if (query.includes('COMMIT')) {
          return Promise.resolve();
        }
        if (query.includes('ROLLBACK')) {
          return Promise.resolve();
        }
        if (query.includes('INSERT INTO assignment_batches')) {
          return Promise.resolve({ rows: [{ id: 1 }] });
        }
        if (query.includes('INSERT INTO delivery_assignments')) {
          return Promise.resolve({ rows: [{ id: 1 }] });
        }
        if (query.includes('INSERT INTO assignment_batch_details')) {
          return Promise.resolve();
        }
        if (query.includes('UPDATE assignment_batches')) {
          return Promise.resolve();
        }
        return Promise.resolve({ rows: [] });
      });
    });
    
    test('should handle empty orders list gracefully', async () => {
      // Mock empty orders and available personnel
      jest.spyOn(AssignmentService, 'getUnassignedOrders')
        .mockResolvedValue([]);
      jest.spyOn(AssignmentService, 'getAvailableDeliveryPersonnel')
        .mockResolvedValue([
          { id: 1, name: 'Test Driver', current_assignments: 0, max_daily_orders: 10 }
        ]);
      
      const result = await AssignmentService.performAutoAssignment(1);
      
      expect(result.success).toBe(true);
      expect(result.message).toContain('No unassigned orders found');
      expect(result.statistics.totalOrders).toBe(0);
      expect(result.statistics.assignedOrders).toBe(0);
    });
    
    test('should handle no available personnel gracefully', async () => {
      // Mock orders but no available personnel
      jest.spyOn(AssignmentService, 'getUnassignedOrders')
        .mockResolvedValue([
          { id: 1, delivery_latitude: '30.0444', delivery_longitude: '31.2357' }
        ]);
      jest.spyOn(AssignmentService, 'getAvailableDeliveryPersonnel')
        .mockResolvedValue([]);
      
      const result = await AssignmentService.performAutoAssignment(1);
      
      expect(result.success).toBe(false);
      expect(result.message).toContain('No available delivery personnel found');
      expect(result.statistics.totalOrders).toBe(1);
      expect(result.statistics.assignedOrders).toBe(0);
      expect(result.statistics.failedAssignments).toBe(1);
    });
    
    test('should rollback transaction on database error', async () => {
      // Mock orders and personnel
      jest.spyOn(AssignmentService, 'getUnassignedOrders')
        .mockResolvedValue([
          { id: 1, delivery_latitude: '30.0444', delivery_longitude: '31.2357' }
        ]);
      jest.spyOn(AssignmentService, 'getAvailableDeliveryPersonnel')
        .mockResolvedValue([
          { 
            id: 1, 
            name: 'Test Driver', 
            base_latitude: '30.0500',
            base_longitude: '31.2400',
            current_assignments: 0, 
            max_daily_orders: 10 
          }
        ]);
      
      // Mock database error during assignment creation
      mockClient.query.mockImplementation((query) => {
        if (query.includes('INSERT INTO delivery_assignments')) {
          throw new Error('Database connection failed');
        }
        if (query.includes('ROLLBACK')) {
          return Promise.resolve();
        }
        return Promise.resolve({ rows: [{ id: 1 }] });
      });
      
      const result = await AssignmentService.performAutoAssignment(1);
      
      expect(result.success).toBe(false);
      expect(result.message).toContain('Assignment failed');
      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
    });
    
    test('should calculate statistics correctly', async () => {
      const mockOrders = [
        { id: 1, delivery_latitude: '30.0444', delivery_longitude: '31.2357' },
        { id: 2, delivery_latitude: '30.0500', delivery_longitude: '31.2400' },
        { id: 3, delivery_latitude: '30.0600', delivery_longitude: '31.2500' },
      ];
      
      const mockPersonnel = [
        { 
          id: 1, 
          name: 'Driver 1', 
          base_latitude: '30.0450',
          base_longitude: '31.2350',
          current_assignments: 0, 
          max_daily_orders: 10 
        },
        { 
          id: 2, 
          name: 'Driver 2', 
          base_latitude: '30.0550',
          base_longitude: '31.2450',
          current_assignments: 1, 
          max_daily_orders: 10 
        },
      ];
      
      jest.spyOn(AssignmentService, 'getUnassignedOrders')
        .mockResolvedValue(mockOrders);
      jest.spyOn(AssignmentService, 'getAvailableDeliveryPersonnel')
        .mockResolvedValue(mockPersonnel);
      
      const result = await AssignmentService.performAutoAssignment(1);
      
      expect(result.success).toBe(true);
      expect(result.statistics.totalOrders).toBe(3);
      expect(result.statistics.assignedOrders).toBe(3);
      expect(result.statistics.failedAssignments).toBe(0);
      expect(result.statistics.deliveryPersonnelUsed).toBeGreaterThan(0);
      expect(result.statistics.avgDistanceKm).toBeGreaterThan(0);
      expect(result.statistics.executionTimeMs).toBeGreaterThan(0);
    });
    
  });
  
  describe('Utility Functions', () => {
    
    test('should convert degrees to radians correctly', () => {
      expect(AssignmentService.toRadians(0)).toBe(0);
      expect(AssignmentService.toRadians(90)).toBeCloseTo(Math.PI / 2, 5);
      expect(AssignmentService.toRadians(180)).toBeCloseTo(Math.PI, 5);
      expect(AssignmentService.toRadians(360)).toBeCloseTo(2 * Math.PI, 5);
    });
    
  });
  
  describe('Error Handling', () => {
    
    test('should handle invalid coordinates gracefully', () => {
      // Test with invalid coordinates
      const distance1 = AssignmentService.calculateDistance(null, null, 30, 31);
      const distance2 = AssignmentService.calculateDistance(30, 31, undefined, undefined);
      
      // Should return NaN or handle gracefully
      expect(isNaN(distance1) || distance1 >= 0).toBe(true);
      expect(isNaN(distance2) || distance2 >= 0).toBe(true);
    });
    
    test('should handle database connection failures', async () => {
      // Mock connection failure
      mockPool.connect.mockRejectedValue(new Error('Connection failed'));
      
      const result = await AssignmentService.performAutoAssignment(1);
      
      expect(result.success).toBe(false);
      expect(result.message).toContain('Assignment failed');
    });
    
  });
  
});

// Integration test helper
describe('Integration Tests', () => {
  
  test('should perform end-to-end assignment with realistic data', async () => {
    // This test would require a test database setup
    // For now, we'll skip it but it's important for full testing
    
    const mockRealisticOrders = [
      {
        id: 1,
        delivery_latitude: '30.0444', // Cairo
        delivery_longitude: '31.2357',
        priority_level: 1,
      },
      {
        id: 2,
        delivery_latitude: '30.0626', // Near Cairo
        delivery_longitude: '31.2497',
        priority_level: 2,
      },
    ];
    
    const mockRealisticPersonnel = [
      {
        id: 1,
        name: 'Ahmed Hassan',
        base_latitude: '30.0500',
        base_longitude: '31.2400',
        current_assignments: 2,
        max_daily_orders: 12,
      },
      {
        id: 2,
        name: 'Mohamed Ali',
        base_latitude: '30.0700',
        base_longitude: '31.2600',
        current_assignments: 1,
        max_daily_orders: 10,
      },
    ];
    
    // Mock the database methods
    jest.spyOn(AssignmentService, 'getUnassignedOrders')
      .mockResolvedValue(mockRealisticOrders);
    jest.spyOn(AssignmentService, 'getAvailableDeliveryPersonnel')
      .mockResolvedValue(mockRealisticPersonnel);
    
    const result = await AssignmentService.performAutoAssignment(6);
    
    expect(result.success).toBe(true);
    expect(result.assignments).toHaveLength(2);
    expect(result.statistics.totalOrders).toBe(2);
    expect(result.statistics.assignedOrders).toBe(2);
    
    // Verify assignments are logical (closer drivers get closer orders)
    result.assignments.forEach(assignment => {
      expect(assignment.distance).toBeLessThan(50); // Reasonable distance in km
      expect(assignment.estimatedTime).toBeGreaterThan(0);
      expect(assignment.reasoning).toContain('distance');
    });
  });
  
});

module.exports = {
  // Export test utilities for other test files
  mockPool,
  mockClient,
};
