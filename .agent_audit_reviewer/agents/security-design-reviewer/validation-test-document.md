# 暗号資産取引プラットフォーム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
個人投資家向けの暗号資産（仮想通貨）取引プラットフォームを構築する。ビットコイン、イーサリアムなど主要な暗号資産の現物取引・レバレッジ取引を提供し、高速な注文処理と豊富なチャート分析機能により競争力のある取引環境を実現する。

### 1.2 主要機能
- ユーザー向け機能: アカウント登録・KYC認証、入出金管理、現物/レバレッジ取引、チャート分析、取引履歴閲覧、アラート設定
- 管理者向け機能: ユーザー管理、取引監視、KYC審査、不正検知アラート、システム設定
- バックオフィス機能: コールドウォレット管理、流動性管理、レポート生成

### 1.3 対象ユーザーと利用シナリオ
- 個人投資家: Webブラウザまたはモバイルアプリから24時間365日取引を実行
- カスタマーサポート: 管理画面からユーザー問い合わせ対応、取引状況確認
- コンプライアンス担当: KYC審査、疑わしい取引の調査、当局報告用データ抽出

## 2. 技術スタック

### 2.1 言語・フレームワーク
- フロントエンド: Vue.js 3.4 (TypeScript)
- バックエンド: Go 1.22 (Gin framework)
- 取引エンジン: Rust 1.75（高速マッチングエンジン）

### 2.2 データベース
- プライマリDB: PostgreSQL 15（ユーザー情報、取引履歴）
- インメモリDB: Redis 7.2（注文ブック、セッション管理）
- 時系列DB: TimescaleDB（価格データ、パフォーマンスメトリクス）

### 2.3 インフラ・デプロイ環境
- クラウドプロバイダ: Google Cloud Platform
- コンテナオーケストレーション: Google Kubernetes Engine (GKE)
- メッセージブローカー: Apache Kafka 3.6
- CDN: Cloudflare

### 2.4 主要ライブラリ
- 認証: golang-jwt/jwt v5
- ORM: GORM v1.25
- WebSocket: gorilla/websocket v1.5
- バリデーション: go-playground/validator v10

## 3. アーキテクチャ設計

### 3.1 全体構成
マイクロサービスアーキテクチャを採用し、以下のサービスに分割する:
- フロントエンド: Vue.js SPA、React Nativeアプリ
- API Gateway: Kong Gateway（リクエストルーティング、レート制限、APIキー検証）
- Auth Service: ユーザー認証・認可、KYC管理
- Trading Service: 注文受付、約定処理、ポジション管理
- Wallet Service: 入出金処理、残高管理、ブロックチェーン連携
- Market Data Service: 価格フィード配信、チャートデータ提供
- Notification Service: メール・プッシュ通知、アラート配信

### 3.2 主要コンポーネントの責務と依存関係

#### API Gateway (Kong)
- 外部リクエストの受付とルーティング
- APIキーベースの認証（パブリックエンドポイント用）
- レート制限: 認証済みユーザー 1000 req/min、未認証 100 req/min
- リクエスト/レスポンスのロギング

#### Auth Service
- ユーザー登録、ログイン処理、JWT発行・検証
- 2段階認証（TOTP）の管理
- KYC申請受付・審査ワークフロー
- ロールベースアクセス制御（RBAC）: USER, ADMIN, COMPLIANCE

#### Trading Service
- 注文の受付・検証（残高チェック、注文制限チェック）
- Rust製マッチングエンジンへの注文転送
- 約定結果の受信・処理
- レバレッジポジション管理、強制決済処理

#### Wallet Service
- 暗号資産の入出金処理
- ホットウォレット・コールドウォレット間の資金移動
- ブロックチェーンノードとの連携（入金監視、出金トランザクション送信）
- 残高の集計・管理

### 3.3 データフロー

#### 取引フロー
1. ユーザーがログインしJWTを取得（有効期限15分）
2. WebSocketでTrading Serviceに接続し、JWTで認証
3. 注文送信 → Trading Serviceが検証 → Rustマッチングエンジンに転送
4. 約定発生 → Kafkaトピックに約定イベント配信
5. Trading Service、Wallet Serviceが約定を処理し残高更新
6. WebSocketで約定通知をユーザーに配信

#### 入出金フロー
1. ユーザーが入金申請 → Wallet Serviceがブロックチェーンアドレスを生成
2. バックグラウンドジョブがブロックチェーンを監視し、入金を検出
3. 指定承認数（Bitcoin: 3承認、Ethereum: 12承認）に達したら残高に反映
4. 出金申請 → KYC済み・2段階認証済みユーザーのみ実行可能
5. 管理者承認後、ホットウォレットからトランザクション送信

## 4. データモデル

### 4.1 主要エンティティと関連
- **User**: ユーザーアカウント（メールアドレス、パスワード、KYCステータス）
- **KYCDocument**: KYC書類（身分証明書、住所証明書、セルフィー画像）
- **Wallet**: ウォレット（通貨ごとの残高、入出金アドレス）
- **Order**: 注文（通貨ペア、注文種別、価格、数量、ステータス）
- **Trade**: 約定（約定価格、約定数量、手数料、タイムスタンプ）
- **Withdrawal**: 出金申請（送金先アドレス、金額、承認ステータス、トランザクションハッシュ）

### 4.2 テーブル設計

#### users テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PRIMARY KEY | ユーザーID |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| password_hash | VARCHAR(255) | NOT NULL | bcryptハッシュ |
| role | VARCHAR(20) | NOT NULL | ロール（USER, ADMIN, COMPLIANCE） |
| kyc_status | VARCHAR(20) | NOT NULL | KYCステータス（PENDING, APPROVED, REJECTED） |
| totp_secret | VARCHAR(100) | | TOTPシークレット（Base32エンコード） |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| last_login_at | TIMESTAMP | | 最終ログイン日時 |

#### kyc_documents テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PRIMARY KEY | ドキュメントID |
| user_id | UUID | FOREIGN KEY (users.id) | ユーザーID |
| document_type | VARCHAR(50) | NOT NULL | 書類種別（ID_CARD, PASSPORT, UTILITY_BILL） |
| file_path | TEXT | NOT NULL | S3上のファイルパス |
| upload_date | TIMESTAMP | NOT NULL | アップロード日時 |
| review_status | VARCHAR(20) | | 審査ステータス（PENDING, APPROVED, REJECTED） |

#### wallets テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PRIMARY KEY | ウォレットID |
| user_id | UUID | FOREIGN KEY (users.id) | ユーザーID |
| currency | VARCHAR(10) | NOT NULL | 通貨コード（BTC, ETH, USDT等） |
| balance | DECIMAL(30,18) | NOT NULL | 利用可能残高 |
| locked_balance | DECIMAL(30,18) | NOT NULL | ロック中残高（未約定注文分） |
| deposit_address | VARCHAR(100) | | 入金用アドレス |

#### orders テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PRIMARY KEY | 注文ID |
| user_id | UUID | FOREIGN KEY (users.id) | ユーザーID |
| symbol | VARCHAR(20) | NOT NULL | 通貨ペア（BTC_USDT等） |
| side | VARCHAR(10) | NOT NULL | 売買区分（BUY, SELL） |
| order_type | VARCHAR(20) | NOT NULL | 注文種別（MARKET, LIMIT） |
| price | DECIMAL(30,18) | | 指値価格 |
| quantity | DECIMAL(30,18) | NOT NULL | 注文数量 |
| filled_quantity | DECIMAL(30,18) | NOT NULL | 約定数量 |
| status | VARCHAR(20) | NOT NULL | ステータス（PENDING, FILLED, CANCELLED） |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### trades テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PRIMARY KEY | 約定ID |
| order_id | UUID | FOREIGN KEY (orders.id) | 注文ID |
| symbol | VARCHAR(20) | NOT NULL | 通貨ペア |
| price | DECIMAL(30,18) | NOT NULL | 約定価格 |
| quantity | DECIMAL(30,18) | NOT NULL | 約定数量 |
| fee | DECIMAL(30,18) | NOT NULL | 手数料 |
| executed_at | TIMESTAMP | NOT NULL | 約定日時 |

#### withdrawals テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PRIMARY KEY | 出金ID |
| user_id | UUID | FOREIGN KEY (users.id) | ユーザーID |
| currency | VARCHAR(10) | NOT NULL | 通貨コード |
| amount | DECIMAL(30,18) | NOT NULL | 出金額 |
| destination_address | VARCHAR(100) | NOT NULL | 送金先アドレス |
| tx_hash | VARCHAR(100) | | トランザクションハッシュ |
| status | VARCHAR(20) | NOT NULL | ステータス（PENDING, APPROVED, COMPLETED, REJECTED） |
| created_at | TIMESTAMP | NOT NULL | 申請日時 |
| approved_at | TIMESTAMP | | 承認日時 |

## 5. API設計

### 5.1 エンドポイント一覧

#### 認証API
- `POST /api/v1/auth/register` - 新規ユーザー登録
- `POST /api/v1/auth/login` - ログイン（JWTトークン発行）
- `POST /api/v1/auth/logout` - ログアウト
- `POST /api/v1/auth/totp/enable` - 2段階認証有効化
- `POST /api/v1/auth/totp/verify` - 2段階認証コード検証

#### KYC API
- `POST /api/v1/kyc/documents` - KYC書類アップロード
- `GET /api/v1/kyc/status` - KYC審査ステータス取得
- `PUT /api/v1/kyc/review/{id}` - KYC審査（管理者用）

#### ウォレットAPI
- `GET /api/v1/wallets` - ウォレット一覧取得
- `GET /api/v1/wallets/{currency}/balance` - 残高取得
- `POST /api/v1/deposits` - 入金申請
- `POST /api/v1/withdrawals` - 出金申請
- `GET /api/v1/withdrawals/{id}` - 出金ステータス確認

#### 取引API
- `POST /api/v1/orders` - 注文作成
- `DELETE /api/v1/orders/{id}` - 注文キャンセル
- `GET /api/v1/orders` - 注文一覧取得
- `GET /api/v1/trades` - 約定履歴取得
- `WebSocket /ws/trading` - リアルタイム取引・価格配信

#### マーケットデータAPI
- `GET /api/v1/markets/{symbol}/ticker` - ティッカー情報取得
- `GET /api/v1/markets/{symbol}/orderbook` - オーダーブック取得
- `GET /api/v1/markets/{symbol}/candles` - ローソク足データ取得

### 5.2 リクエスト/レスポンス形式

#### ログインリクエスト例
```json
POST /api/v1/auth/login
{
  "email": "trader@example.com",
  "password": "SecurePass123!",
  "totp_code": "123456"
}
```

#### ログインレスポンス例
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 900,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "trader@example.com",
    "kyc_status": "APPROVED"
  }
}
```

#### 注文作成リクエスト例
```json
POST /api/v1/orders
Authorization: Bearer {access_token}
{
  "symbol": "BTC_USDT",
  "side": "BUY",
  "order_type": "LIMIT",
  "price": "50000.00",
  "quantity": "0.1"
}
```

### 5.3 認証・認可方式
- JWTベースの認証を採用
- JWTペイロードにユーザーID、メールアドレス、ロール、発行時刻を含む
- アクセストークンの有効期限は15分
- リフレッシュトークンは実装しない（再ログインを要求する設計）
- WebSocket接続時は初回メッセージでJWTを送信し認証
- エンドポイントごとにミドルウェアでロールチェックを実施
- 機密操作（出金、API設定変更）は2段階認証コードの追加検証を必須とする

## 6. 実装方針

### 6.1 エラーハンドリング方針
- すべてのエラーは統一形式のJSONレスポンスとして返却
- HTTPステータスコードを適切に設定（400: Bad Request, 401: Unauthorized, 403: Forbidden, 404: Not Found, 500: Internal Server Error, 503: Service Unavailable）
- 本番環境ではスタックトレースを含めない（開発環境のみ含める）
- 金融系特有のエラー（残高不足、注文制限超過、市場休止中等）には専用のエラーコードを割り当て

エラーレスポンス形式:
```json
{
  "error": {
    "code": "INSUFFICIENT_BALANCE",
    "message": "Insufficient balance for this order",
    "field": "quantity"
  },
  "timestamp": "2025-02-16T12:00:00Z",
  "request_id": "req_abc123"
}
```

### 6.2 ロギング方針
- すべてのAPIリクエスト（メソッド、パス、レスポンスステータス、レスポンスタイム）をINFOレベルで記録
- 注文作成・約定・入出金など金融トランザクションは詳細ログを残す
- エラー発生時はERRORレベルで記録し、Sentryに送信
- ログは構造化JSON形式で出力し、Google Cloud Loggingに転送
- パフォーマンス分析用にAPI別のレスポンスタイム統計を記録

ログフォーマット例:
```json
{
  "timestamp": "2025-02-16T12:00:00Z",
  "level": "INFO",
  "service": "trading-service",
  "method": "POST",
  "path": "/api/v1/orders",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "order_id": "770e9500-f39c-52e5-b827-557766551111",
  "symbol": "BTC_USDT",
  "side": "BUY",
  "quantity": "0.1",
  "response_time_ms": 45
}
```

### 6.3 テスト方針
- ユニットテスト: Go標準testingパッケージ + testifyを使用し、カバレッジ80%以上を目標
- 統合テスト: TestcontainersでPostgreSQL・Redis・Kafkaを起動し、サービス間連携をテスト
- E2Eテスト: Playwrightで主要取引フローの自動テスト
- パフォーマンステスト: k6で注文処理スループット（目標10,000 orders/sec）を検証
- カオスエンジニアリング: Chaos Meshで障害注入テストを実施

### 6.4 デプロイメント方針
- GitHub ActionsでCI/CDパイプラインを構築
  - テスト実行 → Dockerイメージビルド → Google Container Registryにプッシュ
  - Kubernetesマニフェストを更新しArgoCD経由でデプロイ
- Blue/Greenデプロイメントにより、ダウンタイムなしでリリース
- データベースマイグレーションはGolang-migrateを使用し、デプロイ前に実行
- シークレット管理はGoogle Secret Managerを使用し、環境変数として注入

## 7. 非機能要件

### 7.1 パフォーマンス目標
- 注文受付API応答時間: 95パーセンタイルで100ms以内
- 約定処理レイテンシ: 10ms以内
- WebSocket配信遅延: 50ms以内
- 同時接続ユーザー数: 100,000人をサポート
- 注文処理スループット: 10,000 orders/sec

### 7.2 セキュリティ要件
- すべての通信をTLS 1.3で暗号化
- パスワードはbcryptアルゴリズム（コスト係数12）でハッシュ化
- KYC未完了ユーザーは取引を実行できない
- 出金は2段階認証必須とし、管理者承認ワークフローを経由
- API呼び出しにはレート制限を適用（認証済み 1000 req/min、未認証 100 req/min）
- SQLインジェクション対策としてプリペアドステートメント使用
- XSS対策として出力時にHTMLエスケープ処理を実施

### 7.3 可用性・スケーラビリティ
- 稼働率目標: 99.95%（月間ダウンタイム21分以内）
- GKEオートスケーリングを設定し、CPU使用率60%でスケールアウト
- データベースはMulti-AZ構成でレプリカを2台配置
- Redisはクラスタモードで3ノード構成
- 定期的なデータベースバックアップ（1日2回、90日間保持）
- ホットウォレットには総資産の10%以下を保持し、残りはコールドウォレットで管理

### 7.4 コンプライアンス要件
- 本人確認（KYC）およびアンチマネーロンダリング（AML）規制に準拠
- 疑わしい取引パターン（短期間の大量取引、異常な入出金等）を自動検知
- すべての金融トランザクションを7年間保管
- 定期的な外部セキュリティ監査（年1回以上）を実施
