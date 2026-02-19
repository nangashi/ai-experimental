# 企業イベント管理プラットフォーム システム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
企業向けにセミナー、カンファレンス、社内イベントの企画・運営・参加者管理を統合的に支援するSaaSプラットフォームを構築する。従来はスプレッドシート管理や複数ツールの併用で非効率だったイベント運営を、一元管理することで業務効率を向上させる。

### 1.2 主要機能
- イベント作成・公開（タイトル、説明、日時、会場、定員、カテゴリ）
- 参加申込・キャンセル
- 参加者名簿管理（氏名、メールアドレス、部署、参加ステータス）
- QRコードチェックイン機能
- イベント後アンケート
- ダッシュボード（開催実績、参加者数推移、アンケート集計）
- 通知（申込確認、リマインダー、キャンセル通知）

### 1.3 対象ユーザーと利用シナリオ
- **イベント主催者**: 人事部、広報部、営業企画部などのイベント運営担当者
- **参加者**: 社内従業員または外部招待者
- **管理者**: システム管理者、全社イベント統括部門

## 2. 技術スタック

- **Backend**: Node.js v20, Express v4.18
- **Frontend**: Next.js v14, React v18
- **Database**: PostgreSQL 15（RDS）
- **Cache**: Redis 7（ElastiCache）が利用可能だが、現時点でキャッシュ戦略は未定義
- **Infrastructure**: AWS (EC2, RDS, S3, SQS, SES)
- **Deployment**: Docker, ECS Fargate

## 3. アーキテクチャ設計

### 3.1 全体構成
3層アーキテクチャを採用する。

```
[Frontend (Next.js)]
       ↓
[API Layer (Express)]
       ↓
[Business Logic Layer]
       ↓
[Data Access Layer (PostgreSQL)]
```

### 3.2 主要コンポーネント

#### API Layer
- `/api/events`: イベントCRUD操作
- `/api/registrations`: 参加申込・キャンセル
- `/api/checkin`: QRコードスキャン・チェックイン
- `/api/surveys`: アンケート回答
- `/api/dashboard`: 統計情報取得

#### Business Logic Layer
- EventService: イベント作成・更新・削除
- RegistrationService: 申込処理・定員チェック・通知送信
- CheckinService: チェックイン処理
- SurveyService: アンケート集計
- NotificationService: メール・プッシュ通知送信

#### Data Access Layer
- EventRepository
- RegistrationRepository
- UserRepository
- SurveyRepository

## 4. データモデル

### 4.1 主要エンティティ

#### events
| カラム | 型 | 制約 |
|--------|----|----|
| id | UUID | PK |
| title | VARCHAR(255) | NOT NULL |
| description | TEXT | |
| start_datetime | TIMESTAMP | NOT NULL |
| end_datetime | TIMESTAMP | NOT NULL |
| venue | VARCHAR(255) | |
| capacity | INTEGER | NOT NULL |
| category | VARCHAR(50) | |
| status | VARCHAR(20) | DEFAULT 'draft' |
| created_at | TIMESTAMP | DEFAULT NOW() |
| updated_at | TIMESTAMP | DEFAULT NOW() |

#### registrations
| カラム | 型 | 制約 |
|--------|----|----|
| id | UUID | PK |
| event_id | UUID | FK → events.id |
| user_id | UUID | FK → users.id |
| status | VARCHAR(20) | DEFAULT 'registered' |
| registered_at | TIMESTAMP | DEFAULT NOW() |
| checked_in_at | TIMESTAMP | NULL |

#### users
| カラム | 型 | 制約 |
|--------|----|----|
| id | UUID | PK |
| name | VARCHAR(100) | NOT NULL |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| department | VARCHAR(100) | |
| created_at | TIMESTAMP | DEFAULT NOW() |

#### survey_responses
| カラム | 型 | 制約 |
|--------|----|----|
| id | UUID | PK |
| event_id | UUID | FK → events.id |
| user_id | UUID | FK → users.id |
| responses | JSONB | NOT NULL |
| created_at | TIMESTAMP | DEFAULT NOW() |

## 5. API設計

### 5.1 主要エンドポイント

#### GET /api/events
イベント一覧取得。

**クエリパラメータ**:
- `category`: カテゴリフィルタ（オプション）
- `status`: ステータスフィルタ（オプション）

**レスポンス**:
```json
{
  "events": [
    {
      "id": "uuid",
      "title": "Spring Tech Conference",
      "start_datetime": "2026-03-15T09:00:00Z",
      "capacity": 200,
      "registered_count": 150
    }
  ]
}
```

#### POST /api/registrations
参加申込。

**リクエストボディ**:
```json
{
  "event_id": "uuid",
  "user_id": "uuid"
}
```

**処理フロー**:
1. イベントの定員チェック
2. 重複申込チェック
3. registrationsテーブルに挿入
4. 申込確認メール送信（SES経由）

#### GET /api/dashboard/events/:event_id/stats
イベント統計情報取得。

**レスポンス**:
```json
{
  "total_registrations": 150,
  "checked_in_count": 120,
  "survey_response_rate": 0.85,
  "registrations_by_department": [
    {"department": "Engineering", "count": 50},
    {"department": "Sales", "count": 30}
  ]
}
```

**実装**:
- registrationsテーブルからevent_idに一致する全レコードを取得
- usersテーブルからdepartment別に集計するためにJOIN
- survey_responsesテーブルから回答率を計算するためにJOIN

### 5.2 認証・認可
- JWT（JSON Web Token）をHTTP Headerで送信
- トークン有効期限: 24時間
- リフレッシュトークン未実装

## 6. 実装方針

### 6.1 参加申込処理
```javascript
async function createRegistration(eventId, userId) {
  const event = await eventRepository.findById(eventId);
  const registrations = await registrationRepository.findByEventId(eventId);

  if (registrations.length >= event.capacity) {
    throw new Error('Event is full');
  }

  const registration = await registrationRepository.create({
    event_id: eventId,
    user_id: userId,
    status: 'registered'
  });

  await notificationService.sendRegistrationConfirmation(userId, eventId);

  return registration;
}
```

### 6.2 ダッシュボード統計取得
```javascript
async function getEventStats(eventId) {
  const registrations = await db.query(`
    SELECT r.*, u.department
    FROM registrations r
    JOIN users u ON r.user_id = u.id
    WHERE r.event_id = $1
  `, [eventId]);

  const surveyResponses = await db.query(`
    SELECT * FROM survey_responses WHERE event_id = $1
  `, [eventId]);

  const statsByDepartment = {};
  registrations.forEach(reg => {
    if (!statsByDepartment[reg.department]) {
      statsByDepartment[reg.department] = 0;
    }
    statsByDepartment[reg.department]++;
  });

  return {
    total_registrations: registrations.length,
    checked_in_count: registrations.filter(r => r.checked_in_at).length,
    survey_response_rate: surveyResponses.length / registrations.length,
    registrations_by_department: Object.entries(statsByDepartment).map(([dept, count]) => ({
      department: dept,
      count
    }))
  };
}
```

### 6.3 リマインダー送信バッチ
毎日午前9時に、翌日開催イベントの参加者にリマインダーメール送信。

```javascript
async function sendReminders() {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);

  const events = await eventRepository.findByDate(tomorrow);

  for (const event of events) {
    const registrations = await registrationRepository.findByEventId(event.id);

    for (const registration of registrations) {
      const user = await userRepository.findById(registration.user_id);
      await ses.sendEmail({
        to: user.email,
        subject: `Reminder: ${event.title}`,
        body: `Your event starts tomorrow at ${event.start_datetime}`
      });
    }
  }
}
```

### 6.4 エラーハンドリング方針
- 400番台エラー: バリデーションエラー、ビジネスロジック違反
- 500番台エラー: サーバー内部エラー
- エラーログは標準出力に出力

### 6.5 ロギング方針
- Winston libraryを使用
- ログレベル: info, warn, error
- ログフォーマット: JSON

### 6.6 テスト方針
- Unit test: Jest
- Integration test: Supertest
- E2E test: Playwright

### 6.7 デプロイメント方針
- Docker Imageをビルドし、ECRにプッシュ
- ECS Fargateで実行
- Blue-Green Deployment

## 7. 非機能要件

### 7.1 パフォーマンス
想定負荷:
- 月間イベント数: 500件
- 月間参加申込: 10,000件
- 同時接続ユーザー: 500名（ピーク時）

### 7.2 セキュリティ
- HTTPS通信必須
- SQL Injection対策: パラメータ化クエリ使用
- XSS対策: エスケープ処理
- CSRF対策: トークン検証

### 7.3 可用性・スケーラビリティ
- RDS Multi-AZ構成
- ECS Auto Scaling（CPU使用率70%以上で追加インスタンス起動）
- S3によるファイルストレージ

### 7.4 データ保持期限
現時点では明示的なデータ保持期限・アーカイブポリシーは未定義。registrations、survey_responsesなどの履歴データは無期限で保持される。
