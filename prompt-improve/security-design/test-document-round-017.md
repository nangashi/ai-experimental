# Video Streaming Platform System Design

## 1. Overview
- **Project Purpose**: Build a cloud-native video streaming platform for live and on-demand content delivery to global audiences
- **Key Features**:
  - User registration and authentication (free tier and paid subscriptions)
  - Live streaming with real-time chat
  - Video upload, transcoding, and on-demand playback
  - Creator monetization dashboard
  - Content recommendation engine
  - Multi-device support (web, mobile, smart TV)
- **Target Users**: Content creators, viewers, and platform administrators

## 2. Technology Stack
- **Backend**: Go (API gateway), Node.js (real-time services)
- **Frontend**: React, React Native (mobile)
- **Database**: PostgreSQL (user metadata, subscriptions), MongoDB (video metadata, analytics)
- **Streaming**: AWS MediaLive, AWS MediaPackage, CloudFront CDN
- **Message Queue**: RabbitMQ
- **Cache**: Redis (session cache, API rate limiting)
- **Search**: Elasticsearch (video search)
- **Infrastructure**: Kubernetes (EKS), Terraform
- **Main Libraries**: JWT (authentication), Stripe SDK (payments), Socket.IO (real-time chat)

## 3. Architecture Design

### 3.1 Overall Structure
- **API Gateway Layer**: Kong API Gateway for routing, rate limiting, and basic authentication
- **Service Layer**:
  - Auth Service: User authentication and authorization
  - Video Service: Upload, transcoding orchestration, metadata management
  - Streaming Service: Live stream ingestion and delivery
  - Chat Service: Real-time messaging with WebSocket
  - Payment Service: Subscription management and creator payouts
  - Recommendation Service: ML-based content recommendation
- **Data Layer**: PostgreSQL primary, MongoDB for unstructured data, Redis for cache
- **CDN Layer**: CloudFront for global content delivery

### 3.2 Component Dependencies
- API Gateway → Auth Service → All other services
- Video Service → Streaming Service (for live streams)
- Payment Service → External: Stripe API
- Recommendation Service → MongoDB (read-only replica)

### 3.3 Data Flow
1. User uploads video → Video Service → S3 bucket → Lambda triggers transcoding
2. Transcoded assets → CloudFront distribution → End users
3. Live stream: RTMP ingestion → MediaLive → MediaPackage → CloudFront
4. Payment flow: User subscribes → Payment Service → Stripe API → Webhook callback → Update PostgreSQL

## 4. Data Model

### 4.1 Main Entities (PostgreSQL)
**users**
- id (UUID, PK)
- email (VARCHAR, UNIQUE)
- password_hash (VARCHAR)
- display_name (VARCHAR)
- subscription_tier (ENUM: free, premium, creator)
- created_at (TIMESTAMP)

**subscriptions**
- id (UUID, PK)
- user_id (UUID, FK → users.id)
- plan_id (VARCHAR)
- status (ENUM: active, canceled, expired)
- stripe_subscription_id (VARCHAR)
- current_period_end (TIMESTAMP)

**videos** (MongoDB)
- _id (ObjectId)
- creator_id (UUID)
- title (String)
- description (String)
- upload_url (String)
- playback_urls (Array of Objects: {resolution, url})
- view_count (Number)
- metadata (Object: duration, file_size, thumbnails)
- created_at (Date)

## 5. API Design

### 5.1 Authentication Endpoints
- `POST /api/v1/auth/signup`: Create new user account
- `POST /api/v1/auth/login`: Login with email/password, returns JWT
- `POST /api/v1/auth/refresh`: Refresh JWT token using refresh token
- `POST /api/v1/auth/logout`: Invalidate session

### 5.2 Video Management Endpoints
- `POST /api/v1/videos`: Upload video (creator role required)
- `GET /api/v1/videos/:id`: Get video details (public for free videos, authentication required for premium)
- `DELETE /api/v1/videos/:id`: Delete video (creator owner only)
- `GET /api/v1/videos/search`: Search videos by keyword

### 5.3 Streaming Endpoints
- `POST /api/v1/streams/start`: Start live stream (creator role required)
- `GET /api/v1/streams/:id/manifest`: Get HLS manifest URL
- `POST /api/v1/streams/:id/stop`: Stop live stream

### 5.4 Authentication Approach
- JWT-based authentication with access tokens (30-minute expiry) and refresh tokens (7-day expiry)
- Access tokens stored in HTTP-only cookies
- API Gateway validates JWT on each request using public key
- Role-based access control: free, premium, creator, admin roles

### 5.5 Authorization Model
- Role-based (RBAC): User roles determine feature access
- Resource-based: Video ownership for creator actions (edit, delete)
- Subscription-based: Premium content requires active subscription

## 6. Implementation Approach

### 6.1 Error Handling
- Standardized error response format: `{error: {code, message, details}}`
- Circuit breaker for external services (Stripe, AWS MediaLive)
- Retry logic with exponential backoff for transient failures

### 6.2 Logging
- Structured JSON logs with correlation IDs
- Log levels: DEBUG (development), INFO (production default), ERROR (alerts)
- Centralized logging with ELK stack

### 6.3 Testing
- Unit tests for business logic (80% coverage target)
- Integration tests for API endpoints
- Load testing for streaming endpoints (10,000 concurrent viewers target)

### 6.4 Deployment
- Blue-green deployment for zero-downtime updates
- Kubernetes rolling updates with health checks
- Environment-specific ConfigMaps for configuration
- Database migrations with Flyway
- CI/CD pipeline: GitHub Actions → Build → Test → Deploy to staging → Manual approval → Production

## 7. Non-Functional Requirements

### 7.1 Performance
- Video playback latency: <3 seconds for on-demand, <10 seconds for live streams
- API response time: p95 <500ms
- CDN cache hit ratio: >90%

### 7.2 Security
- TLS 1.3 for all external communication
- JWT signature algorithm: RS256
- Sensitive data encryption at rest using AWS KMS
- API rate limiting: 100 requests/minute per user, 1000 requests/minute per IP

### 7.3 Availability and Scalability
- Target uptime: 99.9%
- Auto-scaling based on CPU utilization (70% threshold)
- Database read replicas for high-read workloads
- Redis cluster for session caching
- Multi-AZ deployment for high availability
