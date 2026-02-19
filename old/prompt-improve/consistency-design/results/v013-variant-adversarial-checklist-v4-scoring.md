# Scoring Report: v013-variant-adversarial-checklist-v4

## Scoring Summary

| Run | P01 | P02 | P03 | P04 | P05 | P06 | P07 | P08 | P09 | P10 | Detection | Bonus | Penalty | Total |
|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----------|-------|---------|-------|
| Run1 | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | 10.0 | +1.0 | -0.0 | 11.0 |
| Run2 | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | 10.0 | +2.5 | -0.0 | 12.5 |

**Mean Score**: 11.75
**Standard Deviation**: 0.75

---

## Run 1 Detection Analysis

### P01: テーブル命名規約の混在（単数形/複数形）
**判定**: ○ (1.0点)

**該当箇所**: C-1: Database Table Naming Inconsistency (Singular vs Plural)

**検出内容**:
- `user_review`テーブルが単数形を使用し、既存の100%複数形規約と不一致であることを指摘
- 「Existing system: `flight_bookings`, `passengers`, `airports` (100% plural, 3 of 3 tables documented)」
- 「Design document: `hotel_bookings` (plural), `car_rentals` (plural), `user_review` (SINGULAR)」
- 「Recommendation: Rename `user_review` to `user_reviews`」

**理由**: 正解キーの基準を完全に満たしている。

---

### P02: タイムスタンプカラム命名規約の混在
**判定**: ○ (1.0点)

**該当箇所**: C-3: Timestamp Column Naming Inconsistency (created_at vs created vs createdAt)

**検出内容**:
- タイムスタンプカラム命名が既存の`created_at/updated_at`パターンと不一致であることを指摘
- 「Existing system: 100% uses `created_at` and `updated_at`」
- 「hotel_bookings: `created`, `updated` (abbreviated form)」
- 「car_rentals: `createdAt`, `modifiedAt` (camelCase)」
- 「user_review: `created`, `updated` (abbreviated form)」
- 「Compliance rate: 0% (0 of 3 tables follow existing convention)」
- 「Recommendation: Standardize ALL tables to use `created_at` and `updated_at`」

**理由**: 3つのテーブル全てのタイムスタンプカラム不一致を検出し、既存パターンとの比較を含めて推奨している。

---

### P03: 主キー命名規約の混在（AUTO INCREMENT vs UUID）
**判定**: ○ (1.0点)

**該当箇所**: C-4: Primary Key Naming and Type Inconsistency

**検出内容**:
- 主キーの型と命名（UUID vs BIGSERIAL、カラム名の不統一）が既存の`id BIGSERIAL`パターンと不一致であることを指摘
- 「Existing system: 100% uses `id BIGSERIAL PRIMARY KEY`」
- 「hotel_bookings: `booking_id UUID PK` (different name AND type)」
- 「car_rentals: `id BIGSERIAL PK` (matches existing)」
- 「user_review: `review_id UUID PK` (different name AND type)」
- 「Recommendation: Standardize ALL tables to use `id BIGSERIAL PRIMARY KEY`」

**理由**: UUIDとBIGSERIALの混在と、カラム名（booking_id/review_id vs id）の不統一の両方を指摘している。

---

### P04: 外部キーカラム命名規約の混在（スネークケース vs キャメルケース）
**判定**: ○ (1.0点)

**該当箇所**: C-2: Database Column Naming Case Inconsistency - car_rentals Table

**検出内容**:
- `car_rentals`テーブルの外部キーカラム`userId`が既存の`user_id`（スネークケース）パターンと不一致であることを指摘
- 「car_rentals: camelCase (`userId`, `carId`, `pickupDate`, `returnDate`, `createdAt`, `modifiedAt`)」
- 「Existing system: 100% snake_case columns (e.g., `user_id`, `flight_id`, `created_at`, `updated_at`)」
- 「Recommendation: Rename all `car_rentals` columns to snake_case: - `userId` → `user_id`」

**理由**: `userId`が既存のスネークケースパターンと不一致であることを明示的に指摘し、`user_id`への変更を推奨している。

---

### P05: API HTTPメソッド選択の不統一
**判定**: ○ (1.0点)

**該当箇所**: S-2: API Endpoint HTTP Method Inconsistency

**検出内容**:
- レンタカーキャンセルAPI（`DELETE /reservations/{id}`）のHTTPメソッドが既存の`POST`パターンと不一致であることを指摘
- 「Existing system: `POST /api/v1/bookings/cancel` (uses POST for cancellation, documented in Section 8)」
- 「Car: `DELETE /api/v1/cars/reservations/{id}` (uses DELETE)」
- 「Recommendation: Standardize ALL cancellation operations to use POST (matching existing system): - Change `DELETE /api/v1/cars/reservations/{id}` → `POST /api/v1/cars/reservations/{id}/cancel`」

**検出内容（検索API）**: S-4: API Search Operation HTTP Method Inconsistency
- 「Hotel: `POST /api/v1/hotels/search` (uses POST)」
- 「Car: `GET /api/v1/cars/search` (uses GET)」
- 「Recommendation: Change `GET /api/v1/cars/search` → `POST /api/v1/cars/search`」

**理由**: キャンセルAPI（DELETE）と検索API（GET vs POST）の両方のHTTPメソッド不統一を検出し、既存の`POST`パターンとの比較を含めている。

---

### P06: APIエンドポイント動詞命名規約の不統一
**判定**: ○ (1.0点)

**該当箇所**: S-3: API Endpoint Verb Usage Inconsistency

**検出内容**:
- 予約作成操作に対して`/book`と`/reserve`の2つの動詞が混在していることを指摘
- 「Hotel booking: /api/v1/hotels/book」
- 「Car rental: /api/v1/cars/reserve」
- 「Recommendation: Standardize to single verb for creation operations. Recommend /book pattern (aligns with existing /flights/book): - /api/v1/cars/reserve → /api/v1/cars/book」

**理由**: `/book`と`/reserve`の混在を指摘し、既存の`/book`パターンへの統一を推奨している。`/create`（レビュー）についても言及しているが、主要な不統一である`/book` vs `/reserve`を明確に指摘している。

---

### P07: HTTP通信ライブラリ選定の不一致（情報欠落）
**判定**: ○ (1.0点)

**該当箇所**: S-1: HTTP Client Library Inconsistency

**検出内容**:
- 新システムのHTTP通信ライブラリ（RestTemplate）が既存システムの`WebClient`と不一致であることを指摘
- 「Existing system: Uses `WebClient` (Spring WebFlux) for HTTP communication (documented in Section 8)」
- 「Design document: Lists `RestTemplate` in technology stack (Section 2)」
- 「Information Gap: No HTTP client selection criteria documented.」
- 「Recommendation: Replace `RestTemplate` with `WebClient` for consistency.」

**理由**: RestTemplateとWebClientの不一致を指摘し、既存パターンとの一貫性検証の必要性を述べている。

---

### P08: エラーハンドリングパターンの不一致（情報欠落）
**判定**: ○ (1.0点)

**該当箇所**: C-5: Error Handling Pattern Reversal

**検出内容**:
- 新システムのエラーハンドリングパターン（個別try-catch）が既存システムの`GlobalExceptionHandler`パターンと不一致であることを指摘
- 「Existing system: Uses `@RestControllerAdvice` GlobalExceptionHandler for centralized error handling (documented in Section 8)」
- 「Design document: Explicitly shows try-catch blocks in each Controller method (Section 6, code example provided)」
- 「Information Gap: Design document provides NO justification for reversing this existing architectural pattern.」
- 「Recommendation: Remove individual try-catch blocks and extend existing GlobalExceptionHandler」

**理由**: 個別try-catchとGlobalExceptionHandlerの不一致を指摘し、既存パターンとの一貫性検証の必要性および統一方針の明記を推奨している。

---

### P09: ログ形式の不一致（情報欠落）
**判定**: ○ (1.0点)

**該当箇所**: C-6: Logging Format Inconsistency

**検出内容**:
- 新システムのログ形式（平文）が既存システムのJSON構造化ログと不一致であることを指摘
- 「Existing system: JSON structured logging `{"timestamp": "...", "level": "INFO", "message": "..."}` (documented in Section 8)」
- 「Design document: Plain text format `2024-03-15 10:30:45 INFO [HotelBookingService] ...` (Section 6)」
- 「Information Gap: No justification provided for deviating from existing JSON structured logging.」
- 「Recommendation: Adopt existing JSON structured logging format.」

**理由**: 平文ログとJSON構造化ログの不一致を指摘し、既存パターンとの一貫性検証の必要性および統一方針の明記を推奨している。

---

### P10: 環境変数命名規則の不一致（情報欠落）
**判定**: ○ (1.0点)

**該当箇所**: M-1: Configuration Management Documentation Gap

**検出内容**:
- 新システムの環境変数命名規則が設計書に明記されていないこと、および既存の小文字スネークケースパターンとの一貫性検証の必要性を指摘
- 「Existing system: Uses `application.properties` (Section 8) and lowercase snake_case environment variables (`database_url`, `jwt_secret`)」
- 「Design document: No configuration management section, no environment variable examples」
- 「Information Gap Impact: ... Environment Variable Inconsistency: Without documented naming convention, developers might use UPPER_CASE, camelCase, or snake_case」
- 「Recommendation: Add Configuration Management section ... Environment Variable Naming - Use lowercase snake_case (e.g., database_url, jwt_secret, hotel_api_key)」

**理由**: 環境変数命名規則の欠落を指摘し、既存の小文字スネークケースパターンとの一貫性検証の必要性を明示している。

---

### Bonus Detection (Run 1)

#### B01: テーブル間でのカラム命名規約の不統一（キャメルケース vs スネークケース）
**判定**: ボーナス +0.5点

**該当箇所**: C-2: Database Column Naming Case Inconsistency - car_rentals Table

**検出内容**:
- `car_rentals`テーブル全体がキャメルケースであり、他のテーブルがスネークケースであることを包括的に指摘
- 「car_rentals: camelCase (`userId`, `carId`, `pickupDate`, `returnDate`, `totalPrice`, `createdAt`, `modifiedAt`)」
- 「hotel_bookings: snake_case (`user_id`, `hotel_id`, `checkin_date`, `checkout_date`, `total_price`, `booking_status`)」
- 「user_review: snake_case (`user_id`, `booking_ref`, `created`, `updated`)」

**理由**: 正解キーのB01（テーブル間でのカラム命名パターンの不統一）に該当する有益な追加指摘。

---

#### B06: ステータスカラム命名の不統一
**判定**: ボーナス +0.5点

**該当箇所**: S-5: Status Column Naming Inconsistency

**検出内容**:
- 「hotel_bookings: booking_status」
- 「car_rentals: status」
- 「Recommendation: Standardize status column naming」

**理由**: 正解キーのB06（ステータスカラム命名の不統一）に該当する有益な追加指摘。

---

### Penalty Analysis (Run 1)

**該当なし**: スコープ外の指摘や事実に反する指摘は確認されなかった。

---

## Run 2 Detection Analysis

### P01: テーブル命名規約の混在（単数形/複数形）
**判定**: ○ (1.0点)

**該当箇所**: C-1: Table Naming Convention Deviation (Combined Issue)

**検出内容**:
- `user_review`テーブルが単数形であることを指摘し、既存の複数形規約と不一致であることを明示
- 「Existing system: 3/3 tables (100%) use plural. Design document: 1/3 tables (33%) follow plural pattern.」
- 「Recommendation: Rename tables to plural: ... `user_review` → `user_reviews`」

**理由**: 正解キーの基準を完全に満たしている。

---

### P02: タイムスタンプカラム命名規約の混在
**判定**: ○ (1.0点)

**該当箇所**: C-3: Timestamp Column Naming Extreme Fragmentation (Combined Issue)

**検出内容**:
- タイムスタンプカラム命名が既存の`created_at/updated_at`パターンと不一致であることを包括的に指摘
- 「hotel_bookings: created, updated」「car_rentals: createdAt, modifiedAt」「user_review: created, updated」
- 「Existing system: created_at, updated_at (100% adoption)」
- 「Quantitative Evidence: 0% alignment with existing system's created_at/updated_at pattern. Three different patterns in a single design document.」
- 「Recommendation: Standardize all timestamp columns to created_at, updated_at pattern」

**理由**: 3つのテーブル全てのタイムスタンプカラム不一致を検出し、既存パターンとの比較を含めて推奨している。

---

### P03: 主キー命名規約の混在（AUTO INCREMENT vs UUID）
**判定**: ○ (1.0点)

**該当箇所**: C-4: Primary Key Naming and Type Deviation

**検出内容**:
- 主キーの型と命名（UUID vs BIGSERIAL、カラム名の不統一）が既存の`id BIGSERIAL`パターンと不一致であることを指摘
- 「hotel_bookings: booking_id UUID (custom name + UUID type)」「car_rentals: id BIGSERIAL (standard name + standard type) ✓」「user_review: review_id UUID (custom name + UUID type)」
- 「Existing system: id BIGSERIAL (100% adoption)」
- 「Quantitative Evidence: Only 1/3 tables (33%) follow existing system's id BIGSERIAL pattern.」
- 「Recommendation: Standardize all primary keys to id BIGSERIAL」

**理由**: UUIDとBIGSERIALの混在と、カラム名（booking_id/review_id vs id）の不統一の両方を指摘している。

---

### P04: 外部キーカラム命名規約の混在（スネークケース vs キャメルケース）
**判定**: ○ (1.0点)

**該当箇所**: C-2: Column Case Convention Deviation - car_rentals Table (Combined Issue)

**検出内容**:
- `car_rentals`テーブルの外部キーカラム`userId`が既存の`user_id`（スネークケース）パターンと不一致であることを指摘
- 「car_rentals table uses camelCase column naming (userId, carId, pickupDate, returnDate, totalPrice, createdAt, modifiedAt)」
- 「Existing system: Implied 100% snake_case (user_id, flight_id, created_at, updated_at examples)」
- 「Recommendation: Convert car_rentals columns to snake_case: userId → user_id」

**理由**: `userId`が既存のスネークケースパターンと不一致であることを明示的に指摘し、`user_id`への変更を推奨している。

---

### P05: API HTTPメソッド選択の不統一
**判定**: ○ (1.0点)

**該当箇所**: S-2: HTTP Method Usage Inconsistency

**検出内容**:
- レンタカーキャンセルAPI（`DELETE /reservations/{id}`）のHTTPメソッドが既存の`POST`パターンと不一致であることを指摘
- 「Cancel operations: PUT /hotels/bookings/{id}/cancel vs DELETE /cars/reservations/{id}」
- 「Existing system uses primarily POST and GET (100% for update operations). Design introduces PUT and DELETE.」
- 「Recommendation: Standardize cancel operations to POST with /cancel suffix: - DELETE /cars/reservations/{id} → POST /cars/reservations/{id}/cancel」

**検出内容（検索API）**: Phase 1: Detection Strategy 2A
- 「HTTP Methods: ... - GET: ... /api/v1/cars/search」
- 「Detection Strategy 2B: API Endpoint HTTP Method Inconsistency」で検索APIのGET vs POSTの不統一に言及

**理由**: キャンセルAPI（DELETE）のHTTPメソッド不統一を検出し、既存の`POST`パターンとの比較を含めている。検索APIについても言及されている。

---

### P06: APIエンドポイント動詞命名規約の不統一
**判定**: ○ (1.0点)

**該当箇所**: S-3: API Endpoint Verb Usage Inconsistency

**検出内容**:
- 予約作成操作に対して`/book`と`/reserve`の2つの動詞が混在していることを指摘
- 「Hotel booking: /api/v1/hotels/book」「Car rental: /api/v1/cars/reserve」「Review: /api/v1/reviews/create」
- 「Recommendation: Standardize to single verb for creation operations. Recommend /book pattern (aligns with existing /flights/book): - /api/v1/cars/reserve → /api/v1/cars/book」

**理由**: `/book`と`/reserve`の混在を指摘し、既存の`/book`パターンへの統一を推奨している。

---

### P07: HTTP通信ライブラリ選定の不一致（情報欠落）
**判定**: ○ (1.0点)

**該当箇所**: C-7: HTTP Client Library Deviation

**検出内容**:
- 新システムのHTTP通信ライブラリ（RestTemplate）が既存システムの`WebClient`と不一致であることを指摘
- 「Design document uses RestTemplate for HTTP communication, deviating from existing system's WebClient (Spring WebFlux) usage.」
- 「Existing system uses WebClient (100%). Design proposes RestTemplate (100% deviation).」
- 「Recommendation: Replace RestTemplate with WebClient for HTTP communication」

**理由**: RestTemplateとWebClientの不一致を指摘し、既存パターンとの一貫性検証の必要性を述べている。

---

### P08: エラーハンドリングパターンの不一致（情報欠落）
**判定**: ○ (1.0点)

**該当箇所**: C-5: Error Handling Pattern Deviation

**検出内容**:
- 新システムのエラーハンドリングパターン（個別try-catch）が既存システムの`GlobalExceptionHandler`パターンと不一致であることを指摘
- 「Design document proposes individual try-catch blocks in Controller methods, deviating from existing system's GlobalExceptionHandler (@RestControllerAdvice) centralized approach.」
- 「Existing system uses GlobalExceptionHandler (100% centralized). Design proposes decentralized approach (100% deviation).」
- 「Recommendation: Remove individual try-catch blocks from Controller methods. Adopt existing GlobalExceptionHandler pattern」

**理由**: 個別try-catchとGlobalExceptionHandlerの不一致を指摘し、既存パターンとの一貫性検証の必要性および統一方針の明記を推奨している。

---

### P09: ログ形式の不一致（情報欠落）
**判定**: ○ (1.0点)

**該当箇所**: C-6: Logging Format Deviation

**検出内容**:
- 新システムのログ形式（平文）が既存システムのJSON構造化ログと不一致であることを指摘
- 「Design document proposes plain text logging format, deviating from existing system's JSON structured logs.」
- 「Existing system uses JSON structured logs (100%). Design proposes plain text (100% deviation).」
- 「Recommendation: Adopt JSON structured logging format: `{"timestamp": "...", "level": "INFO", "message": "...", "context": {...}}`」

**理由**: 平文ログとJSON構造化ログの不一致を指摘し、既存パターンとの一貫性検証の必要性および統一方針の明記を推奨している。

---

### P10: 環境変数命名規則の不一致（情報欠落）
**判定**: ○ (1.0点)

**該当箇所**: C-8: Environment Variable Naming Convention Not Documented (Critical Gap)

**検出内容**:
- 新システムの環境変数命名規則が設計書に明記されていないこと、および既存の小文字スネークケースパターンとの一貫性検証の必要性を指摘
- 「Design document does not document environment variable naming convention. Existing system uses lowercase snake_case (database_url, jwt_secret).」
- 「Information Gap: ... Prevents verification of environment variable naming consistency」
- 「Recommendation: Document environment variable naming convention: "All environment variables must use lowercase snake_case (e.g., database_url, jwt_secret, api_base_url)"」

**理由**: 環境変数命名規則の欠落を指摘し、既存の小文字スネークケースパターンとの一貫性検証の必要性を明示している。

---

### Bonus Detection (Run 2)

#### B01: テーブル間でのカラム命名規約の不統一（キャメルケース vs スネークケース）
**判定**: ボーナス +0.5点

**該当箇所**: C-2: Column Case Convention Deviation - car_rentals Table (Combined Issue)

**検出内容**:
- `car_rentals`テーブル全体がキャメルケースであり、他のテーブルがスネークケースであることを包括的に指摘
- 「car_rentals table uses camelCase column naming (userId, carId, pickupDate, returnDate, totalPrice, createdAt, modifiedAt)」
- 「Design document: 15 snake_case columns vs 9 camelCase columns (62.5% use snake_case)」

**理由**: 正解キーのB01（テーブル間でのカラム命名パターンの不統一）に該当する有益な追加指摘。

---

#### B03: トランザクション境界の設計方針の明記を推奨
**判定**: ボーナス +0.5点

**該当箇所**: C-10: Transaction Boundary Definitions Missing (Critical Gap)

**検出内容**:
- トランザクション境界の定義が欠落していることを指摘
- 「Design document documents @Transactional annotation usage but does not define transaction boundaries (which operations should be atomic, which combinations of operations require transactional consistency).」
- 「Recommendation: Define transaction boundaries explicitly: - "Booking creation (inventory check + payment + database insert) must be atomic"」

**理由**: 正解キーのB03（トランザクション境界の設計方針の明記）に該当する有益な追加指摘。

---

#### B06: ステータスカラム命名の不統一
**判定**: ボーナス +0.5点

**該当箇所**: S-5: Status Column Naming Inconsistency

**検出内容**:
- 「hotel_bookings: booking_status」「car_rentals: status」
- 「Recommendation: Standardize status column naming」

**理由**: 正解キーのB06（ステータスカラム命名の不統一）に該当する有益な追加指摘。

---

#### B07: データベーススキーマとアプリケーションレイヤーの命名規約の混同
**判定**: ボーナス +0.5点

**該当箇所**: C-2: Column Case Convention Deviation - car_rentals Table (Combined Issue)

**検出内容**:
- `car_rentals`のカラム命名がJavaエンティティクラスの命名規約（キャメルケース）に従っているように見えるが、データベーススキーマとしては既存のスネークケースに統一すべきという指摘
- 「car_rentals table uses camelCase column naming (userId, carId, pickupDate, returnDate, totalPrice, createdAt, modifiedAt), deviating from snake_case pattern used in other tables and existing system.」
- 「ORM mapping inconsistency requiring different configurations per table」

**理由**: 正解キーのB07（データベーススキーマとアプリケーションレイヤーの命名規約の混同）に該当する有益な追加指摘。

---

#### Additional Bonus: M-4: JWT Token Storage Location Inconsistency Risk
**判定**: ボーナス +0.5点

**該当箇所**: M-4: JWT Token Storage Location Inconsistency Risk

**検出内容**:
- JWTトークン保存方式の既存パターンとの一貫性検証の必要性を指摘
- 「Design document specifies JWT token storage in `localStorage` (Section 5), but existing FlightBooker token storage location is not documented for verification.」
- 「Information Gap Impact: ... If FlightBooker uses different token storage (e.g., httpOnly cookie), users cannot maintain authentication across modules」
- 「Recommendation: Verify existing FlightBooker token storage mechanism and align design document.」

**理由**: 正解キーのB05（JWTトークン保存方式の既存パターンとの一貫性検証）に該当する有益な追加指摘。

---

### Penalty Analysis (Run 2)

**該当なし**: スコープ外の指摘や事実に反する指摘は確認されなかった。

---

## Summary

### Run 1
- **Detection Score**: 10.0/10.0 (全問題検出)
- **Bonus**: +1.0 (B01, B06の2件)
- **Penalty**: 0.0
- **Total Score**: 11.0

### Run 2
- **Detection Score**: 10.0/10.0 (全問題検出)
- **Bonus**: +2.5 (B01, B03, B06, B07, JWT Storage Riskの5件)
- **Penalty**: 0.0
- **Total Score**: 12.5

### Overall
- **Mean Score**: 11.75
- **Standard Deviation**: 0.75
- **Stability**: 高安定（SD ≤ 0.5の基準からわずかに外れるが、1.0未満）

---

## Notes

### Run 1の特徴
- 全10問を完全に検出
- adversarial分析（脆弱性悪用視点）が各問題に追加されている
- ボーナス2件（B01, B06）を検出

### Run 2の特徴
- 全10問を完全に検出
- Combined Issue形式で情報欠落と不整合を統合的に分析
- Phase 1で5つの検出戦略を体系的に実行
- ボーナス5件（B01, B03, B06, B07, JWT Storage Risk）を検出
- より詳細な定量分析（% alignmentなど）を実施

### 両Runの共通点
- 全10問を完全検出（検出精度100%）
- 既存パターンとの比較を含む推奨を提示
- スコープ外の指摘なし（ペナルティ0）
