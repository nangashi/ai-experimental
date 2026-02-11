# E-Learning Platform System Design Document

## 1. Overview

### 1.1 Project Background
This document describes the technical design for a comprehensive e-learning platform supporting video-based courses, live webinars, interactive quizzes, and student progress tracking. The platform targets educational institutions and corporate training programs with 50,000+ concurrent users during peak hours.

### 1.2 Key Features
- **Course Management**: Video content delivery, course catalog, curriculum planning
- **Live Sessions**: Real-time webinars with interactive Q&A and screen sharing
- **Assessment Engine**: Quiz creation, automated grading, progress tracking
- **Analytics Dashboard**: Instructor insights on student engagement and performance
- **Certification System**: Automated certificate generation upon course completion

### 1.3 Target Users
- **Students**: Course enrollment, video playback, quiz submission, progress monitoring
- **Instructors**: Course creation, live session hosting, performance analytics
- **Administrators**: Platform configuration, user management, system monitoring

## 2. Technology Stack

### 2.1 Backend
- **Language**: Java 17
- **Framework**: Spring Boot 3.1, Spring WebFlux for live session handling
- **API Gateway**: Spring Cloud Gateway

### 2.2 Data Storage
- **Primary Database**: PostgreSQL 15 for transactional data
- **Cache Layer**: Redis 7.0
- **Object Storage**: AWS S3 for video content and attachments
- **Search Engine**: Elasticsearch 8.0 for course catalog

### 2.3 Infrastructure
- **Cloud Provider**: AWS (us-east-1 region)
- **Container Orchestration**: Kubernetes (EKS)
- **Message Broker**: Apache Kafka for event streaming
- **Monitoring**: Prometheus + Grafana

## 3. Architecture Design

### 3.1 Overall Architecture
The system follows a microservices architecture with the following core services:
- **Course Service**: Course metadata, curriculum management
- **Video Service**: Video transcoding, streaming optimization
- **Assessment Service**: Quiz engine, grading logic
- **User Service**: Authentication, user profiles, enrollment
- **Analytics Service**: Data aggregation, reporting
- **Notification Service**: Email and push notifications

### 3.2 Component Responsibilities
Each service exposes REST APIs and publishes domain events to Kafka. Services communicate synchronously via REST for immediate data requirements and asynchronously via Kafka for event-driven workflows.

### 3.3 Data Flow
1. Student enrolls in a course → User Service records enrollment → Kafka event triggers Analytics Service
2. Student submits quiz → Assessment Service validates and stores answers → Grading job calculates score → Kafka event updates progress
3. Instructor uploads video → Video Service initiates transcoding → Completion event enables course publishing

## 4. Data Model

### 4.1 Core Entities

#### Users Table
```sql
CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### Courses Table
```sql
CREATE TABLE courses (
    course_id BIGSERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    instructor_id BIGINT NOT NULL REFERENCES users(user_id),
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### Enrollments Table
```sql
CREATE TABLE enrollments (
    enrollment_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    course_id BIGINT NOT NULL REFERENCES courses(course_id),
    enrolled_at TIMESTAMP DEFAULT NOW(),
    progress_percent INT DEFAULT 0
);
```

#### Quiz Submissions Table
```sql
CREATE TABLE quiz_submissions (
    submission_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    quiz_id BIGINT NOT NULL,
    answers JSONB NOT NULL,
    score INT,
    submitted_at TIMESTAMP DEFAULT NOW()
);
```

#### Video Metadata Table
```sql
CREATE TABLE video_metadata (
    video_id BIGSERIAL PRIMARY KEY,
    course_id BIGINT NOT NULL REFERENCES courses(course_id),
    s3_key VARCHAR(500) NOT NULL,
    duration_seconds INT NOT NULL,
    resolution VARCHAR(20),
    uploaded_at TIMESTAMP DEFAULT NOW()
);
```

#### Progress Tracking Table
```sql
CREATE TABLE video_progress (
    progress_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    video_id BIGINT NOT NULL REFERENCES video_metadata(video_id),
    watched_seconds INT DEFAULT 0,
    last_position INT DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW()
);
```

## 5. API Design

### 5.1 Course Enrollment API
```
POST /api/enrollments
Request:
{
  "userId": 12345,
  "courseId": 678
}
Response:
{
  "enrollmentId": 999,
  "status": "success"
}
```

### 5.2 Quiz Submission API
```
POST /api/quizzes/{quizId}/submit
Request:
{
  "userId": 12345,
  "answers": [
    {"questionId": 1, "selectedOption": "B"},
    {"questionId": 2, "selectedOption": "A"}
  ]
}
Response:
{
  "submissionId": 777,
  "score": 85
}
```

### 5.3 Video Progress Update API
```
PUT /api/videos/{videoId}/progress
Request:
{
  "userId": 12345,
  "watchedSeconds": 120,
  "lastPosition": 120
}
Response:
{
  "status": "updated"
}
```

### 5.4 Course Catalog Search API
```
GET /api/courses/search?q=python&category=programming
Response:
{
  "courses": [
    {
      "courseId": 678,
      "title": "Advanced Python Programming",
      "instructor": "John Doe",
      "rating": 4.8
    }
  ]
}
```

### 5.5 Analytics Dashboard API
```
GET /api/analytics/instructor/{instructorId}/courses
Response:
{
  "courses": [
    {
      "courseId": 678,
      "enrollmentCount": 5000,
      "completionRate": 65.5,
      "averageScore": 82.3
    }
  ]
}
```

### 5.6 Authentication
JWT-based authentication with 24-hour token expiration. Tokens are issued via `/api/auth/login` and validated via Spring Security filter chain.

## 6. Implementation Strategy

### 6.1 Video Delivery
Videos are stored in S3 and served via CloudFront CDN. Adaptive bitrate streaming (HLS) is used for optimized playback on various network conditions.

### 6.2 Live Session Management
WebSocket connections are established via Spring WebFlux for real-time communication during webinars. Each live session supports up to 1,000 concurrent participants.

### 6.3 Quiz Grading
Quiz submissions are processed synchronously for immediate feedback. Grading logic is implemented in the Assessment Service with support for multiple question types (multiple choice, true/false, short answer).

### 6.4 Progress Tracking
Video progress is recorded every 30 seconds via the Video Progress Update API. The client-side player sends periodic updates to maintain accurate completion tracking.

### 6.5 Error Handling
All APIs return standard HTTP status codes (200, 400, 401, 404, 500). Error responses include a descriptive message field for client-side display.

### 6.6 Logging
Structured logging is implemented using SLF4J with Logback. Log levels are configured per environment (DEBUG in dev, INFO in staging, WARN in production).

### 6.7 Testing
- Unit tests for business logic (JUnit 5 + Mockito)
- Integration tests for API endpoints (Spring Boot Test)
- Load tests for high-traffic scenarios (JMeter)

### 6.8 Deployment
Kubernetes manifests define service replicas, resource limits, and health check endpoints. Rolling updates are performed during deployments to maintain availability.

## 7. Non-Functional Requirements

### 7.1 Performance Goals
- Video playback should start within 2 seconds of user request
- API response time should not exceed 500ms for 95th percentile
- System should support 50,000 concurrent users during peak hours

### 7.2 Security Requirements
- All API endpoints require authentication except public catalog browsing
- Passwords are hashed using bcrypt with cost factor 12
- HTTPS is enforced for all client communication

### 7.3 Availability and Scalability
- Target uptime: 99.9% (excluding planned maintenance)
- Horizontal scaling is supported for all stateless services
- Database vertical scaling is planned for capacity growth
