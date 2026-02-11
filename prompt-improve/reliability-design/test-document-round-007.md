# Real-Time Event Streaming Platform System Design

## 1. Overview

### Project Purpose
Building a scalable real-time event streaming platform for sports event broadcasting. The platform ingests live event data from multiple sources, processes them in real-time, and delivers personalized content to end-users via mobile and web applications.

### Key Features
- Multi-source event ingestion (stadium sensors, broadcast APIs, social media feeds)
- Real-time event processing and enrichment
- Personalized content delivery with sub-second latency
- Historical event replay and analytics
- Multi-language support with automated translation

### Target Users
- Sports fans accessing live events via mobile/web apps
- Content editors managing event metadata
- Analytics teams querying historical data
- Third-party integrations via public APIs

## 2. Technology Stack

### Languages & Frameworks
- Backend: Java 17 with Spring Boot 3.2, Spring WebFlux for reactive streams
- Frontend: React Native (mobile), Next.js (web)
- Stream Processing: Apache Flink 1.18

### Data Stores
- Primary Database: PostgreSQL 15 (Multi-AZ RDS)
- Time-Series Database: InfluxDB 2.7 for event metrics
- Cache Layer: Redis Cluster 7.2
- Search Index: OpenSearch 2.11

### Streaming Infrastructure
- Event Streaming: Apache Kafka 3.6 (MSK)
- WebSocket Gateway: Socket.IO with Redis adapter

### Infrastructure & Deployment
- Container Orchestration: AWS EKS
- Load Balancing: AWS ALB with WebSocket support
- CDN: CloudFront for static assets
- External APIs: OpenAI API for content translation, Stripe for subscriptions

## 3. Architecture Design

### Overall Structure
Three-tier architecture with event-driven communication:

1. **Ingestion Layer**: Multi-source adapters publishing to Kafka topics
2. **Processing Layer**: Flink jobs consuming Kafka, enriching events, writing to PostgreSQL/InfluxDB
3. **Delivery Layer**: WebSocket gateway and REST API serving client applications

### Component Responsibilities

#### Ingestion Adapters
- Stadium Sensor Adapter: Polls sensor APIs every 100ms, publishes raw telemetry to `sensor-events` topic
- Broadcast API Adapter: Receives webhook callbacks from broadcast partners, validates signatures, publishes to `broadcast-events` topic
- Social Media Adapter: Streams Twitter/Reddit feeds via their APIs, filters relevant mentions, publishes to `social-events` topic

#### Stream Processors (Flink Jobs)
- Event Enrichment Job: Joins events across topics, adds contextual metadata, writes to PostgreSQL `events` table
- Metrics Aggregation Job: Computes real-time statistics (viewer counts, engagement rates), writes to InfluxDB
- Translation Job: Detects non-English content, calls OpenAI API for translation, stores translations in Redis with 5-minute TTL

#### API Services
- WebSocket Gateway: Maintains persistent connections, subscribes to Redis Pub/Sub for event notifications, broadcasts to connected clients
- REST API: Handles client queries, user preferences, subscription management via Stripe

### Data Flow

1. External sources → Ingestion Adapters → Kafka topics (`sensor-events`, `broadcast-events`, `social-events`)
2. Kafka → Flink Enrichment Job → PostgreSQL `events` table + Redis Pub/Sub channel `live-events`
3. Redis Pub/Sub → WebSocket Gateway → Client applications
4. Kafka → Flink Aggregation Job → InfluxDB time-series metrics
5. Client REST queries → API Service → PostgreSQL/Redis → Response

## 4. Data Model

### PostgreSQL Schema

#### events table
```sql
CREATE TABLE events (
  event_id BIGSERIAL PRIMARY KEY,
  event_type VARCHAR(50) NOT NULL,
  source VARCHAR(50) NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  payload JSONB NOT NULL,
  enriched_metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_events_timestamp ON events(timestamp DESC);
CREATE INDEX idx_events_type_timestamp ON events(event_type, timestamp DESC);
```

#### user_subscriptions table
```sql
CREATE TABLE user_subscriptions (
  subscription_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  stripe_subscription_id VARCHAR(255) UNIQUE,
  plan_tier VARCHAR(20) NOT NULL,
  status VARCHAR(20) NOT NULL,
  current_period_end TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user ON user_subscriptions(user_id);
```

#### user_preferences table
```sql
CREATE TABLE user_preferences (
  preference_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE,
  preferred_teams TEXT[],
  notification_settings JSONB,
  language VARCHAR(10),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### InfluxDB Schema

#### event_metrics measurement
- Tags: `event_type`, `source`, `region`
- Fields: `count`, `latency_ms`, `processing_time_ms`, `error_rate`
- Timestamp: event occurrence time

### Redis Data Structures

#### Pub/Sub Channels
- `live-events`: Real-time event broadcasts to WebSocket gateway
- `translation-cache:{event_id}:{lang}`: Cached translations, 5-minute expiry

#### Session Store
- `session:{user_id}`: User session data with 24-hour expiry

## 5. API Design

### WebSocket Protocol

#### Connection
- Endpoint: `wss://api.example.com/events`
- Authentication: JWT token in query parameter `?token=xxx`
- Initial handshake: Client sends `{"type": "subscribe", "teams": ["team_1", "team_2"]}`

#### Event Message Format
```json
{
  "event_id": 12345,
  "event_type": "goal",
  "timestamp": "2026-02-11T10:30:00Z",
  "payload": {
    "team": "team_1",
    "player": "John Doe",
    "score": "2-1"
  },
  "translations": {
    "es": "...",
    "fr": "..."
  }
}
```

### REST API Endpoints

#### GET /events/history
- Query Parameters: `event_type`, `start_time`, `end_time`, `limit`
- Response: Paginated list of historical events
- Authentication: Bearer token

#### POST /subscriptions/webhook
- Stripe webhook endpoint for subscription events
- Validates webhook signature
- Updates `user_subscriptions` table based on event type

#### GET /metrics/summary
- Query Parameters: `start_time`, `end_time`, `aggregation_window`
- Response: Aggregated metrics from InfluxDB
- Authentication: Admin-only endpoint

## 6. Implementation Guidelines

### Error Handling
- External API calls (OpenAI, Stripe): Log errors, emit metrics, continue processing
- Database connection failures: Service returns 503 with retry-after header
- Kafka consumer errors: Commit offset only after successful processing

### Logging
- Structured JSON logs via Logback
- Log levels: ERROR for unrecoverable failures, WARN for degraded operations, INFO for key business events
- Correlation IDs: Generated at ingestion boundary, propagated through all processing stages

### Testing Strategy
- Unit tests: 80% coverage target for business logic
- Integration tests: Testcontainers for database/Kafka interactions
- Load tests: Gatling scripts simulating 10,000 concurrent WebSocket connections
- Chaos experiments: Random pod terminations, network partition simulations

### Deployment
- Container images built via GitHub Actions, pushed to ECR
- Helm charts for Kubernetes deployments
- Deployment strategy: Update EKS deployment with new image tag, wait for rollout status
- Database migrations: Flyway scripts executed manually before deployment

## 7. Non-Functional Requirements

### Performance Targets
- End-to-end latency (ingestion → client delivery): p95 < 500ms
- WebSocket connection capacity: 50,000 concurrent connections per gateway instance
- Event throughput: 10,000 events/second peak load

### Security Requirements
- JWT-based authentication with 15-minute token expiry
- HTTPS/WSS for all external communications
- Stripe webhook signature validation
- PostgreSQL: Row-level security for multi-tenant data isolation

### Scalability & Availability
- Horizontal Pod Autoscaler: Scale WebSocket gateway based on CPU utilization (target 70%)
- Kafka: 3 brokers, replication factor 2 for event topics
- PostgreSQL: Multi-AZ RDS with automated failover
- Redis Cluster: 6 nodes (3 primary + 3 replica)
- EKS: 3 availability zones, minimum 6 nodes
- Target availability: 99.9% uptime (43.8 minutes downtime/month allowed)
