# Smart Route Optimization Backend

## Overview

This backend service provides smart route optimization capabilities for delivery management. It uses mathematical algorithms (not AI) to find optimal delivery routes.

## ⚠️ Important: This is NOT AI

This system uses **smart algorithms**, not artificial intelligence:
- Mathematical optimization algorithms
- Heuristic search methods
- Rule-based decision making
- Statistical analysis

## Quick Start

### 1. Setup Database
```bash
# Create optimization tables
node setup_route_optimization.js

# Create test data
node create_test_orders_for_optimization.js
```

### 2. Test the System
```bash
# Run optimization tests
node test_route_optimization.js
```

### 3. Start Server
```bash
npm start
```

## API Endpoints

### Sessions
- `POST /api/route-optimization/sessions` - Create session
- `GET /api/route-optimization/sessions` - List sessions
- `GET /api/route-optimization/sessions/:id` - Get session details
- `DELETE /api/route-optimization/sessions/:id` - Delete session

### Optimization
- `GET /api/route-optimization/orders/:dm/:dist` - Get orders
- `POST /api/route-optimization/optimize` - Optimize route

### Analytics
- `GET /api/route-optimization/analytics` - Get metrics

## Algorithms

### 1. Nearest Neighbor (Implemented)
- **Type**: Greedy algorithm
- **Complexity**: O(n²)
- **Best for**: Small to medium datasets
- **Speed**: Fast

### 2. Genetic Algorithm (Ready)
- **Type**: Evolutionary algorithm
- **Complexity**: O(g × p × n²)
- **Best for**: Complex optimization problems
- **Speed**: Medium

### 3. Simulated Annealing (Ready)
- **Type**: Probabilistic algorithm
- **Complexity**: O(n² × iterations)
- **Best for**: Finding near-optimal solutions
- **Speed**: Slow

## Configuration

### Environment Variables
```bash
GOOGLE_MAPS_API_KEY=your_api_key_here
DB_HOST=localhost
DB_PORT=5432
DB_NAME=smart_supply
DB_USER=postgres
DB_PASSWORD=your_password
```

### Google Maps Integration
- **Distance Matrix API** - For accurate distances
- **Traffic Data** - Real-time traffic consideration
- **Fallback System** - Haversine formula when API fails

## Database Schema

### Core Tables
```sql
-- Optimization sessions
route_optimization_sessions

-- Order sequences
route_optimization_orders

-- Route waypoints
route_optimization_waypoints

-- Results and metrics
route_optimization_results

-- Optimization history
route_optimization_history

-- Delivery time windows
delivery_time_windows
```

## Performance

### Optimization Metrics
- **Distance Calculation** - Google Maps API + Haversine fallback
- **Time Estimation** - Based on distance and traffic
- **Fuel Cost** - Calculated using consumption rates
- **Optimization Score** - 0-100 efficiency rating

### Typical Performance
- **Small Routes (5-10 orders)**: < 1 second
- **Medium Routes (10-20 orders)**: 1-3 seconds
- **Large Routes (20+ orders)**: 3-10 seconds

## Error Handling

### Common Errors
1. **No orders found** - Delivery man has no assigned orders
2. **Google Maps API failure** - Falls back to Haversine calculation
3. **Invalid delivery man** - Delivery man doesn't exist
4. **Database errors** - Connection or query issues

### Error Response Format
```json
{
  "success": false,
  "error": "Error description",
  "code": "ERROR_CODE"
}
```

## Testing

### Unit Tests
```bash
npm test
```

### Integration Tests
```bash
# Test optimization flow
node test_route_optimization.js

# Test with sample data
node create_test_orders_for_optimization.js
```

### Manual Testing
```bash
# Check database connection
node check_users.js

# Verify delivery men
node check_delivery_men.js
```

## Monitoring

### Key Metrics
- **Optimization Success Rate**
- **Average Processing Time**
- **Google Maps API Usage**
- **Error Rates**

### Logging
- **Session Logs** - All optimization attempts
- **Performance Logs** - Algorithm execution times
- **Error Logs** - Detailed error tracking

## Security

### Authentication
- **JWT Required** - All endpoints require valid token
- **Role-based Access** - Users can only access their data
- **Input Validation** - All inputs are sanitized

### Rate Limiting
- **API Calls** - Limited per user per minute
- **Google Maps API** - Monitored for usage limits

## Deployment

### Production Setup
```bash
# Install dependencies
npm install --production

# Setup environment
cp .env.example .env

# Run migrations
node setup_route_optimization.js

# Start with PM2
pm2 start index.js --name "route-optimization"
```

### Docker Deployment
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Failed
```bash
# Check database status
node -e "const pool = require('./db'); pool.query('SELECT 1').then(() => console.log('OK')).catch(err => console.error('Error:', err)).finally(() => process.exit());"
```

#### 2. Google Maps API Errors
- Verify API key is valid
- Check API quota limits
- Ensure billing is enabled

#### 3. Optimization Not Working
- Check if delivery man has orders
- Verify order status is 'assigned'
- Check database constraints

### Debug Mode
```bash
# Enable debug logging
DEBUG=route-optimization:* npm start
```

## Development

### Adding New Algorithms
1. Create algorithm function in `routeOptimizationService.js`
2. Add algorithm option to controller
3. Update frontend dropdown
4. Add tests for new algorithm

### Code Structure
```
services/
  └── routeOptimizationService.js    # Core optimization logic
controllers/
  └── routeOptimizationController.js # API handlers
routes/
  └── routeOptimization.js          # Route definitions
sql/
  └── route_optimization_tables.sql # Database schema
```

## Contributing

### Code Standards
- **ESLint** - Code linting
- **Prettier** - Code formatting
- **JSDoc** - Function documentation
- **Tests** - Unit and integration tests

### Pull Request Process
1. Create feature branch
2. Add tests for new features
3. Update documentation
4. Submit pull request

## License

Proprietary software. All rights reserved.

---

**Version**: 1.0  
**Last Updated**: December 2024  
**Maintainer**: Smart Supply Chain Team
