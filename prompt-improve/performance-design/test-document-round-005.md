# Medical Appointment Platform System Design

## 1. Overview

### Purpose
Build a medical appointment booking platform connecting patients with healthcare providers. The system enables online appointment scheduling, patient records management, and telemedicine consultations.

### Key Features
- Real-time appointment availability search
- Patient registration and medical history management
- Doctor schedule management
- Video consultation integration
- Prescription and lab report management
- Email/SMS notification system

### Target Users
- Patients seeking medical appointments
- Healthcare providers (doctors, clinics, hospitals)
- Administrative staff for schedule management
- Expected scale: 500K patients, 10K providers, 50K appointments/day

## 2. Technology Stack

### Backend
- Language: Java 17
- Framework: Spring Boot 3.1
- API: RESTful API (Spring MVC)
- Real-time: WebSocket (Spring WebSocket)

### Database
- Primary DB: PostgreSQL 15
- Session storage: Redis 7

### Infrastructure
- Cloud: AWS (EC2, RDS, S3, CloudFront)
- Container: Docker + Kubernetes
- API Gateway: Kong
- CDN: CloudFront for static assets

### Key Libraries
- Video SDK: Twilio Video API
- Email: AWS SES
- SMS: Twilio SMS API
- PDF generation: iText 7

## 3. Architecture Design

### Overall Structure
3-tier architecture with presentation, business logic, and data layers:

```
[Client] → [API Gateway] → [Application Servers] → [Database Layer]
                              ↓
                         [External Services]
                         (Video, Email, SMS)
```

### Core Components

**Appointment Service**
- Appointment creation, modification, cancellation
- Availability search and slot management
- Handles patient-doctor matching logic

**User Management Service**
- Patient registration and authentication
- Doctor profile management
- Role-based access control

**Medical Records Service**
- Patient medical history storage
- Prescription management
- Lab report upload and retrieval

**Notification Service**
- Appointment reminders (email/SMS)
- Status change notifications
- System alerts

**Video Consultation Service**
- Integration with Twilio Video API
- Session management
- Recording storage (optional)

### Data Flow

1. Patient searches for available appointments
2. System queries doctor schedules from database
3. Patient selects a time slot and confirms booking
4. System creates appointment record
5. Notification service sends confirmation to both parties
6. At appointment time, video consultation session is initiated

## 4. Data Model

### Key Entities

**User**
- id (UUID, primary key)
- email (varchar, unique)
- password_hash (varchar)
- role (enum: PATIENT, DOCTOR, ADMIN)
- created_at, updated_at (timestamp)

**Patient**
- id (UUID, primary key)
- user_id (UUID, foreign key)
- full_name (varchar)
- date_of_birth (date)
- phone_number (varchar)
- address (text)
- medical_history (jsonb)

**Doctor**
- id (UUID, primary key)
- user_id (UUID, foreign key)
- full_name (varchar)
- specialization (varchar)
- license_number (varchar)
- consultation_fee (decimal)
- clinic_id (UUID, foreign key)

**Appointment**
- id (UUID, primary key)
- patient_id (UUID, foreign key)
- doctor_id (UUID, foreign key)
- appointment_date (date)
- appointment_time (time)
- duration_minutes (integer, default: 30)
- status (enum: SCHEDULED, COMPLETED, CANCELLED)
- notes (text)
- created_at, updated_at (timestamp)

**MedicalRecord**
- id (UUID, primary key)
- patient_id (UUID, foreign key)
- appointment_id (UUID, foreign key)
- diagnosis (text)
- prescription (text)
- lab_report_url (varchar)
- created_at (timestamp)

**DoctorSchedule**
- id (UUID, primary key)
- doctor_id (UUID, foreign key)
- day_of_week (integer, 0-6)
- start_time (time)
- end_time (time)
- is_available (boolean)

## 5. API Design

### Appointment Endpoints

**GET /api/appointments/search**
- Query params: specialization, date, location
- Response: List of available time slots with doctor information
- Returns all matching appointments in a single response

**POST /api/appointments**
- Request: { patient_id, doctor_id, appointment_date, appointment_time }
- Response: Created appointment details
- Creates appointment record and triggers notification

**GET /api/appointments/{appointment_id}**
- Response: Appointment details with patient and doctor info

**PUT /api/appointments/{appointment_id}**
- Request: { status, notes }
- Updates appointment status

**GET /api/patients/{patient_id}/appointments**
- Response: All appointments for a patient
- Returns complete history without pagination

**GET /api/doctors/{doctor_id}/appointments**
- Query params: date (optional)
- Response: Doctor's appointment schedule

### Medical Records Endpoints

**POST /api/medical-records**
- Request: { patient_id, appointment_id, diagnosis, prescription }
- Response: Created medical record

**GET /api/patients/{patient_id}/medical-records**
- Response: All medical records for a patient
- Returns complete medical history

**GET /api/medical-records/{record_id}/report**
- Response: Lab report file (PDF/image)
- Streams file from S3

### Authentication
- JWT-based authentication
- Token expiry: 24 hours
- Refresh token mechanism not implemented

## 6. Implementation Guidelines

### Error Handling
- Use Spring's @ExceptionHandler for global error handling
- Return standardized error responses with status code and message
- Log all errors with stack traces

### Logging
- Use SLF4J + Logback
- Log levels: INFO for business events, ERROR for exceptions
- Log format: timestamp, level, thread, class, message

### Testing
- Unit tests for service layer (JUnit 5 + Mockito)
- Integration tests for API endpoints (Spring Test)
- Manual testing for video consultation features

### Deployment
- Docker containers deployed on Kubernetes
- Single pod deployment initially
- Blue-green deployment for zero downtime

## 7. Non-Functional Requirements

### Security
- HTTPS for all communications
- Password hashing with BCrypt
- HIPAA compliance for medical data
- Encryption at rest for sensitive data (RDS encryption)

### Availability
- Target uptime: 99.5%
- Database backup: Daily snapshots
- Single region deployment (us-east-1)

### Data Retention
- Appointment records: Retain indefinitely
- Medical records: Retain for 7 years (compliance requirement)
- User activity logs: Retain for 90 days
