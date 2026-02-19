# 企業向け予約管理システム システム設計書

## 1. 概要

### プロジェクトの目的と背景
複数拠点を持つサービス業向けの統合予約管理システムを構築する。現在各拠点で独立して運用されている予約システムを統合し、本社側で一元管理できる体制を整備する。既存のコードベースは社内の他の業務システムと共通のフレームワークを使用しており、今回の新システムもその方針に従う。

### 主要機能の一覧
- 予約受付・変更・キャンセル
- 拠点別・スタッフ別スケジュール管理
- 顧客情報管理
- 通知機能（予約確認、リマインダー）
- レポート・統計情報出力

### 対象ユーザーと利用シナリオ
- **一般顧客**: Webフロントエンドから予約の作成・変更・キャンセルを実施
- **拠点スタッフ**: 管理画面から予約状況確認、スケジュール調整
- **本社管理者**: 全拠点の予約状況確認、レポート出力、システム設定変更

## 2. 技術スタック

### 言語・フレームワーク
- **バックエンド**: Java 17 + Spring Boot 3.2
- **フロントエンド**: React 18 + TypeScript

### データベース
- **メイン**: PostgreSQL 15
- **キャッシュ**: Redis 7

### インフラ・デプロイ環境
- **コンテナ**: Docker
- **オーケストレーション**: Kubernetes (AWS EKS)
- **CI/CD**: GitHub Actions

### 主要ライブラリ
- **ORM**: Spring Data JPA (Hibernate)
- **認証**: Spring Security + JWT
- **バリデーション**: Hibernate Validator
- **HTTP通信**: RestTemplate
- **ログ**: SLF4J + Logback

## 3. アーキテクチャ設計

### 全体構成
レイヤー構成は以下の通り:
- **Presentation Layer**: REST APIコントローラー
- **Business Logic Layer**: サービスクラス
- **Data Access Layer**: リポジトリインターフェース

### 主要コンポーネントの責務と依存関係
各コンポーネントの依存方向は Controller → Service → Repository の一方向とする。Service層内の相互依存は許容する。

**予約管理コンポーネント**:
- `ReservationController`: 予約関連のREST API提供
- `ReservationService`: 予約ロジックの実装
- `ReservationRepository`: 予約データのCRUD操作

**顧客管理コンポーネント**:
- `CustomerController`: 顧客情報API提供
- `CustomerService`: 顧客情報管理ロジック
- `CustomerRepository`: 顧客データのCRUD操作

**通知コンポーネント**:
- `NotificationService`: メール・SMS通知の送信
- `NotificationRepository`: 通知履歴の保存

### データフロー
1. クライアントからのリクエストがControllerで受信
2. Controllerがリクエストをバリデーション
3. Serviceが業務ロジックを実行し、必要に応じて複数のRepositoryを呼び出す
4. Repositoryがデータベースアクセスを実行
5. 結果をControllerが整形してクライアントに返却

## 4. データモデル

### 主要エンティティと関連

**Reservationエンティティ**:
- 顧客(Customer)との関連: 多対一
- 拠点(Location)との関連: 多対一
- スタッフ(Staff)との関連: 多対一

**Customerエンティティ**:
- 予約(Reservation)との関連: 一対多

**Locationエンティティ**:
- 予約(Reservation)との関連: 一対多
- スタッフ(Staff)との関連: 一対多

**Staffエンティティ**:
- 予約(Reservation)との関連: 一対多
- 拠点(Location)との関連: 多対一

### テーブル設計

#### reservationテーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | BIGINT | PRIMARY KEY, AUTO_INCREMENT | 予約ID |
| customerId | BIGINT | NOT NULL, FOREIGN KEY | 顧客ID |
| locationId | BIGINT | NOT NULL, FOREIGN KEY | 拠点ID |
| staffId | BIGINT | NOT NULL, FOREIGN KEY | スタッフID |
| reservationDateTime | TIMESTAMP | NOT NULL | 予約日時 |
| durationMinutes | INT | NOT NULL | 所要時間(分) |
| status | VARCHAR(20) | NOT NULL | ステータス(CONFIRMED, CANCELLED等) |
| createdAt | TIMESTAMP | NOT NULL | 作成日時 |
| updatedAt | TIMESTAMP | NOT NULL | 更新日時 |

#### customerテーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | BIGINT | PRIMARY KEY, AUTO_INCREMENT | 顧客ID |
| firstName | VARCHAR(50) | NOT NULL | 名 |
| lastName | VARCHAR(50) | NOT NULL | 姓 |
| email | VARCHAR(100) | NOT NULL, UNIQUE | メールアドレス |
| phone | VARCHAR(20) | NOT NULL | 電話番号 |
| createdAt | TIMESTAMP | NOT NULL | 登録日時 |

#### locationテーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | BIGINT | PRIMARY KEY, AUTO_INCREMENT | 拠点ID |
| locationName | VARCHAR(100) | NOT NULL | 拠点名 |
| address | VARCHAR(200) | NOT NULL | 住所 |
| phoneNumber | VARCHAR(20) | NOT NULL | 電話番号 |

#### staffテーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | BIGINT | PRIMARY KEY, AUTO_INCREMENT | スタッフID |
| staffName | VARCHAR(100) | NOT NULL | スタッフ名 |
| locationId | BIGINT | NOT NULL, FOREIGN KEY | 所属拠点ID |
| role | VARCHAR(50) | NOT NULL | 役割 |

## 5. API設計

### エンドポイント一覧

#### 予約API
- `POST /api/reservations` - 新規予約作成
- `GET /api/reservations/{id}` - 予約詳細取得
- `PUT /api/reservations/{id}` - 予約変更
- `DELETE /api/reservations/{id}` - 予約キャンセル
- `GET /api/reservations/customer/{customerId}` - 顧客別予約一覧取得

#### 顧客API
- `POST /api/customers` - 顧客登録
- `GET /api/customers/{id}` - 顧客情報取得
- `PUT /api/customers/{id}` - 顧客情報更新

#### 拠点API
- `GET /api/locations` - 拠点一覧取得
- `GET /api/locations/{id}` - 拠点詳細取得

### リクエスト/レスポンス形式

全てのAPIレスポンスは以下の形式を使用する:

**成功時**:
```json
{
  "data": {
    // 実際のデータ
  },
  "status": "success"
}
```

**エラー時**:
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "エラーメッセージ"
  },
  "status": "error"
}
```

### 認証・認可方式
JWT(JSON Web Token)を使用したステートレス認証を採用。各APIリクエストの`Authorization`ヘッダーに`Bearer {token}`形式でトークンを含める。トークンの検証は各コントローラーメソッド内で個別に実装する。

## 6. 実装方針

### エラーハンドリング方針
各コントローラーメソッド内でtry-catchブロックを使用し、例外を個別にハンドリングする。ビジネスロジック例外は`BusinessException`として定義し、システム例外は`SystemException`として定義する。各例外クラスにはエラーコードとメッセージを持たせる。

### ロギング方針
- **ログ形式**: 既存システムに合わせて平文形式とする
- **ログレベル**: ERROR（システムエラー）、WARN（業務例外）、INFO（API呼び出し開始/終了）、DEBUG（詳細トレース）

### テスト方針
- **単体テスト**: JUnit 5 + Mockito
- **統合テスト**: Spring Boot Test + TestContainers
- **カバレッジ目標**: 80%以上

### デプロイメント方針
- **環境**: development, staging, production
- **デプロイ頻度**: 週次（金曜日午後）
- **ロールバック**: 問題発生時は前バージョンに即座に戻す

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 95%のリクエストで500ms以内
- 同時接続数: 1000ユーザー
- データベースクエリ実行時間: 平均100ms以内

### セキュリティ要件
- 通信の暗号化: 全てHTTPSを使用
- パスワード管理: BCryptでハッシュ化
- 個人情報の取り扱い: GDPR準拠

### 可用性・スケーラビリティ
- 稼働率目標: 99.5%以上
- スケーリング: Kubernetesによる水平スケーリング
- バックアップ: 日次でデータベース全体のバックアップ取得
