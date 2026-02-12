# Scoring Report: v013-baseline

## Run 1 Detection Matrix

| Problem ID | Category | Detection | Score | Evidence |
|-----------|----------|-----------|-------|----------|
| P01 | テーブル命名規約の混在 | ○ | 1.0 | Line 110-124: "user_review table uses singular naming... Recommendation: Rename user_review to user_reviews" - Correctly identifies user_review as singular vs existing plural convention and recommends user_reviews |
| P02 | タイムスタンプカラム命名規約の混在 | ○ | 1.0 | Lines 46-76: "Three different timestamp naming patterns... hotel_bookings: created/updated, car_rentals: createdAt/modifiedAt, user_review: created/updated. Existing: created_at, updated_at" - All three table timestamp inconsistencies identified with existing pattern comparison |
| P03 | 主キー命名規約の混在 | ○ | 1.0 | Lines 78-99: "Mixed primary key naming (simple id vs descriptive booking_id/review_id) and mixed types (BIGSERIAL vs UUID)... Existing: id BIGSERIAL, hotel_bookings: booking_id UUID, car_rentals: id BIGSERIAL, user_review: review_id UUID" - Both naming and type inconsistencies identified |
| P04 | 外部キーカラム命名規約の混在 | △ | 0.5 | Line 437-444: "Foreign Key Naming Convention Verification (Positive)... All new tables: user_id - CONSISTENT" - Identifies foreign keys but marks as positive finding, missing that car_rentals uses userId (camelCase) which is inconsistent with existing user_id pattern |
| P05 | API HTTPメソッド選択の不統一 | ○ | 1.0 | Lines 225-250: "Hotels use PUT for cancellation, Cars use DELETE... Existing: POST for cancellation... Recommendation: Standardize to POST" - Correctly identifies both cancellation method and search method inconsistencies (POST vs GET) with existing pattern |
| P06 | APIエンドポイント動詞命名規約の不統一 | ○ | 1.0 | Lines 252-275: "Hotels use /book endpoint, Cars use /reserve endpoint... Recommendation: Standardize to 'book' for all domains" - Correctly identifies /book vs /reserve inconsistency and recommends unification to existing pattern |
| P07 | HTTP通信ライブラリ選定の不一致 | ○ | 1.0 | Lines 162-190: "RestTemplate specified (line 40) while existing FlightBooker uses WebClient (line 270)... RestTemplate is in maintenance mode... Recommendation: Replace RestTemplate with WebClient" - Correctly identifies library conflict and notes existing pattern |
| P08 | エラーハンドリングパターンの不一致 | ○ | 1.0 | Lines 127-159: "Individual try-catch blocks in controller (lines 192-204) vs existing GlobalExceptionHandler (@RestControllerAdvice, line 268)... Critical architectural divergence... Recommendation: Remove individual try-catch, adopt GlobalExceptionHandler" - Correctly identifies pattern conflict with existing system |
| P09 | ログ形式の不一致 | ○ | 1.0 | Lines 192-222: "Plain text logging (line 212) vs existing JSON structured logs (line 269)... Prevents unified log aggregation... Recommendation: Adopt JSON structured logging" - Correctly identifies log format conflict with existing system |
| P10 | 環境変数命名規則の不一致 | ○ | 1.0 | Lines 342-375: "Environment Variable Naming Convention (Information Gap)... Existing: lowercase snake_case (line 271)... No environment variables documented... Recommendation: Document environment variable naming convention" - Correctly identifies missing documentation and existing pattern |

**Detection Score: 9.5 / 10**

---

## Run 1 Bonus/Penalty Assessment

### Bonus Candidates

| ID | Content | Assessment | Score |
|----|---------|------------|-------|
| B01 | car_rentalsテーブルのカラム命名がキャメルケースで統一されているが他テーブルはスネークケース | Issue #1 (lines 18-43): "car_rentals uses camelCase (userId, carId, pickupDate, totalPrice, createdAt, modifiedAt) while hotel_bookings and user_review use snake_case" - 検出 | +0.5 |
| B06 | ステータスカラム命名の不統一（status vs booking_status） | Issue #10 (lines 277-297): "hotel_bookings: booking_status VARCHAR(20), car_rentals: status VARCHAR(20)... Recommendation: Use simple 'status' for all tables" - 検出 | +0.5 |

### Penalty Candidates

| ID | Content | Assessment | Score |
|----|---------|------------|-------|
| - | None identified | No scope violations found | 0 |

**Bonus: +1.0 (2 items)**
**Penalty: -0.0 (0 items)**

---

## Run 1 Final Score

```
Detection Score: 9.5
Bonus: +1.0
Penalty: -0.0
Total: 10.5
```

---

## Run 2 Detection Matrix

| Problem ID | Category | Detection | Score | Evidence |
|-----------|----------|-----------|-------|----------|
| P01 | テーブル命名規約の混在 | ○ | 1.0 | Lines 164-182: "user_review table uses SINGULAR form... Existing: plural (flight_bookings, passengers) 100%... Recommendation: Rename user_review to user_reviews" - Correctly identifies singular vs plural inconsistency with existing pattern |
| P02 | タイムスタンプカラム命名規約の混在 | ○ | 1.0 | Lines 202-219: "Three different timestamp naming patterns... hotel_bookings: created/updated, car_rentals: createdAt/modifiedAt, user_review: created/updated. Existing: created_at/updated_at 100%... Proposed = 0% match existing" - All three table patterns identified with existing comparison |
| P03 | 主キー命名規約の混在 | ○ | 1.0 | Lines 141-161: "hotel_bookings: booking_id UUID, car_rentals: id BIGSERIAL, user_review: review_id UUID. Existing: BIGSERIAL 100%... Mixed primary key types prevent standardized ID generation... Recommendation: Standardize ALL to BIGSERIAL id" - Both naming and type inconsistencies identified |
| P04 | 外部キーカラム命名規約の混在 | ○ | 1.0 | Lines 184-199: "Foreign key columns use both user_id and userId... hotel_bookings: user_id, car_rentals: userId, user_review: user_id. Existing: {table_singular}_id pattern... Recommendation: Standardize ALL to snake_case user_id" - Correctly identifies userId (camelCase) in car_rentals as inconsistent with existing pattern |
| P05 | API HTTPメソッド選択の不統一 | ○ | 1.0 | Lines 236-254: "Hotels: PUT for cancel, Cars: DELETE for cancel. Existing: POST for all updates (line 266)... Recommendation: Standardize to POST /api/v1/{domain}/{resource}/{id}/cancel" - Correctly identifies both cancellation method inconsistencies with existing pattern. Also Lines 256-270 identify GET vs POST search inconsistency |
| P06 | APIエンドポイント動詞命名規約の不統一 | ○ | 1.0 | Lines 272-286: "Hotels: /hotels/book, Cars: /cars/reserve... Recommendation: Standardize to 'book' for all domains to align with existing /flights/book" - Correctly identifies /book vs /reserve inconsistency and recommends existing pattern |
| P07 | HTTP通信ライブラリ選定の不一致 | ○ | 1.0 | Lines 52-70: "RestTemplate specified (line 40) while existing uses WebClient (line 270)... RestTemplate is in maintenance mode... Recommendation: Replace RestTemplate with WebClient" - Correctly identifies library conflict with existing system |
| P08 | エラーハンドリングパターンの不一致 | ○ | 1.0 | Lines 14-31: "Individual try-catch in controllers (lines 192-204) vs existing GlobalExceptionHandler (@RestControllerAdvice, line 268)... Duplicates error handling logic... Recommendation: Adopt GlobalExceptionHandler pattern" - Correctly identifies pattern conflict with existing system |
| P09 | ログ形式の不一致 | ○ | 1.0 | Lines 34-50: "Plain text logging (lines 212-213) vs existing JSON structured logs (line 269)... Mixed log formats require two parsing configurations... Recommendation: Document JSON structured logging" - Correctly identifies log format conflict with existing system |
| P10 | 環境変数命名規則の不一致 | ○ | 1.0 | Lines 340-350: "Environment Variable Naming Convention Not Documented... Existing: lowercase snake_case (line 271)... Design doesn't document this... Recommendation: Add section documenting lowercase snake_case convention" - Correctly identifies missing documentation and existing pattern |

**Detection Score: 10.0 / 10**

---

## Run 2 Bonus/Penalty Assessment

### Bonus Candidates

| ID | Content | Assessment | Score |
|----|---------|------------|-------|
| B01 | car_rentalsテーブルのカラム命名がキャメルケースで統一されているが他テーブルはスネークケース | Issue C-4 (lines 72-96): "Three tables use three different column naming conventions... car_rentals: camelCase (userId, pickupDate, totalPrice) while hotel_bookings and user_review use snake_case... Dominant pattern: snake_case 100% existing" - 検出 | +0.5 |
| B06 | ステータスカラム命名の不統一（status vs booking_status） | Issue S-5 (lines 221-235): "hotel_bookings: booking_status, car_rentals: status... Prevents generic status tracking utilities. Recommendation: Standardize to 'status'" - 検出 | +0.5 |

### Penalty Candidates

| ID | Content | Assessment | Score |
|----|---------|------------|-------|
| - | None identified | No scope violations found | 0 |

**Bonus: +1.0 (2 items)**
**Penalty: -0.0 (0 items)**

---

## Run 2 Final Score

```
Detection Score: 10.0
Bonus: +1.0
Penalty: -0.0
Total: 11.0
```

---

## Summary Statistics

| Metric | Run 1 | Run 2 |
|--------|-------|-------|
| Detection Score | 9.5 | 10.0 |
| Bonus | +1.0 | +1.0 |
| Penalty | -0.0 | -0.0 |
| **Total Score** | **10.5** | **11.0** |
| **Mean** | | **10.75** |
| **SD** | | **0.25** |

---

## Detection Details

### P04 Analysis (Key Difference Between Runs)

**Run 1 (△ 0.5点)**:
- Line 437-444 identifies foreign keys but incorrectly marks as "positive finding"
- States "All new tables: user_id - CONSISTENT"
- **Missing**: Does not identify that car_rentals uses `userId` (camelCase) which violates existing `user_id` (snake_case) pattern
- Evidence: The review only checked table-level foreign key presence, not column naming case conventions

**Run 2 (○ 1.0点)**:
- Lines 184-199 correctly identifies the camelCase vs snake_case issue
- Explicitly states "car_rentals: userId" vs "hotel_bookings: user_id"
- Correctly references existing pattern "{table_singular}_id" (line 262)
- Provides correct recommendation: "Standardize ALL foreign keys to snake_case: user_id"

### Bonus Items Detection

Both runs successfully detected the same bonus items:
- B01 (car_rentals全カラムキャメルケース問題): Both runs identified this as a critical table-level naming inconsistency
- B06 (status vs booking_status不統一): Both runs identified this as a status column naming inconsistency

### Key Insight

Run 2's improvement (+0.5点) came from more thorough analysis of the car_rentals table's column naming. Run 1 correctly identified car_rentals columns as camelCase in Issue #1 but failed to apply this observation to the P04 foreign key check, treating foreign keys as a separate concern. Run 2 consistently applied the snake_case vs camelCase analysis across all column types including foreign keys.
