# Social Media Analytics Dashboard Platform System Design

## 1. Overview

### Project Purpose
Develop a SaaS platform that aggregates social media data from multiple sources (Twitter, Instagram, Facebook, LinkedIn) and provides real-time analytics, engagement metrics, and competitive analysis for marketing teams.

### Key Features
- Multi-account social media data aggregation
- Real-time engagement metrics dashboard
- Competitor analysis and benchmarking
- Custom report generation
- Sentiment analysis on posts and comments
- Automated alert system for viral content detection

### Target Users
- Marketing agencies managing multiple client accounts
- Brand managers tracking social media performance
- Social media analysts performing competitive research

## 2. Technology Stack

### Backend
- Language: Node.js 18.x with TypeScript
- Framework: Express.js
- Queue: RabbitMQ for background job processing

### Database
- Primary Database: PostgreSQL 15
- Cache: Redis 7.0
- Time-series Data: TimescaleDB (PostgreSQL extension)

### Infrastructure
- Deployment: AWS ECS (Fargate)
- CDN: CloudFront for static assets
- API Gateway: AWS API Gateway

### External APIs
- Twitter API v2
- Meta Graph API (Instagram, Facebook)
- LinkedIn Marketing API

## 3. Architecture Design

### System Components

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
┌──────▼──────────────────────┐
│   API Gateway + CDN         │
└──────┬──────────────────────┘
       │
┌──────▼──────────────────────┐
│   Application Server        │
│   (Express.js)              │
└──┬──────────────────────┬───┘
   │                      │
   │                      │
┌──▼──────────┐    ┌─────▼──────────┐
│ PostgreSQL  │    │   RabbitMQ     │
│ + Redis     │    │   Workers      │
└─────────────┘    └────────────────┘
```

### Component Responsibilities
- **API Server**: Handles client requests, authentication, and data aggregation
- **Worker Service**: Background job execution for social media data sync
- **Database Layer**: Stores user data, social media posts, analytics metrics
- **Cache Layer**: Redis for frequently accessed data

## 4. Data Model

### Core Entities

#### accounts
```sql
CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    platform VARCHAR(50),
    platform_account_id VARCHAR(255),
    access_token TEXT,
    refresh_token TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### posts
```sql
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    account_id INTEGER REFERENCES accounts(id),
    platform_post_id VARCHAR(255),
    content TEXT,
    posted_at TIMESTAMP,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### engagement_metrics
```sql
CREATE TABLE engagement_metrics (
    id SERIAL PRIMARY KEY,
    post_id INTEGER REFERENCES posts(id),
    metric_type VARCHAR(50),
    metric_value INTEGER,
    recorded_at TIMESTAMP DEFAULT NOW()
);
```

#### reports
```sql
CREATE TABLE reports (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    report_type VARCHAR(100),
    date_range_start DATE,
    date_range_end DATE,
    status VARCHAR(50),
    report_data JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## 5. API Design

### Dashboard Endpoints

#### GET /api/dashboard/overview
Returns aggregated metrics for all connected accounts.

**Response**:
```json
{
    "total_posts": 1234,
    "total_engagement": 56789,
    "accounts": [
        {
            "account_id": 1,
            "platform": "twitter",
            "posts_count": 450,
            "avg_engagement": 123.4
        }
    ]
}
```

Implementation fetches all user accounts from database, then retrieves post statistics for each account in a loop.

#### GET /api/posts/:accountId
Returns posts for a specific social media account with engagement data.

**Query Parameters**:
- `limit`: Maximum posts to return (optional)
- `offset`: Pagination offset (optional)

**Response**:
```json
{
    "posts": [
        {
            "id": 1,
            "content": "Sample post",
            "engagement": {
                "likes": 100,
                "comments": 20,
                "shares": 5
            }
        }
    ]
}
```

### Analytics Endpoints

#### POST /api/analytics/competitor-analysis
Performs competitive analysis comparing user's accounts with competitor accounts.

**Request**:
```json
{
    "user_accounts": [1, 2, 3],
    "competitor_accounts": ["@competitor1", "@competitor2"],
    "metrics": ["engagement_rate", "posting_frequency"],
    "date_range": {
        "start": "2025-01-01",
        "end": "2025-12-31"
    }
}
```

The API fetches all posts for user accounts and competitor accounts from social media APIs, calculates metrics, and returns comparison data synchronously.

#### GET /api/analytics/trending-hashtags
Returns trending hashtags across all user accounts.

Queries all posts in the database and extracts hashtags from content field, counts occurrences, and returns top hashtags.

## 6. Implementation Approach

### Data Synchronization Strategy
Social media data is synchronized every 15 minutes via scheduled jobs. Workers fetch latest posts from each connected account using platform APIs and store in database.

For each sync cycle:
1. Fetch all connected accounts from database
2. For each account, call platform API to get latest posts
3. For each post, fetch engagement metrics (likes, comments, shares)
4. Store posts and metrics in database

### Report Generation
Users can generate custom reports for any date range. The system:
1. Queries all posts within the specified date range
2. Calculates aggregated metrics (total engagement, top posts, growth trends)
3. Stores report data as JSONB in reports table
4. Returns report to user

Report generation is synchronous and blocks the API request until complete.

### Caching Strategy
Use Redis for the following:
- User session data (TTL: 24 hours)
- API rate limit tracking

### Authentication & Authorization
- JWT tokens for user authentication
- OAuth 2.0 for social media account connections
- API rate limiting: 100 requests per minute per user

## 7. Non-Functional Requirements

### Security
- All API endpoints require JWT authentication
- Social media access tokens encrypted at rest
- HTTPS only for all communications

### Scalability
The system is designed to run as a single ECS task. As user load increases, we can manually increase task count.

### Availability
- Database backups run daily
- Application logs sent to CloudWatch

### Data Retention
All social media posts and engagement metrics are stored indefinitely to support historical analysis and trend tracking.
