// Mock data service for testing delivery system without database
class MockDataService {
  constructor() {
    this.orders = [
      {
        id: 1,
        customer_name: 'Ahmed Hassan',
        delivery_address: '123 Tahrir Square, Cairo',
        delivery_latitude: 30.0444,
        delivery_longitude: 31.2357,
        total_amount: 250.50,
        created_at: new Date('2024-01-15T10:30:00Z'),
        priority_level: 3,
        item_count: 5,
        status: 'pending',
        delivery_man_id: null
      },
      {
        id: 2,
        customer_name: 'Fatima Ali',
        delivery_address: '456 Zamalek District, Cairo',
        delivery_latitude: 30.0626,
        delivery_longitude: 31.2197,
        total_amount: 180.25,
        created_at: new Date('2024-01-15T11:15:00Z'),
        priority_level: 2,
        item_count: 3,
        status: 'pending',
        delivery_man_id: null
      },
      {
        id: 3,
        customer_name: 'Mohamed Salah',
        delivery_address: '789 Maadi, Cairo',
        delivery_latitude: 29.9602,
        delivery_longitude: 31.2569,
        total_amount: 320.75,
        created_at: new Date('2024-01-15T09:45:00Z'),
        priority_level: 1,
        item_count: 8,
        status: 'pending',
        delivery_man_id: null
      },
      {
        id: 4,
        customer_name: 'Nour Ibrahim',
        delivery_address: '321 Heliopolis, Cairo',
        delivery_latitude: 30.0808,
        delivery_longitude: 31.3228,
        total_amount: 145.00,
        created_at: new Date('2024-01-15T12:00:00Z'),
        priority_level: 2,
        item_count: 2,
        status: 'assigned',
        delivery_man_id: 101
      }
    ];

    this.deliveryMen = [
      {
        id: 101,
        name: 'Omar Khaled',
        phone: '+201234567890',
        email: 'omar.khaled@delivery.com',
        latitude: 30.0444,
        longitude: 31.2357,
        current_address: 'Downtown Cairo',
        max_capacity: 8,
        vehicle_type: 'motorcycle',
        status: 'available',
        current_orders: 1,
        average_rating: 4.8
      },
      {
        id: 102,
        name: 'Youssef Ahmed',
        phone: '+201234567891',
        email: 'youssef.ahmed@delivery.com',
        latitude: 30.0626,
        longitude: 31.2197,
        current_address: 'Zamalek, Cairo',
        max_capacity: 6,
        vehicle_type: 'car',
        status: 'available',
        current_orders: 0,
        average_rating: 4.6
      },
      {
        id: 103,
        name: 'Hassan Mahmoud',
        phone: '+201234567892',
        email: 'hassan.mahmoud@delivery.com',
        latitude: 29.9602,
        longitude: 31.2569,
        current_address: 'Maadi, Cairo',
        max_capacity: 5,
        vehicle_type: 'motorcycle',
        status: 'busy',
        current_orders: 3,
        average_rating: 4.9
      },
      {
        id: 104,
        name: 'Amr Mostafa',
        phone: '+201234567893',
        email: 'amr.mostafa@delivery.com',
        latitude: 30.0808,
        longitude: 31.3228,
        current_address: 'Heliopolis, Cairo',
        max_capacity: 7,
        vehicle_type: 'car',
        status: 'available',
        current_orders: 0,
        average_rating: 4.7
      }
    ];

    this.deliveryHistory = [
      {
        id: 1,
        order_id: 4,
        status: 'assigned',
        location_data: {
          latitude: 30.0808,
          longitude: 31.3228,
          address: 'Heliopolis, Cairo'
        },
        timestamp: new Date('2024-01-15T12:00:00Z'),
        notes: 'Order assigned to delivery man'
      },
      {
        id: 2,
        order_id: 4,
        status: 'picked_up',
        location_data: {
          latitude: 30.0444,
          longitude: 31.2357,
          address: 'Warehouse, Downtown Cairo'
        },
        timestamp: new Date('2024-01-15T12:30:00Z'),
        notes: 'Order picked up from warehouse'
      }
    ];

    this.analytics = {
      totalDeliveries: 156,
      averageDeliveryTime: 28.5,
      onTimeRate: 94.2,
      efficiencyScore: 87.8,
      todayDeliveries: 12,
      pendingDeliveries: 8,
      activeDeliveries: 5
    };
  }

  // Get pending orders
  getPendingOrders() {
    return {
      success: true,
      orders: this.orders.filter(order => order.status === 'pending' && !order.delivery_man_id)
    };
  }

  // Get available delivery men
  getAvailableDeliveryMen() {
    return {
      success: true,
      deliveryMen: this.deliveryMen.filter(dm => dm.status === 'available' && dm.current_orders < dm.max_capacity)
    };
  }

  // Assign orders to delivery man
  assignOrders(deliveryManId, orderIds) {
    try {
      const deliveryMan = this.deliveryMen.find(dm => dm.id === deliveryManId);
      if (!deliveryMan) {
        return { success: false, message: 'Delivery man not found' };
      }

      // Update orders
      orderIds.forEach(orderId => {
        const order = this.orders.find(o => o.id === orderId);
        if (order) {
          order.delivery_man_id = deliveryManId;
          order.status = 'assigned';
          order.assigned_at = new Date();
          order.estimated_delivery = new Date(Date.now() + 45 * 60 * 1000); // 45 minutes from now
        }
      });

      // Update delivery man
      deliveryMan.current_orders += orderIds.length;
      if (deliveryMan.current_orders >= deliveryMan.max_capacity) {
        deliveryMan.status = 'busy';
      }

      return {
        success: true,
        message: `Successfully assigned ${orderIds.length} orders to ${deliveryMan.name}`,
        assignedOrders: orderIds.length
      };
    } catch (error) {
      return { success: false, message: 'Assignment failed' };
    }
  }

  // Get active deliveries
  getActiveDeliveries() {
    const activeOrders = this.orders.filter(order => 
      order.status === 'assigned' || order.status === 'picked_up' || order.status === 'in_transit'
    );

    const deliveriesWithDetails = activeOrders.map(order => {
      const deliveryMan = this.deliveryMen.find(dm => dm.id === order.delivery_man_id);
      return {
        ...order,
        delivery_man_name: deliveryMan ? deliveryMan.name : 'Unknown',
        delivery_man_phone: deliveryMan ? deliveryMan.phone : 'N/A',
        estimated_time: Math.floor(Math.random() * 30) + 15 // 15-45 minutes
      };
    });

    return {
      success: true,
      deliveries: deliveriesWithDetails
    };
  }

  // Update delivery status
  updateDeliveryStatus(orderId, status, location = null) {
    const order = this.orders.find(o => o.id === orderId);
    if (!order) {
      return { success: false, message: 'Order not found' };
    }

    order.status = status;
    
    // Add to history
    this.deliveryHistory.push({
      id: this.deliveryHistory.length + 1,
      order_id: orderId,
      status: status,
      location_data: location || {
        latitude: 30.0444 + (Math.random() * 0.1 - 0.05),
        longitude: 31.2357 + (Math.random() * 0.1 - 0.05),
        address: 'Cairo, Egypt'
      },
      timestamp: new Date(),
      notes: `Status updated to ${status}`
    });

    // If delivered, free up delivery man
    if (status === 'delivered' && order.delivery_man_id) {
      const deliveryMan = this.deliveryMen.find(dm => dm.id === order.delivery_man_id);
      if (deliveryMan) {
        deliveryMan.current_orders = Math.max(0, deliveryMan.current_orders - 1);
        if (deliveryMan.current_orders < deliveryMan.max_capacity) {
          deliveryMan.status = 'available';
        }
      }
    }

    return {
      success: true,
      message: `Order ${orderId} status updated to ${status}`
    };
  }

  // Get delivery analytics
  getDeliveryAnalytics() {
    return {
      success: true,
      analytics: this.analytics
    };
  }

  // Get delivery man performance
  getDeliveryManPerformance(deliveryManId) {
    const deliveryMan = this.deliveryMen.find(dm => dm.id === deliveryManId);
    if (!deliveryMan) {
      return { success: false, message: 'Delivery man not found' };
    }

    const performance = {
      id: deliveryManId,
      name: deliveryMan.name,
      totalDeliveries: Math.floor(Math.random() * 50) + 20,
      averageRating: deliveryMan.average_rating,
      onTimeDeliveries: Math.floor(Math.random() * 20) + 15,
      averageDeliveryTime: Math.floor(Math.random() * 15) + 20,
      completionRate: Math.floor(Math.random() * 10) + 90,
      currentOrders: deliveryMan.current_orders,
      status: deliveryMan.status
    };

    return {
      success: true,
      performance: performance
    };
  }

  // Get delivery history for an order
  getDeliveryHistory(orderId) {
    const history = this.deliveryHistory.filter(h => h.order_id == orderId);
    return {
      success: true,
      history: history
    };
  }
}

module.exports = new MockDataService();
