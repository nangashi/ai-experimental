# Healthcare Appointment Management System - Design Document

## 1. Overview

### Project Background
This system provides appointment scheduling and patient management capabilities for small to medium-sized healthcare clinics. The platform allows patients to book appointments online, view their medical history, and communicate with healthcare providers.

### Key Features
- Online appointment booking with real-time availability
- Patient profile and medical history management
- Provider schedule management
- Appointment reminders via email and SMS
- Basic telemedicine support for remote consultations

### Target Users
- Patients: Book appointments, view history, update profile
- Healthcare providers: Manage schedules, view patient information
- Administrative staff: Manage provider schedules, handle cancellations

## 2. Technology Stack

### Languages and Frameworks
- Backend: Java 17 with Spring Boot 3.1
- Frontend: React 18 with TypeScript
- Mobile: React Native (future phase)

### Database
- Primary: PostgreSQL 15
- Cache: Redis 7

### Infrastructure
- Container orchestration: Kubernetes
- Cloud provider: AWS (EKS, RDS, ElastiCache)
- CI/CD: GitHub Actions

### Key Libraries
- Authentication: Spring Security with JWT
- ORM: Spring Data JPA with Hibernate
- API documentation: SpringDoc OpenAPI
- HTTP client: RestTemplate
- Validation: Hibernate Validator

## 3. Architecture Design

### Overall Structure
The system follows a layered architecture pattern:
- Presentation Layer: REST API controllers
- Business Logic Layer: Service components
- Data Access Layer: Repository interfaces
- External Integration Layer: Third-party service clients

### Component Responsibilities

#### Controllers
REST endpoints that handle HTTP requests and delegate business logic to services. Controllers are responsible for request validation and response formatting.

#### Services
Business logic implementation including appointment scheduling rules, availability calculation, and notification triggers.

#### Repositories
Data access interfaces following Spring Data JPA patterns for database operations.

#### External Clients
Integration with email service (SendGrid), SMS gateway (Twilio), and payment processor (Stripe).

### Data Flow
1. Client sends request to REST endpoint
2. Controller validates request and invokes service
3. Service executes business logic and calls repository
4. Repository performs database operations
5. Response flows back through service to controller

## 4. Data Model

### Core Entities

#### Patient
- id (UUID, primary key)
- firstName (VARCHAR(100))
- lastName (VARCHAR(100))
- email (VARCHAR(255), unique)
- phoneNumber (VARCHAR(20))
- dateOfBirth (DATE)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

#### Provider
- providerId (UUID, primary key)
- first_name (VARCHAR(100))
- last_name (VARCHAR(100))
- specialization (VARCHAR(100))
- email (VARCHAR(255), unique)
- createdAt (TIMESTAMP)
- updatedAt (TIMESTAMP)

#### Appointment
- appointmentId (UUID, primary key)
- patientId (UUID, foreign key → Patient.id)
- doctor_id (UUID, foreign key → Provider.providerId)
- scheduled_time (TIMESTAMP)
- duration_minutes (INTEGER)
- status (VARCHAR(20)) - values: scheduled, cancelled, completed
- appointment_type (VARCHAR(50)) - values: in_person, telemedicine
- notes (TEXT)
- created_timestamp (TIMESTAMP)
- last_modified (TIMESTAMP)

#### AvailabilitySlot
- slot_id (UUID, primary key)
- provider_ref (UUID, foreign key → Provider.providerId)
- start_datetime (TIMESTAMP)
- end_datetime (TIMESTAMP)
- is_available (BOOLEAN)

## 5. API Design

### Endpoint Structure

#### Patient Management
```
GET /patients/{id}
POST /patients
PUT /patients/{id}
DELETE /patients/{id}
```

#### Appointment Management
```
GET /api/appointments/{id}
POST /api/appointments/create
PUT /api/appointments/{id}/update
POST /api/appointments/{id}/cancel
GET /api/appointments/list
```

#### Provider Schedule
```
GET /providers/{id}/availability
POST /providers/{id}/availability
PUT /providers/{id}/availability/{slotId}
```

### Request/Response Format

#### Create Appointment Request
```json
{
  "patientId": "uuid-string",
  "providerId": "uuid-string",
  "scheduledTime": "2026-02-15T10:00:00Z",
  "durationMinutes": 30,
  "type": "in_person"
}
```

#### Create Appointment Response (Success)
```json
{
  "success": true,
  "data": {
    "appointmentId": "uuid-string",
    "status": "scheduled",
    "scheduledTime": "2026-02-15T10:00:00Z"
  }
}
```

#### Create Appointment Response (Error)
```json
{
  "success": false,
  "error": {
    "code": "SLOT_UNAVAILABLE",
    "message": "The selected time slot is no longer available"
  }
}
```

### Authentication and Authorization
JWT tokens will be issued upon successful login and must be included in the Authorization header for all protected endpoints. Token expiration is set to 24 hours.

## 6. Implementation Guidelines

### Error Handling Strategy
All service layer methods throw custom exceptions (AppointmentNotFoundException, InvalidSlotException, etc.) which are handled at the controller level. Each controller method includes try-catch blocks to transform exceptions into appropriate HTTP responses.

### Logging Approach
The system uses SLF4J with Logback. Log messages follow this format:
```
[timestamp] [level] [class] - message (key1=value1, key2=value2)
```

Key events to log:
- Appointment creation/cancellation (INFO level)
- Authentication failures (WARN level)
- External service errors (ERROR level)

### Testing Strategy
- Unit tests: JUnit 5 for service layer logic
- Integration tests: Spring Boot Test with TestContainers for repository layer
- API tests: MockMvc for controller layer

### Deployment Approach
Blue-green deployment strategy with automated rollback capability. Database migrations are managed via Flyway and executed before application startup.

## 7. Non-Functional Requirements

### Performance Targets
- API response time: 95th percentile < 200ms for read operations
- Appointment booking: < 500ms end-to-end
- Support 100 concurrent users per instance

### Security Requirements
- All data in transit encrypted via TLS 1.3
- Passwords hashed using bcrypt with strength 12
- JWT tokens stored in httpOnly cookies
- CSRF protection enabled for all state-changing operations
- Rate limiting: 100 requests per minute per user

### Availability and Scalability
- Target uptime: 99.5%
- Horizontal scaling via Kubernetes HPA based on CPU utilization
- Database read replicas for query load distribution
- Redis cache for frequently accessed data (provider schedules, availability slots)