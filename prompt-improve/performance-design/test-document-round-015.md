# E-Commerce Product Search and Recommendation Platform - System Design Document

## 1. Overview

### Project Background
This platform provides advanced product search and personalized recommendation functionality for a large-scale e-commerce marketplace. The system handles millions of products across diverse categories and serves millions of daily active users.

### Key Features
- Real-time product search with faceted filtering
- Personalized product recommendations based on browsing and purchase history
- User review and rating system
- Product comparison functionality
- Wishlist management
- Price alert notifications

### Target Users and Usage Scenarios
- **End Users**: Browse, search, and compare products; receive personalized recommendations
- **Merchants**: Monitor product performance and customer feedback
- **Analysts**: Generate sales and performance reports

## 2. Technology Stack

### Languages & Frameworks
- Backend: Java 17, Spring Boot 3.x
- Frontend: React 18, TypeScript
- Search: Elasticsearch 8.x

### Database
- Primary: PostgreSQL 15
- Cache: Redis 7
- Search Index: Elasticsearch cluster (3 nodes)

### Infrastructure & Deployment
- Cloud: AWS (ECS Fargate, RDS, ElastiCache)
- Load Balancer: AWS Application Load Balancer
- CDN: CloudFront for static assets
- Deployment: Blue-Green deployment via AWS CodeDeploy

### Key Libraries
- Spring Data JPA for database access
- Spring Data Redis for cache management
- Elasticsearch Java Client
- Apache Kafka for event streaming

## 3. Architecture Design

### Overall Architecture
The system follows a microservices architecture with the following key services:
- **Product Service**: Product CRUD operations
- **Search Service**: Elasticsearch integration for search
- **Recommendation Service**: Personalized recommendation engine
- **User Service**: User profile and preference management
- **Review Service**: Product reviews and ratings
- **Notification Service**: Price alert and promotional notifications

### Component Dependencies
- Frontend → API Gateway → Microservices
- All services → PostgreSQL (primary data store)
- Search Service → Elasticsearch cluster
- Recommendation Service → Kafka (event consumption)
- All services → Redis (shared cache)

### Data Flow
1. User searches for products via frontend
2. API Gateway routes request to Search Service
3. Search Service queries Elasticsearch and returns results
4. User browses product details → Product Service retrieves from PostgreSQL
5. User interactions (views, clicks) → Kafka events → Recommendation Service
6. Recommendation Service generates personalized suggestions

## 4. Data Model

### Primary Entities

#### Product
- `product_id` (UUID, PK)
- `merchant_id` (UUID, FK)
- `category_id` (INT, FK)
- `name` (VARCHAR)
- `description` (TEXT)
- `price` (DECIMAL)
- `stock_quantity` (INT)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

#### User
- `user_id` (UUID, PK)
- `email` (VARCHAR, UNIQUE)
- `hashed_password` (VARCHAR)
- `preferences` (JSONB)
- `created_at` (TIMESTAMP)

#### Review
- `review_id` (UUID, PK)
- `product_id` (UUID, FK)
- `user_id` (UUID, FK)
- `rating` (INT, 1-5)
- `comment` (TEXT)
- `created_at` (TIMESTAMP)

#### UserInteraction
- `interaction_id` (BIGSERIAL, PK)
- `user_id` (UUID, FK)
- `product_id` (UUID, FK)
- `interaction_type` (ENUM: 'view', 'click', 'add_to_cart', 'purchase')
- `timestamp` (TIMESTAMP)

#### PriceAlert
- `alert_id` (UUID, PK)
- `user_id` (UUID, FK)
- `product_id` (UUID, FK)
- `target_price` (DECIMAL)
- `created_at` (TIMESTAMP)
- `status` (ENUM: 'active', 'triggered', 'expired')

## 5. API Design

### Search Endpoint
```
GET /api/v1/products/search
Query Parameters:
  - q (string): Search query
  - category (string, optional): Category filter
  - min_price (decimal, optional): Minimum price
  - max_price (decimal, optional): Maximum price
  - sort_by (enum: relevance, price_asc, price_desc, rating)
  - page (int, default: 1)
  - page_size (int, default: 20)

Response:
{
  "products": [...],
  "total_count": 1000,
  "page": 1,
  "page_size": 20
}
```

### Recommendation Endpoint
```
GET /api/v1/recommendations/{user_id}
Query Parameters:
  - count (int, default: 10)

Response:
{
  "recommendations": [
    {
      "product_id": "...",
      "score": 0.95,
      "reason": "Based on your recent browsing history"
    }
  ]
}
```

### Review Submission
```
POST /api/v1/reviews
Request Body:
{
  "product_id": "...",
  "rating": 5,
  "comment": "..."
}

Response:
{
  "review_id": "...",
  "created_at": "..."
}
```

### Authentication & Authorization
- JWT-based authentication
- Tokens issued by User Service
- 24-hour token expiration
- Role-based access control (User, Merchant, Admin)

## 6. Implementation Details

### Product Search Implementation
The Search Service integrates with Elasticsearch to provide real-time search. When users submit a search query:

1. API Gateway forwards the request to Search Service
2. Search Service constructs an Elasticsearch query with filters
3. Results are retrieved from the Elasticsearch index
4. For each product in the results, the service fetches full details from PostgreSQL
5. Results are returned to the frontend

### Recommendation Engine
The Recommendation Service uses a collaborative filtering algorithm combined with content-based filtering:

1. User interactions are published to Kafka topics
2. Recommendation Service consumes events and updates user preference models
3. When a recommendation request arrives, the service:
   - Retrieves user's interaction history from PostgreSQL
   - Fetches similar users' purchase patterns from PostgreSQL
   - Calculates similarity scores for all products
   - Returns top N recommendations

### Review Aggregation
Product ratings are aggregated on-demand:
- When displaying a product, the system queries all reviews for that product
- Average rating is calculated by summing all ratings and dividing by count
- Results are displayed to the user

### Price Alert Processing
A scheduled job runs every 15 minutes to check active price alerts:
1. Retrieve all active price alerts from the database
2. For each alert, fetch current product price from PostgreSQL
3. If current price <= target price, trigger notification
4. Update alert status to 'triggered'
5. Send notification via Notification Service

### Error Handling
- API Gateway returns standard HTTP error codes (400, 401, 403, 404, 500)
- All errors are logged to CloudWatch
- Circuit breaker pattern for external service calls
- Retry logic with exponential backoff for transient failures

### Logging
- Structured JSON logging using Logback
- Log levels: DEBUG (development), INFO (production)
- All service logs aggregated in CloudWatch
- Request/response logging at API Gateway level

### Testing Strategy
- Unit tests for business logic (JUnit 5, Mockito)
- Integration tests for API endpoints (Spring Boot Test)
- Contract tests for inter-service communication (Pact)
- Load testing using JMeter (monthly)

### Deployment
- Blue-Green deployment to minimize downtime
- Health check endpoint: `/actuator/health`
- Automated rollback if health checks fail
- Database migrations using Flyway

## 7. Non-Functional Requirements

### Scalability
- Horizontal scaling of all services via ECS Auto Scaling
- Elasticsearch cluster can be expanded by adding nodes
- Database read replicas for read-heavy operations

### Availability
- Multi-AZ deployment for RDS and ElastiCache
- Application Load Balancer distributes traffic across multiple instances
- Target availability: 99.9%

### Security
- All data encrypted in transit (TLS 1.3)
- Database encryption at rest enabled
- JWT tokens for authentication
- Input validation and sanitization
- Rate limiting at API Gateway (100 requests per minute per user)

### Monitoring
- CloudWatch for infrastructure metrics (CPU, memory, network)
- Application-level logging to CloudWatch Logs
- AWS X-Ray for distributed tracing
