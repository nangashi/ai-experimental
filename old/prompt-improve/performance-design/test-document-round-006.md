# Smart Energy Management System - System Design Document

## 1. Overview

### Project Background
The Smart Energy Management System is a cloud-based platform designed for commercial buildings to optimize energy consumption, reduce costs, and provide real-time monitoring of energy usage patterns. The system integrates with IoT sensors, smart meters, and building management systems to collect energy data and provide actionable insights.

### Key Features
- Real-time energy consumption monitoring across multiple buildings
- Predictive analytics for energy usage forecasting
- Automated alerts for anomalous consumption patterns
- Energy efficiency recommendations based on historical data
- Multi-tenant support for property management companies
- Integration with utility provider APIs for billing reconciliation
- Historical data analysis and reporting

### Target Users
- Building facility managers
- Property management companies
- Energy consultants
- Building owners and tenants

## 2. Technology Stack

### Backend
- Language: Python 3.11
- Framework: FastAPI
- Task Queue: Celery with Redis broker
- API Gateway: Kong

### Database
- Primary Database: PostgreSQL 15
- Time-series Database: TimescaleDB (PostgreSQL extension)
- Cache: Redis 7

### Infrastructure
- Cloud Provider: AWS
- Container Platform: ECS Fargate
- Load Balancer: Application Load Balancer
- Storage: S3 for archived data

### Key Libraries
- pandas for data processing
- scikit-learn for predictive models
- pydantic for data validation
- SQLAlchemy for ORM

## 3. Architecture Design

### Overall Architecture
The system follows a microservices architecture with the following components:

```
[IoT Sensors/Smart Meters]
    ↓ (MQTT/HTTP)
[API Gateway]
    ↓
[Ingestion Service] → [Time-series DB]
    ↓
[Processing Service]
    ↓
[Analytics Service] → [Primary DB]
    ↓
[API Service] ← [Web Dashboard]
```

### Component Responsibilities

#### Ingestion Service
- Receives sensor data via REST API and MQTT
- Validates incoming data
- Stores raw measurements in TimescaleDB
- Publishes events to message queue for downstream processing

#### Processing Service
- Aggregates raw sensor data into hourly/daily summaries
- Calculates energy consumption metrics
- Detects anomalies in usage patterns
- Triggers alerts for threshold violations

#### Analytics Service
- Generates predictive models for energy forecasting
- Produces energy efficiency recommendations
- Runs batch analysis jobs on historical data

#### API Service
- Provides REST API for dashboard and external integrations
- Handles authentication and authorization
- Serves aggregated data and analytics results

## 4. Data Model

### Primary Entities

#### Building
```sql
CREATE TABLE buildings (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    square_footage INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### Sensor
```sql
CREATE TABLE sensors (
    id UUID PRIMARY KEY,
    building_id UUID REFERENCES buildings(id),
    sensor_type VARCHAR(50) NOT NULL,
    location VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### Energy Reading (Time-series)
```sql
CREATE TABLE energy_readings (
    sensor_id UUID NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    value_kwh DECIMAL(10,3) NOT NULL,
    quality_flag INTEGER,
    PRIMARY KEY (sensor_id, timestamp)
);

SELECT create_hypertable('energy_readings', 'timestamp');
```

#### Daily Summary
```sql
CREATE TABLE daily_summaries (
    building_id UUID NOT NULL,
    date DATE NOT NULL,
    total_consumption_kwh DECIMAL(12,3),
    peak_demand_kw DECIMAL(10,3),
    cost_estimate DECIMAL(10,2),
    PRIMARY KEY (building_id, date)
);
```

#### Alert Configuration
```sql
CREATE TABLE alert_configs (
    id UUID PRIMARY KEY,
    building_id UUID REFERENCES buildings(id),
    threshold_kwh DECIMAL(10,3),
    notification_email VARCHAR(255),
    is_enabled BOOLEAN DEFAULT true
);
```

## 5. API Design

### Authentication
- JWT-based authentication
- Token expiration: 24 hours
- Refresh token mechanism for long-lived sessions

### Key Endpoints

#### Get Building Energy Data
```
GET /api/v1/buildings/{building_id}/energy
Query Parameters:
  - start_date (required): ISO 8601 date
  - end_date (required): ISO 8601 date
  - resolution: hour|day|month (default: day)

Response:
{
  "building_id": "uuid",
  "period": {"start": "...", "end": "..."},
  "readings": [
    {"timestamp": "...", "consumption_kwh": 123.45},
    ...
  ]
}
```

#### Get Analytics Report
```
GET /api/v1/buildings/{building_id}/analytics/report
Query Parameters:
  - report_type: efficiency|forecast|comparison
  - period: week|month|quarter|year

Response:
{
  "report_id": "uuid",
  "generated_at": "...",
  "insights": [...],
  "recommendations": [...]
}
```

#### Batch Sensor Data Ingestion
```
POST /api/v1/sensors/readings/batch
Request Body:
{
  "readings": [
    {"sensor_id": "...", "timestamp": "...", "value_kwh": 10.5},
    ...
  ]
}
```

#### Get Tenant Buildings List
```
GET /api/v1/tenants/{tenant_id}/buildings
Response:
{
  "buildings": [
    {"id": "...", "name": "...", "sensor_count": 25},
    ...
  ]
}
```

## 6. Implementation Guidelines

### Data Ingestion Flow
1. API Gateway receives sensor data via POST request
2. Ingestion Service validates data format
3. Write to TimescaleDB energy_readings table
4. Return 202 Accepted response immediately
5. Asynchronous processing triggers aggregation job

### Aggregation Process
- Celery task runs every hour to aggregate raw readings
- Calculates hourly summaries from raw data
- Updates daily_summaries table with rolled-up metrics
- All aggregation runs in a single database transaction

### Alert Processing
- Every 15 minutes, Processing Service queries latest readings
- Compares consumption against alert_configs thresholds
- For each building exceeding threshold, sends email notification
- Logs alert events in alert_history table

### Analytics Report Generation
- User requests report via dashboard
- API Service synchronously calls Analytics Service
- Analytics Service loads historical data from database
- Applies ML models for forecasting
- Generates PDF report
- Returns report to user

### Error Handling
- All API endpoints return standard error format
- Database connection errors trigger automatic retry (max 3 attempts)
- Failed sensor readings are logged but don't block ingestion pipeline

### Logging
- Structured JSON logging for all services
- Log levels: DEBUG for development, INFO for production
- Centralized logging via CloudWatch

### Testing Strategy
- Unit tests for business logic
- Integration tests for API endpoints
- Performance tests for ingestion throughput

### Deployment
- Blue-green deployment for zero-downtime updates
- Database migrations managed via Alembic
- Configuration via environment variables

## 7. Non-Functional Requirements

### Scalability
- System designed to support up to 50 buildings per tenant
- Target sensor count: 1000 sensors per building
- Estimated data volume: 10 million readings per day at peak

### Availability
- Target uptime: 99.5%
- Automated failover for database instances
- Load balancer health checks every 30 seconds

### Data Retention
- Raw energy_readings: 90 days
- Aggregated daily_summaries: 5 years
- Archived data moved to S3 after 90 days
