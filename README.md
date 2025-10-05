# Smart Supply Chain Management System

A comprehensive Flutter application with Node.js backend for managing supply chain operations, including order management, delivery tracking, and smart assignment systems.

## Order Lifecycle

The system follows a simplified order lifecycle:

**Order Created (pending) → Accepted → Delivered**

For detailed documentation, see [ORDER_LIFECYCLE_DOCUMENTATION.md](ORDER_LIFECYCLE_DOCUMENTATION.md)

## Features

- **Multi-role System**: Distributors, Delivery Personnel, Supermarkets
- **Smart Assignment**: AI-powered delivery assignment system
- **Real-time Tracking**: Live order and delivery tracking
- **Analytics Dashboard**: Performance metrics and insights
- **Rating System**: Customer and delivery rating management

## Getting Started

This project consists of:
- **Frontend**: Flutter application (`lib/` directory)
- **Backend**: Node.js API server (`smart-supply-backend/` directory)

### Prerequisites

- Flutter SDK
- Node.js and npm
- PostgreSQL database

### Installation

1. **Backend Setup**:
   ```bash
   cd smart-supply-backend
   npm install
   npm start
   ```

2. **Frontend Setup**:
   ```bash
   flutter pub get
   flutter run
   ```

## Documentation

- [Order Lifecycle Documentation](ORDER_LIFECYCLE_DOCUMENTATION.md)
- [API Documentation](smart-supply-backend/README.md)

## Development

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
