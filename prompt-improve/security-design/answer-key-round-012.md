# Answer Key - Round 012

## Execution Context
- **Observation**: security
- **Target**: design
- **Embedded Issues**: 10 issues

## Embedded Issues

### P01: Password Reset Token Long Expiration
- **Category**: Authentication Design
- **Severity**: Medium
- **Location**: Section 5 - API Design, password reset endpoint
- **Issue Description**: The password reset token has a 2-hour expiration period, which is excessively long and increases the window for token theft or unauthorized access. Industry best practice recommends 15-30 minutes for password reset tokens to minimize security risk.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the 2-hour password reset token expiration as a security risk and recommends shorter expiration (e.g., 15-30 minutes) with clear rationale about token theft risk
  - △ (Partial Detection): Mentions password reset token expiration or security concerns about the authentication flow, but does not specify the 2-hour duration as problematic or provide specific remediation
  - × (No Detection): No mention of password reset token expiration or authentication flow security issues

### P02: Missing CSRF Protection
- **Category**: API Security
- **Severity**: Medium
- **Issue Description**: The API design includes state-changing operations (POST, PUT, DELETE) such as booking creation, modification, and cancellation, but there is no mention of CSRF protection mechanisms. While JWT tokens provide some protection, additional CSRF tokens or SameSite cookie attributes should be specified for defense-in-depth.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the lack of CSRF protection for state-changing endpoints (booking creation/modification/cancellation) and recommends specific mechanisms (CSRF tokens, SameSite attributes, or double-submit cookie pattern)
  - △ (Partial Detection): Mentions CSRF as a general security concern or identifies state-changing endpoints requiring protection, but does not connect them to specific missing protections in the design
  - × (No Detection): No mention of CSRF protection requirements

### P03: Weak Password Requirements
- **Category**: Authentication Design
- **Severity**: Medium
- **Issue Description**: Section 7 specifies "Password minimum length: 8 characters with complexity requirements" but does not define what the complexity requirements are. The minimum length of 8 characters is also below current NIST recommendations (at least 12-16 characters for user-generated passwords without strict complexity rules, or 8 with very strict complexity).
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the undefined password complexity requirements and/or questions the adequacy of 8-character minimum, with reference to modern password policy best practices (NIST, OWASP)
  - △ (Partial Detection): Mentions password policy or authentication security concerns without specifically addressing the vague "complexity requirements" or the 8-character minimum
  - × (No Detection): No mention of password policy issues

### P04: Log Sensitive Data Redaction Not Enforced
- **Category**: Data Protection
- **Severity**: Medium
- **Issue Description**: Section 6 states "Sensitive data (passwords, payment details, passport numbers) should be redacted in logs" using the word "should," which implies a recommendation rather than a requirement. This creates ambiguity and increases the risk that developers will not implement proper redaction, leading to sensitive data exposure in logs.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the weak "should" language for log redaction as insufficient and recommends making it a mandatory requirement with specific enforcement mechanisms or logging framework configuration
  - △ (Partial Detection): Mentions log security or sensitive data in logs without specifically addressing the "should" vs "must" distinction or enforcement mechanisms
  - × (No Detection): No mention of logging security or sensitive data protection in logs

### P05: Database Credentials Storage Not Specified
- **Category**: Infrastructure Security
- **Severity**: Critical
- **Issue Description**: Section 2 and 6 mention database connections and environment-specific configuration via environment variables, but there is no specification of how database credentials (connection strings, passwords) are securely stored and accessed. Storing database credentials in plain text environment variables or configuration files is a critical security risk.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the lack of secure credential management specification and recommends specific solutions (AWS Secrets Manager, HashiCorp Vault, encrypted environment variables with KMS, etc.)
  - △ (Partial Detection): Mentions credential management or secrets management as a general security concern without specifically addressing database credentials or proposing concrete solutions
  - × (No Detection): No mention of credential or secrets management

### P06: Missing Authorization Check for Booking Modification
- **Category**: Authorization Design
- **Severity**: Critical
- **Issue Description**: Section 5 states "Users can only access their own bookings" for the GET operation, but does not explicitly specify authorization checks for the PUT (modify) and DELETE (cancel) booking endpoints. The PUT and DELETE endpoints require ownership verification to prevent unauthorized booking modifications or cancellations by malicious users who guess or enumerate booking IDs.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the missing authorization check specification for PUT/DELETE booking endpoints and recommends explicit ownership verification or access control policy for modification operations
  - △ (Partial Detection): Mentions authorization concerns or booking security without specifically addressing the PUT/DELETE endpoints' missing authorization specification
  - × (No Detection): No mention of authorization issues for booking modification or cancellation

### P07: Elasticsearch Access Control Not Specified
- **Category**: Infrastructure Security
- **Severity**: Medium
- **Issue Description**: Section 2 and 3 specify Elasticsearch 8.9 for flight/hotel search, but there is no mention of access control, authentication, or network isolation for the Elasticsearch cluster. Unauthenticated or publicly accessible Elasticsearch instances are a common source of data breaches.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the lack of Elasticsearch security specification (authentication, access control, network isolation, or encryption) and recommends specific security configurations
  - △ (Partial Detection): Mentions infrastructure security, database security, or data store access control without specifically addressing Elasticsearch
  - × (No Detection): No mention of Elasticsearch security or data store access control

### P08: JWT Token Storage Location Not Specified
- **Category**: Authentication Design
- **Severity**: Critical
- **Issue Description**: Section 5 specifies that JWT tokens are returned upon login and passed in the Authorization header, but does not specify where the token should be stored on the client side (web/mobile). Storing JWT tokens in localStorage (a common mistake) exposes them to XSS attacks. The design should explicitly recommend secure storage mechanisms (httpOnly cookies for web, secure keychain for mobile).
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the missing JWT token storage specification and recommends secure storage mechanisms (httpOnly cookies for web, secure keychain/keystore for mobile) with explicit warnings against localStorage
  - △ (Partial Detection): Mentions JWT token security concerns or client-side storage without specifically addressing storage location recommendations or XSS risk
  - × (No Detection): No mention of JWT token storage or client-side token security

### P09: Missing Input Validation Specification for Booking Data
- **Category**: Input Validation Design
- **Severity**: Medium
- **Issue Description**: Section 5 shows that booking creation accepts a JSONB field with arbitrary flight_details structure, and Section 4 shows bookings.booking_data as JSONB. There is no specification of schema validation or sanitization for this user-provided structured data, creating risk of injection attacks, data integrity issues, or excessive data storage.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the lack of input validation specification for JSONB fields (booking_data, flight_details) and recommends schema validation mechanisms (JSON schema, strict type checking, size limits, nested object depth limits)
  - △ (Partial Detection): Mentions input validation concerns or API security without specifically addressing the JSONB structured data validation gaps
  - × (No Detection): No mention of input validation for structured data or JSONB fields

### P10: Rate Limiting Insufficient for Brute Force Attacks
- **Category**: API Security
- **Severity**: Medium
- **Issue Description**: Section 7 specifies "Rate limiting: 100 requests per minute per user for search APIs" but does not specify rate limiting for authentication endpoints (login, password reset). Authentication endpoints are particularly vulnerable to brute force attacks and should have much stricter rate limits (e.g., 5-10 attempts per 15 minutes per IP/user).
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the lack of rate limiting specification for authentication endpoints (login, password reset, signup) and recommends specific, stricter limits for these endpoints compared to general API rate limits
  - △ (Partial Detection): Mentions rate limiting or authentication security without specifically addressing the missing rate limits for authentication endpoints
  - × (No Detection): No mention of rate limiting for authentication or brute force protection

## Bonus Issues

Bonus issues are not included in the embedded 10 problems but provide additional value if detected.

| ID | Category | Content | Bonus Condition |
|----|---------|---------|----------------|
| B01 | Data Protection | Database encryption at rest not specified for PostgreSQL storing sensitive travel and payment data | Points awarded if reviewer mentions database encryption at rest requirements |
| B02 | Monitoring | No specification of security monitoring, alerting, or intrusion detection for anomalous booking patterns or failed authentication attempts | Points awarded if reviewer mentions security monitoring, SIEM, or anomalous behavior detection |
| B03 | API Security | Missing specification of API request size limits or max JSON payload size, creating DoS risk | Points awarded if reviewer identifies missing request size/payload limits |
| B04 | Authorization Design | Role-based access control mentioned for admin endpoints but admin roles and permissions are not defined | Points awarded if reviewer identifies undefined admin role model or permission structure |
| B05 | Infrastructure Security | RabbitMQ message queue security (authentication, encryption, access control) not specified | Points awarded if reviewer mentions message queue security or event bus access control |
| B06 | Data Protection | No specification of PCI DSS compliance requirements or data retention policies for payment card data, despite integration with Stripe | Points awarded if reviewer mentions PCI DSS, payment compliance, or card data retention policies |
| B07 | Audit Trail | No specification of audit logging for sensitive operations (booking modifications, cancellations, payment refunds, admin actions) | Points awarded if reviewer mentions audit trails, audit logging, or compliance logging requirements |
