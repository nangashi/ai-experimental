# オンライン診療予約システム システム設計書

## 1. 概要

### プロジェクトの目的と背景
地域医療機関向けのオンライン診療予約システムを構築する。患者が24時間いつでも診療予約を行い、医療機関側は予約管理と診察準備を効率化することを目指す。

### 主要機能
- 患者による診療予約の作成・変更・キャンセル
- 医師のスケジュール管理と予約枠設定
- 診察券QRコード発行
- 診察履歴の閲覧
- 予約リマインダー通知（メール・SMS）
- 管理者による医療機関・医師マスタ管理

### 対象ユーザーと利用シナリオ
- **患者**: スマートフォンアプリまたはWebブラウザから予約操作
- **医師**: タブレット端末から診察スケジュールと患者情報を確認
- **医療機関スタッフ**: PC端末から予約状況の確認と調整
- **システム管理者**: 管理画面からマスタデータメンテナンス

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: Java 17 + Spring Boot 3.1
- フロントエンド: TypeScript + React 18
- モバイルアプリ: React Native

### データベース
- メインDB: PostgreSQL 15
- セッションストア: Redis 7

### インフラ・デプロイ環境
- クラウド: AWS
- コンピュート: ECS Fargate（コンテナ実行）
- ロードバランサー: ALB
- ストレージ: S3（画像保存）

### 主要ライブラリ
- 認証: Spring Security + JWT
- ORM: Spring Data JPA (Hibernate)
- API仕様: OpenAPI 3.0
- 通知: Amazon SNS (メール・SMS)

## 3. アーキテクチャ設計

### 全体構成
```
[患者アプリ] ─┐
[医師アプリ] ─┼→ [ALB] → [API Gateway] → [Application Server (ECS)]
[管理画面]  ─┘                                    ↓
                                          [PostgreSQL]
                                          [Redis]
                                          [S3]
```

レイヤー構成:
- Presentation Layer: REST API Controller
- Application Layer: Service (ビジネスロジック)
- Domain Layer: Entity, Repository
- Infrastructure Layer: DB接続, 外部API連携

### 主要コンポーネントの責務
- **AppointmentService**: 予約作成・変更・キャンセル処理
- **ScheduleService**: 医師スケジュール管理と予約枠の生成
- **NotificationService**: メール・SMS通知の送信
- **PatientService**: 患者情報管理
- **AuthService**: 認証・認可処理

### データフロー
1. 患者が予約リクエストを送信
2. API Gatewayが認証トークンを検証
3. AppointmentServiceが予約可能性をチェック
4. 予約データをPostgreSQLに保存
5. NotificationServiceが確認メールを送信

## 4. データモデル

### 主要エンティティ

#### patients (患者)
| カラム | 型 | 制約 | 備考 |
|-------|---|-----|------|
| patient_id | BIGINT | PK, AUTO_INCREMENT | |
| name | VARCHAR(100) | NOT NULL | |
| email | VARCHAR(255) | UNIQUE, NOT NULL | |
| phone | VARCHAR(20) | NOT NULL | |
| birth_date | DATE | NOT NULL | |
| created_at | TIMESTAMP | NOT NULL | |

#### doctors (医師)
| カラム | 型 | 制約 | 備考 |
|-------|---|-----|------|
| doctor_id | BIGINT | PK, AUTO_INCREMENT | |
| clinic_id | BIGINT | FK(clinics) | |
| name | VARCHAR(100) | NOT NULL | |
| specialty | VARCHAR(50) | NOT NULL | 診療科 |
| email | VARCHAR(255) | UNIQUE, NOT NULL | |

#### appointments (予約)
| カラム | 型 | 制約 | 備考 |
|-------|---|-----|------|
| appointment_id | BIGINT | PK, AUTO_INCREMENT | |
| patient_id | BIGINT | FK(patients), NOT NULL | |
| doctor_id | BIGINT | FK(doctors), NOT NULL | |
| appointment_date | DATE | NOT NULL | |
| time_slot | TIME | NOT NULL | |
| status | VARCHAR(20) | NOT NULL | scheduled/completed/cancelled |
| symptoms | TEXT | | |
| created_at | TIMESTAMP | NOT NULL | |

#### medical_records (診察履歴)
| カラム | 型 | 制約 | 備考 |
|-------|---|-----|------|
| record_id | BIGINT | PK, AUTO_INCREMENT | |
| patient_id | BIGINT | FK(patients), NOT NULL | |
| doctor_id | BIGINT | FK(doctors), NOT NULL | |
| appointment_id | BIGINT | FK(appointments), UNIQUE | |
| diagnosis | TEXT | NOT NULL | 診断内容 |
| prescription | TEXT | | 処方内容 |
| created_at | TIMESTAMP | NOT NULL | |

## 5. API設計

### エンドポイント一覧

#### 予約関連
- `POST /api/appointments` - 予約作成
- `GET /api/appointments/{id}` - 予約詳細取得
- `PUT /api/appointments/{id}` - 予約変更
- `DELETE /api/appointments/{id}` - 予約キャンセル
- `GET /api/appointments?patient_id={id}` - 患者の予約一覧取得
- `GET /api/appointments?doctor_id={id}&date={date}` - 医師の日別予約一覧取得

#### 診察履歴関連
- `GET /api/medical-records?patient_id={id}` - 患者の診察履歴一覧取得
- `GET /api/medical-records/{id}` - 診察履歴詳細取得

#### スケジュール関連
- `GET /api/schedules/available-slots?doctor_id={id}&date={date}` - 予約可能枠取得

### リクエスト/レスポンス形式

#### POST /api/appointments
Request:
```json
{
  "patient_id": 123,
  "doctor_id": 456,
  "appointment_date": "2026-03-15",
  "time_slot": "10:00",
  "symptoms": "発熱と咳"
}
```

Response:
```json
{
  "appointment_id": 789,
  "status": "scheduled",
  "created_at": "2026-02-11T12:00:00Z"
}
```

### 認証・認可方式
- JWT (JSON Web Token) をAuthorizationヘッダーで送信
- トークン有効期限: 24時間
- リフレッシュトークンによる自動更新機能あり

## 6. 実装方針

### エラーハンドリング方針
- ビジネスロジック例外は独自例外クラス（AppointmentException等）で表現
- @ControllerAdviceによるグローバル例外ハンドリング
- エラーレスポンス形式:
```json
{
  "error_code": "APPOINTMENT_NOT_AVAILABLE",
  "message": "指定された時間枠は既に予約済みです",
  "timestamp": "2026-02-11T12:00:00Z"
}
```

### ロギング方針
- SLF4J + Logback使用
- ログレベル: ERROR (システムエラー), WARN (予約競合等), INFO (API呼び出し), DEBUG (開発用)
- リクエストID（X-Request-ID）をMDCに格納し、全ログに出力

### テスト方針
- 単体テスト: JUnit 5 + Mockito
- 統合テスト: @SpringBootTest + TestContainers (PostgreSQL)
- E2Eテスト: Playwright (フロントエンド)
- カバレッジ目標: 行カバレッジ80%以上

### デプロイメント方針
- CI/CD: GitHub Actions
- ブルーグリーンデプロイメント
- ヘルスチェック: `/actuator/health` エンドポイント
- ロールバック: 前バージョンのタスク定義に切り戻し

## 7. 非機能要件

### セキュリティ要件
- 個人情報の暗号化保存（患者氏名、電話番号、メールアドレス）
- HTTPS通信必須
- SQLインジェクション対策（ParameterizedQueryの使用）
- CSRF対策（トークン検証）

### 可用性・スケーラビリティ
- 稼働率目標: 99.5% (月間ダウンタイム3.6時間以内)
- 同時接続数: 最大500セッション
- 水平スケーリング: ECSタスク数の自動増減（CPU使用率70%を閾値）
