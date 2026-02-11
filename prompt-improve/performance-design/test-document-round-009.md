# Smart City Traffic Management Platform - System Design Document

## 1. Overview

### Project Purpose and Background
This platform aims to optimize traffic flow in urban areas by analyzing real-time traffic data from sensors, cameras, and connected vehicles. The system provides adaptive traffic light control, congestion prediction, and route recommendations to reduce commute times by 20% and emissions by 15%.

### Key Features
- Real-time traffic monitoring via IoT sensors and cameras
- Adaptive traffic signal optimization
- Congestion prediction and alerts
- Dynamic route recommendation for drivers
- Historical traffic analytics dashboard
- Integration with public transportation systems

### Target Users and Usage Scenarios
- **City Traffic Controllers**: Monitor citywide traffic in real-time, override automatic controls during emergencies
- **Commuters**: Receive route recommendations via mobile app (expected 500,000+ daily active users)
- **City Planners**: Analyze long-term traffic patterns for infrastructure planning

## 2. Technology Stack

### Languages and Frameworks
- **Backend**: Java 17 with Spring Boot 3.2
- **Frontend**: React 18 with TypeScript
- **Real-time Processing**: Apache Kafka, Apache Flink

### Database
- **Primary Database**: PostgreSQL 15 for transactional data
- **Time-Series Database**: InfluxDB for sensor data
- **Cache**: Redis 7.0

### Infrastructure and Deployment
- **Cloud Provider**: AWS (ECS Fargate for application tier)
- **Message Broker**: Amazon MSK (Kafka)
- **Object Storage**: Amazon S3 for raw camera footage
- **Monitoring**: CloudWatch

### Key Libraries
- Spring Data JPA
- Spring Kafka
- Jackson for JSON processing
- React Query for frontend state management

## 3. Architecture Design

### Overall Architecture
The system follows a microservices architecture with event-driven communication:

- **Traffic Data Ingestion Service**: Receives sensor data via MQTT and HTTP webhooks
- **Traffic Analysis Service**: Processes events from Kafka to detect congestion patterns
- **Signal Control Service**: Calculates optimal traffic light timings and sends commands to city controllers
- **Route Recommendation Service**: Provides real-time route suggestions to mobile clients
- **Analytics Service**: Generates traffic reports for city planners

### Component Responsibilities and Dependencies
- **Traffic Data Ingestion Service**:
  - Receives 10,000+ messages/second from 5,000 traffic sensors across the city
  - Stores raw sensor readings in InfluxDB
  - Publishes events to `traffic-events` Kafka topic

- **Traffic Analysis Service**:
  - Consumes from `traffic-events` topic
  - Identifies congestion patterns using 15-minute rolling window aggregations
  - Publishes congestion alerts to `congestion-alerts` topic

- **Signal Control Service**:
  - Consumes congestion alerts
  - Calculates traffic light timing adjustments
  - Stores control decisions in PostgreSQL `signal_adjustments` table

- **Route Recommendation Service**:
  - Exposes REST API for mobile clients
  - Queries current traffic conditions from PostgreSQL
  - Applies Dijkstra's algorithm to compute shortest paths

### Data Flow
1. Sensors → Traffic Data Ingestion Service → Kafka topic
2. Kafka topic → Traffic Analysis Service → Congestion alerts
3. Mobile app → Route Recommendation Service → Database queries → Response to client

## 4. Data Model

### Primary Entities

**Intersection**
- `id` (UUID, primary key)
- `name` (VARCHAR)
- `latitude` (DECIMAL)
- `longitude` (DECIMAL)
- `city_zone` (VARCHAR)

**TrafficSensor**
- `id` (UUID, primary key)
- `intersection_id` (UUID, foreign key → Intersection)
- `sensor_type` (ENUM: camera, loop_detector, radar)
- `installation_date` (TIMESTAMP)

**TrafficReading** (stored in InfluxDB)
- `sensor_id` (UUID)
- `timestamp` (TIMESTAMP)
- `vehicle_count` (INTEGER)
- `average_speed` (FLOAT)
- `congestion_level` (INTEGER 0-10)

**SignalAdjustment**
- `id` (UUID, primary key)
- `intersection_id` (UUID, foreign key → Intersection)
- `adjustment_time` (TIMESTAMP)
- `red_duration_seconds` (INTEGER)
- `green_duration_seconds` (INTEGER)
- `reason` (TEXT)

**RouteRequest**
- `id` (UUID, primary key)
- `user_id` (UUID)
- `origin_lat` (DECIMAL)
- `origin_lon` (DECIMAL)
- `destination_lat` (DECIMAL)
- `destination_lon` (DECIMAL)
- `request_time` (TIMESTAMP)

## 5. API Design

### Endpoints

**POST /api/routes/recommend**
- Request: `{ "origin": { "lat": 35.6762, "lon": 139.6503 }, "destination": { "lat": 35.6895, "lon": 139.6917 } }`
- Response: `{ "route": [ ... ], "estimated_time_minutes": 25, "distance_km": 8.3 }`
- Authentication: API key in header

**GET /api/intersections/{id}/current-status**
- Response: `{ "congestion_level": 7, "current_signal_timing": { ... }, "recent_readings": [ ... ] }`
- Authentication: JWT token

**POST /api/sensors/readings** (webhook for sensor data)
- Request: `{ "sensor_id": "...", "timestamp": "...", "vehicle_count": 45, "average_speed": 22.5 }`
- Response: `{ "status": "accepted" }`
- Authentication: Sensor-specific API key

**GET /api/analytics/traffic-history**
- Query params: `start_date`, `end_date`, `intersection_id`
- Response: Aggregated traffic statistics
- Authentication: JWT token with admin role

### Authentication and Authorization
- **Sensor endpoints**: API key validation
- **Mobile app endpoints**: OAuth 2.0 with JWT tokens (15-minute expiration)
- **Admin endpoints**: JWT with role-based access control

## 6. Implementation Policy

### Error Handling
- All service-to-service calls will use circuit breaker pattern (Resilience4j)
- API responses include standard error codes (4xx for client errors, 5xx for server errors)
- Failed Kafka message processing will retry 3 times with exponential backoff

### Logging
- Structured logging (JSON format) with correlation IDs across service boundaries
- Log levels: DEBUG for development, INFO for production
- Sensitive data (user locations) will be masked in logs

### Testing
- Unit tests with 80% code coverage target
- Integration tests for critical paths (route recommendation, signal adjustment)
- Load testing to validate 10,000 requests/second capacity

### Deployment
- Blue-green deployment strategy
- Database migrations via Flyway
- Feature flags for gradual rollout of new signal control algorithms

## 7. Non-Functional Requirements

### Security
- API endpoints secured with rate limiting (100 requests/minute per client)
- All data in transit encrypted with TLS 1.3
- User location data encrypted at rest

### Scalability
- Application tier can scale horizontally via ECS auto-scaling
- Database read replicas for analytics queries
