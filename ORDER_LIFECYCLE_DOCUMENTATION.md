# Order Lifecycle Documentation

## Overview
This document defines the standardized order lifecycle for the Smart Supply Chain Management System.

## Order Lifecycle Flow

### Primary Flow
```
Order Created (pending) → Accepted → Delivered
```

### Status Definitions

#### 1. **Pending** 
- **Description**: Order has been created and is awaiting distributor acceptance
- **Actions**: Distributor can accept or reject the order
- **Next Status**: `accepted` or `cancelled`

#### 2. **Accepted**
- **Description**: Order has been accepted by the distributor and is being processed
- **Actions**: Order is being prepared, packed, and assigned to delivery personnel
- **Next Status**: `delivered`

#### 3. **Delivered**
- **Description**: Order has been successfully delivered to the customer
- **Actions**: Final status - order completion
- **Next Status**: None (terminal status)

### Legacy Status Support

For backward compatibility, the following legacy statuses are still supported but map to the primary flow:

- `order_placed` → maps to `pending`
- `confirmed` → maps to `accepted`
- `processing` → maps to `accepted`
- `assigned` → maps to `accepted`
- `shipped` → maps to `accepted`
- `out_for_delivery` → maps to `accepted`
- `completed` → maps to `delivered`

### Implementation Details

#### Frontend (Flutter)
- **File**: `lib/services/tracking_service.dart`
- **Method**: `getNextExpectedStatus()` - Returns next status in the flow
- **Method**: `isOrderTrackable()` - Checks if status is trackable

#### Backend (Node.js)
- **File**: `smart-supply-backend/models/order.model.js`
- **File**: `smart-supply-backend/controllers/order.controller.js`
- **Initial Status**: All new orders start with `pending` status
- **Status Updates**: Handled through `updateStatus()` method

#### Database
- **Table**: `orders`
- **Column**: `status` (VARCHAR)
- **Valid Values**: `pending`, `accepted`, `delivered`, `cancelled`

### Status Transitions

| Current Status | Valid Next Status | Description |
|---------------|------------------|-------------|
| `pending` | `accepted`, `cancelled` | Order awaiting acceptance |
| `accepted` | `delivered` | Order being processed |
| `delivered` | - | Terminal status |
| `cancelled` | - | Terminal status |

### Business Rules

1. **Order Creation**: All orders start in `pending` status
2. **Acceptance**: Only distributors can change status from `pending` to `accepted`
3. **Delivery**: Only delivery personnel can change status from `accepted` to `delivered`
4. **Cancellation**: Orders can be cancelled from `pending` status only
5. **No Rollback**: Once an order is `accepted`, it cannot return to `pending`
6. **No Rollback**: Once an order is `delivered`, it cannot be changed

### API Endpoints

#### Update Order Status
```
PUT /api/orders/:id/status
Body: { "status": "accepted" | "delivered" | "cancelled" }
```

#### Get Order Status
```
GET /api/orders/:id
Response: { "status": "pending" | "accepted" | "delivered" | "cancelled" }
```

### Tracking Integration

The order lifecycle integrates with the tracking system:

- **Trackable Statuses**: `pending`, `accepted`, `delivered`
- **Progress Calculation**: Based on current status position in lifecycle
- **Estimated Delivery**: Calculated from order creation time + processing time

### Error Handling

- **Invalid Transitions**: API returns 400 Bad Request for invalid status transitions
- **Status Validation**: All status updates are validated against the lifecycle rules
- **Rollback Protection**: Database constraints prevent invalid status changes

### Future Enhancements

1. **Status History**: Track all status changes with timestamps
2. **Notifications**: Send notifications on status changes
3. **Analytics**: Track time spent in each status for performance metrics
4. **Custom Statuses**: Allow custom statuses for specific business needs

---

**Last Updated**: December 2024  
**Version**: 1.0  
**Author**: Smart Supply Chain Development Team
