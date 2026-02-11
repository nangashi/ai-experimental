# Consistency Design Review - E-Learning Platform

## Review Metadata
- **Review Date**: 2026-02-11
- **Reviewer**: consistency-design-reviewer
- **Document**: E-Learning Platform システム設計書
- **Prompt Version**: v004-baseline

---

## Pass 1 - Structural Understanding Summary

The design document presents a comprehensive e-learning platform for corporate and individual training. It covers 7 main sections: overview, technology stack, architecture, data models, API design, implementation guidelines, and non-functional requirements.

**Document Structure Observed**:
- Well-organized with clear section hierarchy
- Includes technical specifications for backend (NestJS), frontend (Next.js), and infrastructure (AWS)
- Data models with 4 main tables defined
- API endpoints with request/response formats
- Implementation policies for logging and testing
- Security and performance requirements

**Missing Information Noted**:
- No explicit documentation of naming convention standards
- No directory/file structure layout
- Implementation pattern decisions not fully documented
- Authentication/authorization implementation approach unclear
- Error handling patterns not specified

---

## Pass 2 - Detailed Consistency Analysis

### Inconsistencies Identified

#### CRITICAL: Severe Naming Convention Inconsistencies (Severity: Critical)

**Issue C1: Mixed Case Styles in Data Model**

The data model exhibits severe inconsistency in column naming conventions across tables:

- **User table**: Mixed styles - `userId`, `email`, `passwordHash`, `displayName` (camelCase) BUT `created_at` (snake_case)
- **Course table**: Predominantly snake_case - `course_id`, `instructor_id`, `created_at` BUT `status` (no prefix)
- **Enrollment table**: Consistent snake_case - `enrollment_id`, `user_id`, `course_id`, `enrolled_at`, `completion_status`
- **Video table**: Pure camelCase - `videoId`, `courseId`, `s3Key`, `durationSeconds`, `uploadedAt`

**Impact**:
- Database schema will have mixed conventions, making queries inconsistent
- ORM mapping (Prisma) will require constant case conversion
- High risk of developer confusion and runtime errors
- Code reviews will be difficult without a clear standard

**Pattern Evidence Absence**: The design document provides no rationale for these case choices and no existing codebase patterns to reference.

---

**Issue C2: Inconsistent Primary Key Naming**

Primary keys use three different patterns:
- `userId` (camelCase, User table)
- `course_id` (snake_case, Course table)
- `enrollment_id` (snake_case, Enrollment table)
- `videoId` (camelCase, Video table)

**Impact**:
- JOIN operations in queries will mix conventions
- Foreign key relationships become visually confusing (`user_id` references `userId`)
- Automated migration tools may fail
- API serialization requires custom field mapping

---

**Issue C3: Timestamp Column Naming Inconsistency**

Timestamp columns use three different patterns:
- `created_at` (snake_case with underscore, User/Course tables)
- `enrolled_at` (snake_case with underscore, Enrollment table)
- `uploadedAt` (camelCase, Video table)

**Impact**:
- Timestamp queries require remembering different conventions per table
- Audit trail implementations will be inconsistent
- Common utility functions for created/updated timestamps cannot be standardized

---

#### CRITICAL: Architecture Pattern Inconsistencies (Severity: Critical)

**Issue A1: Undefined Repository Layer Implementation**

The document claims a 3-layer architecture with a "Repository層（データアクセス）" but:

1. **No Repository implementation details provided**:
   - Will repositories wrap Prisma Client directly?
   - Will each entity have its own repository?
   - What interface patterns will repositories expose?

2. **Potential ORM Anti-pattern**:
   - Document specifies "Prisma" as the ORM
   - Common anti-pattern: Services call Prisma directly, bypassing Repository layer
   - No guidance on preventing this architectural drift

**Impact**:
- Risk of inconsistent data access patterns across modules
- Service layer may directly couple to Prisma, breaking architectural boundaries
- Difficult to mock data layer for testing
- Future ORM migrations would require rewriting all service logic

**Pattern Evidence Absence**: No reference to existing repository patterns or interfaces in the codebase.

---

**Issue A2: Unclear Dependency Direction in Service Layer**

Services list responsibilities but lack dependency architecture:

```
CourseService: コースのCRUD、公開制御
EnrollmentService: 受講登録、受講者管理
CertificateService: 証明書発行
```

**Missing Critical Information**:
- Can `CertificateService` call `EnrollmentService`? (cross-service dependencies)
- Do services share repositories or have dedicated repositories?
- How are service-to-service communications handled?

**Impact**:
- Risk of circular dependencies between services
- Unclear transaction boundaries across services
- Potential for inconsistent service interaction patterns

---

#### SIGNIFICANT: Implementation Pattern Gaps (Severity: Significant)

**Issue I1: Authentication Implementation Pattern Not Specified**

The document states:
- "Passport.js" is listed as authentication library
- "RoleGuard: ロールベースのアクセス制御" is mentioned

**Missing Critical Details**:
- Where is authentication enforced? (Guard/Middleware/Decorator)
- Is it applied globally or per-controller?
- How are public endpoints excluded?
- What is the middleware execution order?

**Impact Without Existing Pattern Reference**:
- Each developer may implement auth checks differently
- Risk of missing authentication on sensitive endpoints
- Inconsistent error responses for auth failures
- Difficult to audit security coverage

---

**Issue I2: Error Handling Pattern Undefined**

The API response format shows error structure:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input"
  }
}
```

**Missing Information**:
- Where are these responses generated? (Global exception filter vs individual try-catch)
- How are different error types mapped to error codes?
- Are validation errors handled separately from system errors?
- What HTTP status codes correspond to each error code?

**Impact**:
- Controllers may implement inconsistent error handling
- Risk of exposing internal error details in production
- Difficult to maintain consistent error messages
- Client applications cannot rely on error format consistency

---

**Issue I3: Transaction Management Pattern Not Documented**

Data models show foreign key relationships requiring transactional operations:
- Creating a course enrollment may require multiple table updates
- Certificate issuance likely requires atomic enrollment status update

**Missing Information**:
- Are transactions managed at Repository layer or Service layer?
- Does Prisma transaction API (`$transaction`) get wrapped?
- How are nested service calls handled within transactions?
- What is the transaction isolation level?

**Impact**:
- Risk of data inconsistency from partial updates
- Different developers may implement transactions differently
- Difficult to debug transaction-related issues
- Performance issues if transaction scope is unclear

---

**Issue I4: Asynchronous Processing Pattern Unclear**

Architecture mentions:
- "非同期処理: SQS → Lambda (動画エンコーディング)"

**Missing Information**:
- How does NestJS backend publish messages to SQS?
- Are message publishing operations abstracted?
- How are async job failures handled?
- Is there a queue abstraction or direct AWS SDK usage?

**Impact**:
- Future async operations may use different patterns
- Difficult to switch queue providers
- Inconsistent error handling for async failures
- Testing async workflows becomes fragmented

---

#### MODERATE: API Design Inconsistencies (Severity: Moderate)

**Issue API1: Inconsistent Endpoint Naming Patterns**

API endpoints show mixed patterns:

**RESTful Pattern**:
- `GET /api/v1/courses` - standard resource collection
- `GET /api/v1/courses/:id` - standard resource detail
- `POST/PUT/DELETE /api/v1/courses/:id` - standard CRUD

**Action-Based Pattern**:
- `POST /api/v1/courses/:id/enroll` - action as path segment
- `POST /api/v1/videos/:id/progress` - action as path segment

**Inconsistency**:
- Why is enrollment not `POST /api/v1/enrollments` (resource-based)?
- Why is progress not `PUT /api/v1/video-progress/:videoId` (resource update)?

**Impact**:
- Mixed mental models for API design
- Future endpoints may follow either pattern arbitrarily
- REST clients may struggle with action-based endpoints
- API documentation becomes harder to organize

**Pattern Evidence Absence**: No explanation of when to use resource-based vs action-based endpoints.

---

**Issue API2: Response Format Timestamp Inconsistency**

API response format includes:
```json
{
  "timestamp": "2026-02-11T10:30:00Z"
}
```

**Inconsistency with Data Models**:
- Data model uses `created_at`/`enrolled_at`/`uploadedAt` (mixed conventions)
- API response uses ISO 8601 format in camelCase (`timestamp`)
- No specification for how database timestamps are serialized in API responses

**Impact**:
- Will `created_at` become `createdAt` or `created_at` in API responses?
- Clients must handle multiple timestamp formats
- Serialization logic must be customized per response

---

#### MODERATE: Missing Pattern Documentation (Severity: Moderate)

**Issue M1: Directory Structure Not Specified**

The document provides no guidance on file organization:

**Questions Without Answers**:
- Is it domain-based (`/course`, `/user`, `/video`) or layer-based (`/controllers`, `/services`, `/repositories`)?
- Where do shared utilities live?
- How are DTOs organized?
- Where are configuration files placed?

**Impact Without Existing Pattern**:
- Each module may adopt different organization
- Difficult to locate related files
- Inconsistent import paths
- Hard to enforce architectural boundaries with directory structure

---

**Issue M2: Environment Variable Naming Convention Missing**

Non-functional requirements mention:
- Database connection (PostgreSQL)
- Redis cache configuration
- AWS service credentials
- JWT secret for authentication

**Missing Information**:
- Are environment variables UPPER_SNAKE_CASE or camelCase?
- Is there a prefix convention (e.g., `DB_*`, `AWS_*`, `REDIS_*`)?
- How are secrets managed in different environments?

**Impact**:
- `.env` files may become disorganized
- Risk of naming collisions
- Difficult to validate required environment variables at startup
- Documentation of environment setup becomes fragmented

---

**Issue M3: Configuration File Format Consistency**

Technology stack mentions various configuration needs:
- Docker configuration
- GitHub Actions CI/CD
- AWS infrastructure (likely CloudFormation/Terraform)

**Missing Information**:
- Is infrastructure configuration in YAML or JSON?
- Are application configs in `.json`, `.yaml`, or `.env`?
- How are environment-specific configs managed?

**Impact**:
- Developers must learn multiple config formats
- Config validation tools differ by format
- Difficult to establish unified config management practices

---

### Pattern Evidence

**Evidence Collection Attempted**:

Searched the repository for existing codebase patterns:
- No TypeScript/JavaScript source files found
- No `package.json` found to verify library versions
- No existing API implementations to reference
- No database schema files to verify naming conventions

**Conclusion**: This appears to be a **greenfield project** with no existing codebase. All consistency issues identified represent **lack of explicit standards documentation** rather than divergence from existing patterns.

---

### Impact Analysis

#### Development Velocity Impact

**High Impact**:
- **Onboarding friction**: New developers lack clear conventions, leading to inconsistent implementations
- **Code review overhead**: Without standards, every review becomes a negotiation of style choices
- **Refactoring risk**: Inconsistent patterns increase difficulty of future refactoring

**Time Cost Estimate**:
- Mixed naming conventions could add 15-20% overhead to development time
- Missing architectural patterns may require mid-project architecture rework (high cost)

---

#### Maintenance Impact

**High Impact**:
- **Bug investigation**: Inconsistent patterns make it harder to predict code behavior
- **Feature additions**: Each new feature requires deciding conventions anew
- **Library upgrades**: Without abstraction patterns, library updates affect many files

---

#### Team Collaboration Impact

**Critical Impact**:
- **Merge conflicts**: Different developers may format similar code differently
- **Knowledge silos**: Without shared patterns, expertise becomes fragmented
- **Technical debt accumulation**: Inconsistencies compound over time without standards

---

### Recommendations

#### Priority 1: Establish Naming Convention Standards (Critical)

**Recommendation R1: Define and Document Database Naming Convention**

**Proposed Standard** (choose ONE consistently):

**Option A: Pure snake_case** (recommended for PostgreSQL projects):
```sql
-- User table
user_id UUID PRIMARY KEY
email VARCHAR(255)
password_hash VARCHAR(255)
display_name VARCHAR(100)
created_at TIMESTAMP

-- Course table
course_id UUID PRIMARY KEY
instructor_id UUID REFERENCES users(user_id)
created_at TIMESTAMP

-- Video table
video_id UUID PRIMARY KEY
course_id UUID REFERENCES courses(course_id)
s3_key VARCHAR(500)
duration_seconds INTEGER
uploaded_at TIMESTAMP
```

**Rationale**:
- PostgreSQL convention favors snake_case
- All identifiers remain lowercase (no quoting needed)
- Consistent with timestamp conventions already used
- Aligns with common ORMs' default mapping

**Option B: Pure camelCase** (if matching TypeScript convention):
```sql
-- Requires quoted identifiers in PostgreSQL
userId UUID PRIMARY KEY
email VARCHAR(255)
passwordHash VARCHAR(255)
displayName VARCHAR(100)
createdAt TIMESTAMP
```

**Rationale**:
- Matches TypeScript naming
- No case conversion needed in ORM
- Requires quoted identifiers in SQL (e.g., `SELECT "userId" FROM "User"`)

**Action Items**:
1. Add "Naming Conventions" section to design document
2. Specify primary key naming rule (e.g., `{table_name}_id` or `id`)
3. Specify timestamp column standard (`created_at`/`updated_at` vs `createdAt`/`updatedAt`)
4. Update all data model tables to follow chosen convention
5. Create Prisma schema validation script to enforce convention

---

**Recommendation R2: Define API Naming and Response Conventions**

**Proposed Standards**:

1. **Endpoint Pattern Rule**:
   - Use resource-based endpoints for CRUD: `POST /api/v1/enrollments` (not `POST /courses/:id/enroll`)
   - Use action-based endpoints only for non-resource operations: `POST /api/v1/auth/login`

2. **Response Field Naming**:
   - Use camelCase for all JSON response fields (JavaScript/TypeScript convention)
   - Ensure database field mapping is handled by ORM serialization

3. **Timestamp Serialization**:
   - Always serialize timestamps as ISO 8601 with UTC timezone
   - Use consistent field names: `createdAt`, `updatedAt`, `timestamp`

**Action Items**:
1. Add "API Design Standards" section to design document
2. Update endpoint list to follow resource-based pattern consistently
3. Specify ORM serialization configuration (Prisma `@map` for field name mapping)
4. Document timestamp serialization in API response format section

---

#### Priority 2: Document Architecture Implementation Patterns (Critical)

**Recommendation A1: Define Repository Layer Pattern**

**Proposed Pattern**:

```typescript
// Repository interface example
export interface ICourseRepository {
  findById(id: string): Promise<Course | null>;
  findAll(filter: CourseFilter): Promise<Course[]>;
  create(data: CreateCourseData): Promise<Course>;
  update(id: string, data: UpdateCourseData): Promise<Course>;
  delete(id: string): Promise<void>;
}

// Implementation wrapping Prisma
export class CourseRepository implements ICourseRepository {
  constructor(private prisma: PrismaClient) {}

  async findById(id: string): Promise<Course | null> {
    return this.prisma.course.findUnique({ where: { id } });
  }
  // ... other methods
}
```

**Rationale**:
- Abstracts Prisma behind interface (testable, swappable)
- Clear boundary between Service and Data layers
- Enforces single data access pattern

**Action Items**:
1. Add "Repository Pattern Implementation" section to design document
2. Specify one repository per aggregate root (Course, User, Enrollment, Video)
3. Document that Services MUST use Repositories, never Prisma directly
4. Create code scaffolding template for new repositories

---

**Recommendation A2: Define Service Dependency Rules**

**Proposed Rules**:

1. **Horizontal Dependencies**: Services at the same layer can call each other via dependency injection
2. **Vertical Dependencies**: Services call Repositories only, never database directly
3. **Circular Dependency Prevention**: Use events or mediator pattern for bidirectional communication
4. **Transaction Boundaries**: Transactions managed at Service layer using Repository methods

**Dependency Graph Example**:
```
CertificateService → EnrollmentService → EnrollmentRepository
                                      → CourseRepository (via CourseService)
```

**Action Items**:
1. Add "Service Layer Architecture" section with dependency diagram
2. Document allowed dependency patterns
3. Specify transaction management approach (next recommendation)

---

#### Priority 3: Specify Implementation Patterns (Significant)

**Recommendation I1: Document Authentication Implementation Pattern**

**Proposed Pattern**:

```typescript
// Global authentication guard (NestJS pattern)
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  // Applied globally in main.ts or per-controller
}

// Role-based guard (composed with auth guard)
@Injectable()
export class RolesGuard implements CanActivate {
  // Checks user.role after authentication
}

// Controller usage
@Controller('courses')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('instructor', 'admin')
export class CourseController {
  // Authentication + authorization applied
}

// Public endpoint override
@Public() // Custom decorator to skip auth
@Get('public-courses')
getPublicCourses() {
  // ...
}
```

**Action Items**:
1. Add "Authentication & Authorization Implementation" section to design document
2. Specify Passport.js strategy configuration (JWT strategy)
3. Document guard application pattern (global vs per-controller)
4. Define `@Public()` decorator for public endpoints
5. Specify guard execution order

---

**Recommendation I2: Document Error Handling Pattern**

**Proposed Pattern**:

```typescript
// Global exception filter (NestJS pattern)
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    // Transform all errors to standard format
    const response = {
      success: false,
      error: {
        code: this.mapErrorCode(exception),
        message: this.mapErrorMessage(exception)
      },
      timestamp: new Date().toISOString()
    };
    // Set appropriate HTTP status code
  }
}

// Service layer - throw domain exceptions
throw new CourseNotFoundException(courseId);
// Filter catches and converts to API response
```

**Action Items**:
1. Add "Error Handling Pattern" section to design document
2. Define custom exception classes (e.g., `NotFoundException`, `ValidationException`)
3. Specify error code mapping table (exception type → error code)
4. Document HTTP status code mapping
5. Specify production error message sanitization rules

---

**Recommendation I3: Document Transaction Management Pattern**

**Proposed Pattern**:

```typescript
// Service layer manages transactions
export class EnrollmentService {
  constructor(
    private enrollmentRepo: EnrollmentRepository,
    private courseRepo: CourseRepository,
    private prisma: PrismaClient
  ) {}

  async enrollUser(userId: string, courseId: string): Promise<Enrollment> {
    return this.prisma.$transaction(async (tx) => {
      // All operations within transaction
      const course = await this.courseRepo.findById(courseId, tx);
      if (!course) throw new CourseNotFoundException();

      const enrollment = await this.enrollmentRepo.create({
        userId,
        courseId,
        enrolledAt: new Date()
      }, tx);

      // Other operations...
      return enrollment;
    });
  }
}
```

**Action Items**:
1. Add "Transaction Management Pattern" section to design document
2. Specify transaction API usage (Prisma `$transaction`)
3. Document transaction scope rules (Service layer only)
4. Specify isolation level for different operation types
5. Define retry policy for transaction conflicts

---

**Recommendation I4: Document Asynchronous Processing Pattern**

**Proposed Pattern**:

```typescript
// Queue abstraction
export interface IMessageQueue {
  publish(topic: string, message: any): Promise<void>;
  subscribe(topic: string, handler: MessageHandler): void;
}

// SQS implementation
export class SQSMessageQueue implements IMessageQueue {
  // Wraps AWS SDK
}

// Service layer usage
export class VideoService {
  constructor(private queue: IMessageQueue) {}

  async uploadVideo(file: Buffer): Promise<Video> {
    // Save to S3
    const video = await this.saveVideo(file);

    // Queue async encoding job
    await this.queue.publish('video.encoding.requested', {
      videoId: video.id,
      s3Key: video.s3Key
    });

    return video;
  }
}
```

**Action Items**:
1. Add "Asynchronous Processing Pattern" section to design document
2. Define queue abstraction interface
3. Specify message format and topics/queue naming convention
4. Document error handling and retry strategy for async jobs
5. Specify monitoring and dead-letter queue configuration

---

#### Priority 4: Document File Organization and Configuration (Moderate)

**Recommendation M1: Define Directory Structure Convention**

**Proposed Structure** (domain-based with layer separation):

```
src/
├── modules/
│   ├── course/
│   │   ├── controllers/
│   │   │   └── course.controller.ts
│   │   ├── services/
│   │   │   └── course.service.ts
│   │   ├── repositories/
│   │   │   └── course.repository.ts
│   │   ├── entities/
│   │   │   └── course.entity.ts
│   │   ├── dto/
│   │   │   ├── create-course.dto.ts
│   │   │   └── update-course.dto.ts
│   │   └── course.module.ts
│   ├── user/
│   ├── enrollment/
│   └── video/
├── common/
│   ├── guards/
│   ├── filters/
│   ├── decorators/
│   └── utils/
├── config/
│   ├── database.config.ts
│   └── jwt.config.ts
└── main.ts
```

**Action Items**:
1. Add "Directory Structure Standards" section to design document
2. Specify domain-based module organization
3. Define shared code organization (`/common` directory)
4. Document when to create new modules vs extend existing ones

---

**Recommendation M2: Define Environment Variable Convention**

**Proposed Convention**:

```bash
# Database
DATABASE_URL=postgresql://...
DATABASE_POOL_SIZE=10

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# AWS
AWS_REGION=ap-northeast-1
AWS_S3_BUCKET=video-content
AWS_SQS_QUEUE_URL=https://...

# Authentication
JWT_SECRET=...
JWT_EXPIRES_IN=15m
REFRESH_TOKEN_EXPIRES_IN=7d

# Application
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
```

**Rules**:
- UPPER_SNAKE_CASE for all variables
- Prefix by service (`DATABASE_`, `REDIS_`, `AWS_`, `JWT_`)
- Duration values with unit suffix (`15m`, `7d`)

**Action Items**:
1. Add "Environment Variables" section to design document
2. Create `.env.example` file with all required variables
3. Document required vs optional variables
4. Specify validation at application startup (use library like `joi` or `class-validator`)

---

**Recommendation M3: Define Configuration File Format**

**Proposed Standards**:

1. **Application Config**: TypeScript files (`config/*.ts`) with type safety
2. **Infrastructure Config**: YAML for Kubernetes/Docker Compose
3. **CI/CD Config**: YAML for GitHub Actions
4. **Environment-Specific Values**: `.env` files (not checked into git)

**Action Items**:
1. Add "Configuration Management" section to design document
2. Specify config file format by category
3. Document secrets management approach (AWS Secrets Manager, etc.)
4. Define configuration validation approach

---

### Positive Alignments

Despite the consistency gaps, the design document demonstrates several strengths:

1. **Clear Technology Choices**: Specific versions for PostgreSQL 15, Redis 7, Next.js 14
2. **Structured API Versioning**: `/api/v1/` prefix allows future API evolution
3. **Consistent JWT Token Strategy**: Clear token expiration policies
4. **Logging Structure**: Winston structured logging with clear log levels
5. **Comprehensive Coverage**: Addresses security, performance, and scalability concerns

These elements provide a solid foundation once consistency issues are addressed.

---

## Summary

This design document presents a well-scoped e-learning platform but exhibits **critical consistency gaps** that will hinder implementation if not addressed:

**Most Critical Issues**:
1. **Severe database naming convention inconsistency** (mixed camelCase/snake_case within and across tables)
2. **Undefined Repository layer implementation** (risk of architectural drift)
3. **Missing authentication/authorization pattern** (security implementation inconsistency risk)
4. **Undocumented error handling approach** (API response consistency risk)

**Root Cause**: As a greenfield project, the document lacks **explicit standard definitions** that would guide consistent implementation.

**Recommended Action**: Before implementation begins, enhance the design document with:
1. "Standards & Conventions" section (naming, casing, formatting)
2. "Architecture Implementation Patterns" section (repository, service dependencies, transactions)
3. "Common Implementation Patterns" section (auth, error handling, logging, async processing)
4. "Project Organization" section (directory structure, configuration management)

Addressing these gaps now will prevent costly mid-project rework and establish a foundation for consistent, maintainable code.
