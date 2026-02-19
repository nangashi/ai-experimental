# メディカルデバイス管理プラットフォーム システム設計書

## 1. 概要

### プロジェクトの目的と背景
医療機関向けに、接続された医療デバイス（心電図モニター、血圧計、パルスオキシメーター等）のリアルタイム監視とデータ収集を行うクラウドプラットフォームを構築する。複数の病院・クリニックから同時に数千台のデバイスが接続され、バイタルサインのストリーミングデータを継続的に受信・蓄積する。

### 主要機能
- デバイスからのバイタルデータのリアルタイム受信（WebSocket経由）
- 患者モニタリングダッシュボード（複数デバイスの同時表示）
- 異常値アラート通知（医療スタッフへのリアルタイム通知）
- 過去データの検索・分析機能
- デバイス管理（登録、ステータス監視、ファームウェア更新）
- レポート生成（日次・週次の患者サマリ）

### 対象ユーザーと利用シナリオ
- 医師・看護師: 患者のリアルタイムモニタリング、過去データの閲覧
- 医療施設管理者: デバイスの稼働状況管理、レポート作成
- システム管理者: デバイスの登録・設定、システム監視

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: Java 17, Spring Boot 3.1
- フロントエンド: React 18, TypeScript 5.0
- リアルタイム通信: Spring WebSocket, STOMP protocol

### データベース
- メインDB: PostgreSQL 15（患者情報、デバイスマスタ、設定情報）
- 時系列データ: PostgreSQL（バイタルデータの蓄積）

### インフラ・デプロイ環境
- クラウド: AWS（EC2, RDS, S3）
- コンテナ: Docker, ECS（Fargate）
- ロードバランサ: Application Load Balancer
- オブジェクトストレージ: S3（レポートファイル、デバイスログ）

### 主要ライブラリ
- Spring Security（認証・認可）
- Spring Data JPA（データアクセス）
- Jackson（JSON処理）
- SockJS（WebSocketフォールバック）
- Chart.js（データ可視化）

## 3. アーキテクチャ設計

### 全体構成
```
[医療デバイス群]
    ↓ WebSocket
[ALB] → [WebSocket Server (ECS)] → [PostgreSQL (RDS)]
                ↓
          [REST API Server (ECS)]
                ↓
          [フロントエンド (S3 + CloudFront)]
```

### 主要コンポーネント
- **WebSocket Server**: デバイスからの接続を受け付け、バイタルデータをストリーム受信
- **REST API Server**: ダッシュボード用のデータ取得API、設定変更API
- **Alert Service**: 異常値を検知し、医療スタッフに通知
- **Report Generator**: 定期レポートの生成（バッチ処理）
- **Device Manager**: デバイスのステータス管理、ファームウェア更新

### データフロー
1. デバイスがWebSocket接続を確立（デバイスID認証）
2. バイタルデータ（JSON形式）を1秒間隔で送信
3. WebSocket Serverがデータを受信し、DBに即時保存
4. Alert Serviceが異常値を検知し、Pub/Sub経由で通知
5. ダッシュボードがREST APIでデータを定期ポーリング（5秒間隔）

## 4. データモデル

### 主要エンティティ

#### devices（デバイス管理）
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| device_id | VARCHAR(50) | PRIMARY KEY | デバイス固有ID |
| hospital_id | INTEGER | NOT NULL, FK | 所属病院ID |
| device_type | VARCHAR(20) | NOT NULL | デバイス種別（ECG, BP, SPO2） |
| patient_id | INTEGER | FK | 装着中の患者ID（NULLable） |
| status | VARCHAR(20) | NOT NULL | 稼働状態（ACTIVE, INACTIVE） |
| firmware_version | VARCHAR(20) | NOT NULL | ファームウェアバージョン |
| created_at | TIMESTAMP | NOT NULL | 登録日時 |

#### vital_data（バイタルデータ）
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| data_id | BIGSERIAL | PRIMARY KEY | データID |
| device_id | VARCHAR(50) | NOT NULL, FK | デバイスID |
| patient_id | INTEGER | NOT NULL, FK | 患者ID |
| timestamp | TIMESTAMP | NOT NULL | 測定時刻 |
| data_type | VARCHAR(20) | NOT NULL | データ種別 |
| value | NUMERIC(10,2) | NOT NULL | 測定値 |
| unit | VARCHAR(10) | NOT NULL | 単位 |

#### patients（患者情報）
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| patient_id | SERIAL | PRIMARY KEY | 患者ID |
| hospital_id | INTEGER | NOT NULL, FK | 所属病院ID |
| patient_name | VARCHAR(100) | NOT NULL | 患者氏名 |
| birth_date | DATE | NOT NULL | 生年月日 |
| admission_date | DATE | | 入院日 |

#### alert_rules（アラートルール）
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| rule_id | SERIAL | PRIMARY KEY | ルールID |
| data_type | VARCHAR(20) | NOT NULL | データ種別 |
| min_threshold | NUMERIC(10,2) | | 最小閾値 |
| max_threshold | NUMERIC(10,2) | | 最大閾値 |
| severity | VARCHAR(20) | NOT NULL | 重要度（HIGH, MEDIUM, LOW） |

## 5. API設計

### エンドポイント一覧

#### デバイス管理
- `GET /api/devices` - デバイス一覧取得
- `GET /api/devices/{deviceId}` - デバイス詳細取得
- `POST /api/devices` - デバイス登録
- `PUT /api/devices/{deviceId}` - デバイス情報更新
- `POST /api/devices/{deviceId}/assign` - 患者への割り当て

#### バイタルデータ
- `GET /api/patients/{patientId}/vitals` - 患者のバイタルデータ取得
- `GET /api/patients/{patientId}/vitals/latest` - 最新バイタルデータ取得
- `GET /api/patients/{patientId}/vitals/history` - 期間指定でのバイタル履歴取得

#### ダッシュボード
- `GET /api/dashboard/active-patients` - 監視中患者一覧
- `GET /api/dashboard/alerts` - アラート一覧

#### レポート
- `POST /api/reports/generate` - レポート生成リクエスト
- `GET /api/reports/{reportId}` - レポートダウンロード

### リクエスト/レスポンス例

```json
GET /api/patients/12345/vitals/latest

Response:
{
  "patientId": 12345,
  "deviceId": "ECG-001",
  "timestamp": "2026-02-11T10:30:45Z",
  "vitals": [
    {"type": "heart_rate", "value": 72, "unit": "bpm"},
    {"type": "blood_pressure_sys", "value": 120, "unit": "mmHg"},
    {"type": "blood_pressure_dia", "value": 80, "unit": "mmHg"}
  ]
}
```

### 認証・認可
- JWT認証（Bearer Token）
- ロールベースアクセス制御（ADMIN, DOCTOR, NURSE）
- デバイス認証は専用のAPIキー方式

## 6. 実装方針

### エラーハンドリング
- グローバル例外ハンドラ（@ControllerAdvice）で統一的なエラーレスポンス
- デバイス接続エラー時は自動再接続（exponential backoff）
- データベース接続エラー時はリトライ（最大3回）

### ロギング
- アクセスログ: ALBレベルでS3に保存
- アプリケーションログ: JSON形式でCloudWatch Logsに出力
- エラーログ: Slackに即時通知（CRITICAL以上）

### テスト方針
- 単体テスト: JUnit 5 + Mockito（カバレッジ80%以上）
- 統合テスト: TestContainers（DB, Redis）
- E2Eテスト: Selenium（主要フロー）
- 負荷テスト: JMeter（デバイス接続1000台同時）

### デプロイメント
- Blue/Greenデプロイメント（ECS）
- カナリアリリース（新バージョンを10%のトラフィックで先行検証）
- 自動ロールバック（ヘルスチェック失敗時）

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以下
- ダッシュボード更新遅延: 5秒以内
- デバイス接続数: 同時5000台対応
- データ書き込みスループット: 5000レコード/秒

### セキュリティ要件
- データ暗号化: 保存時（RDS暗号化）、通信時（TLS 1.3）
- アクセスログの保管: 3年間
- 個人情報の匿名化: レポート出力時
- 定期的な脆弱性診断（四半期ごと）

### 可用性・スケーラビリティ
- SLA: 99.9%稼働率
- RDSマルチAZ構成（自動フェイルオーバー）
- ECSタスク数の自動スケーリング（CPU使用率70%で追加）
- データベースリードレプリカ（読み取り負荷分散）
