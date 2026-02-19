# Consistency Design Review: Real-time Chat System

## Step 1: Structural Pre-Analysis

### 1.1 Document Structure Mapping

**Major Sections and Purpose:**
1. **概要 (Section 1)**: Project objectives, main features, target users (500 employees)
2. **技術スタック (Section 2)**: Technology choices - Java 17 + Spring Boot, React 18, PostgreSQL 15, Redis 7.0
3. **アーキテクチャ設計 (Section 3)**: System architecture, components, data flow
4. **データモデル (Section 4)**: Database schema definitions
5. **API設計 (Section 5)**: Authentication, REST endpoints, WebSocket endpoints, request/response formats
6. **実装方針 (Section 6)**: Error handling, logging, deployment strategies
7. **非機能要件 (Section 7)**: Performance, security, availability

**Organization Approach**: Top-down hierarchical structure from business context to technical implementation details.

**Section Dependencies:**
- Section 2 (Tech Stack) provides foundation for Section 3 (Architecture)
- Section 3 (Architecture) defines components referenced in Section 4 (Data Model)
- Section 5 (API Design) depends on Section 3 (Components) and Section 4 (Data Model)
- Section 6 (Implementation) operationalizes patterns from Section 3 and 5

### 1.2 Pattern Catalog Extraction

#### Naming Conventions

**Classes/Interfaces/Types:**
- Controller suffix: `MessageController`, `UserController`
- Service suffix: `MessageService`, `UserService`, `PresenceService`
- Repository suffix: `MessageRepository`, `UserRepository`
- Handler suffix: `ChatWebSocketHandler`
- Exception suffix: `BusinessException`

**Functions/Methods:**
- Not explicitly documented
- Implicit: Standard CRUD operations implied (e.g., "メッセージ送信/取得のビジネスロジック")

**Files/Directories:**
- Not explicitly documented
- Implicit: Likely layered structure (controller/, service/, repository/)

**Database Entities:**
- **Tables**: Mixed convention
  - Singular: `user`
  - Plural: `chat_rooms`, `messages`, `room_members`
- **Columns**: Mixed case styles
  - snake_case: `user_name`, `password_hash`, `created`, `updated`, `room_id`, `room_type`, `message_id`, `sender_id`, `message_text`, `send_time`, `room_member_id`, `room_id_fk`, `user_id`
  - camelCase: `userId`, `email`, `displayName`, `roomName`, `createdAt`, `updatedAt`, `roomId`, `edited`, `joinedAt`, `role`
- **Primary Keys**: Pattern `{table}_id` (e.g., `message_id`, `room_id`, `room_member_id`) but exception with `userId`
- **Foreign Keys**: Inconsistent suffixes (`roomId`, `sender_id`, `room_id_fk`)

**Variables/Constants:**
- Not explicitly documented

#### Architectural Patterns

**Layer Composition:**
- Stated: 3-tier architecture (Controller/WebSocket Handler, Service, Repository)
- Explicit deviation: "ServiceからControllerを直接呼び出す逆向き依存が一部で見られるが、本システムでも既存パターンに倣い、通知送信時にServiceからWebSocketControllerを直接参照する設計とする"

**Dependency Direction:**
- Standard: Controller → Service → Repository
- Documented exception: Service → WebSocket Controller (for notifications)

**Responsibility Separation:**
- Controller: REST API endpoints, WebSocket connection management
- Service: Business logic
- Repository: Data persistence

**Module/Component Organization:**
- Domain-driven grouping: Messaging, User Management, Presence Management

#### Implementation Patterns

**Error Handling:**
- Approach: Individual try-catch in each Controller method
- Pattern: Catch `BusinessException` from Service layer
- Response: Convert to HTTP status code + error message
- Note: "各Controllerメソッドで個別にtry-catchを実装する" (explicitly stated)

**Authentication/Authorization:**
- Mechanism: JWT (JSON Web Token)
- Storage: localStorage
- Transmission: Authorization header
- Token lifetime: 1 hour (access), 7 days (refresh)

**Data Access:**
- Primary: Spring Data JPA (implied from Repository pattern)
- Cache: Redis via Lettuce client
- Pattern: Repository abstraction layer

**Transaction Management:**
- Not explicitly documented

**Asynchronous Processing:**
- WebSocket for real-time messaging (STOMP)
- Notification queue for offline users (mechanism not detailed)

**Logging:**
- Levels: DEBUG, INFO, WARN, ERROR
- Format: Plain text (example: `[INFO] 2024-01-15 12:34:56 - User login: userId=123`)
- Destination: stdout (production: collected by Fluentd)
- Note: Not structured logging (JSON format not used)

#### API/Interface Design

**Endpoint Naming:**
- Authentication: `/auth/{action}` (login, logout, refresh-token)
- REST API: `/api/{resource}` pattern
- Resource naming: Mixed case
  - Plural: `/api/users`, `/api/chatrooms`
  - Lowercase: `chatrooms` (not `chatRooms` or `chat-rooms`)
  - Kebab-case for actions: `/auth/refresh-token`
- WebSocket: `/ws` (connection), `/topic/rooms/{roomId}` (subscribe), `/app/chat/{roomId}` (send)

**Request/Response Formats:**
- Success: `{ "data": {...}, "error": null }`
- Error: `{ "data": null, "error": { "code": "...", "message": "..." } }`
- Wrapper pattern with consistent structure

**Versioning:**
- Not explicitly documented
- Current API uses `/api/` without version prefix

**Error Response Structure:**
- Structured with `code` and `message` fields
- Example code: `VALIDATION_ERROR`

#### Configuration & Environment

**Configuration File Formats:**
- Docker Compose for local (implied YAML)
- Kubernetes manifests (YAML)
- Not explicitly stated for application config (likely Spring Boot properties/YAML)

**Environment Variable Naming:**
- Not explicitly documented

**Secrets Management:**
- Not explicitly documented
- JWT and bcrypt mentioned but storage/management approach not detailed

### 1.3 Information Completeness Assessment

**Present:**
- Naming: Database table/column names, component suffixes (Controller/Service/Repository)
- Architecture: 3-tier pattern, dependency direction exception
- Implementation: Error handling (individual try-catch), logging format, JWT authentication
- API: Endpoint patterns, response wrapper structure
- Data Model: Complete schema definitions with types and constraints

**Implicit:**
- Naming: Method naming conventions, file/directory structure
- Implementation: Transaction boundaries, ORM usage patterns
- Configuration: Application config file format, environment variable conventions
- Dependency: Library version selection criteria

**Missing:**
- Naming: Variable naming conventions, constant naming rules, environment variable format
- Architecture: Transaction boundary definitions, cross-cutting concern handling (beyond error handling)
- Implementation: Connection pooling strategy, retry policies, timeout configurations, structured logging decision rationale
- API: Pagination patterns, rate limiting, API versioning strategy
- Configuration: Secrets management approach, config file location/naming conventions
- Testing: Unit test patterns, integration test strategies
- Deployment: Rolling update vs blue-green decision criteria, health check endpoints

### 1.4 Cross-Pattern Dependencies

**Dependencies Identified:**

1. **Database naming → ORM mapping**: Mixed snake_case/camelCase in columns requires explicit JPA `@Column` mapping
2. **JWT in localStorage → CSRF protection**: Document states "SameSite=Strict Cookie" but JWT is in localStorage (conflict)
3. **Individual try-catch → Error response format**: Each Controller must implement identical error transformation logic
4. **Service → WebSocket Controller dependency → Transaction boundaries**: Reverse dependency may complicate transaction management
5. **Plain text logging → Security**: User IDs in logs (privacy consideration not addressed)
6. **REST + WebSocket dual interface → Consistency**: Both `/api/chatrooms/{roomId}/messages` (POST) and `/app/chat/{roomId}` (SEND) exist - unclear which to prefer

**Conflicts Detected:**

1. **Database column case style inconsistency**: Same table mixes snake_case (`user_name`) and camelCase (`userId`, `displayName`)
2. **Table naming inconsistency**: Singular (`user`) vs plural (`messages`, `chat_rooms`)
3. **Foreign key naming inconsistency**: `roomId`, `sender_id`, `room_id_fk` use different suffixes
4. **CSRF protection vs JWT storage**: Document claims CSRF protection via cookies, but authentication uses localStorage
5. **Architecture violation acknowledged**: Service → Controller dependency explicitly deviates from stated 3-tier pattern

**Assumptions Made:**

1. "既存システムのユーザーテーブルに倣い、単数形で命名" - assumes existing system has singular table naming
2. "既存の社内システムでは、ServiceからControllerを直接呼び出す逆向き依存が一部で見られる" - assumes this anti-pattern should be continued
3. REST API message send exists alongside WebSocket - assumes both are needed
4. Plain text logging - assumes structured logging is not an existing pattern

---

## Step 2: Inconsistency Detection & Problem Review

### 2.1 Internal Consistency Verification

#### Database Naming Patterns (Critical Inconsistency)

**Category: Naming Convention Consistency**

**Pattern from Step 1.2:** Mixed conventions documented
- Tables: `user` (singular) vs `chat_rooms`, `messages`, `room_members` (plural)
- Columns: snake_case vs camelCase mixed within same tables
- Primary keys: `{table}_id` pattern violated (`userId` instead of `user_id`)
- Foreign keys: Three different suffixes (`roomId`, `sender_id`, `room_id_fk`)

**Internal Inconsistency Detected:**

1. **Table Naming Contradiction:**
   - Document states: "既存システムのユーザーテーブルに倣い、単数形で命名"
   - Reality: Only `user` is singular; all other tables are plural
   - If "following existing patterns," either all should be singular or justification needed for divergence

2. **Column Case Style Chaos:**
   - `user` table: `userId` (camelCase), `user_name` (snake_case), `email` (no separator), `displayName` (camelCase), `password_hash` (snake_case), `created` (no separator)
   - `chat_rooms` table: `room_id` (snake_case), `roomName` (camelCase), `room_type` (snake_case), `createdAt` (camelCase)
   - `messages` table: `message_id` (snake_case), `roomId` (camelCase), `sender_id` (snake_case), `message_text` (snake_case), `send_time` (snake_case)
   - No consistent rule followed

3. **Foreign Key Suffix Inconsistency:**
   - `messages.roomId` - no suffix
   - `messages.sender_id` - `_id` suffix
   - `room_members.room_id_fk` - `_id_fk` suffix
   - All reference primary keys but use different naming conventions

**Impact:** JPA entity classes will require extensive `@Column` annotations, increasing maintenance burden. Database queries joining tables become error-prone. Developer cognitive load increases when switching between tables.

#### API Endpoint Naming (Significant Inconsistency)

**Category: API/Interface Design Consistency**

**Pattern from Step 1.2:** `/api/{resource}` structure with lowercase resource names

**Internal Inconsistency Detected:**

1. **Resource Name Case Inconsistency:**
   - `/api/users` (plural, lowercase)
   - `/api/chatrooms` (plural, lowercase, compound word concatenated)
   - Expected from table name `chat_rooms`: either `/api/chat-rooms` (kebab-case) or `/api/chat_rooms` (snake_case)
   - Inconsistent compound word handling

2. **Dual Message Send Interface:**
   - REST: `POST /api/chatrooms/{roomId}/messages`
   - WebSocket: `SEND /app/chat/{roomId}`
   - No guidance on when to use which interface
   - WebSocket path uses `/app/chat` (singular, different from `/api/chatrooms`)

**Impact:** API consumers face confusion about endpoint naming rules. Frontend developers may inconsistently call REST vs WebSocket for same operation.

### 2.2 Cross-Category Consistency Verification

#### CSRF Protection vs JWT Storage (Critical Inconsistency)

**Categories: Implementation Pattern (Authentication) ↔ Security Requirement**

**Pattern Conflict:**
- Section 5.1 states: "トークンはlocalStorageに保存"
- Section 7.2 states: "CSRF対策: SameSite=Strict Cookieを使用"

**Inconsistency Analysis:**
- JWT in localStorage means Authorization header is used for authentication (stateless, not cookie-based)
- CSRF protection via SameSite cookies is irrelevant when tokens are not in cookies
- If using localStorage, CSRF is not the primary concern (XSS is)
- Document claims CSRF protection but implements a pattern that doesn't use cookies

**Impact:** Security posture misrepresented. Actual vulnerability is XSS (which can steal localStorage tokens), not CSRF. Mitigation strategies will be misdirected.

#### Service → Controller Dependency vs Transaction Management (Critical Inconsistency)

**Categories: Architecture Pattern ↔ Implementation Pattern**

**Pattern Conflict:**
- Section 3.1 explicitly allows Service → WebSocketController for notifications
- Section 6 lists no transaction management strategy
- Step 1.3 identified transaction boundaries as "Missing"

**Inconsistency Analysis:**
- Reverse dependency (Service calling Controller) breaks transactional context
- If `MessageService.sendMessage()` is `@Transactional` and calls `WebSocketController.broadcast()`, the WebSocket send happens inside the transaction
- WebSocket failures could rollback database commits, or vice versa
- No compensation strategy documented for partial failures

**Impact:** Message delivery guarantees unclear. Potential for messages persisted to DB but not sent via WebSocket, or sent via WebSocket but DB commit fails.

#### Plain Text Logging vs Security (Moderate Inconsistency)

**Categories: Implementation Pattern (Logging) ↔ Security Requirement**

**Pattern Conflict:**
- Section 6.2: Example log `[INFO] 2024-01-15 12:34:56 - User login: userId=123`
- Section 7.2: Security requirements include password hashing, JWT, HTTPS
- No mention of PII (Personally Identifiable Information) logging restrictions

**Inconsistency Analysis:**
- Plain text logs with user IDs may violate GDPR/privacy regulations
- No log sanitization or masking strategy documented
- Security section doesn't address log data protection

**Impact:** Compliance risk. Logs may contain sensitive information without protection. Log aggregation systems (Fluentd) may store PII indefinitely.

### 2.3 Completeness Impact Analysis

#### Missing Transaction Management (Critical Gap)

**Gap from Step 1.3:** Transaction boundaries not documented

**Consistency Verification Impact:**
- Cannot verify if transaction patterns align with existing codebase
- Cannot assess if `@Transactional` annotations are placed consistently
- Service → Controller dependency creates ambiguity about transaction scope
- Dual REST/WebSocket interfaces for message sending may have different transactional behavior

**Required Explicit Documentation:**
1. Transaction scope for each Service method
2. Transaction isolation level choices
3. Compensation strategy for WebSocket send failures within transactions
4. Read-only transaction optimization patterns

#### Missing API Versioning Strategy (Significant Gap)

**Gap from Step 1.3:** API versioning not documented

**Consistency Verification Impact:**
- Cannot verify if versioning approach matches existing APIs
- Current `/api/` prefix lacks version (e.g., `/api/v1/`)
- Future breaking changes will require migration strategy
- If existing systems use versioned APIs, this design diverges

**Required Explicit Documentation:**
1. Version prefix in URL or header-based versioning
2. Deprecation policy for old versions
3. Backward compatibility requirements

#### Missing Pagination Patterns (Moderate Gap)

**Gap from Step 1.3:** Pagination not documented

**Consistency Verification Impact:**
- `GET /api/chatrooms/{roomId}/messages` will return potentially thousands of messages
- No limit, offset, cursor, or page parameters defined
- Performance target (Section 7.1) says "1秒以内（過去1年分のメッセージ）" but no pagination to enforce limits
- Cannot verify consistency with existing list endpoints

**Required Explicit Documentation:**
1. Pagination parameter names (limit/offset vs page/size)
2. Default page size
3. Maximum page size limits
4. Response format for paginated data (total count, hasNext, etc.)

### 2.4 Exploratory Problem Detection

#### Edge Case: Room Member Role Enforcement (Critical)

**Pattern Context:** `room_members.role` column has values OWNER/ADMIN/MEMBER

**Problem:**
- No authorization pattern documented for enforcing role-based permissions
- Section 5.1 only covers authentication (JWT), not authorization
- Unclear if Spring Security method-level annotations (`@PreAuthorize`) are used
- No specification of which roles can perform which operations (e.g., can MEMBER delete room?)

**Cross-Category Issue:** Spans API Design (Section 5) + Implementation (Section 6) + Data Model (Section 4)

**Impact:** Authorization logic may be inconsistently implemented across endpoints. Security vulnerabilities if permissions not checked uniformly.

#### Edge Case: Concurrent WebSocket Connection Handling (Significant)

**Pattern Context:**
- Section 3.3 data flow: "オンラインユーザーにはWebSocket経由でリアルタイム配信"
- Section 7.1 target: 500 simultaneous users

**Problem:**
- No pattern for handling multiple concurrent connections from same user (e.g., desktop + mobile)
- `PresenceService` stores online/offline/away status in Redis, but unclear if per-connection or per-user
- If user has 2 connections and closes 1, should they be marked offline?
- No documented pattern for connection tracking vs user presence tracking

**Cross-Category Issue:** Spans Architecture (Section 3) + Implementation (Section 6)

**Impact:** Presence status may flicker incorrectly. Messages may be delivered to some devices but not others.

#### Edge Case: Message Edit/Delete Propagation (Significant)

**Pattern Context:**
- API includes `PUT /api/messages/{id}` (edit) and `DELETE /api/messages/{id}` (delete)
- `messages.edited` boolean flag exists

**Problem:**
- No WebSocket event defined for message edits/deletes
- Section 5.3 WebSocket endpoints only cover new message sending/receiving
- Clients subscribed to `/topic/rooms/{roomId}` won't receive edit/delete events
- Inconsistent with real-time nature of system

**Cross-Category Issue:** Spans API Design (Section 5) + Architecture (Section 3.3 data flow)

**Impact:** Users see outdated messages until page refresh. Real-time experience broken for edits/deletes.

#### Latent Risk: Notification Queue Mechanism Undefined (Moderate)

**Pattern Context:** Section 3.3 states "オフラインユーザーには通知キューに登録"

**Problem:**
- No implementation details for notification queue
- Not mentioned in tech stack (Section 2)
- Unclear if Redis, DB table, or external service (e.g., RabbitMQ)
- No retry policy, dead-letter queue, or failure handling documented
- Inconsistent with detailed architecture in other areas

**Cross-Category Issue:** Spans Architecture (Section 3) + Tech Stack (Section 2) + Implementation (Section 6)

**Impact:** Offline notification delivery reliability unknown. Cannot assess consistency with existing async processing patterns.

#### Anti-Pattern Propagation: Service → Controller Dependency (Critical)

**Pattern Context:** Section 3.1 explicitly states following existing anti-pattern

**Problem:**
- "既存の社内システムでは、ServiceからControllerを直接呼び出す逆向き依存が一部で見られるが、本システムでも既存パターンに倣い..."
- Design document acknowledges this as a deviation ("逆向き依存") but chooses to propagate it
- Consistency evaluation stance (Step 1, "Evaluation Stance") says to flag alignment with existing patterns, even if anti-patterns
- However, this creates long-term technical debt

**Cross-Category Issue:** Spans Architecture (Section 3) + Implementation (Section 6)

**Impact:** Violates single responsibility and testability. Service unit tests must mock Controllers. Future refactoring becomes harder. While "consistent" with existing code, actively harms codebase quality.

---

## Inconsistencies Identified (Prioritized)

### Critical Inconsistencies

1. **Database Column Naming Chaos (Severity: Critical)**
   - **Issue:** Inconsistent case styles within same tables (snake_case, camelCase, no separator mixed)
   - **Evidence:** `user` table has `userId` (camel), `user_name` (snake), `displayName` (camel), `password_hash` (snake) in one schema
   - **Impact:** JPA mapping complexity, developer confusion, error-prone queries, maintenance burden
   - **Recommendation:** Standardize on single convention (suggest snake_case for PostgreSQL, or camelCase consistently mapped with `@Column`)

2. **CSRF Protection Misalignment (Severity: Critical)**
   - **Issue:** Document claims CSRF protection via cookies, but JWT stored in localStorage
   - **Evidence:** Section 5.1 "トークンはlocalStorageに保存" vs Section 7.2 "CSRF対策: SameSite=Strict Cookieを使用"
   - **Impact:** Security posture misrepresented, actual XSS vulnerability not addressed, incorrect mitigation strategies
   - **Recommendation:** Correct security documentation to address XSS (primary threat for localStorage), or switch to httpOnly cookies for JWT storage

3. **Transaction Management + Service→Controller Dependency (Severity: Critical)**
   - **Issue:** Reverse dependency (Service calling WebSocketController) with no transaction boundary definition
   - **Evidence:** Section 3.1 allows Service→Controller calls, Section 6 has no transaction management section, Step 1.3 identified as missing
   - **Impact:** Unclear message delivery guarantees, potential for DB commit/rollback inconsistencies with WebSocket sends
   - **Recommendation:** Document transactional boundaries explicitly; isolate WebSocket broadcasting outside transactional context (use ApplicationEvent or async queue)

4. **Authorization Pattern Missing (Severity: Critical)**
   - **Issue:** `room_members.role` column exists but no authorization enforcement pattern documented
   - **Evidence:** Section 5.1 covers authentication only, no `@PreAuthorize` or role-checking pattern specified
   - **Impact:** Permissions may be inconsistently checked, security vulnerabilities
   - **Recommendation:** Document role-based access control pattern (Spring Security method annotations or custom interceptor), specify which roles can perform which operations

5. **Service→Controller Anti-Pattern Propagation (Severity: Critical)**
   - **Issue:** Design explicitly chooses to follow existing anti-pattern instead of correcting it
   - **Evidence:** Section 3.1 "既存の社内システムでは、ServiceからControllerを直接呼び出す逆向き依存が一部で見られるが、本システムでも既存パターンに倣い..."
   - **Impact:** Technical debt accumulation, testability compromised, single responsibility violation
   - **Recommendation:** Break this pattern using event-driven architecture (ApplicationEventPublisher) or async messaging

### Significant Inconsistencies

6. **API Endpoint Compound Word Handling (Severity: Significant)**
   - **Issue:** Inconsistent handling of compound words in API paths
   - **Evidence:** `/api/chatrooms` (concatenated lowercase) vs table name `chat_rooms` (snake_case) vs expected `/api/chat-rooms` (kebab-case)
   - **Impact:** API consumers confused about naming rules, harder to predict endpoint names
   - **Recommendation:** Standardize compound word handling (suggest kebab-case for URLs: `/api/chat-rooms`)

7. **Dual Message Send Interface Without Guidance (Severity: Significant)**
   - **Issue:** Both REST POST and WebSocket SEND for message sending, no usage guidance
   - **Evidence:** `POST /api/chatrooms/{roomId}/messages` and `SEND /app/chat/{roomId}` both exist
   - **Impact:** Inconsistent usage by frontend, unclear which interface to prefer
   - **Recommendation:** Document when to use REST vs WebSocket (suggest WebSocket for real-time, REST for fallback/history)

8. **Message Edit/Delete Real-time Propagation Missing (Severity: Significant)**
   - **Issue:** Edit/delete APIs exist but no WebSocket events defined for real-time propagation
   - **Evidence:** Section 5.2.4 has `PUT /api/messages/{id}` and `DELETE /api/messages/{id}`, but Section 5.3 WebSocket endpoints only cover new messages
   - **Impact:** Real-time experience broken for edits/deletes, users see stale data
   - **Recommendation:** Add WebSocket events `/topic/rooms/{roomId}/edits` and `/topic/rooms/{roomId}/deletes` or use action type field in message payload

9. **Concurrent WebSocket Connection Handling Undefined (Severity: Significant)**
   - **Issue:** No pattern for multiple connections from same user
   - **Evidence:** Section 3.3 mentions "オンラインユーザーにはWebSocket経由で配信" but no multi-device handling
   - **Impact:** Presence status may be incorrect, messages may not reach all devices
   - **Recommendation:** Document connection tracking strategy (per-connection ID in Redis Set per user, mark offline only when all connections closed)

10. **API Versioning Strategy Missing (Severity: Significant)**
    - **Issue:** No version prefix in API paths
    - **Evidence:** Current paths use `/api/` without version (e.g., `/api/v1/`)
    - **Impact:** Future breaking changes require migration strategy, potential inconsistency with existing APIs
    - **Recommendation:** Add version prefix (`/api/v1/`) and document deprecation policy

### Moderate Inconsistencies

11. **Table Naming Convention Inconsistency (Severity: Moderate)**
    - **Issue:** Singular vs plural table names mixed
    - **Evidence:** `user` (singular) stated as "既存システムに倣い" but `chat_rooms`, `messages`, `room_members` are plural
    - **Impact:** Developer confusion about naming rules, harder to predict table names
    - **Recommendation:** Clarify if existing system actually uses mixed conventions, or standardize on plural for all tables

12. **Foreign Key Naming Convention Inconsistency (Severity: Moderate)**
    - **Issue:** Three different suffixes for foreign keys
    - **Evidence:** `roomId` (no suffix), `sender_id` (`_id` suffix), `room_id_fk` (`_id_fk` suffix)
    - **Impact:** Harder to identify foreign keys in schema, inconsistent JOIN query patterns
    - **Recommendation:** Standardize on single convention (suggest `{referenced_table}_id`)

13. **Pagination Pattern Missing (Severity: Moderate)**
    - **Issue:** No pagination documented for list endpoints
    - **Evidence:** `GET /api/chatrooms/{roomId}/messages` with no limit/offset parameters, but performance target says "過去1年分のメッセージ"
    - **Impact:** Potential performance issues, inconsistency with existing list APIs
    - **Recommendation:** Document pagination parameters (limit/offset or cursor), default/max page sizes, response format

14. **Plain Text Logging vs Privacy (Severity: Moderate)**
    - **Issue:** User IDs in plain text logs with no PII protection documented
    - **Evidence:** Section 6.2 example `User login: userId=123`, no log sanitization mentioned
    - **Impact:** Compliance risk (GDPR), logs may contain sensitive information
    - **Recommendation:** Document log sanitization policy, consider structured logging with PII masking

15. **Notification Queue Implementation Undefined (Severity: Moderate)**
    - **Issue:** Offline notification queue mentioned but not detailed
    - **Evidence:** Section 3.3 "オフラインユーザーには通知キューに登録" but not in tech stack or implementation
    - **Impact:** Reliability unknown, cannot assess consistency with existing async patterns
    - **Recommendation:** Specify queue technology (Redis List, DB table, or RabbitMQ), retry policy, failure handling

### Minor Improvements

16. **Primary Key Naming Inconsistency (Severity: Minor)**
    - **Issue:** `userId` doesn't follow `{table}_id` pattern
    - **Evidence:** `messages.message_id`, `chat_rooms.room_id`, but `user.userId` (not `user.user_id`)
    - **Impact:** Minor cognitive load, otherwise low impact
    - **Recommendation:** Standardize primary key naming pattern

17. **WebSocket Path Inconsistency with REST (Severity: Minor)**
    - **Issue:** WebSocket uses `/app/chat/{roomId}` while REST uses `/api/chatrooms/{roomId}`
    - **Evidence:** Section 5.3 vs Section 5.2.3
    - **Impact:** Minor developer confusion
    - **Recommendation:** Align path structure (`/app/chatrooms/{roomId}` or use consistent singular/plural)

---

## Pattern Evidence (References to Existing Codebase)

**Evidence from Design Document:**

1. **Acknowledged Existing Patterns:**
   - "既存システムのユーザーテーブルに倣い、単数形で命名" (Section 4.1.1)
   - "既存の社内システムでは、ServiceからControllerを直接呼び出す逆向き依存が一部で見られる" (Section 3.1)

2. **Implied Existing Patterns:**
   - Use of Spring Boot, Spring Data JPA, Spring Security (Section 2) suggests existing Spring ecosystem
   - Kubernetes + Docker deployment (Section 2.3) suggests existing container orchestration
   - Fluentd for log collection (Section 6.2) suggests existing logging infrastructure

**Verification Needed:**

To fully verify consistency with existing codebase, the following should be checked:

1. **Database Naming Conventions:**
   - Examine existing table schemas to confirm singular vs plural convention
   - Check existing column case styles (snake_case vs camelCase prevalence)
   - Verify foreign key naming patterns across existing tables

2. **API Patterns:**
   - Review existing API endpoints for compound word handling (kebab-case vs concatenation)
   - Check if existing APIs use versioning (`/api/v1/` pattern)
   - Verify pagination parameter names (limit/offset vs page/size)

3. **Architecture Patterns:**
   - Confirm if Service→Controller anti-pattern is truly widespread or isolated
   - Check existing transaction management annotations and scope patterns
   - Review existing authorization patterns (method-level vs interceptor-based)

4. **Implementation Patterns:**
   - Verify existing error handling approach (global handler vs individual try-catch)
   - Check existing logging format (plain text vs structured JSON)
   - Review existing async processing mechanisms (notification queues, event systems)

---

## Impact Analysis (Consequences of Divergence)

### Immediate Development Impact

1. **Increased Development Time (Critical):**
   - Inconsistent database naming requires extensive JPA `@Column` annotations
   - Each Controller method needs individual try-catch implementation
   - Authorization logic must be manually added to each endpoint

2. **Testing Complexity (Critical):**
   - Service unit tests must mock Controller dependencies (anti-pattern consequence)
   - Transaction boundary ambiguity makes integration testing harder
   - WebSocket + REST dual interfaces require separate test suites

3. **Code Review Burden (Significant):**
   - Reviewers must verify each endpoint follows inconsistent naming rules
   - Security checks (authorization) must be manually verified per endpoint
   - Database queries must be carefully checked for case style errors

### Long-Term Maintenance Impact

4. **Technical Debt Accumulation (Critical):**
   - Service→Controller anti-pattern will be harder to refactor later
   - Inconsistent naming conventions will compound as codebase grows
   - Missing pagination will require breaking API changes in future

5. **Onboarding Friction (Significant):**
   - New developers face steep learning curve due to inconsistent conventions
   - Mixed naming styles require extensive documentation
   - Undocumented patterns (transaction boundaries, authorization) lead to bugs

6. **Refactoring Risk (Significant):**
   - Database schema changes require updating inconsistent column mappings
   - Service→Controller dependency makes layered architecture refactoring difficult
   - Missing versioning strategy makes breaking changes risky

### Production Impact

7. **Security Vulnerabilities (Critical):**
   - Missing authorization pattern enforcement
   - CSRF vs XSS misalignment leaves localStorage JWT vulnerable
   - Plain text logging may expose PII

8. **Performance Issues (Significant):**
   - No pagination on message history endpoints
   - Unclear caching strategy for presence information
   - Transaction scope ambiguity may cause long-running transactions

9. **Operational Issues (Moderate):**
   - Undefined notification queue mechanism affects offline message reliability
   - No defined health check endpoints for Kubernetes liveness/readiness probes
   - Plain text logs harder to query/analyze at scale

---

## Recommendations (Specific Alignment Suggestions)

### Immediate Priority (Address Before Implementation)

1. **Standardize Database Naming Conventions:**
   - **Action:** Choose one convention and apply consistently
   - **Suggestion:** Use `snake_case` for all columns (PostgreSQL standard), plural for all tables
   - **Example:** `user.userId` → `users.user_id`, `chat_rooms.roomName` → `chat_rooms.room_name`
   - **Effort:** High (requires schema redesign)

2. **Correct Security Documentation:**
   - **Action:** Fix CSRF vs XSS misalignment
   - **Suggestion:** Either (a) move JWT to httpOnly cookies and keep CSRF protection, or (b) acknowledge XSS risk with localStorage and document CSP (Content Security Policy)
   - **Effort:** Low (documentation change)

3. **Define Transaction Boundaries:**
   - **Action:** Document `@Transactional` scope for each Service method
   - **Suggestion:** Make WebSocket broadcasting async and outside transaction (use `ApplicationEventPublisher` or message queue)
   - **Effort:** Medium (requires architecture adjustment)

4. **Document Authorization Pattern:**
   - **Action:** Add section on role-based access control
   - **Suggestion:** Use Spring Security `@PreAuthorize("hasRole('ADMIN')")` annotations on Controller methods
   - **Example:** `DELETE /api/chatrooms/{id}` requires OWNER or ADMIN role
   - **Effort:** Medium (requires security design)

5. **Break Service→Controller Anti-Pattern:**
   - **Action:** Refactor notification sending to event-driven pattern
   - **Suggestion:** MessageService publishes `MessageSentEvent`, WebSocketNotificationListener subscribes and broadcasts
   - **Rationale:** Even if existing code uses anti-pattern, new greenfield project is opportunity to fix
   - **Effort:** Medium (requires architecture change)

### High Priority (Address During Initial Implementation)

6. **Add API Versioning:**
   - **Action:** Prefix all endpoints with `/api/v1/`
   - **Suggestion:** Document deprecation policy (e.g., support N-1 versions for 6 months)
   - **Effort:** Low (path change)

7. **Standardize Endpoint Naming:**
   - **Action:** Use kebab-case for compound words
   - **Suggestion:** `/api/chatrooms` → `/api/v1/chat-rooms`
   - **Effort:** Low (path change)

8. **Document Pagination Pattern:**
   - **Action:** Add pagination to all list endpoints
   - **Suggestion:** Use `?limit=50&offset=0` or cursor-based pagination for chat history
   - **Response format:** `{ "data": [...], "pagination": { "total": 1000, "hasNext": true } }`
   - **Effort:** Medium (requires implementation)

9. **Add WebSocket Events for Edit/Delete:**
   - **Action:** Define real-time events for message modifications
   - **Suggestion:** Use message type field: `{ "type": "NEW|EDIT|DELETE", "messageId": ..., "content": ... }`
   - **Effort:** Medium (requires implementation)

10. **Define Notification Queue Mechanism:**
    - **Action:** Specify technology and retry policy
    - **Suggestion:** Use Redis List as queue, 3 retries with exponential backoff, dead-letter queue after failures
    - **Effort:** Medium (requires infrastructure design)

### Medium Priority (Address Before Production)

11. **Document Multi-Device Connection Handling:**
    - **Action:** Define presence tracking strategy
    - **Suggestion:** Redis Set per user with connection IDs, mark offline only when set is empty
    - **Effort:** Medium (requires implementation)

12. **Implement Structured Logging:**
    - **Action:** Switch to JSON format for logs
    - **Suggestion:** Use Logstash JSON encoder, mask PII fields (userId can be hashed or use session ID)
    - **Example:** `{ "timestamp": "...", "level": "INFO", "event": "user_login", "sessionId": "abc123", "userId": "<hashed>" }`
    - **Effort:** Low (configuration change)

13. **Clarify Dual Message Send Interfaces:**
    - **Action:** Document when to use REST vs WebSocket
    - **Suggestion:** WebSocket for real-time (primary), REST for fallback when WebSocket disconnected or for automated systems
    - **Effort:** Low (documentation)

14. **Standardize Foreign Key Naming:**
    - **Action:** Use consistent suffix
    - **Suggestion:** `{referenced_table}_id` pattern (e.g., `roomId` → `room_id`, `sender_id` remains, `room_id_fk` → `room_id`)
    - **Effort:** Low (schema change)

### Low Priority (Polish & Alignment)

15. **Add Health Check Endpoints:**
    - **Action:** Define Kubernetes liveness/readiness probes
    - **Suggestion:** `GET /actuator/health` (Spring Boot Actuator standard)
    - **Effort:** Low (configuration)

16. **Document Environment Variable Conventions:**
    - **Action:** Define naming pattern for env vars
    - **Suggestion:** Use UPPER_SNAKE_CASE (e.g., `DATABASE_URL`, `JWT_SECRET_KEY`)
    - **Effort:** Low (documentation)

17. **Align WebSocket Path with REST:**
    - **Action:** Use consistent resource naming
    - **Suggestion:** `/app/chat/{roomId}` → `/app/chat-rooms/{roomId}` (matches REST path structure)
    - **Effort:** Low (path change)

---

## Summary

This design document contains **5 critical inconsistencies** that must be addressed before implementation:
1. Database naming chaos (mixed case styles within tables)
2. Security documentation misalignment (CSRF vs JWT storage)
3. Undefined transaction boundaries with architectural anti-pattern
4. Missing authorization enforcement pattern
5. Deliberate propagation of Service→Controller anti-pattern

Additionally, **5 significant inconsistencies** and **5 moderate inconsistencies** were identified across naming conventions, API design, and implementation patterns.

The most severe issue is the **inconsistent database schema naming**, which will create immediate friction during JPA entity development. The **CSRF/XSS confusion** represents a critical security documentation flaw. The **Service→Controller anti-pattern** is explicitly acknowledged but chosen anyway, representing a missed opportunity to break technical debt in a greenfield project.

**Recommended Action:** Prioritize fixing the critical inconsistencies before starting implementation. The effort required is Medium to High for database naming standardization, but Low to Medium for security documentation, transaction boundaries, and authorization patterns.
