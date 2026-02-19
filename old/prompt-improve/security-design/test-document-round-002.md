# デジタルウォレット決済システム 設計書

## 1. 概要

### プロジェクトの目的と背景
モバイルアプリベースのデジタルウォレット決済システムを構築する。ユーザーは銀行口座やクレジットカードを登録し、QRコード決済や個人間送金を行える。競合サービスとの差別化として、複数通貨対応と小規模店舗向けの簡易導入を重視する。

### 主要機能
- ユーザー登録・KYC（本人確認）
- 決済手段の登録（銀行口座、クレジットカード）
- QRコード決済（店舗支払い）
- 個人間送金（P2P送金）
- 取引履歴・残高照会
- 加盟店管理（店舗オーナー向け）

### 対象ユーザーと利用シナリオ
- **一般ユーザー**: アプリで決済・送金を行う
- **加盟店オーナー**: QRコードを発行し、決済を受け付ける
- **管理者**: 不正取引の検出・凍結、システム監視

---

## 2. 技術スタック

### 言語・フレームワーク
- **Backend**: Java 17 + Spring Boot 3.2
- **Frontend**: React Native（iOS/Android）
- **管理画面**: Next.js 14

### データベース
- **メインDB**: PostgreSQL 15（トランザクション管理）
- **キャッシュ**: Redis 7.2（セッション、レート制限）
- **ドキュメントストア**: MongoDB（監査ログ、KYC書類メタデータ）

### インフラ・デプロイ環境
- **ホスティング**: AWS（ECS Fargate、RDS、ElastiCache）
- **API Gateway**: AWS API Gateway
- **CI/CD**: GitHub Actions → ECR → ECS Blue/Green Deployment

### 主要ライブラリ
- Spring Security（認証・認可）
- Stripe API（クレジットカード決済処理）
- Plaid API（銀行口座連携）
- ZXing（QRコード生成）
- Lombok、MapStruct

---

## 3. アーキテクチャ設計

### 全体構成
3層アーキテクチャ + 外部API連携層
- **Presentation Layer**: REST API（Spring Web）
- **Business Logic Layer**: Service層（トランザクション境界）
- **Data Access Layer**: JPA Repository
- **External Integration Layer**: Stripe/Plaid クライアント

### 主要コンポーネント
- **AuthService**: ユーザー認証、JWT発行
- **PaymentService**: 決済処理、残高管理
- **TransferService**: P2P送金処理
- **MerchantService**: 加盟店QRコード生成・管理
- **TransactionHistoryService**: 取引履歴照会
- **FraudDetectionService**: 不正検出ルール実行（外部サービス連携も検討）

### データフロー
1. ユーザーがアプリで決済リクエスト
2. API Gateway → AuthService（JWT検証）
3. PaymentService → Stripe/Plaid APIで決済実行
4. トランザクション記録 → DB保存
5. 非同期で監査ログ書き込み（MongoDB）

---

## 4. データモデル

### 主要エンティティ

#### users
| カラム | 型 | 制約 | 備考 |
|--------|----|----|------|
| id | BIGINT | PK, AUTO_INCREMENT | |
| email | VARCHAR(255) | UNIQUE, NOT NULL | |
| password_hash | VARCHAR(255) | NOT NULL | bcrypt |
| phone_number | VARCHAR(20) | UNIQUE | E.164形式 |
| kyc_status | VARCHAR(20) | NOT NULL | pending/approved/rejected |
| created_at | TIMESTAMP | NOT NULL | |
| updated_at | TIMESTAMP | NOT NULL | |

#### payment_methods
| カラム | 型 | 制約 | 備考 |
|--------|----|----|------|
| id | BIGINT | PK, AUTO_INCREMENT | |
| user_id | BIGINT | FK(users.id), NOT NULL | |
| type | VARCHAR(20) | NOT NULL | card/bank_account |
| provider_token | VARCHAR(255) | NOT NULL | Stripe/Plaidトークン |
| last_four | VARCHAR(4) | | カード/口座の下4桁 |
| is_default | BOOLEAN | DEFAULT false | |
| created_at | TIMESTAMP | NOT NULL | |

#### transactions
| カラム | 型 | 制約 | 備考 |
|--------|----|----|------|
| id | UUID | PK | |
| user_id | BIGINT | FK(users.id), NOT NULL | |
| amount | DECIMAL(15, 2) | NOT NULL | |
| currency | VARCHAR(3) | NOT NULL | ISO 4217 |
| type | VARCHAR(20) | NOT NULL | payment/transfer/refund |
| status | VARCHAR(20) | NOT NULL | pending/completed/failed |
| merchant_id | BIGINT | FK(merchants.id), NULLABLE | |
| recipient_user_id | BIGINT | FK(users.id), NULLABLE | P2P送金時 |
| created_at | TIMESTAMP | NOT NULL | |

#### merchants
| カラム | 型 | 制約 | 備考 |
|--------|----|----|------|
| id | BIGINT | PK, AUTO_INCREMENT | |
| owner_user_id | BIGINT | FK(users.id), NOT NULL | |
| name | VARCHAR(255) | NOT NULL | |
| qr_code_data | TEXT | NOT NULL | 決済用QRコード文字列 |
| created_at | TIMESTAMP | NOT NULL | |

---

## 5. API設計

### エンドポイント一覧

#### 認証
- `POST /api/v1/auth/register` - 新規ユーザー登録
- `POST /api/v1/auth/login` - ログイン（JWT発行）
- `POST /api/v1/auth/refresh` - トークン更新

#### 決済
- `POST /api/v1/payments` - 決済実行
- `GET /api/v1/payments/{id}` - 決済詳細取得
- `POST /api/v1/payments/{id}/refund` - 返金処理

#### 送金
- `POST /api/v1/transfers` - P2P送金
- `GET /api/v1/transfers/{id}` - 送金詳細取得

#### 決済手段管理
- `POST /api/v1/payment-methods` - 決済手段登録
- `GET /api/v1/payment-methods` - 登録済み決済手段一覧
- `DELETE /api/v1/payment-methods/{id}` - 決済手段削除

#### 加盟店管理
- `POST /api/v1/merchants` - 加盟店登録
- `GET /api/v1/merchants/{id}/qrcode` - QRコード取得

### リクエスト/レスポンス形式
- Content-Type: `application/json`
- エラーレスポンス統一形式:
```json
{
  "error": "PAYMENT_FAILED",
  "message": "Insufficient funds",
  "timestamp": "2026-02-10T12:34:56Z"
}
```

### 認証・認可方式
- JWT（Access Token: 15分, Refresh Token: 7日）
- Authorizationヘッダーで `Bearer {token}` 形式
- トークンはlocalStorageに保存（フロントエンド）
- 加盟店APIは加盟店オーナーのみアクセス可能（ユーザー属性で判定）

---

## 6. 実装方針

### エラーハンドリング
- 統一例外ハンドラー（`@ControllerAdvice`）でエラーレスポンス生成
- ビジネスロジック例外は独自例外クラス（`PaymentException`, `TransferException`）
- 外部API障害時はリトライ3回（指数バックオフ）

### ロギング
- Logback + SLF4J
- 全APIリクエスト/レスポンスをINFOレベルで記録
- エラー発生時はスタックトレース含めERRORレベル
- 決済処理は専用ログファイルに分離

### テスト方針
- 単体テスト: JUnit 5 + Mockito（カバレッジ80%目標）
- 統合テスト: TestContainers（PostgreSQL, Redis）
- E2Eテスト: Playwright（主要フロー3パターン）

### デプロイメント方針
- Blue/Green Deployment（ダウンタイムゼロ）
- 本番デプロイは週1回（水曜日夜間）
- ロールバック可能な状態を維持（前バージョンイメージ保持）

---

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以内
- 同時接続数: 10,000ユーザー
- トランザクション処理: 1秒あたり100件

### セキュリティ要件
- PCI DSS準拠（クレジットカード情報は自システムに保存せず、Stripeトークン化）
- 通信はすべてHTTPS（TLS 1.3）
- パスワードはbcryptでハッシュ化（ストレッチング係数12）
- APIには適切なレート制限を設定する

### 可用性・スケーラビリティ
- SLA: 99.9%（月間ダウンタイム43分以内）
- Auto Scaling: CPU使用率70%でスケールアウト
- データベース: Multi-AZ構成（フェイルオーバー自動）
- 定期バックアップ: 1日1回（フルバックアップ）、7日間保持
