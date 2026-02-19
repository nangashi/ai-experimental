# Consistency Design Review: リアルタイムチャットシステム設計書

## Inconsistencies Identified

### Critical

#### C1. Architectural Pattern Violation with Inadequate Justification
**Issue**: Section 3.1 states "既存の社内システムでは、ServiceからControllerを直接呼び出す逆向き依存が一部で見られるが、本システムでも既存パターンに倣い、通知送信時にServiceからWebSocketControllerを直接参照する設計とする"

**Problem**: This violates the standard 3-layer architecture principle stated in the same section. The justification "existing pattern in some systems" is insufficient without:
- Verification that this is the dominant pattern (70%+ in related modules)
- Analysis of why this pattern exists (legacy debt vs intentional design)
- Assessment of whether notification use case genuinely requires this violation

**Risk**: Creates circular dependency potential, reduces testability, and may propagate an anti-pattern without confirming it's the established convention.

#### C2. Inconsistent Session Management Architecture
**Issue**: Section 2.2 lists "Redis for session storage" but Section 5.1 specifies "JWT stored in localStorage (stateless authentication)"

**Problem**: JWT-based authentication is stateless and doesn't require session storage. This architectural conflict suggests:
- Confusion between session-based and token-based authentication
- Potential plan to implement both mechanisms (unnecessary complexity)
- Misunderstanding of Redis's role (should be for presence/cache, not sessions)

**Impact**: Unclear which authentication pattern to follow, prevents verification of alignment with existing authentication systems.

#### C3. Missing Transaction Boundary Specification
**Issue**: No transaction management policy documented despite complex operations (message save + presence check + notification queue in Section 3.3)

**Problem**: Without explicit transaction boundaries, cannot verify:
- Whether pattern aligns with existing Service-level @Transactional usage
- How distributed transaction (PostgreSQL + Redis) is handled
- Consistency guarantees for multi-step operations

**Impact**: High risk of data inconsistency if default transaction scope differs from existing codebase patterns.

#### C4. Security Pattern Conflict
**Issue**: Section 5.1 stores JWT in localStorage (XSS vulnerable) while Section 7.2 mentions "SameSite=Strict Cookie for CSRF protection"

**Problem**: Conflicting storage mechanisms:
- localStorage + Authorization header (cannot use SameSite cookies)
- Cookie-based token storage (different from localStorage approach)

**Impact**: Cannot verify alignment with existing authentication token storage pattern. Mixing approaches creates security vulnerabilities.

### Significant

#### S1. Database Naming Convention Inconsistency
**Issue**: Inconsistent patterns across multiple dimensions:

**Table naming**:
- `user` (singular) - explicitly justified as "following existing system"
- `chat_rooms`, `messages`, `room_members` (plural) - no justification

**Column naming**:
- camelCase: `userId`, `roomId`, `displayName`, `roomName`, `createdAt`, `updatedAt`, `joinedAt`
- snake_case: `user_name`, `password_hash`, `room_id`, `message_id`, `sender_id`, `message_text`, `send_time`, `room_member_id`, `room_id_fk`, `user_id`

**Timestamp columns**:
- `created`/`updated` (user table)
- `createdAt`/`updatedAt` (chat_rooms)
- `send_time` (messages)
- `joinedAt` (room_members)

**Foreign key columns**:
- `roomId`, `sender_id` (direct name)
- `room_id_fk`, `user_id` (with suffix)

**Problem**: No explicit naming convention policy documented. Cannot verify if:
- snake_case is the codebase standard and camelCase columns are errors
- Mixed casing is intentional (PK/FK in camelCase, others in snake_case)
- This matches existing database schema patterns

**Impact**:
- JPA entity auto-mapping will fail without explicit @Column annotations
- Developers cannot determine which pattern to follow for new columns
- High risk of further fragmentation

#### S2. Missing File Placement and Package Structure Policy
**Issue**: No directory structure or file placement rules documented

**Problem**: Cannot verify alignment for:
- Domain-based vs layer-based package organization
- WebSocket handler placement (same package as REST controllers?)
- Configuration class placement
- DTO/Request/Response object placement

**Impact**: Moderate risk of inconsistent file organization that diverges from existing project structure.

#### S3. Missing Asynchronous Processing Pattern
**Issue**: Section 3.3 step 5 mentions "register to notification queue for offline users" but:
- No queue technology in tech stack (RabbitMQ? Kafka? SQS?)
- No async processing pattern specified (Spring @Async? Message listener?)
- No error handling for async operations

**Problem**: Cannot verify if notification mechanism aligns with existing async patterns in the codebase.

#### S4. Error Handling Pattern Lacks Consistency Mechanism
**Issue**: Section 6.1 specifies "implement try-catch individually in each Controller method"

**Problem**:
- This approach leads to code duplication across controllers
- No mechanism specified to ensure consistent error response format (Section 5.4)
- Modern Spring Boot projects typically use @ControllerAdvice for global exception handling
- Cannot verify if individual try-catch is the dominant pattern or if @ExceptionHandler exists

**Impact**: High risk of inconsistent error responses and maintenance burden if this diverges from existing error handling approach.

#### S5. API Endpoint Naming Inconsistency
**Issue**: `/api/chatrooms` (no separator between "chat" and "rooms")

**Problem**:
- Inconsistent with table name `chat_rooms` (with underscore)
- Cannot verify if existing APIs use compound words without separator (chatrooms, userprofiles) or with separator (chat-rooms, user-profiles)
- URL casing pattern not documented (kebab-case vs camelCase vs no separator)

#### S6. Missing API Versioning Strategy
**Issue**: REST endpoints (Section 5.2) have no version prefix (e.g., `/v1/api/users`)

**Problem**: Cannot verify if:
- Existing APIs use versioning (should follow same pattern)
- Existing APIs don't use versioning (alignment by omission)
- This is initial version with plan to add versioning later

**Impact**: Incompatible API evolution strategy if existing systems use versioning.

### Moderate

#### M1. Logging Pattern Misalignment with Monitoring Stack
**Issue**: Section 6.2 specifies "plain text logging" but Section 2.3 uses Prometheus + Grafana

**Problem**:
- Prometheus + Grafana typically require structured logs (JSON) for effective querying
- Plain text format: `[INFO] 2024-01-15 12:34:56 - User login: userId=123`
- Modern observability stacks use structured logging (MDC, JSON format)

**Cannot verify**: Whether existing services use plain text or structured logging with the same monitoring stack.

#### M2. Missing Configuration Management Policy
**Issue**: No specification for:
- Configuration file format (application.yml vs application.properties)
- Environment variable naming convention (UPPER_SNAKE_CASE? kebab-case?)
- Profile-specific configuration strategy

**Problem**: Cannot verify alignment with existing Spring Boot configuration patterns.

#### M3. Missing Database Migration Tool
**Issue**: Database schema defined but no migration tool specified (Flyway? Liquibase? manual scripts?)

**Problem**: Cannot verify if this follows existing database versioning approach.

#### M4. WebSocket Scalability Pattern Missing
**Issue**: Section 3.3 describes WebSocket message broadcast but doesn't address:
- Kubernetes multi-pod deployment (session affinity needed?)
- Cross-pod message delivery (Redis pub/sub? Shared broker?)
- Connection state management in distributed environment

**Problem**: Cannot verify if this aligns with existing WebSocket implementation patterns (if any exist).

#### M5. Missing Pagination Specification
**Issue**: List endpoints lack pagination parameters:
- `GET /api/users` - returns all 500 users?
- `GET /api/chatrooms/{roomId}/messages` - returns all messages?

**Problem**: Cannot verify if:
- Existing APIs use consistent pagination pattern (page/size? offset/limit? cursor?)
- Response format includes pagination metadata (totalCount, hasNext, etc.)

#### M6. Missing Data Access Pattern Rationale
**Issue**: Section 2.4 mentions "Spring Data JPA" but doesn't specify:
- Repository interface pattern vs EntityManager direct use
- Custom query approach (JPQL? Criteria API? native SQL?)
- Lazy loading strategy

**Problem**: Cannot verify alignment with existing JPA usage patterns.

### Minor

#### N1. Positive Alignment: Technology Stack Consistency
**Observation**: Java 17 + Spring Boot 3.1.5 suggests alignment with recent platform upgrade decisions. TypeScript + React 18 indicates modern frontend stack.

**Cannot verify without codebase access**: Whether existing services use the same versions.

#### N2. Positive Alignment: Security Baseline
**Observation**: Section 7.2 includes standard security practices (HTTPS, bcrypt, XSS/CSRF protection) suggesting awareness of security requirements.

**Issue**: JWT in localStorage conflicts with XSS protection claim (see C4).

#### N3. Missing Full-Text Search Implementation Detail
**Issue**: Section 1.2 lists "message search" as a feature, Section 7.1 specifies "1 second for 1 year of messages"

**Problem**: No full-text search solution specified:
- PostgreSQL native text search?
- Elasticsearch?
- Simple LIKE query (unlikely to meet performance goal)

**Cannot verify**: Alignment with existing search implementation patterns.

#### N4. Missing File Storage Backend
**Issue**: Section 1.2 mentions "file sharing (images, documents)" but no storage backend in tech stack

**Problem**:
- Local filesystem? (not suitable for Kubernetes multi-pod)
- S3-compatible object storage?
- No size limits or allowed file types specified

**Cannot verify**: Alignment with existing file upload patterns.

#### N5. Missing Rate Limiting and Security Controls
**Issue**: No rate limiting, request throttling, or abuse prevention mechanisms specified for:
- WebSocket connections (DDoS risk)
- Message sending (spam prevention)
- API endpoints

**Cannot verify**: Whether existing systems implement rate limiting and if so, which approach (Spring rate limiter? API gateway? Redis-based?)

---

## Pattern Evidence

Due to limited references to existing codebase, most inconsistencies cannot be verified against actual patterns. The design document provides only two explicit references:

1. **Existing user table naming**: "既存システムのユーザーテーブルに倣い、単数形で命名" (Section 4.1.1)
   - Only confirms singular `user` table exists
   - Does not confirm other tables use singular/plural pattern

2. **Existing Service→Controller dependency**: "既存の社内システムでは、ServiceからControllerを直接呼び出す逆向き依存が一部で見られる" (Section 3.1)
   - Acknowledges this exists in "some" systems (一部)
   - Does not quantify prevalence (70%+ threshold for dominant pattern)
   - Does not analyze whether this is intentional design or technical debt

**Missing evidence for**:
- Database column naming convention (camelCase vs snake_case)
- Error handling approach (global handler vs individual try-catch)
- Logging format (structured vs plain text)
- Authentication token storage (localStorage vs cookie)
- API versioning strategy
- Configuration file format
- Async processing pattern
- File upload storage backend
- All other identified gaps

---

## Impact Analysis

### Critical Impact (C1-C4)

**Architectural Fragmentation**:
- Violating layered architecture (C1) without confirmation of dominant pattern risks creating architectural inconsistency that's difficult to refactor later
- Service→Controller dependency reduces testability and may conflict with existing DI container configuration

**Security Inconsistency**:
- JWT localStorage + CSRF cookie conflict (C4) suggests fundamental misunderstanding of authentication mechanism
- If existing systems use HttpOnly cookies, this design introduces XSS vulnerability
- If existing systems use localStorage, CSRF protection claim is invalid

**Data Integrity Risk**:
- Missing transaction boundaries (C3) in distributed system (PostgreSQL + Redis) can lead to:
  - Messages saved but presence check fails (orphaned data)
  - Notification queue registration fails but message appears sent
  - Inconsistent state across data stores

**Authentication Confusion**:
- Session storage (Redis) + stateless JWT (C2) conflict prevents implementing either correctly
- Cannot integrate with existing SSO or authentication infrastructure

### Significant Impact (S1-S6)

**Developer Experience Degradation**:
- Database naming inconsistency (S1) forces developers to memorize each column's casing
- JPA entity generation requires manual @Column annotations for every field
- IDE auto-completion less effective

**Maintenance Burden**:
- Individual try-catch (S4) multiplies error handling code across controllers
- Changing error format requires updating every controller method
- Increases bug introduction risk during modifications

**API Contract Inconsistency**:
- No versioning (S6) makes breaking changes difficult to manage
- Endpoint naming inconsistency (S5) reduces API discoverability
- If existing APIs have different patterns, frontend developers face inconsistent conventions

**Integration Risk**:
- Async pattern mismatch (S3) may duplicate queue infrastructure or conflict with existing message broker
- File placement mismatch (S2) makes code navigation and onboarding harder

### Moderate Impact (M1-M6)

**Operational Inefficiency**:
- Plain text logs (M1) with Prometheus/Grafana reduce observability effectiveness
- Structured log queries (e.g., "all errors for userId=123") become difficult

**Scalability Risk**:
- WebSocket scalability (M4) not addressed for Kubernetes multi-pod deployment
- Missing pagination (M5) can cause performance degradation with large datasets

**Process Inconsistency**:
- Different database migration tools (M3) across services complicate deployment
- Different configuration formats (M2) increase onboarding friction

---

## Recommendations

### Critical Priority

**C1 - Architectural Pattern Verification**:
1. Conduct codebase analysis to quantify Service→Controller usage:
   ```bash
   # Search for Controller references in Service classes
   grep -r "Controller" --include="*Service.java" --count
   ```
2. If <50% of services use this pattern, remove reverse dependency and use event-driven notification (ApplicationEventPublisher)
3. If >70% use this pattern, document rationale and add architecture decision record (ADR)

**C2 - Authentication Architecture Clarification**:
1. Determine existing authentication mechanism:
   - If JWT: Remove Redis session storage, clarify that Redis is only for presence/cache
   - If session-based: Replace JWT with session cookies, use Redis as session store
2. Update Section 5.1 and 2.2 to align

**C3 - Transaction Boundary Documentation**:
1. Add explicit transaction management section:
   - Define @Transactional scope (Service method level?)
   - Specify distributed transaction handling (saga pattern? eventual consistency?)
   - Document Redis operation consistency guarantees (separate from SQL transaction)
2. Example:
   ```
   MessageService.sendMessage() transaction:
   - Start: @Transactional
   - Save message to PostgreSQL (within transaction)
   - Commit transaction
   - Update Redis presence (outside transaction, eventual consistency acceptable)
   - Queue notification (async, retry on failure)
   ```

**C4 - Authentication Token Storage Alignment**:
1. Search existing codebase for token storage pattern:
   ```bash
   grep -r "localStorage.setItem.*token" frontend/src/
   grep -r "document.cookie.*token" frontend/src/
   ```
2. If existing uses HttpOnly cookies: Change design to cookie-based, remove localStorage
3. If existing uses localStorage: Remove CSRF cookie mention, document XSS mitigation (Content-Security-Policy)

### Significant Priority

**S1 - Database Naming Convention Standardization**:
1. Consult existing schema:
   ```sql
   SELECT table_name FROM information_schema.tables WHERE table_schema='public';
   SELECT column_name FROM information_schema.columns WHERE table_name IN (...);
   ```
2. Determine dominant pattern:
   - Table naming: singular vs plural (count prevalence)
   - Column casing: snake_case vs camelCase (count prevalence)
   - Timestamp naming: created_at vs createdAt vs created (count prevalence)
   - FK naming: with _fk suffix vs without (count prevalence)
3. Update all table definitions to follow dominant pattern (70%+ threshold)
4. Document naming convention explicitly in Section 4 or new "Coding Standards" section

**S2 - File Placement Policy Documentation**:
1. Analyze existing project structure:
   ```bash
   find src/main/java -type d -maxdepth 3
   ```
2. Identify pattern (domain-based like `/user`, `/chat` or layer-based like `/controller`, `/service`)
3. Document in new Section 6.4 "Code Organization":
   ```
   Package structure:
   - com.company.chat.domain.message (Message, MessageRepository, MessageService, MessageController)
   - com.company.chat.domain.user (User, UserRepository, UserService, UserController)
   - com.company.chat.common.config (WebSocketConfig, SecurityConfig)
   - com.company.chat.common.exception (GlobalExceptionHandler, BusinessException)
   ```

**S3 - Asynchronous Processing Pattern Specification**:
1. Check existing async implementation:
   ```bash
   grep -r "@Async" --include="*.java"
   grep -r "RabbitTemplate\|KafkaTemplate" --include="*.java"
   ```
2. If @Async dominant: Add to Section 2.4 dependencies (spring-boot-starter-async), document in 6.1
3. If message queue dominant: Add RabbitMQ/Kafka to tech stack (2.3), document queue naming convention

**S4 - Error Handling Consistency Mechanism**:
1. Search for existing error handling:
   ```bash
   grep -r "@ControllerAdvice\|@ExceptionHandler" --include="*.java"
   ```
2. If global handler exists: Change Section 6.1 to use @ControllerAdvice, reference existing handler
3. If individual try-catch dominant: Add error response builder utility class to ensure format consistency:
   ```java
   ErrorResponseBuilder.build(exception) -> {data: null, error: {...}}
   ```

**S5 - API Endpoint Naming Alignment**:
1. Analyze existing API paths:
   ```bash
   grep -r "@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping" --include="*Controller.java" | grep -o '"/[^"]*"'
   ```
2. Determine compound word pattern (chatrooms vs chat-rooms vs chat_rooms)
3. Update Section 5.2 endpoints to match

**S6 - API Versioning Strategy**:
1. Check existing APIs for version prefix:
   ```bash
   grep -r 'RequestMapping.*"/v[0-9]' --include="*Controller.java"
   ```
2. If versioning used: Add `/v1` prefix to all endpoints in Section 5.2
3. If not used: Add note explaining no versioning (initial version, internal API, etc.)

### Moderate Priority

**M1 - Logging Format Alignment**:
1. Check existing log configuration:
   ```bash
   grep -r "logback.xml\|log4j2.xml" -A 20
   grep -r "JsonLayout\|JSONLayout" --include="*.xml"
   ```
2. If structured logging used: Change Section 6.2 to JSON format with MDC (userId, requestId, traceId)
3. If plain text used: Keep current approach but add structured fields in MDC for key metrics

**M2-M6 - Documentation Enhancements**:
- Add explicit sections for:
  - Configuration management (application.yml, env var naming)
  - Database migrations (Flyway with versioning convention)
  - WebSocket scalability (Redis pub/sub for cross-pod messaging)
  - Pagination standard (page/size parameters, response envelope)
  - JPA query approach (Repository interfaces with method naming convention)

### Process Recommendation

Before finalizing design, perform **codebase pattern analysis**:
1. Use grep/find to extract existing patterns quantitatively
2. Apply 70% threshold for "dominant pattern" classification
3. Document pattern choice rationale when deviating from existing code
4. Create architecture decision records (ADRs) for significant pattern selections

This ensures "consistency" evaluation is based on empirical evidence rather than assumptions about existing codebase conventions.
