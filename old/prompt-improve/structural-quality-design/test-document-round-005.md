# RealEstateHub システム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
RealEstateHubは、不動産仲介業者向けの物件管理・マッチングプラットフォームです。複数の不動産業者が物件情報を登録・共有し、顧客の希望条件に基づいて最適な物件を自動推薦することで、業務効率化と成約率向上を目指します。

### 1.2 主要機能
- 物件情報の登録・更新・検索
- 顧客情報の管理と希望条件の登録
- AIによる物件マッチング・推薦
- 内見予約の管理
- 契約ステータスの追跡
- 業者間での物件情報共有
- ダッシュボードでの統計・レポート表示

### 1.3 対象ユーザーと利用シナリオ
- **不動産仲介業者**: 物件登録、顧客管理、マッチング、内見予約管理
- **システム管理者**: 業者アカウント管理、統計分析、システム監視
- **エンドユーザー（将来拡張）**: 物件検索、お気に入り登録、内見予約申込

## 2. 技術スタック

### 2.1 言語・フレームワーク
- **Backend**: Java 17 + Spring Boot 3.2
- **Frontend**: React 18 + TypeScript
- **API**: RESTful API

### 2.2 データベース
- **Primary DB**: PostgreSQL 15
- **Cache**: Redis 7.0
- **Full-text Search**: Elasticsearch 8.x

### 2.3 インフラ・デプロイ環境
- **Cloud**: AWS (ECS Fargate)
- **CI/CD**: GitHub Actions
- **Monitoring**: CloudWatch + Datadog

### 2.4 主要ライブラリ
- Spring Security (認証・認可)
- Spring Data JPA (ORM)
- Lombok (コード簡略化)
- MapStruct (DTO変換)
- JUnit 5 + Mockito (テスト)

## 3. アーキテクチャ設計

### 3.1 全体構成
RealEstateHubは3層アーキテクチャを採用します。

```
[Frontend (React)] <-- REST API --> [Backend (Spring Boot)]
                                           |
                                           v
                          [Service Layer] + [Repository Layer]
                                           |
                      +--------------------+--------------------+
                      |                    |                    |
                  [PostgreSQL]          [Redis]          [Elasticsearch]
```

### 3.2 主要コンポーネントの責務と依存関係

#### PropertyManagementService
物件登録、更新、検索を担当。内部で顧客マッチングロジック、内見予約の空き時間計算、契約ステータス更新、統計データ集計も実施。

```java
@Service
public class PropertyManagementService {
    @Autowired
    private PropertyRepository propertyRepository;
    @Autowired
    private CustomerRepository customerRepository;
    @Autowired
    private AppointmentRepository appointmentRepository;
    @Autowired
    private ContractRepository contractRepository;
    @Autowired
    private ElasticsearchTemplate elasticsearchTemplate;
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    public PropertyDTO createProperty(PropertyRequest request) {
        // property creation + cache update + elasticsearch indexing
    }

    public List<PropertyDTO> matchCustomers(Long propertyId) {
        // customer matching logic
    }

    public void updateContractStatus(Long propertyId, String status) {
        // contract status update + notification + statistics
    }
}
```

#### CustomerManagementService
顧客情報の登録・更新・検索、および希望条件の保存を担当。

```java
@Service
public class CustomerManagementService {
    @Autowired
    private CustomerRepository customerRepository;
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
}
```

#### NotificationService
メール、SMS、プッシュ通知の送信を担当。

```java
@Service
public class NotificationService {
    private final String smtpHost = "smtp.example.com";
    private final String smsApiKey = "sk_live_12345";

    public void sendEmail(String to, String subject, String body) {
        // Direct SMTP connection
    }

    public void sendSMS(String phoneNumber, String message) {
        // Direct SMS API call
    }
}
```

### 3.3 データフロー
1. Frontend → REST APIでリクエスト受信
2. Controller → Serviceに処理を委譲
3. Service → Repositoryでデータ操作 + Cache/Elasticsearch更新
4. Repository → PostgreSQLへアクセス
5. Service → DTOに変換してControllerに返却
6. Controller → JSONレスポンスをFrontendに返却

## 4. データモデル

### 4.1 主要エンティティと関連

#### Property（物件）
```sql
CREATE TABLE properties (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255),
    description TEXT,
    address VARCHAR(500),
    price DECIMAL(15, 2),
    area DECIMAL(10, 2),
    room_count INTEGER,
    broker_id BIGINT,
    status VARCHAR(50),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    available_from DATE,
    owner_name VARCHAR(255),
    owner_phone VARCHAR(20)
);
```

#### Customer（顧客）
```sql
CREATE TABLE customers (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(20),
    broker_id BIGINT,
    preferred_area VARCHAR(500),
    max_price DECIMAL(15, 2),
    min_area DECIMAL(10, 2),
    created_at TIMESTAMP
);
```

#### Appointment（内見予約）
```sql
CREATE TABLE appointments (
    id BIGSERIAL PRIMARY KEY,
    property_id BIGINT,
    customer_id BIGINT,
    broker_id BIGINT,
    appointment_date TIMESTAMP,
    status VARCHAR(50),
    created_at TIMESTAMP
);
```

#### Contract（契約）
```sql
CREATE TABLE contracts (
    id BIGSERIAL PRIMARY KEY,
    property_id BIGINT,
    customer_id BIGINT,
    broker_id BIGINT,
    contract_date TIMESTAMP,
    status VARCHAR(50),
    commission DECIMAL(15, 2),
    created_at TIMESTAMP
);
```

### 4.2 注意事項
- `properties`テーブルに物件オーナー情報（owner_name, owner_phone）を直接含める
- `customers`テーブルに希望条件（preferred_area, max_price, min_area）を直接含める
- 現時点では外部キー制約は設定せず、アプリケーション側でデータ整合性を管理

## 5. API設計

### 5.1 エンドポイント一覧

#### 物件管理
- `POST /properties/create` - 物件登録
- `PUT /properties/update/{id}` - 物件更新
- `DELETE /properties/delete/{id}` - 物件削除
- `GET /properties/search?query={keyword}` - 物件検索
- `GET /properties/{id}` - 物件詳細取得
- `POST /properties/{id}/match-customers` - 顧客マッチング実行

#### 顧客管理
- `POST /customers/create` - 顧客登録
- `PUT /customers/update/{id}` - 顧客更新
- `GET /customers/{id}` - 顧客詳細取得

#### 内見予約
- `POST /appointments/create` - 内見予約作成
- `PUT /appointments/update/{id}` - 内見予約更新
- `GET /appointments/{id}` - 内見予約詳細取得

#### 契約管理
- `POST /contracts/create` - 契約作成
- `PUT /contracts/status/{id}` - 契約ステータス更新
- `GET /contracts/{id}` - 契約詳細取得

### 5.2 リクエスト/レスポンス形式
全APIでJSON形式を使用。

**リクエスト例（物件登録）**:
```json
{
  "title": "新築マンション 3LDK",
  "description": "駅徒歩5分、南向き...",
  "address": "東京都渋谷区...",
  "price": 50000000,
  "area": 75.5,
  "roomCount": 3,
  "brokerId": 123
}
```

**レスポンス例（物件詳細）**:
```json
{
  "id": 456,
  "title": "新築マンション 3LDK",
  "description": "駅徒歩5分、南向き...",
  "address": "東京都渋谷区...",
  "price": 50000000,
  "area": 75.5,
  "roomCount": 3,
  "brokerId": 123,
  "status": "available",
  "createdAt": "2026-02-01T10:00:00Z"
}
```

### 5.3 認証・認可方式
- JWT（JSON Web Token）を使用
- ログイン時にJWTトークンを発行し、Cookieに保存
- 各APIリクエストでCookieからトークンを取得して検証
- Roleベースのアクセス制御（BROKER, ADMIN）

## 6. 実装方針

### 6.1 エラーハンドリング方針
- 全例外を`GlobalExceptionHandler`でキャッチし、JSON形式のエラーレスポンスを返却
- HTTPステータスコードで大まかなエラー種別を示す（400, 404, 500）
- エラーメッセージはユーザー向けの簡潔な説明とする

### 6.2 ロギング方針
- Spring Bootのデフォルトロギング（Logback）を使用
- ログレベルは環境ごとに設定ファイルで管理（dev: DEBUG, prod: INFO）
- 機密情報（パスワード、トークン）はログに出力しない

### 6.3 テスト方針
- 単体テスト: JUnit 5 + Mockito でServiceレイヤーをテスト
- 統合テスト: Spring Boot Test + TestContainersでRepository/API全体をテスト
- カバレッジ目標: 80%以上

### 6.4 デプロイメント方針
- GitHub ActionsでCI/CDパイプラインを構築
- mainブランチへのマージでステージング環境に自動デプロイ
- リリースタグ作成で本番環境にデプロイ
- Blue-Green deploymentで無停止デプロイを実現

## 7. 非機能要件

### 7.1 パフォーマンス目標
- API応答時間: 95パーセンタイルで200ms以下
- 物件検索: 1秒以内に結果を返却
- 同時接続数: 1000ユーザーまで対応

### 7.2 セキュリティ要件
- 通信はHTTPSで暗号化
- JWT認証の実装
- SQLインジェクション対策（Prepared Statement使用）
- XSS対策（入力値のサニタイゼーション）
- CSRF対策（Spring Securityのデフォルト設定を使用）

### 7.3 可用性・スケーラビリティ
- 目標稼働率: 99.5%以上
- ECS Fargateのオートスケーリングで負荷に応じてコンテナ数を調整
- RDSのMulti-AZ構成で可用性を確保
- Redisクラスタでキャッシュの冗長化
