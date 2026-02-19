# FoodConnect システム設計書

## 1. 概要

### プロジェクトの目的と背景
FoodConnectは、レストラン・小売店と顧客をつなぐフードデリバリープラットフォームです。ユーザーは複数の店舗から料理を注文し、配達パートナーを通じて配送を受けることができます。店舗側は在庫管理、メニュー登録、売上分析機能を利用できます。

### 主要機能
- 顧客向け: 店舗検索、メニュー閲覧、注文、決済、配達追跡
- 店舗向け: メニュー管理、注文受付、在庫管理、売上レポート
- 配達パートナー向け: 配達リクエスト受諾、配達完了報告、収益確認
- 管理者向け: ユーザー管理、紛争解決、プラットフォーム分析

### 対象ユーザーと利用シナリオ
- 顧客: モバイルアプリから注文、クレジットカードまたは電子マネーで決済
- 店舗スタッフ: タブレットアプリで注文受付・調理完了通知
- 配達パートナー: スマートフォンアプリで配達依頼を受け取り、リアルタイムで配達状況を更新
- 管理者: Webダッシュボードで全体監視

## 2. 技術スタック

- **言語・フレームワーク**: Java 17, Spring Boot 3.1, Kotlin
- **データベース**: PostgreSQL 15 (メインDB), Redis 7.0 (セッション・キャッシュ)
- **インフラ・デプロイ環境**: AWS (ECS Fargate, RDS, ElastiCache, S3, CloudFront)
- **主要ライブラリ**: Spring Security 6.1, Hibernate 6.2, Jackson 2.15

## 3. アーキテクチャ設計

### 全体構成
```
[Mobile App] --HTTPS--> [API Gateway] ---> [Backend Services]
                                            ├─ User Service
                                            ├─ Order Service
                                            ├─ Payment Service
                                            ├─ Delivery Service
                                            └─ Notification Service
                                     |
                                     v
                            [PostgreSQL, Redis]
```

### 主要コンポーネント
- **API Gateway**: ルーティング、レート制限
- **User Service**: ユーザー登録、認証、プロフィール管理
- **Order Service**: 注文作成、ステータス管理、履歴
- **Payment Service**: 決済処理、返金、トランザクション記録
- **Delivery Service**: 配達パートナーマッチング、位置情報追跡
- **Notification Service**: プッシュ通知、SMS、メール配信

### データフロー
1. 顧客が注文を作成 → Order Service
2. Order Service が Payment Service に決済リクエスト
3. 決済成功後、Order Service が店舗に通知
4. 調理完了後、Delivery Service が配達パートナーにマッチング
5. 配達完了時、Order Service がステータス更新、Notification Service が顧客に通知

## 4. データモデル

### 主要エンティティ

#### Users
| カラム | 型 | 制約 | 説明 |
|--------|---|------|------|
| id | UUID | PK | ユーザーID |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| password_hash | VARCHAR(255) | NOT NULL | パスワードハッシュ (bcrypt) |
| role | VARCHAR(50) | NOT NULL | CUSTOMER, RESTAURANT, DRIVER, ADMIN |
| phone | VARCHAR(20) | | 電話番号 |
| created_at | TIMESTAMP | NOT NULL | 登録日時 |

#### Orders
| カラム | 型 | 制約 | 説明 |
|--------|---|------|------|
| id | UUID | PK | 注文ID |
| customer_id | UUID | FK(users.id) | 顧客ID |
| restaurant_id | UUID | FK(restaurants.id) | 店舗ID |
| status | VARCHAR(50) | NOT NULL | PENDING, CONFIRMED, PREPARING, DELIVERING, COMPLETED, CANCELLED |
| total_amount | DECIMAL(10,2) | NOT NULL | 合計金額 |
| delivery_address | TEXT | NOT NULL | 配達先住所 |
| created_at | TIMESTAMP | NOT NULL | 注文日時 |

#### Payments
| カラム | 型 | 制約 | 説明 |
|--------|---|------|------|
| id | UUID | PK | 決済ID |
| order_id | UUID | FK(orders.id) | 注文ID |
| amount | DECIMAL(10,2) | NOT NULL | 決済金額 |
| payment_method | VARCHAR(50) | NOT NULL | CREDIT_CARD, E_WALLET |
| card_last4 | VARCHAR(4) | | カード下4桁 |
| status | VARCHAR(50) | NOT NULL | PENDING, COMPLETED, FAILED, REFUNDED |
| transaction_id | VARCHAR(255) | | 外部決済サービスのトランザクションID |
| created_at | TIMESTAMP | NOT NULL | 決済日時 |

## 5. API設計

### 認証
- **認証方式**: JWT (JSON Web Token)
- **トークン有効期限**: 24時間
- **リフレッシュトークン**: 30日間有効

### 主要エンドポイント

#### 認証・認可
```
POST /api/v1/auth/signup
  Request: { email, password, role }
  Response: { token, refreshToken, user }

POST /api/v1/auth/login
  Request: { email, password }
  Response: { token, refreshToken, user }

POST /api/v1/auth/password-reset
  Request: { email }
  Response: { message: "Reset link sent" }
```

#### 注文管理
```
GET /api/v1/orders
  Headers: Authorization: Bearer <token>
  Response: [ { id, status, totalAmount, ... } ]

POST /api/v1/orders
  Headers: Authorization: Bearer <token>
  Request: { restaurantId, items[], deliveryAddress }
  Response: { id, status, ... }

PATCH /api/v1/orders/{orderId}/status
  Headers: Authorization: Bearer <token>
  Request: { status }
  Response: { id, status, ... }
```

#### 決済
```
POST /api/v1/payments
  Headers: Authorization: Bearer <token>
  Request: { orderId, paymentMethod, cardToken }
  Response: { id, status, transactionId }
```

## 6. 実装方針

### エラーハンドリング方針
- すべての例外は `GlobalExceptionHandler` で集約処理
- クライアントにはエラーコード + メッセージを返却
- 内部エラー詳細（スタックトレース等）はログに記録

### ロギング方針
- アプリケーションログは JSON 形式で標準出力
- ログレベル: INFO (本番環境), DEBUG (開発環境)
- アクセスログには ユーザーID、リクエストパス、レスポンスステータス、処理時間 を記録

### テスト方針
- 単体テスト: JUnit 5 + Mockito
- 統合テスト: Spring Boot Test + Testcontainers
- カバレッジ目標: 80%以上

### デプロイメント方針
- Blue/Green デプロイメントで無停止デプロイ
- Docker イメージを ECR に保存、ECS Fargate でコンテナ実行
- RDS は Multi-AZ 構成
- 静的ファイル (画像、メニュー写真) は S3 + CloudFront 経由で配信

## 7. 非機能要件

### パフォーマンス目標
- API レスポンスタイム: 95%ile で 300ms 以内
- 注文ピーク時 (昼・夕方) に 1,000 req/sec を処理

### セキュリティ要件
- すべての通信は HTTPS で暗号化
- パスワードは bcrypt でハッシュ化
- API は JWT トークンによる認証必須（public エンドポイントを除く）

### 可用性・スケーラビリティ
- 可用性目標: 99.9% (年間ダウンタイム 8.76時間以内)
- オートスケーリング: CPU 使用率 70% で水平スケール
- データベースは Read Replica で読み取り負荷分散
