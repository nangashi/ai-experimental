# Healthcare Appointment Management System - Design Document

## 1. Overview

### Project Purpose
This system provides an online appointment booking and management platform for healthcare clinics. It aims to reduce phone-based booking overhead and improve patient experience through real-time availability checking and automated reminders.

### Key Features
- Patient registration and profile management
- Real-time appointment booking with availability checking
- Doctor schedule management
- Automated email/SMS reminders
- Medical history tracking
- Admin dashboard for clinic staff

### Target Users
- **Patients**: Book, reschedule, and cancel appointments online
- **Doctors**: View schedule, update availability
- **Clinic Staff**: Manage doctors, patients, appointments, and generate reports

## 2. Technology Stack

### Backend
- **Language**: Java 17
- **Framework**: Spring Boot 3.2
- **ORM**: Spring Data JPA with Hibernate
- **Validation**: Hibernate Validator
- **API**: RESTful APIs with JSON

### Database
- **Primary**: MySQL 8.0
- **Caching**: Redis 7.0 (for session storage and frequently accessed data)

### Infrastructure
- **Deployment**: AWS ECS (Fargate)
- **Load Balancer**: AWS ALB
- **Storage**: AWS S3 (for document uploads)
- **Notification**: AWS SNS for SMS, SendGrid for email

### Libraries
- Lombok for boilerplate reduction
- MapStruct for DTO mapping
- JWT library for authentication
- Twilio SDK for SMS fallback

## 3. Architecture Design

### Overall Structure
The system follows a layered architecture:

```
┌─────────────────────────────┐
│   Presentation Layer        │
│   (REST Controllers)        │
└─────────────────────────────┘
           ↓
┌─────────────────────────────┐
│   Business Logic Layer      │
│   (Service Classes)         │
└─────────────────────────────┘
           ↓
┌─────────────────────────────┐
│   Data Access Layer         │
│   (Repository Interfaces)   │
└─────────────────────────────┘
           ↓
┌─────────────────────────────┐
│      Database (MySQL)       │
└─────────────────────────────┘
```

### Core Components

#### AppointmentService
Handles all appointment-related business logic including booking, cancellation, rescheduling, and conflict detection. Also responsible for sending email/SMS notifications to patients and doctors, updating patient medical history records, and generating appointment reports.

#### PatientRepository
Data access layer for patient entities using Spring Data JPA.

#### DoctorScheduleManager
Manages doctor availability, working hours, and vacation periods.

#### NotificationSender
Sends notifications via email and SMS using AWS SNS and SendGrid.

### Data Flow
1. Client sends HTTP request to REST controller
2. Controller validates input and delegates to service layer
3. Service layer executes business logic, accesses database through repositories, and calls external APIs (SendGrid, AWS SNS) directly
4. Response is formatted and returned to client

## 4. Data Model

### Main Entities

#### Patient
```sql
CREATE TABLE patients (
    patient_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    date_of_birth DATE NOT NULL,
    medical_history TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

#### Doctor
```sql
CREATE TABLE doctors (
    doctor_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    specialization VARCHAR(100) NOT NULL,
    license_number VARCHAR(50) NOT NULL UNIQUE,
    working_hours_start TIME,
    working_hours_end TIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Appointment
```sql
CREATE TABLE appointments (
    appointment_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    patient_id BIGINT NOT NULL,
    doctor_id BIGINT NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    duration_minutes INT DEFAULT 30,
    status VARCHAR(20) NOT NULL,
    reason TEXT,
    notes TEXT,
    patient_email VARCHAR(255),
    patient_phone VARCHAR(20),
    doctor_name VARCHAR(200),
    doctor_specialization VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);
```

### Relationships
- One patient can have multiple appointments
- One doctor can have multiple appointments
- Appointment references both patient and doctor

## 5. API Design

### Appointment Endpoints

#### Create Appointment
```
POST /appointments/create
Content-Type: application/json

Request Body:
{
  "patientId": 123,
  "doctorId": 45,
  "appointmentDate": "2026-02-20",
  "appointmentTime": "14:30",
  "reason": "Annual checkup"
}

Response (200):
{
  "appointmentId": 789,
  "status": "CONFIRMED",
  "message": "Appointment created successfully"
}
```

#### Cancel Appointment
```
DELETE /appointments/cancel/{appointmentId}

Response (200):
{
  "message": "Appointment cancelled"
}
```

#### Get Patient Appointments
```
GET /appointments/patient/{patientId}

Response (200):
[
  {
    "appointmentId": 789,
    "doctorName": "Dr. Smith",
    "appointmentDate": "2026-02-20",
    "appointmentTime": "14:30",
    "status": "CONFIRMED"
  }
]
```

### Patient Endpoints

#### Register Patient
```
POST /patients/register
Content-Type: application/json

Request Body:
{
  "firstName": "John",
  "lastName": "Doe",
  "email": "john.doe@example.com",
  "phone": "+1234567890",
  "dateOfBirth": "1985-05-15"
}

Response (201):
{
  "patientId": 123,
  "message": "Patient registered successfully"
}
```

### Authentication
All endpoints except registration require JWT token in the `Authorization` header:
```
Authorization: Bearer {jwt_token}
```

JWT tokens are issued upon successful login and expire after 24 hours.

## 6. Implementation Guidelines

### Error Handling
Errors are handled at the controller level with `@ControllerAdvice`. Common exceptions are mapped to appropriate HTTP status codes:
- `ResourceNotFoundException` → 404
- `ValidationException` → 400
- `UnauthorizedException` → 401
- All other exceptions → 500

Error response format:
```json
{
  "timestamp": "2026-02-11T10:30:00Z",
  "status": 500,
  "error": "Internal Server Error",
  "message": "An unexpected error occurred",
  "path": "/appointments/create"
}

```

### Logging
Use SLF4J with Logback. Log levels:
- ERROR: System failures, unexpected exceptions
- WARN: Recoverable issues, deprecated API usage
- INFO: Application startup, shutdown, significant business events
- DEBUG: Detailed execution flow (disabled in production)

### Testing
Write unit tests for all service layer methods. Integration tests for critical flows like appointment booking.

### Deployment
Application is containerized using Docker and deployed to AWS ECS. Continuous deployment is configured via GitHub Actions.

## 7. Non-Functional Requirements

### Performance
- API response time: < 500ms for 95th percentile
- Database query optimization with proper indexing
- Redis caching for frequently accessed data (doctor schedules, patient profiles)

### Security
- All passwords hashed using BCrypt
- JWT-based authentication for API access
- HTTPS for all communications
- Input validation to prevent SQL injection

### Availability
- Target uptime: 99.5%
- Database backups every 24 hours
- Multi-AZ deployment for high availability

### Scalability
- Horizontal scaling via ECS task count adjustment
- Database read replicas for read-heavy workloads
- Stateless application design for seamless scaling
