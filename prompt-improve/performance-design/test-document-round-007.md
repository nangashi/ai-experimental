# Medical Appointment Management System - Design Document

## 1. Overview

### Project Background
The Medical Appointment Management System is a cloud-based platform designed to streamline patient appointment scheduling, doctor availability management, and medical record access for a network of 50+ clinics across the region. The system aims to reduce scheduling conflicts, minimize no-shows through automated reminders, and provide seamless integration with existing Electronic Health Record (EHR) systems.

### Key Features
- Real-time appointment booking with availability checks
- Multi-clinic and multi-specialty doctor management
- Automated SMS/email appointment reminders
- Patient medical history access for doctors
- Waitlist management for cancelled appointments
- Prescription and lab report uploads
- Appointment analytics and reporting

### Target Users
- **Patients**: Book, reschedule, or cancel appointments; view medical records
- **Clinic Staff**: Manage doctor schedules, check-in patients, handle walk-ins
- **Doctors**: View daily schedules, access patient records during consultations
- **System Administrators**: Monitor system health, generate reports

## 2. Technology Stack

### Backend
- **Language/Framework**: Java 17, Spring Boot 3.2
- **Database**: PostgreSQL 15 (primary), Redis 7 (caching)
- **Message Queue**: RabbitMQ 3.12
- **Storage**: AWS S3 (for medical documents)

### Frontend
- **Web Application**: React 18, TypeScript
- **Mobile Application**: React Native

### Infrastructure
- **Cloud Provider**: AWS
- **Deployment**: ECS Fargate (containerized)
- **Load Balancer**: Application Load Balancer
- **CDN**: CloudFront (for static assets)

### External Integrations
- **SMS Provider**: Twilio
- **Email Provider**: SendGrid
- **Payment Gateway**: Stripe

## 3. Architecture Design

### Component Structure

The system follows a microservices architecture with the following core services:

1. **Appointment Service**
   - Handles booking, cancellation, and rescheduling
   - Manages doctor availability slots
   - Validates appointment conflicts
   - Dependencies: Patient Service, Doctor Service, Notification Service

2. **Patient Service**
   - Manages patient profiles and authentication
   - Stores patient medical history metadata
   - Dependencies: Medical Record Service

3. **Doctor Service**
   - Manages doctor profiles, specialties, and clinic assignments
   - Handles schedule template management (weekly recurring slots)
   - Dependencies: None

4. **Notification Service**
   - Sends appointment reminders (SMS/Email)
   - Processes notification events from RabbitMQ
   - Dependencies: External SMS/Email providers

5. **Medical Record Service**
   - Stores references to medical documents (prescriptions, lab reports)
   - Retrieves documents from S3
   - Dependencies: AWS S3

6. **Analytics Service**
   - Generates clinic performance reports
   - Tracks no-show rates, popular time slots
   - Dependencies: All other services (read-only queries)

### Data Flow

#### Appointment Booking Flow
1. Patient selects clinic, doctor, and desired date via web/mobile app
2. Frontend queries Appointment Service API `/api/appointments/available-slots` with doctorId and date
3. Appointment Service returns available time slots
4. Patient selects slot and submits booking
5. Appointment Service validates availability and creates appointment record
6. Notification Service queues reminder notifications (1 day before, 1 hour before)

#### Medical Record Access Flow
1. Doctor selects patient from daily schedule
2. Frontend requests patient medical history via `/api/patients/{id}/records`
3. Patient Service returns patient profile and record metadata list
4. For each record, frontend fetches document URL from Medical Record Service
5. Medical Record Service generates pre-signed S3 URL (valid for 1 hour)
6. Frontend displays document links for doctor to view

## 4. Data Model

### Core Entities

#### appointments
- `id` (UUID, PK)
- `patient_id` (UUID, FK → patients.id)
- `doctor_id` (UUID, FK → doctors.id)
- `clinic_id` (UUID, FK → clinics.id)
- `appointment_date` (DATE)
- `start_time` (TIME)
- `end_time` (TIME)
- `status` (ENUM: scheduled, completed, cancelled, no_show)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

#### patients
- `id` (UUID, PK)
- `name` (VARCHAR)
- `email` (VARCHAR, UNIQUE)
- `phone` (VARCHAR)
- `date_of_birth` (DATE)
- `created_at` (TIMESTAMP)

#### doctors
- `id` (UUID, PK)
- `name` (VARCHAR)
- `specialty` (VARCHAR)
- `email` (VARCHAR)
- `phone` (VARCHAR)

#### clinics
- `id` (UUID, PK)
- `name` (VARCHAR)
- `address` (TEXT)
- `phone` (VARCHAR)

#### doctor_schedule_templates
- `id` (UUID, PK)
- `doctor_id` (UUID, FK → doctors.id)
- `clinic_id` (UUID, FK → clinics.id)
- `day_of_week` (INT, 0=Sunday...6=Saturday)
- `start_time` (TIME)
- `end_time` (TIME)
- `slot_duration_minutes` (INT, default 30)

#### medical_records
- `id` (UUID, PK)
- `patient_id` (UUID, FK → patients.id)
- `doctor_id` (UUID, FK → doctors.id)
- `record_type` (ENUM: prescription, lab_report, imaging)
- `s3_key` (VARCHAR)
- `uploaded_at` (TIMESTAMP)

## 5. API Design

### Appointment Service

#### GET /api/appointments/available-slots
**Request**:
```json
{
  "doctorId": "uuid",
  "clinicId": "uuid",
  "date": "2026-02-15"
}
```

**Response**:
```json
{
  "date": "2026-02-15",
  "slots": [
    {"startTime": "09:00", "endTime": "09:30", "available": true},
    {"startTime": "09:30", "endTime": "10:00", "available": false},
    ...
  ]
}
```

**Implementation Note**: The service queries `doctor_schedule_templates` to get the schedule pattern for the requested day of week, then queries `appointments` table to filter out booked slots.

#### POST /api/appointments
**Request**:
```json
{
  "patientId": "uuid",
  "doctorId": "uuid",
  "clinicId": "uuid",
  "appointmentDate": "2026-02-15",
  "startTime": "09:00",
  "endTime": "09:30"
}
```

**Response**:
```json
{
  "appointmentId": "uuid",
  "status": "scheduled"
}
```

#### GET /api/appointments/patient/{patientId}
Retrieves all appointments for a specific patient.

**Response**:
```json
{
  "appointments": [
    {
      "id": "uuid",
      "doctorName": "Dr. Smith",
      "clinicName": "Central Clinic",
      "appointmentDate": "2026-02-15",
      "startTime": "09:00",
      "status": "scheduled"
    },
    ...
  ]
}
```

### Patient Service

#### GET /api/patients/{id}/records
Retrieves medical record metadata for a patient.

**Response**:
```json
{
  "patientId": "uuid",
  "records": [
    {
      "id": "uuid",
      "recordType": "prescription",
      "doctorName": "Dr. Smith",
      "uploadedAt": "2026-01-10T14:30:00Z"
    },
    ...
  ]
}
```

### Authentication & Authorization
- JWT-based authentication
- Token expiration: 24 hours
- Role-based access control (patient, doctor, clinic_staff, admin)

## 6. Implementation Guidelines

### Error Handling
- All API endpoints return standardized error responses with HTTP status codes
- Service-level exceptions are logged with correlation IDs for tracing
- User-facing errors are translated to user-friendly messages

### Logging
- Structured logging using JSON format
- Log levels: ERROR (system failures), WARN (business validation failures), INFO (key operations)
- Correlation ID propagated across service calls

### Testing Strategy
- Unit tests for business logic (target: 80% coverage)
- Integration tests for API endpoints
- End-to-end tests for critical user journeys (booking, cancellation)

### Deployment Strategy
- Blue-green deployment for zero-downtime releases
- Database migrations executed via Flyway before service deployment
- Rollback plan: revert to previous ECS task definition

## 7. Non-Functional Requirements

### Security
- All API endpoints require JWT authentication
- Patient medical records accessible only to assigned doctors and patients
- Data encryption at rest (RDS encryption enabled)
- Data encryption in transit (HTTPS/TLS 1.3)

### Scalability
- System should handle up to 50 clinics, 500 doctors, 100,000 patients
- Horizontal scaling via ECS auto-scaling based on CPU utilization (target: 70%)

### Availability
- Target uptime: 99.5%
- Database replication: Multi-AZ deployment for RDS
- Service-level retry logic for transient failures
