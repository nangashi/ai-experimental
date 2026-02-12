# SmartHealth IoT Platform システム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
SmartHealth IoT Platformは、医療機関向けのリアルタイムバイタルモニタリングシステムです。患者の心拍数、血圧、体温、血中酸素濃度などのバイタルデータをウェアラブルデバイスから収集し、医療スタッフに異常値のアラートを提供します。

### 1.2 主要機能
- デバイスからのバイタルデータ収集（MQTT経由）
- リアルタイムアラート生成と配信
- 患者データの時系列分析とダッシュボード表示
- 医療スタッフ向けモバイルアプリ連携
- 監査ログとコンプライアンスレポート

### 1.3 対象ユーザーと利用シナリオ
- 看護師: 複数患者のバイタル監視、緊急アラート対応
- 医師: 患者の長期的なバイタルトレンド分析
- システム管理者: デバイス登録、ユーザー管理、監査ログ確認

---

## 2. 技術スタック

### 2.1 言語・フレームワーク
- バックエンド: Java 17 + Spring Boot 3.1
- フロントエンド: React 18 + TypeScript
- IoTゲートウェイ: Python 3.11 + FastAPI

### 2.2 データベース
- メインDB: PostgreSQL 15（患者マスタ、デバイス管理）
- 時系列DB: InfluxDB 2.7（バイタルデータ）
- キャッシュ: Redis 7.0（セッション、アラートキュー）

### 2.3 インフラ・デプロイ環境
- クラウド: AWS（ap-northeast-1）
- コンテナ: Docker + ECS Fargate
- メッセージング: AWS IoT Core（MQTTブローカー）
- ストレージ: S3（監査ログ、バックアップ）

### 2.4 主要ライブラリ
- Spring Data JPA（ORM）
- Lombok（ボイラープレート削減）
- Micrometer + Prometheus（メトリクス収集）
- SLF4J + Logback（ログ出力）

---

## 3. アーキテクチャ設計

### 3.1 全体構成
```
[ウェアラブルデバイス] → [AWS IoT Core] → [IoTゲートウェイ(FastAPI)]
                                                ↓
                                         [Kafkaキュー]
                                                ↓
                           ┌───────────────────────────────┐
                           │ バックエンド (Spring Boot)    │
                           │ - データ取り込みサービス      │
                           │ - アラート判定サービス        │
                           │ - REST API                    │
                           └───────────────────────────────┘
                                    ↓           ↓
                              [PostgreSQL]  [InfluxDB]
                                                ↓
                                      [React Dashboard]
```

### 3.2 主要コンポーネント

#### IoTゲートウェイ (FastAPI)
- AWS IoT CoreからMQTTメッセージを受信
- デバイス認証とデータ検証
- Kafkaへのメッセージ送信

#### データ取り込みサービス (Spring Boot)
- Kafkaコンシューマー（バイタルデータ）
- InfluxDBへの時系列データ書き込み
- バッチ処理による異常値検出

#### アラート判定サービス (Spring Boot)
- リアルタイムストリーム処理（Kafka Streams）
- 閾値ベースのアラート生成
- WebSocketによるプッシュ通知

#### REST APIサービス (Spring Boot)
- 患者データCRUD
- 時系列クエリ（InfluxDBプロキシ）
- 監査ログ記録

---

## 4. データモデル

### 4.1 PostgreSQL（患者マスタ）

#### patientsテーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | 患者ID |
| name | VARCHAR(100) | NOT NULL | 患者名 |
| birth_date | DATE | NOT NULL | 生年月日 |
| medical_record_number | VARCHAR(50) | UNIQUE | カルテ番号 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

#### devicesテーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | デバイスID |
| device_serial | VARCHAR(50) | UNIQUE, NOT NULL | シリアル番号 |
| patient_id | BIGINT | FK → patients.id | 患者ID |
| status | VARCHAR(20) | NOT NULL | ステータス（active/inactive） |
| last_heartbeat | TIMESTAMP | | 最終通信日時 |

### 4.2 InfluxDB（バイタルデータ）

#### vital_signsメジャメント
- タグ: patient_id, device_id, vital_type
- フィールド: value（FLOAT）
- タイムスタンプ: 1秒精度

---

## 5. API設計

### 5.1 エンドポイント一覧

#### 患者管理
- `POST /api/patients` - 患者登録
- `GET /api/patients/{id}` - 患者情報取得
- `PUT /api/patients/{id}` - 患者情報更新
- `DELETE /api/patients/{id}` - 患者削除

#### バイタルデータ
- `GET /api/vitals/{patientId}?start={timestamp}&end={timestamp}` - 時系列データ取得
- `GET /api/vitals/{patientId}/latest` - 最新バイタル取得

#### アラート
- `GET /api/alerts?patientId={id}&status={status}` - アラート一覧取得
- `PUT /api/alerts/{id}/acknowledge` - アラート確認

### 5.2 認証・認可
- JWT認証（Bearer Token）
- トークンはlocalStorageに保存（React側）
- ロール: ADMIN, DOCTOR, NURSE

### 5.3 リクエスト/レスポンス例

#### POST /api/patients
**Request:**
```json
{
  "name": "山田太郎",
  "birthDate": "1980-01-01",
  "medicalRecordNumber": "MRN-12345"
}
```

**Response (200 OK):**
```json
{
  "id": 123,
  "name": "山田太郎",
  "birthDate": "1980-01-01",
  "medicalRecordNumber": "MRN-12345",
  "createdAt": "2024-01-15T10:00:00Z"
}
```

---

## 6. 実装方針

### 6.1 エラーハンドリング
- 全てのREST APIは共通のエラーレスポンス形式を使用
- 例外は`@ControllerAdvice`でグローバルハンドリング
- クライアント側でエラーメッセージをトースト表示

### 6.2 ロギング方針
- アプリケーションログはJSON形式でCloudWatch Logsに出力
- ログレベル: 本番環境ではINFO以上、開発環境はDEBUG
- 患者IDや医療データはマスキングして出力

### 6.3 テスト方針
- 単体テスト: JUnit 5 + Mockito
- 統合テスト: TestContainers（PostgreSQL, Kafka）
- E2Eテスト: Cypress（主要フロー）

### 6.4 デプロイメント方針
- GitHub ActionsでCI/CD
- 本番デプロイは手動承認必須
- Blue-Greenデプロイメント（ECS）

---

## 7. 非機能要件

### 7.1 パフォーマンス目標
- APIレスポンス: 95%ile < 200ms
- バイタルデータ取り込み遅延: < 3秒
- 同時接続ユーザー数: 500人

### 7.2 セキュリティ要件
- 通信は全てHTTPS
- デバイス認証はX.509証明書
- 患者データは暗号化せずにRDS上に保存（VPC内なので問題ない）
- パスワードはbcryptでハッシュ化

### 7.3 可用性・スケーラビリティ
- SLA: 99.5%（年間ダウンタイム43.8時間以内）
- ECSタスクは2AZ以上で冗長化
- RDSはMulti-AZ構成
- 障害時は手動でフェイルオーバー実施
- スケーリング: CPU使用率が70%を超えたら手動でタスク数を増やす

### 7.4 監視・アラート
- CloudWatch Alarmsで基本的なメトリクス監視
- エラーログが発生したらSlack通知
- デバイスの通信途絶は5分後に検知

---

## 8. 追加要件

### 8.1 監査ログ
- すべてのAPI呼び出しをS3にJSON形式で保存
- ログフォーマット: `{timestamp, userId, action, resource, result}`
- 保存期間: 7年（法令遵守）

### 8.2 データバックアップ
- RDSは日次自動バックアップ（保持期間7日）
- InfluxDBは週次手動バックアップ

### 8.3 災害復旧計画
- RTO: 4時間
- RPO: 24時間
- DR環境は未構築（予算制約）
