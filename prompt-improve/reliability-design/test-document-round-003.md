# MediConnect Appointment Scheduling System - System Design Document

## 1. Overview

### Purpose
MediConnect is a cloud-based appointment scheduling platform connecting patients with healthcare providers across multiple clinics. The system supports real-time appointment booking, waitlist management, automated reminders, and integration with existing Electronic Health Record (EHR) systems.

### Key Features
- Multi-tenant appointment scheduling with provider availability management
- Patient self-service booking with insurance verification
- Automated SMS/email reminder system
- Waitlist management with automatic rebooking
- EHR synchronization for appointment status
- Provider dashboard for schedule management

### Target Users
- Patients: Book and manage appointments online
- Healthcare providers: Manage availability and view schedules
- Clinic administrators: Configure rules and monitor operations

## 2. Technology Stack

### Backend
- Language: Java 17
- Framework: Spring Boot 3.2, Spring Data JPA
- Message Queue: RabbitMQ 3.12
- Scheduler: Quartz Scheduler 2.3

### Database
- Primary: PostgreSQL 15 (appointment data, patient records)
- Cache: Redis 7.0 (session management, rate limiting counters)

### Infrastructure
- Cloud Platform: AWS (ECS Fargate for compute)
- Load Balancer: AWS ALB
- Storage: S3 (appointment confirmations, reports)
- External Services: Twilio (SMS), SendGrid (email), EHR vendor APIs (HL7 FHIR)

### Deployment
- Containerization: Docker
- Orchestration: AWS ECS with Fargate
- CI/CD: GitHub Actions
- Infrastructure as Code: Terraform

## 3. Architecture Design

### Overall Structure
The system follows a layered monolithic architecture with clear separation between web layer, service layer, and data access layer. External service integrations are abstracted behind facade interfaces.

```
┌─────────────┐     ┌─────────────┐
│   Patients  │     │  Providers  │
└──────┬──────┘     └──────┬──────┘
       │                   │
       └───────┬───────────┘
               │
        ┌──────▼──────┐
        │   AWS ALB   │
        └──────┬──────┘
               │
        ┌──────▼──────────────────┐
        │  ECS Tasks (3 instances)│
        │  - Web Layer            │
        │  - Service Layer        │
        │  - Data Access Layer    │
        └──┬─────────┬────────────┘
           │         │
    ┌──────▼──┐   ┌─▼─────────┐
    │PostgreSQL│   │  Redis    │
    └──────────┘   └───────────┘
           │
    ┌──────▼────────┐
    │   RabbitMQ    │
    └──┬────────┬───┘
       │        │
 ┌─────▼───┐ ┌─▼────────┐
 │  Twilio │ │SendGrid  │
 └─────────┘ └──────────┘
```

### Key Components

#### Appointment Service
Manages appointment lifecycle (creation, modification, cancellation). Coordinates with Availability Service to enforce booking rules.

#### Availability Service
Manages provider schedules, break times, and holiday calendars. Performs conflict detection for booking attempts.

#### Reminder Service
Asynchronous worker that polls the database every 5 minutes for upcoming appointments and enqueues reminder messages to RabbitMQ.

#### Notification Service
Consumes messages from RabbitMQ and dispatches SMS/email via Twilio and SendGrid. Retries on failures.

#### EHR Integration Service
Synchronizes appointment data with external EHR systems using HL7 FHIR APIs. Operates on a nightly batch schedule.

## 4. Data Model

### Core Entities

#### Appointment
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| appointment_id | UUID | PK | Unique identifier |
| patient_id | UUID | FK, NOT NULL | Reference to patient |
| provider_id | UUID | FK, NOT NULL | Reference to provider |
| clinic_id | UUID | FK, NOT NULL | Clinic location |
| appointment_time | TIMESTAMP | NOT NULL | Scheduled time |
| duration_minutes | INTEGER | NOT NULL | Appointment duration |
| status | VARCHAR(20) | NOT NULL | SCHEDULED, COMPLETED, CANCELLED, NO_SHOW |
| created_at | TIMESTAMP | NOT NULL | Creation timestamp |
| updated_at | TIMESTAMP | NOT NULL | Last update timestamp |
| version | INTEGER | NOT NULL | Optimistic locking version |

#### Provider
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| provider_id | UUID | PK | Unique identifier |
| clinic_id | UUID | FK, NOT NULL | Clinic affiliation |
| name | VARCHAR(100) | NOT NULL | Provider name |
| specialty | VARCHAR(50) | NOT NULL | Medical specialty |
| max_daily_appointments | INTEGER | NOT NULL | Capacity limit |

#### Availability
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| availability_id | UUID | PK | Unique identifier |
| provider_id | UUID | FK, NOT NULL | Provider reference |
| day_of_week | INTEGER | NOT NULL | 1=Monday, 7=Sunday |
| start_time | TIME | NOT NULL | Availability start |
| end_time | TIME | NOT NULL | Availability end |

## 5. API Design

### REST Endpoints

#### POST /api/v1/appointments
Creates a new appointment. Validates provider availability and patient conflicts.

**Request Body:**
```json
{
  "patientId": "uuid",
  "providerId": "uuid",
  "appointmentTime": "2025-03-15T10:00:00Z",
  "durationMinutes": 30
}
```

**Response (201 Created):**
```json
{
  "appointmentId": "uuid",
  "confirmationCode": "ABC123",
  "status": "SCHEDULED"
}
```

#### DELETE /api/v1/appointments/{appointmentId}
Cancels an appointment. Triggers waitlist rebooking logic.

**Response (204 No Content)**

#### GET /api/v1/providers/{providerId}/availability
Returns available time slots for a provider.

**Query Parameters:**
- `date`: ISO 8601 date
- `durationMinutes`: Desired appointment duration

**Response (200 OK):**
```json
{
  "availableSlots": [
    {"startTime": "2025-03-15T09:00:00Z", "endTime": "2025-03-15T09:30:00Z"},
    {"startTime": "2025-03-15T10:00:00Z", "endTime": "2025-03-15T10:30:00Z"}
  ]
}
```

### Authentication
JWT-based authentication with tokens valid for 24 hours. Tokens are issued by a separate OAuth2 service and validated via shared secret. Patient and provider tokens have different scopes encoded in the JWT claims.

## 6. Implementation Strategy

### Error Handling
Unhandled exceptions are caught by a global exception handler that returns standardized error responses with HTTP status codes. Application-specific exceptions extend from a base `AppException` class.

### Logging
Structured logging using SLF4J with Logback. Log entries include request correlation IDs for tracing.

### Testing
- Unit tests: JUnit 5 with Mockito
- Integration tests: Testcontainers for PostgreSQL and RabbitMQ
- Load testing: JMeter scripts for appointment booking endpoints

### Deployment
Blue-green deployment on AWS ECS. Database migrations are executed manually before deployment using Flyway.

## 7. Non-Functional Requirements

### Performance
- API response time: p95 < 500ms for appointment booking
- Reminder delivery: All reminders sent within 30 minutes of scheduled trigger time

### Security
- TLS 1.3 for all external communications
- Patient data encrypted at rest (AWS KMS)
- API rate limiting: 100 requests/minute per user

### Availability
- Target uptime: 99.9% (excluding planned maintenance)
- ECS tasks run across 2 Availability Zones
- PostgreSQL uses AWS RDS with automated backups
- Redis runs in single-instance mode for session storage

### Scalability
- Horizontal scaling: ECS task count adjusts based on CPU utilization (target 70%)
- Database connection pooling: HikariCP with max 20 connections per instance
- RabbitMQ queue depth monitoring: Alert when queue size exceeds 10,000 messages

### Monitoring
Application metrics (request rate, error rate, latency) are collected via Micrometer and exported to CloudWatch. Custom business metrics include daily appointment creation count and cancellation rate.

### Disaster Recovery
PostgreSQL automated backups retained for 7 days. Point-in-time recovery supported within backup retention window.
