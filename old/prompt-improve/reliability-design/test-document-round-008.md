# Smart Energy Management System - System Design Document

## 1. Overview

### Project Purpose
The Smart Energy Management System provides real-time monitoring and optimization of energy consumption for commercial and industrial facilities. The platform aggregates data from IoT sensors, weather forecasts, and utility pricing APIs to enable automated load balancing, demand response participation, and cost optimization.

### Key Features
- Real-time energy consumption monitoring across multiple facilities
- Predictive load forecasting using historical data and weather patterns
- Automated demand response (DR) event participation
- Energy cost optimization through peak shaving and load shifting
- Facility performance dashboards and compliance reporting
- Integration with building management systems (BMS) and smart meters

### Target Users
- Facility managers for commercial buildings
- Energy managers for industrial plants
- Utility companies for demand response programs
- Building operators for day-to-day monitoring

## 2. Technology Stack

### Languages & Frameworks
- Backend: Go 1.21 with Gin framework
- Frontend: React 18 with TypeScript
- Data processing: Apache Kafka Streams for real-time aggregation

### Databases
- PostgreSQL 15 (facility metadata, user accounts, DR event history)
- InfluxDB 2.x (time-series sensor data, 15-second granularity)
- Redis 7.0 (caching forecast results, session management)

### Infrastructure
- Kubernetes on AWS EKS (3 availability zones)
- Application Load Balancer for frontend/API
- AWS IoT Core for smart meter connectivity (MQTT protocol)
- S3 for historical data archival (daily snapshots)

### Key External Dependencies
- WeatherAPI.com (forecast data for predictive models)
- Utility Grid API (real-time pricing, DR event notifications via webhook)
- Building Management System (BMS) SOAP API (HVAC control commands)

## 3. Architecture Design

### Component Overview
```
[Smart Meters] --MQTT--> [IoT Core] ---> [Ingestion Service]
                                              |
                                              v
                                         [Kafka Topic: sensor-readings]
                                              |
                      +----------------------+------------------------+
                      |                      |                        |
                      v                      v                        v
              [Aggregation Service]   [Forecast Service]      [DR Coordinator]
                      |                      |                        |
                      v                      v                        v
                 [InfluxDB]            [PostgreSQL]              [BMS Controller]
                                            ^
                                            |
                                       [API Gateway] <--> [React Frontend]
```

### Component Responsibilities
- **Ingestion Service**: Validates and forwards MQTT messages to Kafka
- **Aggregation Service**: Consumes sensor-readings topic, computes 1-min/15-min/hourly rollups, writes to InfluxDB
- **Forecast Service**: Runs ML models (LSTM) every 15 minutes to predict next 24h load profile
- **DR Coordinator**: Listens to utility webhook for DR events, calculates optimal load reduction strategy, sends BMS commands
- **API Gateway**: Serves dashboard queries, historical data exports, user management

### Data Flow
1. Smart meters publish readings every 15 seconds to AWS IoT Core
2. Ingestion Service forwards to Kafka topic `sensor-readings` (partitioned by facility ID)
3. Aggregation Service consumes from Kafka, writes rollups to InfluxDB
4. Forecast Service queries InfluxDB + WeatherAPI every 15 minutes, stores predictions in PostgreSQL
5. DR Coordinator receives utility webhook, queries forecast, sends HVAC/lighting commands to BMS
6. Frontend polls API Gateway every 30 seconds for dashboard updates

## 4. Data Model

### PostgreSQL Schema

#### facilities
- id (UUID, primary key)
- name (VARCHAR(255))
- location (GEOGRAPHY)
- timezone (VARCHAR(50))
- contract_demand_kw (DECIMAL) - utility contract capacity limit
- created_at, updated_at (TIMESTAMP)

#### dr_events
- id (UUID, primary key)
- facility_id (UUID, foreign key)
- event_start (TIMESTAMP WITH TIME ZONE)
- event_end (TIMESTAMP WITH TIME ZONE)
- target_reduction_kw (DECIMAL)
- achieved_reduction_kw (DECIMAL, nullable)
- status (ENUM: scheduled, active, completed, failed)
- created_at (TIMESTAMP)

#### load_forecasts
- id (BIGSERIAL, primary key)
- facility_id (UUID, foreign key)
- forecast_timestamp (TIMESTAMP WITH TIME ZONE)
- predicted_load_kw (DECIMAL)
- confidence_interval_upper (DECIMAL)
- confidence_interval_lower (DECIMAL)
- created_at (TIMESTAMP)
- UNIQUE(facility_id, forecast_timestamp)

### InfluxDB Measurements

#### energy_readings
- Tags: facility_id, meter_id, meter_type
- Fields: active_power_kw, reactive_power_kvar, voltage_v, frequency_hz
- Timestamp: 15-second precision

#### energy_rollups_15min
- Tags: facility_id
- Fields: avg_power_kw, max_power_kw, total_energy_kwh
- Timestamp: 15-minute intervals

## 5. API Design

### REST Endpoints

#### GET /api/facilities/{facility_id}/current
- Returns current power consumption, contract utilization percentage
- Response includes latest 15-second reading from InfluxDB
- Cache: Redis, 10-second TTL

#### POST /api/dr-events
- Creates demand response event
- Request: { facility_id, event_start, event_end, target_reduction_kw }
- Returns: event ID and calculated baseline load
- Authorization: Utility API key required

#### GET /api/facilities/{facility_id}/forecast
- Returns 24-hour load forecast with confidence intervals
- Query params: start_time (default: now), granularity (15min/1hour)
- Response: array of { timestamp, predicted_load_kw, confidence_upper, confidence_lower }

### Webhook Endpoints

#### POST /webhooks/utility/dr-notification
- Receives DR event notification from utility grid operator
- Payload: { event_id, facility_ids[], event_start, event_end, target_reduction_percentage }
- Triggers DR Coordinator workflow
- Returns 200 immediately (async processing)

## 6. Implementation Details

### Error Handling
- API Gateway returns standard error responses: { error_code, message, details }
- Ingestion Service logs malformed MQTT messages to CloudWatch, continues processing
- Forecast Service retries WeatherAPI calls with exponential backoff (max 3 attempts)
- BMS Controller logs command failures but does not retry (manual intervention required)

### Logging
- Structured JSON logs with correlation IDs (trace_id propagated from API requests)
- Log levels: DEBUG for development, INFO for production
- Centralized via CloudWatch Logs with 30-day retention

### Testing
- Unit tests: Go stdlib testing, target 80% coverage
- Integration tests: Testcontainers for PostgreSQL/Redis/Kafka
- End-to-end tests: Cypress for critical user flows (facility dashboard, DR event creation)

### Deployment
- CI/CD: GitHub Actions with automated testing
- Deployment target: EKS with rolling update strategy (maxUnavailable: 1)
- Database migrations: Flyway SQL scripts run before deployment
- Configuration: Environment variables via Kubernetes ConfigMaps

## 7. Non-Functional Requirements

### Performance
- Dashboard API latency: p95 < 500ms
- Ingestion throughput: 10,000 sensor readings/second
- Forecast computation: Complete within 5 minutes for 100 facilities

### Security
- API authentication via JWT tokens (Auth0)
- TLS 1.3 for all external communications
- Secrets management via AWS Secrets Manager
- Network isolation: Private subnets for databases, public for ALB only

### Availability & Scalability
- Target uptime: 99.5% (excluding planned maintenance)
- Multi-AZ deployment: Services replicated across 3 zones
- Auto-scaling: HPA based on CPU utilization (target 70%)
- InfluxDB retention policy: 90 days granular data, 2 years downsampled to hourly
- PostgreSQL: Single primary instance (no read replicas)

### Monitoring
- Metrics collected via Prometheus, visualized in Grafana
- Key metrics: API request rate, Kafka consumer lag, InfluxDB write throughput
- Alerts configured for: Kafka lag > 10,000 messages, API error rate > 5%, InfluxDB disk usage > 80%
