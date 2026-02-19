# SwiftPay Digital Wallet Platform システム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
SwiftPay Digital Wallet Platformは、個人向けデジタルウォレットサービスです。ユーザーは複数の決済手段（クレジットカード、デビットカード、銀行口座）を登録し、オンライン/オフライン加盟店での支払い、個人間送金、チャージ・出金を一つのアプリで完結できます。金融庁の資金移動業の登録を前提とした設計です。

### 1.2 主要機能
- ウォレット残高管理（チャージ、出金、履歴照会）
- QRコード決済（店舗での支払い）
- オンライン決済（EC加盟店連携）
- 個人間送金（P2P）
- ポイント・キャンペーン管理
- 本人確認（eKYC）と不正検知

### 1.3 対象ユーザーと利用シナリオ
- 一般ユーザー: 日常的な支払い、送金、ポイント利用
- 加盟店: 決済受付、売上照会、返金処理
- カスタマーサポート: 問い合わせ対応、トランザクション調査
- リスク管理者: 不正取引の検知・凍結処理

---

## 2. 技術スタック

### 2.1 言語・フレームワーク
- バックエンド: Java 17 + Spring Boot 3.1
- モバイルアプリ: Flutter 3.13
- 管理画面: Next.js 14 + TypeScript

### 2.2 データベース
- メインDB: PostgreSQL 15（ユーザー情報、ウォレット残高、取引履歴）
- キャッシュ: Redis 7.0（セッション、レート制限カウンター）
- 検索: Elasticsearch 8.10（取引検索、不正検知ログ）

### 2.3 インフラ・デプロイ環境
- クラウド: AWS（ap-northeast-1, ap-northeast-3）
- コンテナ: EKS（Kubernetes 1.28）
- CI/CD: GitHub Actions + ArgoCD
- 外部サービス: Stripe（カード決済処理）、Liquid eKYC（本人確認）

### 2.4 主要ライブラリ
- Spring Security（認証・認可）
- Hibernate（ORM）
- Resilience4j（サーキットブレーカー、リトライ）
- Micrometer（メトリクス）

---

## 3. アーキテクチャ設計

### 3.1 全体構成
マイクロサービスアーキテクチャを採用し、以下のサービスで構成:

- **User Service**: ユーザー登録、プロフィール管理、eKYC
- **Wallet Service**: 残高管理、チャージ、出金
- **Payment Service**: 決済処理、QRコード生成
- **Transfer Service**: 個人間送金
- **Notification Service**: プッシュ通知、メール送信
- **Fraud Detection Service**: 不正検知、リスクスコアリング

各サービスはREST APIで通信し、非同期処理にはAWS SQSを使用。

### 3.2 主要コンポーネントの責務
- **API Gateway**: Kong（認証、レート制限、ルーティング）
- **サービス間通信**: HTTP/REST（同期）、SQS（非同期）
- **データ整合性**: Saga パターン（分散トランザクション）

### 3.3 データフロー

#### 決済フロー（QRコード決済）
1. ユーザーがアプリでQRコードを表示
2. 店舗がQRコードをスキャンし、金額入力
3. Payment Serviceが残高チェック
4. Wallet Serviceで残高減算
5. 加盟店の売上加算
6. Notification Serviceで通知送信

---

## 4. データモデル

### 4.1 主要エンティティ

#### users テーブル
```sql
CREATE TABLE users (
    user_id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    kyc_status VARCHAR(20), -- PENDING, VERIFIED, REJECTED
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### wallets テーブル
```sql
CREATE TABLE wallets (
    wallet_id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(user_id),
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### transactions テーブル
```sql
CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY,
    wallet_id UUID REFERENCES wallets(wallet_id),
    type VARCHAR(20), -- CHARGE, WITHDRAW, PAYMENT, TRANSFER
    amount DECIMAL(15, 2) NOT NULL,
    status VARCHAR(20), -- PENDING, COMPLETED, FAILED
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 4.2 データ整合性
- ウォレット残高はトランザクション単位で更新
- 同時アクセス制御は楽観的ロック（version列）を使用
- 決済失敗時は自動リトライを3回実施

---

## 5. API設計

### 5.1 エンドポイント一覧

#### ウォレット操作
- `POST /wallets/charge` - チャージ（カード/銀行口座）
- `POST /wallets/withdraw` - 出金
- `GET /wallets/balance` - 残高照会

#### 決済
- `POST /payments/qr` - QRコード決済
- `POST /payments/online` - オンライン決済
- `POST /payments/cancel` - 決済キャンセル

#### 送金
- `POST /transfers` - 個人間送金
- `GET /transfers/{id}` - 送金状況確認

### 5.2 認証・認可
- **認証方式**: OAuth 2.0 + JWT（有効期限1時間、Refresh Token有効期限7日間）
- **多要素認証**: SMS OTP（6桁、有効期限3分）
- **APIキー認証**: 加盟店向けAPI（X-API-Key ヘッダー）

認証トークンはlocalStorageに保存し、リクエストごとにAuthorizationヘッダーに付与。

### 5.3 レート制限
API Gatewayで以下のレート制限を設定:
- 一般ユーザー: 100 req/min
- 加盟店API: 1000 req/min
- 送金API: 10 req/min（不正利用防止）

---

## 6. 実装方針

### 6.1 エラーハンドリング
- 外部API（Stripe、Liquid eKYC）呼び出しには3回リトライを実施（指数バックオフ: 1秒、2秒、4秒）
- リトライ後も失敗した場合はエラーログを記録し、管理者に通知
- ユーザーへのエラーメッセージは詳細情報を含めず、「エラーが発生しました。しばらくしてからお試しください」と表示

### 6.2 ロギング方針
- **アクセスログ**: 全APIリクエスト（エンドポイント、ユーザーID、レスポンスタイム）
- **エラーログ**: 例外スタックトレース、リクエストパラメータ
- **監査ログ**: 決済、送金、出金などの金融取引（トランザクションID、ユーザーID、金額、タイムスタンプ）

ログはJSON形式でCloudWatch Logsに出力し、S3に30日間保管。

### 6.3 テスト方針
- **単体テスト**: JUnit 5、カバレッジ目標80%
- **統合テスト**: Testcontainersでデータベース・キャッシュを含むテスト
- **E2Eテスト**: Playwrightで主要フロー（決済、送金）を自動化

---

## 7. 非機能要件

### 7.1 パフォーマンス目標
- **API応答時間**: 95%ile < 300ms
- **同時接続**: 5000ユーザー
- **スループット**: 決済処理 500 TPS

### 7.2 セキュリティ要件
- **暗号化**: TLS 1.3（通信時）
- **パスワードハッシュ**: bcrypt（コストファクタ12）
- **機密データ**: クレジットカード番号はStripeに保存し、自システムでは保持しない（トークン化）
- **不正検知**: 1時間に10回以上の送金失敗でアカウント一時凍結

### 7.3 可用性・スケーラビリティ
- **SLA目標**: 99.9%（月間ダウンタイム43分以内）
- **Multi-AZ構成**: RDSはMulti-AZ、EKSは2つのAZに分散
- **Auto Scaling**: CPU使用率70%でPod数を増加（最小3、最大10）
- **災害復旧**: 障害時は待機系リージョン（ap-northeast-3）に手動切り替え（RTO 2時間、RPO 15分）

### 7.4 監視・アラート
- **メトリクス**: Prometheus + Grafana（CPU、メモリ、API応答時間、エラー率）
- **アラート条件**:
  - API エラー率 > 5%
  - 決済成功率 < 95%
  - DB接続プールの枯渇

---

## 8. 運用方針

### 8.1 デプロイメント
- **デプロイ頻度**: 週2回（火曜・木曜）
- **デプロイ方式**: Blue-Green Deployment
- **ロールバック**: 前バージョンのコンテナイメージを保持し、問題発生時に即座に切り戻し

### 8.2 データバックアップ
- **PostgreSQL**: RDS自動バックアップ（保持期間7日）+ 手動スナップショット（月次）
- **S3**: バージョニング有効化、ライフサイクルポリシーで90日後にGlacierに移行

### 8.3 災害復旧計画
- **RTO**: 2時間（待機系リージョンへの手動切り替え）
- **RPO**: 15分（RDSクロスリージョンレプリケーション）
- **復旧手順**: Runbookに記載（DNS切り替え、データベースプロモーション、アプリケーション再起動）

### 8.4 コンプライアンス
- 資金移動業の法令遵守（取引履歴10年保管）
- 個人情報保護法対応（本人同意取得、開示請求対応）
- PCI DSS準拠（カード情報の非保持化）
