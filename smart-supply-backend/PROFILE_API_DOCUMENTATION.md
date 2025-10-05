# Profile API Documentation

## Overview
Enhanced profile management API with comprehensive CRUD operations for user profiles, including validation, error handling, and avatar support.

## Base URL
```
http://localhost:3000/api/profile
```

## Authentication
All endpoints require Bearer token authentication:
```
Authorization: Bearer <jwt_token>
```

---

## Endpoints

### 1. GET /api/profile/me
**Description**: Get current user's profile information

**Headers**:
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Response** (200 OK):
```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john@example.com",
  "role": "supermarket",
  "phone": "+962791234567",
  "address": "Amman, Jordan",
  "latitude": 31.9539,
  "longitude": 35.9106,
  "created_at": "2024-01-01T00:00:00.000Z",
  "updated_at": "2024-01-01T00:00:00.000Z",
  "contact_email": "john@example.com",
  "contact_phone": "+962791234567"
}
```

**Error Responses**:
- `404 Not Found`: User not found
- `401 Unauthorized`: Invalid or missing token
- `500 Internal Server Error`: Server error

---

### 2. PUT /api/profile/me
**Description**: Update current user's profile information

**Headers**:
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body** (all fields optional):
```json
{
  "name": "Updated Name",
  "email": "newemail@example.com",
  "phone": "+962791234567",
  "address": "New Address, Amman",
  "latitude": 31.9539,
  "longitude": 35.9106
}
```

**Validation Rules**:
- `name`: String, trimmed
- `email`: Valid email format, lowercase, trimmed
- `phone`: Minimum 10 characters
- `address`: String, trimmed
- `latitude`: Number between -90 and 90
- `longitude`: Number between -180 and 180

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Updated Name",
    "email": "newemail@example.com",
    "phone": "+962791234567",
    "address": "New Address, Amman",
    "latitude": 31.9539,
    "longitude": 35.9106,
    "updated_at": "2024-01-01T12:00:00.000Z"
  }
}
```

**Error Responses**:
- `400 Bad Request`: 
  - "Nothing to update"
  - "Invalid email format"
  - "Phone number must be at least 10 digits"
  - "Email already exists"
- `404 Not Found`: User not found
- `401 Unauthorized`: Invalid token
- `500 Internal Server Error`: Server error

---

### 3. GET /api/profile/:id
**Description**: Get any user's basic profile by ID (public endpoint)

**Parameters**:
- `id`: User ID (integer)

**Response** (200 OK):
```json
{
  "id": 1,
  "name": "John Doe",
  "role": "supermarket",
  "email": "john@example.com"
}
```

**Error Responses**:
- `404 Not Found`: User not found
- `500 Internal Server Error`: Server error

---

### 4. GET /api/profile/me/avatar
**Description**: Get current user's avatar URL (placeholder)

**Headers**:
```
Authorization: Bearer <token>
```

**Response** (200 OK):
```json
{
  "success": true,
  "avatar_url": null,
  "default_avatar": true
}
```

---

### 5. POST /api/profile/me/avatar
**Description**: Upload profile picture (placeholder - not implemented)

**Headers**:
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Response** (501 Not Implemented):
```json
{
  "success": false,
  "message": "Avatar upload functionality coming soon",
  "feature": "profile_picture_upload"
}
```

---

## Database Schema

### Users Table
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(50),
  address TEXT,
  role VARCHAR(50) NOT NULL,
  base_latitude DECIMAL(10, 8),
  base_longitude DECIMAL(11, 8),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## Flutter Integration

### API Service Methods

```dart
// Get user profile
static Future<Map<String, dynamic>> fetchUserProfile(String token)

// Update profile (returns updated data)
static Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> data, String role)

// Get avatar (placeholder)
static Future<Map<String, dynamic>> getUserAvatar(String token)

// Upload avatar (placeholder)
static Future<Map<String, dynamic>> uploadAvatar(String token, String imagePath)
```

### Usage Example

```dart
// Update user email
try {
  final updatedData = await ApiService.updateProfile(
    token, 
    {'email': 'newemail@example.com'}, 
    'supermarket'
  );
  print('Updated: ${updatedData['email']}');
} catch (e) {
  print('Error: $e');
}
```

---

## Error Handling

### Common Error Codes
- `400`: Bad Request (validation errors)
- `401`: Unauthorized (invalid token)
- `404`: Not Found (user doesn't exist)
- `500`: Internal Server Error
- `501`: Not Implemented (avatar upload)

### Error Response Format
```json
{
  "message": "Error description",
  "success": false
}
```

---

## Security Features

1. **JWT Authentication**: All protected endpoints require valid JWT token
2. **Input Validation**: Email format, phone length, data sanitization
3. **SQL Injection Protection**: Parameterized queries
4. **Unique Constraints**: Email uniqueness enforced
5. **Data Sanitization**: Trimming and lowercase conversion

---

## Testing

Run the test script to verify all functionality:
```bash
node test_profile_api.js
```

The test covers:
- Profile retrieval
- Name, email, phone, address updates
- Coordinate updates
- Validation scenarios
- Error handling

---

## Future Enhancements

1. **Avatar Upload**: File upload with multer
2. **Image Processing**: Resize and optimize avatars
3. **Profile Pictures**: Store and serve user images
4. **Advanced Validation**: Phone number format validation
5. **Audit Trail**: Track profile change history
6. **Bulk Updates**: Update multiple fields atomically
