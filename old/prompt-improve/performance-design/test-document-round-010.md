# Polyglot Connect システム設計書

## 1. 概要

### プロジェクトの目的と背景
Polyglot Connectは、グローバルビジネスコミュニケーションを支援するリアルタイム多言語翻訳プラットフォームである。ビデオ会議、チャット、ドキュメント共有における言語障壁を解消し、多国籍チームの生産性向上を実現する。

### 主要機能
- リアルタイム音声翻訳（50言語対応）
- テキストチャット翻訳（100言語対応）
- ドキュメント翻訳・共同編集
- 翻訳履歴管理・検索
- 用語集カスタマイズ機能
- 翻訳品質フィードバック収集

### 対象ユーザーと利用シナリオ
- 多国籍企業の遠隔会議（5-20名規模）
- グローバルカスタマーサポート（同時接続数: 100-500）
- 国際イベントのリアルタイム字幕配信（視聴者数: 1,000-10,000）

## 2. 技術スタック

### 言語・フレームワーク
- Backend: Python 3.11 (FastAPI)
- Frontend: React 18 (TypeScript)
- Real-time Communication: WebSocket (Socket.IO)

### データベース
- Primary DB: PostgreSQL 15
- Cache: Redis 7
- Search Engine: Elasticsearch 8

### インフラ・デプロイ環境
- Cloud Provider: AWS (ECS, RDS, ElastiCache)
- CDN: CloudFront
- Translation API: Google Cloud Translation API

### 主要ライブラリ
- Audio Processing: WebRTC, FFmpeg
- Translation: google-cloud-translate v3
- Text Processing: spaCy, NLTK

## 3. アーキテクチャ設計

### 全体構成
```
[Frontend Layer]
  └─ React SPA + Socket.IO Client

[API Gateway Layer]
  └─ FastAPI + WebSocket Server

[Application Layer]
  ├─ Translation Service
  ├─ Session Management Service
  ├─ User Management Service
  └─ Document Service

[Data Layer]
  ├─ PostgreSQL (User, Session, Translation History)
  ├─ Redis (Session Cache, Translation Cache)
  └─ Elasticsearch (Translation History Search)

[External Services]
  └─ Google Cloud Translation API
```

### 主要コンポーネントの責務

#### Translation Service
- リアルタイム翻訳リクエスト処理
- Google Translation API連携
- 翻訳結果のキャッシング
- カスタム用語集の適用

#### Session Management Service
- 会議セッション作成・管理
- 参加者管理
- WebSocket接続管理

#### Document Service
- 多言語ドキュメント管理
- バージョン管理
- 共同編集の同期処理

### データフロー

#### リアルタイム音声翻訳フロー
1. Client: 音声をWebSocketで送信
2. Translation Service: 音声をテキストに変換（Speech-to-Text）
3. Translation Service: テキストを翻訳（Google Translation API）
4. Translation Service: 翻訳結果をDBに保存
5. Translation Service: 全参加者にWebSocketで配信

#### チャット翻訳フロー
1. Client: メッセージ送信
2. Translation Service: 各参加者の言語に翻訳
3. Translation Service: 翻訳結果をキャッシュ
4. Translation Service: 全参加者に配信

## 4. データモデル

### User テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | ユーザーID |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| preferred_language | VARCHAR(10) | NOT NULL | 優先言語コード |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

### Session テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | セッションID |
| organizer_id | UUID | FK(User.id) | 主催者ID |
| title | VARCHAR(255) | NOT NULL | セッション名 |
| started_at | TIMESTAMP | NOT NULL | 開始日時 |
| ended_at | TIMESTAMP | NULL | 終了日時 |

### Participant テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | 参加者ID |
| session_id | UUID | FK(Session.id) | セッションID |
| user_id | UUID | FK(User.id) | ユーザーID |
| language | VARCHAR(10) | NOT NULL | 参加時言語設定 |
| joined_at | TIMESTAMP | NOT NULL | 参加日時 |

### TranslationHistory テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | BIGSERIAL | PK | 翻訳履歴ID |
| session_id | UUID | FK(Session.id) | セッションID |
| speaker_id | UUID | FK(User.id) | 発言者ID |
| original_text | TEXT | NOT NULL | 原文 |
| original_language | VARCHAR(10) | NOT NULL | 原文言語 |
| translated_text | TEXT | NOT NULL | 翻訳文 |
| target_language | VARCHAR(10) | NOT NULL | 翻訳先言語 |
| translated_at | TIMESTAMP | NOT NULL | 翻訳日時 |

### CustomGlossary テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | 用語集ID |
| organization_id | UUID | FK(Organization.id) | 組織ID |
| source_term | VARCHAR(255) | NOT NULL | 原文用語 |
| target_term | VARCHAR(255) | NOT NULL | 翻訳用語 |
| source_language | VARCHAR(10) | NOT NULL | 原文言語 |
| target_language | VARCHAR(10) | NOT NULL | 翻訳先言語 |

## 5. API設計

### WebSocket Events

#### Client → Server
- `join_session`: セッション参加
- `send_message`: メッセージ送信
- `send_audio`: 音声データ送信

#### Server → Client
- `message_translated`: 翻訳済みメッセージ配信
- `audio_translated`: 翻訳済み音声配信
- `participant_joined`: 参加者入室通知

### REST API Endpoints

#### セッション管理
- `POST /api/sessions`: セッション作成
- `GET /api/sessions/{id}`: セッション詳細取得
- `GET /api/sessions/{id}/history`: 翻訳履歴取得

#### ユーザー管理
- `POST /api/users`: ユーザー登録
- `GET /api/users/{id}`: ユーザー情報取得
- `PATCH /api/users/{id}`: ユーザー情報更新

#### 用語集管理
- `POST /api/glossaries`: 用語集作成
- `GET /api/glossaries/{org_id}`: 組織用語集取得
- `PUT /api/glossaries/{id}`: 用語更新

### 認証・認可方式
- 認証: JWT (Access Token: 1h, Refresh Token: 30d)
- 認可: RBAC (Role: Admin, Member, Guest)
- WebSocket認証: JWTをクエリパラメータで送信

## 6. 実装方針

### エラーハンドリング方針
- API連携エラー: 3回リトライ（指数バックオフ）
- Translation API失敗時: フォールバック翻訳エンジン（DeepL API）を使用
- WebSocket切断時: クライアント側で自動再接続（最大5回）

### ロギング方針
- 構造化ログ（JSON形式）
- ログレベル: DEBUG, INFO, WARNING, ERROR
- 翻訳リクエスト・レスポンスの全量ロギング

### テスト方針
- Unit Test: pytest（カバレッジ80%以上）
- Integration Test: 外部API連携のモックテスト
- Load Test: Locustで同時接続500セッション検証

### デプロイメント方針
- Blue-Green Deployment
- カナリアリリース（新機能は10%トラフィックで検証）
- ロールバック時間: 5分以内

## 7. 非機能要件

### パフォーマンス
- 翻訳レスポンスタイム: 平均500ms以内
- WebSocket接続確立: 200ms以内
- API応答時間: 95パーセンタイルで1秒以内

### セキュリティ要件
- 翻訳データの暗号化保存（AES-256）
- 通信の暗号化（TLS 1.3）
- 個人情報の保持期間: 翻訳履歴は30日間

### 可用性・スケーラビリティ
- システム稼働率: 99.9%
- Auto-scaling: CPU使用率70%でスケールアウト
- セッション同時接続数: 1,000セッション対応
