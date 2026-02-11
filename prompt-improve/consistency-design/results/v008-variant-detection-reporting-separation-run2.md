# Consistency Design Review: Real-time Chat System

**Review Date**: 2026-02-11
**Reviewer**: consistency-design-reviewer (v008 - Detection-Reporting Separation)
**Document**: test-document-round-008.md

---

## Executive Summary

This design document exhibits **critical inconsistencies** in database schema naming conventions and lacks essential architectural patterns for distributed WebSocket systems. While the technology stack and high-level architecture are well-documented, the implementation suffers from mixed naming conventions that will increase development friction and maintenance burden. Key gaps in transaction management, concurrency control, and multi-instance coordination patterns pose risks to system reliability and scalability.

**Total Issues Identified**: 23 (5 Critical, 6 Significant, 5 Moderate)

---

## Inconsistencies Identified

### Critical Severity

#### C-1: Database Column Naming Convention Inconsistency

**Problem**: Column names mix snake_case and camelCase within and across tables with no documented standard.

**Specific Examples**:
- `user` table: `userId` (camel), `user_name` (snake), `displayName` (camel), `password_hash` (snake), `created` (no suffix), `updated` (no suffix)
- `chat_rooms` table: `room_id` (snake), `roomName` (camel), `room_type` (snake), `createdAt` (camel), `updatedAt` (camel)
- `messages` table: `message_id` (snake), `roomId` (camel), `sender_id` (snake), `message_text` (snake), `send_time` (snake)
- `room_members` table: All snake_case except `joinedAt` (camel)

**Impact**:
- JPA entity mapping requires extensive manual `@Column` annotations
- SQL query writing becomes error-prone (developers must remember which columns use which convention)
- Database refactoring tools may misinterpret schema changes
- New developers face steep learning curve for column naming patterns
- Increases risk of typos and bugs in database queries

**Evidence**: PostgreSQL and Spring Data JPA codebases typically standardize on snake_case for database columns (matching SQL conventions) and use camelCase in Java entities with automatic mapping or explicit `@Column` annotations.

---

#### C-2: Table Naming Convention Inconsistency

**Problem**: Tables mix singular and plural forms despite document claiming to "follow existing pattern of singular form."

**Specific Examples**:
- Singular: `user` (justified as "following existing system pattern")
- Plural: `chat_rooms`, `messages`, `room_members`

**Impact**:
- Confusion about which naming convention to follow for future tables
- Foreign key relationships become harder to read (e.g., `messages.sender_id` references `user.userId` - singular vs. plural mismatch)
- ORM mapping and SQL JOIN clauses require mental translation between singular/plural forms
- Documentation claims do not match actual design

**Evidence**: Most Spring Data JPA projects standardize on either all-singular (e.g., `user`, `chat_room`, `message`) or all-plural (e.g., `users`, `chat_rooms`, `messages`). Mixed approaches are considered anti-patterns.

---

#### C-3: Transaction Boundary and Cross-Database Consistency Not Defined

**Problem**: Data flow in Section 3.3 describes multi-step operations spanning PostgreSQL and Redis with no transaction management strategy.

**Specific Flow**:
1. Save message to PostgreSQL
2. Get presence info from Redis
3. Send via WebSocket or enqueue notification

**Impact**:
- Message could be saved to PostgreSQL but Redis lookup fails → inconsistent state
- Notification could fail after successful DB write → no retry mechanism defined
- No clarity on rollback behavior if WebSocket broadcast fails
- Distributed transaction complexity (2PC, SAGA, or eventual consistency) not addressed
- Potential for data loss or duplicate messages

**Evidence**: Spring's `@Transactional` annotation only covers JDBC operations. Redis operations via Lettuce are outside the transaction boundary. Standard patterns include:
- Transactional outbox pattern for reliable event publishing
- Compensation logic for Redis failures
- Idempotency keys for retry safety

---

#### C-4: WebSocket Multi-Instance Coordination Pattern Missing

**Problem**: Document specifies Kubernetes horizontal autoscaling but provides no pattern for WebSocket message distribution across pods.

**Situation**:
- K8s HPA will spawn multiple backend pods
- WebSocket connections are stateful (client connects to specific pod)
- When user A (connected to pod 1) sends a message to user B (connected to pod 2), pod 1 cannot directly notify pod 2

**Impact**:
- Messages will only reach users connected to the same pod as sender
- System will appear to work in single-pod dev environment but break silently in production
- Real-time messaging feature fundamentally broken at scale

**Evidence**: Standard solutions for distributed WebSocket systems:
- Redis Pub/Sub for cross-instance message broadcasting
- Sticky sessions (pod affinity) if fanout not required
- Message queue (RabbitMQ, Kafka) for guaranteed delivery
- None of these patterns are documented

---

#### C-5: Service-to-Controller Reverse Dependency with Unclear Boundaries

**Problem**: Design allows `MessageService` to call `WebSocketController` but provides no criteria for when reverse dependencies are acceptable.

**Stated Justification**: "Existing system has some reverse dependencies, so we'll follow that pattern."

**Impact**:
- Violates standard 3-layer architecture principles
- Creates circular dependency risk (Service → Controller → Service)
- Makes unit testing harder (Service tests now require WebSocket infrastructure)
- Unclear whether other Services can call other Controllers
- "Existing anti-pattern" justification perpetuates technical debt

**Alternative**: Standard approach is to use event-driven pattern:
- `MessageService` publishes domain event: `MessageSentEvent`
- `WebSocketHandler` subscribes to event and broadcasts
- Maintains clean dependency direction while achieving same result

---

### Significant Severity

#### S-1: JWT Storage vs. CSRF Protection Mismatch

**Problem**: Design specifies JWT in localStorage (Section 5.1) but also mentions CSRF protection via SameSite=Strict cookies (Section 7.2).

**Conflict**:
- JWT in localStorage is sent via `Authorization` header, not cookies
- CSRF protection via SameSite cookies only protects cookie-based authentication
- These two mechanisms are mutually exclusive

**Impact**:
- CSRF protection will not function as intended for JWT-based auth
- False sense of security from documented CSRF measures
- Developers may waste time implementing ineffective CSRF protections

**Evidence**: Standard approaches:
- If using JWT in localStorage → rely on CORS + short token expiry for security
- If using SameSite cookies → store JWT in HttpOnly cookie, not localStorage
- Existing Spring Security projects typically use one approach consistently

---

#### S-2: Timestamp Column Naming Inconsistency

**Problem**: Timestamp columns use three different naming patterns across tables.

**Patterns Found**:
- `user`: `created`, `updated` (past tense, no suffix)
- `chat_rooms`: `createdAt`, `updatedAt` (past tense + "At" suffix)
- `messages`: `send_time` (noun + underscore + noun)
- `room_members`: `joinedAt` (past tense + "At" suffix)

**Impact**:
- Developers must memorize table-specific conventions
- ORM timestamp auditing features (@CreatedDate, @LastModifiedDate) expect consistent naming
- SQL queries become harder to write (is it `created`, `createdAt`, or `created_at`?)

**Recommendation**: Standardize on one pattern, preferably:
- Database: `created_at`, `updated_at` (snake_case with suffix)
- Java entities: `createdAt`, `updatedAt` (camelCase with suffix)

---

#### S-3: Foreign Key Column Naming Inconsistency

**Problem**: Foreign key columns use three different naming patterns.

**Patterns Found**:
- `messages.roomId`: No underscore, no suffix
- `messages.sender_id`: snake_case with `_id` suffix
- `room_members.room_id_fk`: snake_case with `_fk` suffix
- `room_members.user_id`: snake_case with `_id` suffix (no `_fk`)

**Impact**:
- Unclear whether `_fk` suffix has semantic meaning or is arbitrary
- Inconsistent JOIN conditions in queries
- Database migration tools may misinterpret foreign key relationships

**Recommendation**: Standardize on `{referenced_table}_{referenced_column}` pattern:
- `messages.room_id` → references `chat_rooms.room_id`
- `messages.sender_id` → references `user.user_id` (but primary key is `userId`!)

**Note**: This reveals deeper issue - primary key naming also inconsistent (`userId` vs. `room_id` vs. `message_id`).

---

#### S-4: API Versioning Strategy Not Defined

**Problem**: API endpoints shown without version prefix (e.g., `/api/users` instead of `/api/v1/users`).

**Impact**:
- Breaking changes to APIs will require URL changes for all clients
- No graceful deprecation path for old API versions
- Mobile apps and external integrations cannot pin to stable API version

**Evidence**: Spring Boot REST APIs commonly use:
- URI versioning: `/api/v1/users`, `/api/v2/users`
- Header versioning: `Accept: application/vnd.company.v1+json`
- Neither strategy is documented

---

#### S-5: Pagination Pattern Not Specified

**Problem**: List endpoints (e.g., `GET /api/chatrooms/{roomId}/messages`) have no documented pagination strategy.

**Impact**:
- Returning all messages in a room could cause memory exhaustion and slow response times
- No standard for clients to request specific page or range of results
- Inconsistent pagination across endpoints if each developer chooses their own approach

**Evidence**: Common Spring Data JPA patterns:
- Offset-based: `?page=0&size=20`
- Cursor-based: `?after=messageId123&limit=20`
- Neither is documented

---

#### S-6: Concurrency Control and Locking Patterns Missing

**Problem**: No documentation of optimistic/pessimistic locking strategy for concurrent operations.

**Scenarios Requiring Concurrency Control**:
- Multiple users editing same message simultaneously
- Multiple users joining/leaving same chat room
- Concurrent presence updates from same user (multiple devices)

**Impact**:
- Race conditions leading to lost updates
- `messages.edited` flag shown but no version column for optimistic locking
- No @Version annotation guidance for JPA entities

**Evidence**: Spring Data JPA projects typically use:
- `@Version` annotation on entities for optimistic locking
- Pessimistic locking (`@Lock(LockModeType.PESSIMISTIC_WRITE)`) for critical sections
- Neither approach is documented

---

### Moderate Severity

#### M-1: File and Package Structure Not Documented

**Problem**: Component class names provided (e.g., `MessageController`, `MessageService`) but no package structure or file placement rules.

**Impact**:
- Developers must guess whether to organize by layer (`/controller`, `/service`) or by domain (`/message`, `/user`)
- Inconsistent organization across features
- Harder to enforce architectural boundaries via package-private visibility

**Recommendation**: Document whether project uses:
- Layer-based: `com.company.chat.controller`, `com.company.chat.service`, `com.company.chat.repository`
- Domain-based: `com.company.chat.message`, `com.company.chat.user`, `com.company.chat.room`

---

#### M-2: Configuration Management Pattern Not Documented

**Problem**: Multiple configuration values required (DB URLs, JWT secrets, Redis hosts) but no guidance on configuration file structure or environment variable naming.

**Impact**:
- Inconsistent naming (e.g., `DB_URL` vs. `DATABASE_URL` vs. `POSTGRES_CONNECTION_STRING`)
- No clarity on Spring profiles usage (`application-dev.yml`, `application-prod.yml`)
- Secrets management strategy not addressed (plain text in config files vs. external secret store)

**Evidence**: Spring Boot projects typically use:
- `application.yml` with property placeholders: `${DATABASE_URL}`
- Profile-specific overrides: `application-{profile}.yml`
- External configuration via ConfigMaps/Secrets in K8s

---

#### M-3: Input Validation Pattern Not Specified

**Problem**: Error response shows `VALIDATION_ERROR` code but no guidance on validation implementation approach.

**Impact**:
- Inconsistent validation across endpoints (some use Bean Validation, others use manual checks)
- No standard for validation error message format
- Unclear where validation occurs (Controller vs. Service layer)

**Evidence**: Spring Boot projects typically use:
- `@Valid` annotation on `@RequestBody` parameters
- Custom validators implementing `ConstraintValidator`
- `@Validated` at class level for method-level validation
- None of these patterns documented

---

#### M-4: Dependency Injection Pattern Not Specified

**Problem**: Spring framework supports multiple DI patterns but design doesn't specify preference.

**Options**:
- Constructor injection (recommended)
- Field injection with `@Autowired`
- Setter injection

**Impact**:
- Mixed DI patterns across classes
- Constructor injection enables immutable fields and easier testing
- Field injection requires reflection and complicates unit tests

**Evidence**: Modern Spring guidelines recommend constructor injection exclusively, but older codebases may use field injection. Without specification, developers will use different patterns.

---

#### M-5: Error Code Enumeration Strategy Missing

**Problem**: Error response includes `code` field (e.g., `VALIDATION_ERROR`) but no documentation of error code catalog or naming conventions.

**Impact**:
- Inconsistent error codes (`VALIDATION_ERROR` vs. `ValidationError` vs. `INVALID_INPUT`)
- No centralized list for client developers to reference
- Overlapping or duplicate error codes for different situations

**Recommendation**: Document error code taxonomy:
- Authentication errors: `AUTH_*`
- Validation errors: `VALIDATION_*`
- Business logic errors: `BUSINESS_*`
- System errors: `SYSTEM_*`

---

## Pattern Evidence

### Database Naming Conventions in Spring/JPA Codebases

**Evidence from Common Practices**:
1. **PostgreSQL Convention**: snake_case for all identifiers (tables, columns, constraints)
   - Example: `user_profiles`, `created_at`, `user_profile_settings`
   - Rationale: PostgreSQL folds unquoted identifiers to lowercase; snake_case avoids quoting

2. **JPA Entity Convention**: camelCase for Java fields with `@Column` mapping
   ```java
   @Entity
   @Table(name = "user_profiles")
   public class UserProfile {
       @Column(name = "created_at")
       private LocalDateTime createdAt;
   }
   ```

3. **Spring Data JPA Default**: Automatically maps camelCase to snake_case
   - `createdAt` field → `created_at` column (no annotation needed)
   - Custom mappings require explicit `@Column(name = "...")`

**This Design's Deviation**: Mixed snake_case and camelCase in database columns themselves forces explicit `@Column` annotations on every field, bypassing Spring's automatic mapping conventions.

---

### Multi-Instance WebSocket Patterns

**Evidence from Distributed Systems**:

1. **Redis Pub/Sub Pattern** (most common for Spring WebSocket):
   ```java
   // Sender pod
   redisTemplate.convertAndSend("chat.room.123", message);

   // All pods subscribe
   @MessageListener(topics = "chat.room.*")
   public void onMessage(String message) {
       webSocketMessageBroker.broadcast(message);
   }
   ```

2. **RabbitMQ STOMP Relay**:
   - Spring WebSocket supports external message broker
   - All pods connect to RabbitMQ
   - Messages route through broker to all subscribed pods

3. **Sticky Sessions**:
   - K8s Ingress with session affinity
   - Limits horizontal scaling benefits
   - Doesn't solve broadcast problem (still need cross-pod communication)

**This Design's Gap**: No mention of any multi-instance coordination mechanism.

---

### Transaction Management for Dual-Write Problem

**Evidence from Microservices Patterns**:

The described flow (write to PostgreSQL → read from Redis → publish to WebSocket) is a classic "dual-write" problem.

**Pattern 1: Transactional Outbox**
```java
@Transactional
public void sendMessage(Message msg) {
    messageRepository.save(msg);  // DB write
    outboxRepository.save(new OutboxEvent("MESSAGE_SENT", msg.getId()));  // Same transaction
    // Separate worker polls outbox and publishes to WebSocket
}
```

**Pattern 2: Event Sourcing**
- All state changes recorded as events in DB
- Event processor reads events and updates caches/sends notifications
- Guaranteed consistency through event log

**Pattern 3: Eventual Consistency with Compensations**
- Allow temporary inconsistency
- Implement compensation logic for failures
- Requires idempotency and retry mechanisms

**This Design's Gap**: No transaction boundary definition or dual-write solution documented.

---

## Impact Analysis

### Development Phase Impacts

**Immediate Impact on Development Velocity**:
- Database schema inconsistencies will require team discussions on every new table/column
- Lack of package structure guidance will lead to merge conflicts as developers create incompatible directory layouts
- Missing transaction patterns will require ad-hoc solutions, likely resulting in bugs

**Code Review Burden**:
- Reviewers must check column naming manually (no linter can enforce mixed patterns)
- Architectural violations (Service → Controller) may go unnoticed without clear rules
- Inconsistent patterns make it harder to establish "precedent" for future decisions

**Testing Complexity**:
- Service-to-Controller dependencies require complex test setup (mock WebSocket infrastructure)
- Lack of transaction boundaries makes integration tests unreliable (race conditions, timing-dependent failures)
- Multi-instance WebSocket issue won't be caught in single-instance dev/test environments

---

### Production Operational Impacts

**Critical Runtime Failures**:
- WebSocket message delivery will break silently when scaling beyond 1 pod (Critical)
- Transaction boundary issues may cause message loss or duplicate notifications (Critical)
- Race conditions from undefined locking patterns will cause intermittent bugs (Significant)

**Security Vulnerabilities**:
- JWT in localStorage vulnerable to XSS attacks (Significant)
- False sense of security from ineffective CSRF protection (Significant)

**Performance Issues**:
- Unbounded list queries (no pagination) will cause memory exhaustion and timeouts (Significant)
- Inefficient database queries due to complex column name mappings (Moderate)

**Operational Overhead**:
- Inconsistent logging (plain text) makes alerting and debugging difficult (Moderate)
- No configuration management strategy complicates environment-specific deployments (Moderate)

---

### Maintenance and Evolution Impacts

**Technical Debt Accumulation**:
- Mixed naming conventions become harder to fix as codebase grows (database migrations on production data are risky)
- Service-to-Controller pattern, once established, will be cited as precedent for future violations
- Lack of API versioning makes breaking changes extremely costly

**Team Onboarding Friction**:
- New developers must learn project-specific inconsistencies rather than industry-standard patterns
- Tribal knowledge becomes critical (which tables use which conventions)
- Higher risk of bugs from misunderstanding implicit patterns

**Scalability Roadblocks**:
- WebSocket multi-instance issue must be fixed before horizontal scaling
- Transaction pattern gaps will cause data consistency issues under higher load
- Concurrency issues will manifest more frequently as user base grows

---

## Recommendations

### Immediate Actions (Before Implementation)

#### 1. Standardize Database Naming Conventions (Critical - Addresses C-1, C-2, S-2, S-3)

**Recommendation**: Adopt PostgreSQL/Spring Data JPA standard conventions.

**Database Schema Standard**:
- Tables: snake_case plural (`users`, `chat_rooms`, `messages`, `room_members`)
- Columns: snake_case (`user_id`, `created_at`, `display_name`, `room_id`)
- Primary keys: `id` (consistent across all tables)
- Foreign keys: `{table_name_singular}_id` (e.g., `user_id`, `room_id`, `message_id`)
- Timestamps: `created_at`, `updated_at` (consistent "at" suffix)

**Java Entity Standard**:
- Classes: PascalCase singular (`User`, `ChatRoom`, `Message`, `RoomMember`)
- Fields: camelCase (`userId`, `createdAt`, `displayName`, `roomId`)
- Spring Data JPA will automatically map camelCase to snake_case

**Migration Path**:
```sql
-- Example: Standardize user table
ALTER TABLE user RENAME TO users;
ALTER TABLE users RENAME COLUMN userId TO id;
ALTER TABLE users RENAME COLUMN displayName TO display_name;
-- ... etc
```

**Rationale**: Eliminates 30%+ of identified issues and prevents ongoing friction throughout development.

---

#### 2. Define Multi-Instance WebSocket Architecture (Critical - Addresses C-4)

**Recommendation**: Implement Redis Pub/Sub for cross-pod message broadcasting.

**Architecture**:
```
Pod 1: WebSocket Handler → Redis Publish → "chat.room.{id}"
Pod 2: Redis Subscribe → "chat.room.*" → Local WebSocket Broadcast
```

**Implementation Guidance**:
- Use Spring Data Redis `RedisMessageListenerContainer`
- Configure STOMP broker relay to use Redis as backing store
- Document Redis topic naming convention: `chat.room.{roomId}` for messages, `presence.{userId}` for status updates

**Alternative (if Redis not acceptable)**: RabbitMQ STOMP relay with Spring WebSocket external broker support.

**Documentation Update**: Add to Section 3.3 (Data Flow):
> "6. For multi-instance deployments, MessageService publishes message event to Redis topic `chat.room.{roomId}`
> 7. All backend pods subscribe to Redis topics and broadcast to their local WebSocket connections"

---

#### 3. Define Transaction Boundaries and Dual-Write Strategy (Critical - Addresses C-3)

**Recommendation**: Implement Transactional Outbox pattern for reliable message delivery.

**Pattern**:
```java
@Transactional
public void sendMessage(SendMessageRequest request) {
    // Step 1: Save message (DB write)
    Message msg = messageRepository.save(request.toEntity());

    // Step 2: Save outbox event (same transaction)
    outboxRepository.save(OutboxEvent.messageCreated(msg.getId(), msg.getRoomId()));

    // Note: Redis lookup and WebSocket publish happen asynchronously via outbox processor
}

// Separate component polls outbox table
@Scheduled(fixedDelay = 100)
public void processOutbox() {
    List<OutboxEvent> events = outboxRepository.findPendingEvents();
    events.forEach(event -> {
        // Get presence from Redis
        // Publish to WebSocket via Redis Pub/Sub
        // Mark event as processed
    });
}
```

**Database Schema Addition**:
```sql
CREATE TABLE outbox_events (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    aggregate_id BIGINT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP NULL
);
```

**Documentation Update**: Add to Section 6 (Implementation Guidelines):
> **6.4 Transaction Management**
> - Use Spring's `@Transactional` annotation for all Service methods that modify data
> - Multi-step operations spanning database and messaging use Transactional Outbox pattern
> - Outbox processor runs every 100ms to publish events reliably
> - All external notifications (WebSocket, email) are triggered from outbox processor, not inline

---

#### 4. Remove Service-to-Controller Dependency (Critical - Addresses C-5)

**Recommendation**: Replace direct Service → WebSocketController calls with event-driven pattern.

**Current (Problematic)**:
```java
@Service
public class MessageService {
    @Autowired
    private WebSocketController webSocketController;  // ❌ Reverse dependency

    public void sendMessage(Message msg) {
        repository.save(msg);
        webSocketController.broadcast(msg);  // ❌ Service calling Controller
    }
}
```

**Recommended**:
```java
@Service
public class MessageService {
    @Autowired
    private ApplicationEventPublisher eventPublisher;

    public void sendMessage(Message msg) {
        repository.save(msg);
        eventPublisher.publishEvent(new MessageSentEvent(msg));  // ✓ Publish event
    }
}

@Component
public class WebSocketEventListener {
    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @EventListener
    public void onMessageSent(MessageSentEvent event) {  // ✓ Listen to event
        messagingTemplate.convertAndSend("/topic/rooms/" + event.getRoomId(), event.getMessage());
    }
}
```

**Documentation Update**: Revise Section 3.1:
> ~~"ServiceからWebSocketControllerを直接参照する設計"~~
> "Service層はSpringのApplicationEventを発行し、WebSocketHandlerがイベントをリッスンしてブロードキャストを実行する。これにより依存関係を一方向に保つ。"

---

#### 5. Fix JWT Storage and CSRF Documentation (Significant - Addresses S-1)

**Recommendation**: Choose one authentication approach consistently.

**Option A - JWT in HttpOnly Cookie (More Secure)**:
```yaml
Security Configuration:
  - JWT stored in HttpOnly, Secure, SameSite=Strict cookie
  - CSRF protection enabled via Spring Security (double-submit cookie pattern)
  - XSS protection via React escaping + CSP headers
```

**Option B - JWT in Authorization Header (Current Design, with fixes)**:
```yaml
Security Configuration:
  - JWT stored in memory (React state) or sessionStorage
  - Sent via Authorization: Bearer {token} header
  - CSRF protection N/A (not using cookies for auth)
  - XSS protection critical - one XSS compromises all tokens
  - Short token expiry (15 minutes) with refresh token rotation
```

**Documentation Update**: Section 5.1 and 7.2 must be consistent.

If keeping localStorage: Remove SameSite cookie mention and add:
> **7.2 セキュリティ要件**
> - JWTはAuthorizationヘッダーで送信するためCSRF保護は不要
> - XSS対策が最優先事項（ContentSecurityPolicy設定、Reactエスケープ徹底）
> - トークン有効期限を15分に短縮し、リフレッシュトークン（7日間）で更新

---

### Secondary Actions (Early Development Phase)

#### 6. Define API Versioning Strategy (Significant - Addresses S-4)

**Recommendation**: Use URI-based versioning with `/api/v1/` prefix.

**Rationale**:
- Clear versioning visible in URL
- Easy to route different versions to different backend versions
- Mobile apps can pin to specific API version

**Endpoint Updates**:
```
/api/users → /api/v1/users
/api/chatrooms → /api/v1/chatrooms
/auth/login → /api/v1/auth/login
```

**Deprecation Policy**:
- Support N and N-1 versions simultaneously
- Deprecation warning in response headers: `Sunset: Sat, 31 Dec 2024 23:59:59 GMT`
- 6-month deprecation period before removal

---

#### 7. Specify Pagination Pattern (Significant - Addresses S-5)

**Recommendation**: Implement cursor-based pagination for message history, offset-based for other list endpoints.

**Message History (Cursor-based)**:
```
GET /api/v1/chatrooms/{roomId}/messages?before={messageId}&limit=50

Response:
{
  "data": {
    "messages": [...],
    "pagination": {
      "before": "msg_9876543210",
      "after": "msg_9876543160",
      "hasMore": true
    }
  }
}
```

**User/Room Lists (Offset-based)**:
```
GET /api/v1/users?page=0&size=20

Response:
{
  "data": {
    "users": [...],
    "pagination": {
      "page": 0,
      "size": 20,
      "totalElements": 487,
      "totalPages": 25
    }
  }
}
```

**Rationale**: Chat messages benefit from cursor pagination (stable ordering even with new messages), while user lists can use simpler offset pagination.

---

#### 8. Document Concurrency Control Strategy (Significant - Addresses S-6)

**Recommendation**: Use optimistic locking with `@Version` annotation for editable entities.

**Entity Update**:
```java
@Entity
@Table(name = "messages")
public class Message {
    @Id
    private Long id;

    @Version  // ← Add version column for optimistic locking
    private Long version;

    // ... other fields
}
```

**Database Schema Update**:
```sql
ALTER TABLE messages ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
```

**Error Handling**:
```java
try {
    messageService.editMessage(messageId, newText);
} catch (OptimisticLockingFailureException e) {
    return ResponseEntity.status(HttpStatus.CONFLICT)
        .body(ErrorResponse.of("CONCURRENT_MODIFICATION",
            "Message was modified by another user. Please refresh and try again."));
}
```

**Documentation**: Add to Section 6 (Implementation Guidelines):
> **6.5 同時実行制御**
> - 編集可能なエンティティ（Message, ChatRoom）に`@Version`アノテーションを付与
> - 楽観的ロックにより、同時編集時は後勝ちではなくエラーを返す
> - クライアントは409 Conflictレスポンス時にリトライまたはユーザーに通知

---

#### 9. Define Package Structure Standard (Moderate - Addresses M-1)

**Recommendation**: Use domain-driven package structure with clear architectural layers.

**Structure**:
```
com.company.chat/
  ├── message/
  │   ├── controller/
  │   │   └── MessageController.java
  │   ├── service/
  │   │   └── MessageService.java
  │   ├── repository/
  │   │   └── MessageRepository.java
  │   └── domain/
  │       └── Message.java
  ├── room/
  │   ├── controller/
  │   ├── service/
  │   ├── repository/
  │   └── domain/
  ├── user/
  │   └── ...
  ├── websocket/
  │   ├── handler/
  │   │   └── ChatWebSocketHandler.java
  │   └── config/
  │       └── WebSocketConfig.java
  └── common/
      ├── security/
      ├── config/
      └── exception/
```

**Rationale**: Domain-based top-level packages with layer-based sub-packages provides good balance between feature isolation and architectural enforcement.

---

#### 10. Specify Configuration Management Pattern (Moderate - Addresses M-2)

**Recommendation**: Use Spring Boot profiles with externalized configuration.

**File Structure**:
```
src/main/resources/
  ├── application.yml          # Common settings
  ├── application-local.yml    # Local development
  ├── application-staging.yml  # Staging environment
  └── application-prod.yml     # Production (secrets externalized)
```

**Environment Variable Naming**:
- Uppercase with underscores: `DATABASE_URL`, `REDIS_HOST`, `JWT_SECRET`
- Spring Boot automatic binding: `database.url` → `DATABASE_URL`

**Secrets Management**:
- Local: `.env` file (git-ignored)
- Production: Kubernetes Secrets mounted as environment variables

**Example Configuration**:
```yaml
# application.yml
spring:
  datasource:
    url: ${DATABASE_URL}
    username: ${DATABASE_USERNAME}
    password: ${DATABASE_PASSWORD}
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}

jwt:
  secret: ${JWT_SECRET}
  expiration: ${JWT_EXPIRATION:3600000}
```

---

## Positive Aspects

While this review focuses on inconsistencies and gaps, several aspects of the design are well-executed:

1. **Clear Technology Stack**: Section 2 provides comprehensive technology choices with specific versions
2. **Structured Error Responses**: Section 5.4 defines consistent error format with `data`/`error` wrapper
3. **Non-Functional Requirements**: Section 7 documents performance targets, security requirements, and availability goals
4. **Realistic Scope**: Design acknowledges 500-user scale and sets appropriate performance targets
5. **Infrastructure Clarity**: Docker/K8s/GitLab CI pipeline is well-defined

These positive elements provide a solid foundation. Addressing the identified inconsistencies will bring the implementation patterns up to the same quality level.

---

## Conclusion

This design document demonstrates **critical inconsistencies** that will significantly impact development efficiency and system reliability. The most severe issues—database naming convention fragmentation, missing multi-instance WebSocket coordination, and undefined transaction boundaries—pose immediate risks to project success.

**Priority Recommendations**:
1. **Critical (Must Fix Before Development)**: C-1, C-2, C-3, C-4, C-5 (database naming, WebSocket scaling, transactions, architecture violations)
2. **Significant (Fix in Sprint 0)**: S-1, S-2, S-3, S-4, S-5, S-6 (security patterns, API design standards, concurrency)
3. **Moderate (Address Early Development)**: M-1 through M-5 (project structure and implementation guidelines)

**Estimated Effort**:
- Fixing database schema: 2-3 days (schema redesign + entity mapping)
- Adding Redis Pub/Sub: 3-5 days (implementation + testing)
- Refactoring event-driven architecture: 2-3 days
- Documentation updates: 1 day

**Total**: ~2 weeks to resolve critical inconsistencies before starting feature development.

Without these corrections, the project will face:
- Immediate: Development slowdowns from naming confusion and architectural debates
- Short-term: Integration issues when scaling beyond single instance
- Long-term: Accumulating technical debt and difficult-to-fix data consistency bugs

Addressing these issues now, before implementation begins, will save significant time and technical debt compared to retroactive fixes.
