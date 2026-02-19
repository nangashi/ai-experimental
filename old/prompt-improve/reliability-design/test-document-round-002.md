# IoT Device Management Platform システム設計書

## 1. 概要

### プロジェクトの目的と背景
産業用IoTセンサーデバイスの統合管理プラットフォームを構築する。工場や物流拠点に設置された数万台のセンサーからのデータ収集、デバイス状態監視、ファームウェア更新を一元管理する。

### 主要機能
- センサーデータのリアルタイム収集とストリーミング処理
- デバイス登録・認証・ライフサイクル管理
- ファームウェアのOTA（Over-The-Air）更新
- デバイス状態監視とアラート通知
- データ分析・可視化ダッシュボード

### 対象ユーザーと利用シナリオ
- デバイス管理者: デバイス登録・設定変更・ファームウェア更新
- 運用監視者: リアルタイムモニタリング・障害対応
- データアナリスト: 収集データの分析・レポート作成

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド API: Java 17, Spring Boot 3.2
- ストリーミング処理: Kafka Streams
- フロントエンド: React 18, TypeScript

### データベース
- デバイスメタデータ: PostgreSQL 15
- 時系列データ: TimescaleDB（PostgreSQL拡張）
- キャッシュ: Redis 7.2

### インフラ・デプロイ環境
- コンテナ: Docker, Kubernetes 1.28
- クラウド: AWS（EKS, RDS, MSK, S3, CloudFront）
- リージョン: ap-northeast-1（東京）

### 主要ライブラリ
- Kafka Streams 3.6
- Spring Data JPA
- Resilience4j（サーキットブレーカー、リトライ）
- Micrometer（メトリクス）

## 3. アーキテクチャ設計

### 全体構成
```
[IoT Devices]
    ↓ MQTT/TLS
[MQTT Broker (AWS IoT Core)]
    ↓
[Kafka Topic: sensor-data]
    ↓
[Kafka Streams Processor] → [TimescaleDB]
    ↓
[API Gateway] → [Backend API] → [PostgreSQL]
                              → [Redis Cache]
```

### 主要コンポーネント

#### Device Ingestion Service
- MQTT経由のセンサーデータ受信
- データバリデーションとKafkaへのパブリッシュ
- デバイス認証トークンの検証

#### Stream Processing Service
- Kafka Streamsによるリアルタイムデータ処理
- 異常値検知とアラート生成
- データ集約とTimescaleDBへの書き込み

#### Device Management API
- デバイスのCRUD操作
- ファームウェア更新スケジュール管理
- デバイス状態クエリ

#### Firmware Update Service
- OTA更新パッケージの配信
- 更新進捗トラッキング
- ロールバック機能

### データフロー
1. IoTデバイスがMQTTでセンサーデータを送信（1秒間隔）
2. AWS IoT CoreがKafka Topicにメッセージをルーティング
3. Kafka Streams Processorがストリーム処理を実行
4. 処理結果をTimescaleDBに書き込み
5. Frontend DashboardがAPI経由でデータを取得・可視化

## 4. データモデル

### デバイス管理（PostgreSQL）

#### devices テーブル
```sql
CREATE TABLE devices (
    device_id UUID PRIMARY KEY,
    device_name VARCHAR(255) NOT NULL,
    device_type VARCHAR(50) NOT NULL,
    firmware_version VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    location_id UUID,
    registered_at TIMESTAMP NOT NULL,
    last_seen_at TIMESTAMP,
    metadata JSONB
);
```

#### firmware_updates テーブル
```sql
CREATE TABLE firmware_updates (
    update_id UUID PRIMARY KEY,
    target_version VARCHAR(50) NOT NULL,
    rollout_strategy VARCHAR(50),
    scheduled_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE device_update_status (
    device_id UUID REFERENCES devices(device_id),
    update_id UUID REFERENCES firmware_updates(update_id),
    status VARCHAR(50),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT,
    PRIMARY KEY (device_id, update_id)
);
```

### 時系列データ（TimescaleDB）

#### sensor_measurements テーブル
```sql
CREATE TABLE sensor_measurements (
    time TIMESTAMPTZ NOT NULL,
    device_id UUID NOT NULL,
    metric_type VARCHAR(50) NOT NULL,
    value DOUBLE PRECISION,
    unit VARCHAR(20)
);

SELECT create_hypertable('sensor_measurements', 'time');
CREATE INDEX idx_device_time ON sensor_measurements (device_id, time DESC);
```

## 5. API設計

### デバイス管理API

#### GET /api/v1/devices
- クエリパラメータ: status, location_id, page, size
- レスポンス: デバイス一覧（ページネーション）

#### POST /api/v1/devices
- リクエスト: device_name, device_type, location_id
- レスポンス: 登録されたデバイス情報とAPIキー

#### GET /api/v1/devices/{device_id}/metrics
- クエリパラメータ: start_time, end_time, metric_type
- レスポンス: 時系列データ

#### POST /api/v1/firmware/updates
- リクエスト: target_version, device_ids[], rollout_strategy
- レスポンス: 更新ジョブID

### 認証・認可
- デバイス認証: X.509証明書ベースの相互TLS認証（AWS IoT Core）
- API認証: JWT（有効期限24時間）
- 権限管理: RBAC（Role-Based Access Control）

## 6. 実装方針

### エラーハンドリング
- 外部APIエラーは標準化されたエラーレスポンス形式で返却
- 予期しない例外はグローバルエラーハンドラでキャッチ
- クライアントエラー（4xx）とサーバーエラー（5xx）を明確に区別

### ロギング
- 構造化ログ（JSON形式）を採用
- ログレベル: ERROR（障害）、WARN（異常）、INFO（重要イベント）、DEBUG（詳細）
- センシティブ情報（APIキー、個人情報）はマスキング

### テスト方針
- ユニットテスト: JUnit 5、カバレッジ80%以上
- 統合テスト: Testcontainersを使用したDB・Kafkaのインメモリテスト
- E2Eテスト: Cypress

### デプロイメント
- CI/CD: GitHub Actions
- デプロイ戦略: Kubernetes Rolling Update（maxUnavailable: 1, maxSurge: 1）
- 環境: dev → staging → production

## 7. 非機能要件

### パフォーマンス目標
- デバイスデータ取り込みスループット: 100,000 msg/sec
- API応答時間: P95 < 500ms, P99 < 1000ms
- ダッシュボード読み込み時間: 3秒以内

### セキュリティ要件
- デバイス通信の暗号化（TLS 1.3）
- API通信の暗号化（HTTPS）
- データベース接続の暗号化
- 定期的な脆弱性スキャン

### 可用性・スケーラビリティ
- 目標稼働率: 99.9%（月間ダウンタイム43分以内）
- オートスケーリング: CPU使用率70%で自動スケール
- データ保持期間: ホットデータ90日、コールドデータ2年（S3アーカイブ）

## 8. 障害対応とモニタリング

### 監視項目
- インフラメトリクス: CPU、メモリ、ディスクI/O
- アプリケーションメトリクス: リクエスト数、エラー率、レイテンシ
- ビジネスメトリクス: アクティブデバイス数、データ取り込みレート

### アラート設定
- P1（緊急）: サービス全断、データ損失の可能性
- P2（重要）: 一部機能停止、パフォーマンス低下
- P3（注意）: リソース枯渇の兆候、非クリティカルなエラー

### 障害対応手順
- インシデント検知後15分以内に初期対応開始
- エスカレーションパス: オンコール担当 → チームリード → マネージャー
- ポストモーテムを実施し、再発防止策を文書化
