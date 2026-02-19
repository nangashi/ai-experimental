# MediConnect システム設計書

## 1. 概要

### 1.1 プロジェクト概要

MediConnect は、医療機関向けの電子カルテ・遠隔診療プラットフォームである。患者情報の一元管理、医師による診療記録の作成・参照、患者とのビデオ診療、処方箋の電子化を主要機能として提供する。

### 1.2 対象ユーザー

| ロール | 説明 |
|--------|------|
| 患者 | アプリ経由でビデオ診療予約・参加、処方箋確認 |
| 医師 | 電子カルテ閲覧・記録、ビデオ診療実施、処方箋発行 |
| 医療事務員 | 患者登録、予約管理、請求処理 |
| システム管理者 | ユーザー管理、システム設定 |

### 1.3 ビジネス要件

- 日本の医療情報ガイドライン（厚生労働省）への準拠
- 複数医療機関（クリニック・病院）のマルチテナント対応
- ピーク時 5,000 同時接続のスケーラビリティ

---

## 2. 技術スタック

### 2.1 フロントエンド

- **Web**: React 18 / TypeScript
- **モバイル**: React Native（iOS/Android）
- **UIライブラリ**: Material UI v5

### 2.2 バックエンド

- **API**: Node.js 18 / Express 4.18
- **ビデオ通話**: WebRTC（Twilio Video SDK v2.27.0 を採用）
- **メッセージキュー**: AWS SQS

### 2.3 データストア

- **プライマリDB**: PostgreSQL 15
- **キャッシュ**: Redis 7
- **ファイルストレージ**: AWS S3（検査画像・処方箋 PDF）

### 2.4 インフラ

- **クラウド**: AWS（東京リージョン）
- **コンテナ**: Docker / ECS Fargate
- **CDN**: CloudFront
- **IaC**: Terraform

---

## 3. アーキテクチャ設計

### 3.1 全体構成

```
[患者/医師 クライアント]
        |
   [CloudFront]
        |
  [API Gateway]
        |
  [Application Layer (ECS Fargate)]
    ├── auth-service
    ├── patient-service
    ├── consultation-service
    └── prescription-service
        |
  [Data Layer]
    ├── PostgreSQL (RDS)
    ├── Redis
    └── S3
```

### 3.2 マルチテナント設計

テナント（医療機関）ごとにスキーマを分離したマルチスキーマ方式を採用する。各リクエストのテナント識別は、JWTトークンに含まれる `tenant_id` クレームに基づく。

サービス間通信は内部ネットワーク（VPC内）で行い、AWS内部エンドポイントを使用する。

### 3.3 API設計方針

RESTful API を基本とし、主要エンドポイントは以下の通り。

```
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
GET    /api/v1/patients/{id}
POST   /api/v1/patients/{id}/records
GET    /api/v1/patients/{id}/prescriptions
POST   /api/v1/consultations
PUT    /api/v1/consultations/{id}/join
POST   /api/v1/prescriptions
POST   /api/v1/files/upload
```

外部からのリクエストはすべて API Gateway を経由する。各エンドポイントのレスポンスは JSON 形式で返す。

---

## 4. データモデル

### 4.1 主要エンティティ

**patients テーブル**

| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | 主キー |
| tenant_id | UUID | テナントID |
| full_name | VARCHAR(100) | 氏名 |
| date_of_birth | DATE | 生年月日 |
| gender | VARCHAR(10) | 性別 |
| phone_number | VARCHAR(20) | 電話番号 |
| email | VARCHAR(255) | メールアドレス |
| insurance_number | VARCHAR(50) | 保険証番号 |
| created_at | TIMESTAMP | 作成日時 |

**medical_records テーブル**

| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | 主キー |
| patient_id | UUID | 患者ID |
| doctor_id | UUID | 担当医師ID |
| tenant_id | UUID | テナントID |
| record_date | DATE | 診療日 |
| diagnosis | TEXT | 診断内容 |
| soap_note | TEXT | SOAPノート |
| created_at | TIMESTAMP | 作成日時 |

**prescriptions テーブル**

| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | 主キー |
| medical_record_id | UUID | 診療記録ID |
| patient_id | UUID | 患者ID |
| medications | JSONB | 処方薬情報 |
| issued_at | TIMESTAMP | 発行日時 |
| pdf_url | VARCHAR(500) | PDF保存パス |

### 4.2 データ分類

システムが扱うデータは以下の通りである。

- 患者基本情報（氏名、生年月日、連絡先）
- 医療情報（診断結果、処方内容、検査結果）
- 保険情報（保険証番号、加入保険）
- 請求情報（診療費、支払履歴）

データの保持期間については法令（医療法施行規則第22条）の規定に従い、診療録は最低5年間保持する。削除方針は今後のフェーズで定義する予定である。

---

## 5. 認証・認可設計

### 5.1 認証フロー

認証には JWT（JSON Web Token）を使用する。

1. ユーザーがメールアドレス・パスワードでログイン
2. auth-service がパスワードをbcryptで検証（コスト係数12）
3. アクセストークン（有効期限: 24時間）とリフレッシュトークン（有効期限: 30日）を発行
4. クライアントはアクセストークンを `localStorage` に保存し、以降のAPIリクエストに `Authorization: Bearer` ヘッダーで付与する
5. アクセストークンの有効期限切れ時はリフレッシュトークンを使用して再発行

### 5.2 認可モデル

ロールベースアクセス制御（RBAC）を採用する。

| ロール | 権限 |
|--------|------|
| patient | 自分の診療記録・処方箋の閲覧、予約管理 |
| doctor | 担当患者の診療記録の閲覧・記録、処方箋発行 |
| staff | 患者登録・更新、予約管理 |
| admin | 全機能 + ユーザー管理 |

各 API エンドポイントには `role` ミドルウェアを設定し、対応するロールを持つユーザーのみアクセスを許可する。ただし、doctor ロールは `patient_id` パラメータによるフィルタリングなしに patient-service の全患者データを参照できる設計とする。

### 5.3 セッション管理

リフレッシュトークンは Redis に保存し、ユーザーIDをキーとしてトークン値を管理する。ログアウト時にはRedisからエントリを削除する。

---

## 6. データ保護

### 6.1 通信の暗号化

外部通信（クライアント〜CloudFront〜API Gateway）はすべて TLS 1.2 以上で暗号化する。VPC 内部の通信については内部ネットワークであるため平文で行う。

### 6.2 保存データの暗号化

PostgreSQL のデータはAWSのRDS暗号化（AES-256）により保護する。S3バケットはサーバーサイド暗号化（SSE-S3）を有効化する。

診断結果・処方内容などの医療機密情報については、アプリケーションレベルでの追加暗号化は行わず、RDS暗号化で十分と判断している。

### 6.3 個人情報の取り扱い

患者情報（PII）を含むログ出力については、エンジニアの判断に委ねる運用とする。システムの本番ログは CloudWatch Logs に集約する。

---

## 7. 入力検証・API セキュリティ

### 7.1 入力検証方針

すべてのAPIリクエストにおいて、フロントエンドで入力検証が完了した状態でAPIに送信される設計とする。バックエンドでは基本的な型チェック（JSONスキーマバリデーション）のみ実施する。

### 7.2 ファイルアップロード

患者の検査画像や書類アップロードは `/api/v1/files/upload` エンドポイントで受け付ける。S3 への保存前にウイルススキャンを実施する。ファイル種別・サイズの制限は実装フェーズで決定する。

### 7.3 CORS設定

API Gateway の CORS 設定は、開発効率を優先するため `Access-Control-Allow-Origin: *` を設定する。本番環境では必要に応じて絞り込みを検討する。

### 7.4 セッション系 API の保護

医師による処方箋発行（`POST /api/v1/prescriptions`）や患者情報更新（`PUT /api/v1/patients/{id}`）などのstate-changingな操作に対するリクエスト保護の設計は現フェーズのスコープ外とする。

---

## 8. インフラ・運用セキュリティ

### 8.1 シークレット管理

データベース接続情報・APIキーなどの機密設定値は AWS Secrets Manager で管理し、ECS タスク起動時に環境変数として注入する。

### 8.2 サードパーティ依存関係

使用するライブラリについては、開発時点でのバージョンを固定する。脆弱性情報の定期チェック方針は今後の運用フェーズで策定する予定である。

### 8.3 監査ログ

システムの操作履歴はアプリケーションログとして CloudWatch Logs に記録する。ログには操作ユーザーID、操作種別、タイムスタンプを含める。

### 8.4 ネットワークセキュリティ

- セキュリティグループによるポートアクセス制限
- RDS・Redis は VPC プライベートサブネットに配置
- NAT Gateway 経由での外部アクセス

### 8.5 認証エンドポイント保護

`/api/v1/auth/login` エンドポイントについては、高可用性を優先するため呼び出し制限は設けない設計とする。アカウントロック機能については別途検討する。

---

## 9. 非機能要件

### 9.1 可用性・冗長性

- RDS Multi-AZ 構成（フェイルオーバー対応）
- ECS サービスの最小タスク数: 2
- 目標稼働率: 99.9%

### 9.2 スケーラビリティ

- ECS Auto Scaling（CPU使用率70%でスケールアウト）
- CloudFront によるコンテンツキャッシュ
- ElastiCache による DB クエリキャッシュ

### 9.3 バックアップ

- RDS 自動バックアップ: 7日間保持
- S3 バージョニング有効化
- 定期的な復元テストは運用フェーズで計画

### 9.4 監視・アラート

- CloudWatch によるメトリクス監視
- エラー率・レイテンシのアラート設定
- ECS タスク異常終了時の通知
