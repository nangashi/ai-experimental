# Smart Home Energy Management System - System Design Document

## 1. Overview

### Purpose
The Smart Home Energy Management System (SHEMS) provides real-time energy consumption monitoring, predictive analytics, and automated control for residential smart home devices. The system helps homeowners optimize energy usage, reduce costs, and integrate with renewable energy sources (solar panels, home batteries).

### Key Features
- Real-time energy consumption monitoring from smart meters and IoT devices
- Predictive analytics for energy usage patterns and cost forecasting
- Automated device control based on energy prices and user preferences
- Integration with solar panel systems and home battery storage
- Mobile app and web dashboard for monitoring and control
- Energy bill analysis and optimization recommendations

### Target Users
- Homeowners with smart home devices
- Property management companies
- Energy utility providers (B2B integration)

## 2. Technology Stack

### Languages & Frameworks
- Backend: Go 1.21 (API Gateway, Device Manager, Analytics Engine)
- Frontend: React 18 with TypeScript
- Mobile: React Native

### Databases
- Primary: PostgreSQL 15 (user data, device registry, historical analytics)
- Time Series: TimescaleDB (hypertable extension on PostgreSQL for sensor data)
- Cache: Redis 7.0 Cluster (real-time device state, session management)

### Infrastructure & Deployment
- Cloud: AWS (EKS for Kubernetes orchestration)
- Message Queue: MQTT Broker (AWS IoT Core for device communication)
- Event Bus: Amazon Kinesis (real-time event streaming)
- Container Registry: Amazon ECR
- Monitoring: Prometheus + Grafana
- Deployment: Kubernetes with Helm charts

### Key Libraries
- MQTT client: Eclipse Paho
- Time series processing: TimescaleDB Go client
- Machine Learning: TensorFlow Lite (edge inference on device gateway)
- Authentication: OAuth 2.0 / JWT

## 3. Architecture Design

### System Components

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Mobile    │────▶│ API Gateway  │────▶│   Device    │
│     App     │     │   (Go)       │     │  Manager    │
└─────────────┘     └──────────────┘     └─────────────┘
                           │                      │
                           │                      │
                           ▼                      ▼
                    ┌──────────────┐     ┌─────────────┐
                    │  Analytics   │────▶│   MQTT      │
                    │   Engine     │     │   Broker    │
                    └──────────────┘     └─────────────┘
                           │                      │
                           │                      │
                           ▼                      ▼
                    ┌──────────────┐     ┌─────────────┐
                    │ PostgreSQL + │     │   Kinesis   │
                    │ TimescaleDB  │     │   Stream    │
                    └──────────────┘     └─────────────┘
```

### Component Responsibilities

**API Gateway**
- Request routing and load balancing
- JWT token validation
- Rate limiting for API endpoints (1000 req/min per user)
- WebSocket connection management for real-time updates

**Device Manager**
- Device registration and authentication
- Command dispatch to IoT devices via MQTT
- Device state synchronization with Redis
- Firmware update coordination

**Analytics Engine**
- Historical data aggregation from TimescaleDB
- Machine learning model execution for prediction
- Energy optimization recommendations
- Report generation (daily/weekly/monthly)

**MQTT Broker (AWS IoT Core)**
- Bidirectional communication with smart home devices
- Topic-based message routing
- Device shadow management

**Kinesis Stream**
- Real-time event ingestion from MQTT bridge
- Event fanout to analytics and notification services

### Data Flow

1. **Real-time Sensor Data**: Device → MQTT → Kinesis → TimescaleDB + Redis
2. **User Command**: Mobile App → API Gateway → Device Manager → MQTT → Device
3. **Analytics Query**: Web Dashboard → API Gateway → Analytics Engine → TimescaleDB
4. **Prediction**: Analytics Engine → TensorFlow Model → Recommendation API

## 4. Data Model

### Core Entities

**User**
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  subscription_tier VARCHAR(50) DEFAULT 'free'
);
```

**Device**
```sql
CREATE TABLE devices (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  device_type VARCHAR(100) NOT NULL,
  mqtt_topic VARCHAR(255) UNIQUE NOT NULL,
  firmware_version VARCHAR(50),
  last_seen TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Energy Consumption (TimescaleDB Hypertable)**
```sql
CREATE TABLE energy_consumption (
  time TIMESTAMPTZ NOT NULL,
  device_id UUID REFERENCES devices(id),
  power_watts DECIMAL(10, 2),
  cumulative_kwh DECIMAL(10, 4),
  voltage DECIMAL(5, 2),
  current DECIMAL(5, 2)
);

SELECT create_hypertable('energy_consumption', 'time');
```

**Device Command Log**
```sql
CREATE TABLE device_commands (
  id UUID PRIMARY KEY,
  device_id UUID REFERENCES devices(id),
  command_type VARCHAR(100) NOT NULL,
  payload JSONB,
  status VARCHAR(50) DEFAULT 'pending',
  sent_at TIMESTAMP DEFAULT NOW(),
  acked_at TIMESTAMP
);
```

## 5. API Design

### Authentication
- OAuth 2.0 Authorization Code flow for web/mobile
- JWT tokens (access token: 1 hour, refresh token: 30 days)
- Device authentication: X.509 certificates for MQTT connections

### Key Endpoints

**User Management**
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/login` - User login (returns JWT)
- `POST /api/v1/auth/refresh` - Refresh access token

**Device Management**
- `POST /api/v1/devices` - Register new device
- `GET /api/v1/devices` - List user's devices
- `GET /api/v1/devices/{id}` - Get device details
- `POST /api/v1/devices/{id}/commands` - Send command to device
- `GET /api/v1/devices/{id}/status` - Get real-time device status (from Redis)

**Analytics**
- `GET /api/v1/analytics/consumption` - Query historical consumption data
  - Query params: `start_time`, `end_time`, `device_id`, `granularity`
- `GET /api/v1/analytics/predictions` - Get energy usage predictions
- `GET /api/v1/analytics/recommendations` - Get optimization recommendations

**Real-time Updates**
- `WS /api/v1/stream` - WebSocket endpoint for real-time device updates

### Request/Response Format

**Send Device Command**
```json
POST /api/v1/devices/123e4567-e89b-12d3-a456-426614174000/commands
{
  "command_type": "set_power",
  "payload": {
    "power_state": "on",
    "target_temperature": 22
  }
}

Response:
{
  "command_id": "789e4567-e89b-12d3-a456-426614174111",
  "status": "sent",
  "sent_at": "2026-02-11T10:30:00Z"
}
```

## 6. Implementation Strategy

### Error Handling
- API Gateway returns standard HTTP error codes with JSON error objects
- Device Manager logs all MQTT publish failures to `device_command_errors` table
- Analytics Engine retries failed database queries up to 3 times with exponential backoff (1s, 2s, 4s)

### Logging
- Structured JSON logging with correlation IDs for distributed tracing
- Log levels: DEBUG (development), INFO (production), ERROR (always)
- Centralized logging via CloudWatch Logs

### Testing
- Unit tests: Go (testify), React (Jest + React Testing Library)
- Integration tests: Testcontainers for PostgreSQL/Redis
- E2E tests: Cypress for web, Detox for mobile
- Load testing: k6 for API endpoints (target: 10,000 concurrent users)

### Deployment
- Blue-green deployment strategy for API Gateway and backend services
- Kubernetes rolling updates with readiness probes
- Database migrations: Flyway with backward-compatible schema changes
- Canary releases for Analytics Engine (10% → 50% → 100% over 3 days)

## 7. Non-functional Requirements

### Performance Goals
- API response time: p95 < 200ms for read operations
- Device command latency: < 500ms from API call to device execution
- Real-time data ingestion: 100,000 events/second via Kinesis
- TimescaleDB query performance: < 2s for 90-day historical data aggregation

### Security Requirements
- All API endpoints require JWT authentication
- MQTT connections secured with TLS 1.3 and device certificates
- Redis cluster uses AUTH password authentication
- Database connections encrypted with SSL
- PII data encrypted at rest (AES-256)

### Availability & Scalability
- Target uptime: 99.9% (8.76 hours downtime/year)
- Auto-scaling: Kubernetes HPA based on CPU utilization (target 70%)
- PostgreSQL read replicas for analytics queries (2 replicas)
- Redis Cluster: 3 master + 3 replica nodes
- Cross-region failover: Active-passive configuration (primary: us-east-1, DR: us-west-2)

### Disaster Recovery
- PostgreSQL: Daily full backups + continuous WAL archiving to S3
- Redis: RDB snapshots every 6 hours
- RPO: 1 hour, RTO: 4 hours
- Backup retention: 30 days

## 8. Open Issues & Future Enhancements

### Current Limitations
- Analytics Engine predictions currently limited to 7-day forecasts (plan to extend to 30 days)
- Mobile app lacks offline mode for viewing historical data
- No support for multi-home management (users can only register devices for one home)

### Planned Features (Q2 2026)
- Integration with electric vehicle charging stations
- Dynamic pricing optimization based on real-time energy market data
- Community energy sharing marketplace
- Voice assistant integration (Alexa, Google Home)
