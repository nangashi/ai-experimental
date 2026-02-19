# Travel Booking Platform システム設計書

## 1. 概要

### プロジェクトの目的と背景
本プロジェクトは、ホテル・航空券・レンタカー・現地ツアーを一括予約できるオンライン旅行予約プラットフォームを構築する。既存の航空券予約システム（FlightBooker）と統合し、総合旅行プラットフォームへと進化させる。

### 主要機能
- ホテル検索・予約
- レンタカー予約
- 現地ツアー予約
- ユーザーレビュー・評価システム
- マルチ通貨対応の決済
- メール通知（予約確認、キャンセル通知）

### 対象ユーザー
- 個人旅行者（国内・海外）
- 法人ユーザー（出張予約）
- 旅行代理店パートナー

---

## 2. 技術スタック

### 言語・フレームワーク
- Backend: Java 17, Spring Boot 3.2
- Frontend: React 18, TypeScript 5.0

### データベース
- PostgreSQL 15

### インフラ・デプロイ環境
- AWS ECS (Fargate)
- AWS RDS (PostgreSQL)
- CloudFront + S3 (Frontend)

### 主要ライブラリ
- Spring Data JPA
- Spring Security + JWT
- RestTemplate (HTTP通信)
- Jackson (JSON処理)
- Lombok
- MapStruct (DTO変換)

---

## 3. アーキテクチャ設計

### 全体構成
レイヤー構成: **Presentation層 → Service層 → Repository層**

- **Presentation層**: REST API Controller
- **Service層**: ビジネスロジック、外部サービス連携
- **Repository層**: データアクセス、JPA Repositoryインターフェース

### 主要コンポーネントの責務

#### HotelBookingController
- エンドポイント: `/api/v1/hotels/*`
- 責務: ホテル検索・予約リクエストのハンドリング

#### HotelBookingService
- 責務: ホテル在庫確認、予約処理、決済連携
- 外部サービス連携: HotelInventoryAPI（外部ホテルシステム）

#### HotelBookingRepository
- 責務: hotel_booking テーブルへのCRUD操作

#### CarRentalController
- エンドポイント: `/api/v1/cars/*`
- 責務: レンタカー検索・予約リクエストのハンドリング

#### CarRentalService
- 責務: レンタカー在庫確認、予約処理、決済連携
- 外部サービス連携: CarRentalAPI（外部レンタカーシステム）

#### CarRentalRepository
- 責務: car_rentals テーブルへのCRUD操作

#### ReviewController
- エンドポイント: `/api/v1/reviews/*`
- 責務: レビュー投稿・取得リクエストのハンドリング

#### ReviewService
- 責務: レビュー投稿処理、不適切コンテンツフィルタリング

#### ReviewRepository
- 責務: user_review テーブルへのCRUD操作

---

## 4. データモデル

### 主要エンティティ

#### hotel_bookings テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|---|-----|-----|
| booking_id | UUID | PK | 予約ID |
| user_id | BIGINT | NOT NULL, FK → users(id) | ユーザーID |
| hotel_id | VARCHAR(100) | NOT NULL | ホテルID（外部システム） |
| checkin_date | DATE | NOT NULL | チェックイン日 |
| checkout_date | DATE | NOT NULL | チェックアウト日 |
| total_price | DECIMAL(10,2) | NOT NULL | 合計金額 |
| currency | VARCHAR(3) | NOT NULL | 通貨コード |
| booking_status | VARCHAR(20) | NOT NULL | 予約ステータス |
| created | TIMESTAMP | NOT NULL | 作成日時 |
| updated | TIMESTAMP | NOT NULL | 更新日時 |

#### car_rentals テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|---|-----|-----|
| id | BIGSERIAL | PK | レンタカー予約ID |
| userId | BIGINT | NOT NULL, FK → users(id) | ユーザーID |
| carId | VARCHAR(100) | NOT NULL | 車両ID（外部システム） |
| pickupDate | DATE | NOT NULL | 受取日 |
| returnDate | DATE | NOT NULL | 返却日 |
| totalPrice | DECIMAL(10,2) | NOT NULL | 合計金額 |
| currency | VARCHAR(3) | NOT NULL | 通貨コード |
| status | VARCHAR(20) | NOT NULL | 予約ステータス |
| createdAt | TIMESTAMP | NOT NULL | 作成日時 |
| modifiedAt | TIMESTAMP | NOT NULL | 更新日時 |

#### user_review テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|---|-----|-----|
| review_id | UUID | PK | レビューID |
| user_id | BIGINT | NOT NULL, FK → users(id) | ユーザーID |
| booking_ref | VARCHAR(50) | NOT NULL | 予約参照番号 |
| rating | INTEGER | NOT NULL CHECK (1-5) | 評価（1-5星） |
| comment | TEXT | NULL | コメント |
| created | TIMESTAMP | NOT NULL | 作成日時 |
| updated | TIMESTAMP | NOT NULL | 更新日時 |

---

## 5. API設計

### エンドポイント一覧

#### ホテル予約API
- `POST /api/v1/hotels/search` - ホテル検索
- `POST /api/v1/hotels/book` - ホテル予約作成
- `GET /api/v1/hotels/bookings/{booking_id}` - 予約詳細取得
- `PUT /api/v1/hotels/bookings/{booking_id}/cancel` - 予約キャンセル

#### レンタカー予約API
- `GET /api/v1/cars/search` - レンタカー検索
- `POST /api/v1/cars/reserve` - レンタカー予約作成
- `GET /api/v1/cars/reservations/{id}` - 予約詳細取得
- `DELETE /api/v1/cars/reservations/{id}` - 予約キャンセル

#### レビューAPI
- `POST /api/v1/reviews/create` - レビュー投稿
- `GET /api/v1/reviews/{review_id}` - レビュー取得
- `GET /api/v1/reviews/hotel/{hotel_id}` - ホテルのレビュー一覧

### リクエスト/レスポンス形式

すべてのAPIレスポンスは以下の形式:
```json
{
  "data": { ... },
  "error": null
}
```

エラー時:
```json
{
  "data": null,
  "error": {
    "code": "ERROR_CODE",
    "message": "エラーメッセージ"
  }
}
```

### 認証・認可方式
- JWT認証（Bearer Token）
- トークンはlocalStorageに保存
- トークン有効期限: 24時間

---

## 6. 実装方針

### エラーハンドリング方針
各Controllerメソッドで個別にtry-catchを実装し、例外をハンドリングする。

```java
@PostMapping("/book")
public ResponseEntity<?> createBooking(@RequestBody BookingRequest request) {
    try {
        BookingResponse response = bookingService.createBooking(request);
        return ResponseEntity.ok(new ApiResponse(response, null));
    } catch (ValidationException e) {
        return ResponseEntity.badRequest()
            .body(new ApiResponse(null, new ApiError("VALIDATION_ERROR", e.getMessage())));
    } catch (Exception e) {
        return ResponseEntity.internalServerError()
            .body(new ApiResponse(null, new ApiError("INTERNAL_ERROR", "予約処理に失敗しました")));
    }
}
```

### ロギング方針
SLF4J + Logbackを使用。ログレベル: INFO, WARN, ERROR

ログ形式（平文）:
```
2024-03-15 10:30:45 INFO [HotelBookingService] Creating booking for user 12345
2024-03-15 10:30:46 ERROR [HotelBookingService] Failed to create booking: Payment gateway timeout
```

### データアクセス方針
Spring Data JPAのRepositoryインターフェースを使用。
トランザクション管理は`@Transactional`アノテーションをServiceクラスのメソッドレベルで付与。

```java
@Service
public class HotelBookingService {
    @Transactional
    public BookingResponse createBooking(BookingRequest request) {
        // 予約処理
    }
}
```

### デプロイメント方針
- Blue/Green Deployment（ECS）
- ローリングアップデート戦略
- ヘルスチェックエンドポイント: `/actuator/health`

---

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以内
- 同時接続数: 5,000ユーザー
- データベースコネクションプール: 最大50接続

### セキュリティ要件
- HTTPS通信必須
- JWT認証
- CORS設定（許可オリジンリスト管理）
- 入力バリデーション（Bean Validation）

### 可用性・スケーラビリティ
- SLA: 99.5%以上
- Auto Scaling: CPU使用率70%でスケールアウト
- RDSマルチAZ構成
- CloudFrontによるキャッシング（静的コンテンツ）

---

## 8. 既存システムとの統合

### 既存FlightBookerシステムの技術スタック
- Database: PostgreSQL（テーブル名は複数形、例: `flight_bookings`, `passengers`, `airports`）
- 外部キー命名規約: `{参照先テーブル名単数形}_id`（例: `user_id`, `flight_id`）
- 主キー: AUTO INCREMENT BIGINT（例: `id BIGSERIAL PRIMARY KEY`）
- タイムスタンプカラム: `created_at`, `updated_at`
- API命名: 動詞を含むエンドポイント（例: `/api/v1/flights/book`, `/api/v1/bookings/cancel`）
- HTTPメソッド: 主にPOSTとGET（更新系もPOST）
- レスポンス形式: `{ "data": ..., "error": ... }`
- エラーハンドリング: GlobalExceptionHandler（@RestControllerAdvice）による集中管理
- ログ形式: JSON構造化ログ（`{"timestamp": "...", "level": "INFO", "message": "..."}`）
- HTTP通信: WebClient（Spring WebFlux）
- 環境変数命名: 小文字スネークケース（例: `database_url`, `jwt_secret`）
- 設定ファイル: application.properties
