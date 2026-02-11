# TravelConnect System Design Document

## 1. Overview

### Purpose and Background
TravelConnect is a comprehensive travel booking platform that enables users to search, compare, and book flights, hotels, and rental cars from multiple providers. The platform aims to provide a seamless user experience with personalized recommendations, real-time availability updates, and integrated payment processing.

### Key Features
- Multi-provider flight, hotel, and car rental search
- User account management with booking history
- Payment processing with multiple payment methods
- Booking modification and cancellation
- Loyalty program integration
- Travel itinerary management
- Price alerts and notifications

### Target Users and Use Cases
- **Individual travelers**: Searching and booking personal trips
- **Travel agents**: Managing bookings for multiple clients
- **Corporate accounts**: Business travel management with expense tracking
- **Guest users**: Limited booking capabilities without account creation

## 2. Technology Stack

### Languages and Frameworks
- **Backend**: Node.js 18.x with Express 4.18
- **Frontend**: React 18.2 with Next.js 14.0
- **Mobile**: React Native 0.72

### Database
- **Primary Database**: PostgreSQL 15.3 for transactional data
- **Cache Layer**: Redis 7.0 for session management and rate limiting
- **Search Index**: Elasticsearch 8.9 for flight/hotel search

### Infrastructure and Deployment
- **Cloud Provider**: AWS (ECS for container orchestration)
- **CDN**: CloudFront for static asset delivery
- **Load Balancer**: Application Load Balancer (ALB)
- **Environment**: Production, Staging, Development

### Key Libraries
- **Authentication**: Passport.js 0.6.0 with JWT strategy
- **Payment Processing**: Stripe SDK 12.8.0
- **Email**: Nodemailer 6.9.0
- **Validation**: Joi 17.9.0
- **Logging**: Winston 3.10.0

## 3. Architecture Design

### Overall Structure
The system follows a microservices architecture with the following core services:
- **API Gateway**: Request routing and authentication
- **User Service**: User account and profile management
- **Booking Service**: Booking creation, modification, cancellation
- **Payment Service**: Payment processing and refunds
- **Search Service**: Flight/hotel/car search aggregation
- **Notification Service**: Email and push notifications
- **Provider Integration Service**: Third-party provider API integration

### Component Responsibilities and Dependencies
- **API Gateway** depends on User Service for authentication
- **Booking Service** depends on Payment Service and Provider Integration Service
- **Search Service** reads from Elasticsearch cluster
- **Notification Service** consumes events from RabbitMQ message queue

### Data Flow
1. User submits search request through web/mobile app
2. API Gateway validates JWT token and forwards to Search Service
3. Search Service queries Elasticsearch and external provider APIs
4. Results are cached in Redis for 5 minutes
5. User selects booking and proceeds to payment
6. Payment Service processes payment via Stripe
7. Booking Service creates booking record and publishes event
8. Notification Service sends confirmation email

## 4. Data Model

### Core Entities
- **Users**: id, email, password_hash, name, phone, created_at, updated_at
- **Bookings**: id, user_id, type, provider_reference, status, total_amount, currency, created_at, updated_at
- **Payments**: id, booking_id, amount, payment_method, stripe_payment_id, status, created_at
- **TravelItineraries**: id, user_id, name, start_date, end_date, created_at
- **BookingItems**: id, booking_id, itinerary_id, item_type, details (JSONB), created_at

### Table Design
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    phone VARCHAR(50),
    role VARCHAR(50) DEFAULT 'user',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    type VARCHAR(50) NOT NULL,
    provider_reference VARCHAR(255),
    status VARCHAR(50) NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    booking_data JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id),
    amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    stripe_payment_id VARCHAR(255),
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## 5. API Design

### Authentication Endpoints
- `POST /api/v1/auth/signup` - User registration
- `POST /api/v1/auth/login` - User login (returns JWT token)
- `POST /api/v1/auth/logout` - User logout
- `POST /api/v1/auth/reset-password` - Initiate password reset (sends email with reset link valid for 2 hours)
- `POST /api/v1/auth/confirm-reset` - Complete password reset with token

### Booking Endpoints
- `GET /api/v1/bookings` - List user bookings
- `GET /api/v1/bookings/{id}` - Get booking details
- `POST /api/v1/bookings` - Create new booking
- `PUT /api/v1/bookings/{id}` - Modify booking
- `DELETE /api/v1/bookings/{id}` - Cancel booking

### Search Endpoints
- `GET /api/v1/search/flights` - Search flights
- `GET /api/v1/search/hotels` - Search hotels
- `GET /api/v1/search/cars` - Search rental cars

### Request/Response Format
All API requests and responses use JSON format. Example booking creation:

```json
POST /api/v1/bookings
Authorization: Bearer {jwt_token}

{
  "type": "flight",
  "provider": "airline_x",
  "flight_details": {
    "departure": "LAX",
    "arrival": "JFK",
    "date": "2024-06-15"
  },
  "passengers": [
    {"name": "John Doe", "passport": "X12345678"}
  ]
}
```

### Authentication and Authorization
- JWT tokens are issued upon successful login with 24-hour expiration
- Tokens are passed in Authorization header as Bearer token
- Each API endpoint validates token signature and expiration
- Role-based access control for admin endpoints
- Users can only access their own bookings

## 6. Implementation Guidelines

### Error Handling
- All errors return standard JSON format with error code and message
- HTTP status codes: 400 (validation), 401 (unauthorized), 403 (forbidden), 404 (not found), 500 (server error)
- Database connection errors are retried up to 3 times with exponential backoff
- Payment failures trigger automatic refund workflow

### Logging
- Application logs are written to stdout and collected by CloudWatch
- Log format: JSON with timestamp, level, service, message, and context
- Sensitive data (passwords, payment details, passport numbers) should be redacted in logs
- Request/response logging for all API calls

### Testing Strategy
- Unit tests for business logic with 80% coverage target
- Integration tests for API endpoints
- End-to-end tests for critical user flows
- Load testing with 1000 concurrent users

### Deployment
- Containerized deployment using Docker
- Blue-green deployment strategy for zero-downtime releases
- Database migrations run automatically before container startup
- Environment-specific configuration via environment variables

## 7. Non-Functional Requirements

### Performance Goals
- API response time: p95 < 500ms
- Search results returned within 2 seconds
- Database query optimization with indexes on frequently queried fields
- Elasticsearch index refresh interval: 5 seconds

### Security Requirements
- All external communication over HTTPS/TLS 1.3
- Database connections encrypted with TLS
- Password minimum length: 8 characters with complexity requirements
- Rate limiting: 100 requests per minute per user for search APIs
- Session timeout: 30 minutes of inactivity

### Availability and Scalability
- Target uptime: 99.9%
- Horizontal scaling for API Gateway and service containers
- Database replication with read replicas for scaling reads
- RabbitMQ cluster for high availability messaging
- Auto-scaling based on CPU utilization (threshold: 70%)
