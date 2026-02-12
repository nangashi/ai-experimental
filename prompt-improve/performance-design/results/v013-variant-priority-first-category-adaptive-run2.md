# Performance Design Review: スマート農業IoTプラットフォーム

## Pass 1: Critical Issues (System-Wide Impact)

### P01: 単一EC2インスタンス構成による可用性・スケーラビリティリスク
**Impact**: システム全体の単一障害点（SPOF）であり、インスタンス障害時に全機能が停止する。また、水平スケーリングが不可能なため、農業法人の大規模圃場（50-200センサー/圃場）や複数クライアントを管理する農業コンサルタントの負荷に対応できない。

**Evidence**:
- Section 2: "AWS EC2 (t3.medium × 1インスタンス)"
- Section 7: 可用性目標 99.0% に対し、単一インスタンス構成では達成が困難

**Recommendation**:
- 最小2インスタンス構成のAuto Scaling Group + Application Load Balancer導入
- ステートレス設計の徹底（セッション状態をRedis等の外部ストアに保存）
- RDS Multi-AZ構成の明示的な採用

---

### P02: センサーデータ長期蓄積によるMongoDB無制限増大リスク
**Impact**: センサーデータが無制限に蓄積されると、MongoDBのストレージ容量が枯渇し、新規データの書き込み失敗やクエリパフォーマンスの劇的な低下を招く。100センサー×1分間隔×1年で約52億レコードに達する。

**Evidence**:
- Section 4: MongoDB sensor_readings コレクションに保持期間・アーカイブ戦略の記載なし
- Section 7: "秒間1000メッセージ処理" の要件があるが、データライフサイクル管理が未定義

**Recommendation**:
- TTLインデックスによる自動削除戦略（例: 直近3ヶ月のみ保持、それ以降はS3へアーカイブ）
- MongoDBの`createIndex({ timestamp: 1 }, { expireAfterSeconds: 7776000 })`設定
- 長期分析用データはAWS S3 + Athenaへの月次エクスポート

---

### P03: ダッシュボードAPI における N+1 クエリ問題
**Impact**: 農業法人の大規模圃場（200センサー）では、センサーごとにMongoDBクエリを発行するため、200+3 = 203回のデータベースアクセスが発生し、3秒のレスポンス目標を大幅に超過する（推定 10-30秒）。

**Evidence**:
- Section 5: `/api/farms/:farmId/dashboard` 実装（line 118-147）
- Line 129-136: `for (const sensor of sensors.rows)` ループ内で個別にMongoDBクエリ実行

**Recommendation**:
- MongoDBのバルククエリへの置換:
```javascript
const sensorIds = sensors.rows.map(s => s.id);
const readings = await mongodb.collection('sensor_readings').aggregate([
  { $match: { sensor_id: { $in: sensorIds } } },
  { $sort: { timestamp: -1 } },
  { $group: { _id: "$sensor_id", latest: { $first: "$$ROOT" } } }
]).toArray();
```
- PostgreSQLクエリも結合により1回に統合（farms/sensors/irrigation_schedulesをJOIN）

---

### P04: センサー履歴データ取得における無制限クエリリスク
**Impact**: 長期間の履歴データリクエスト（例: 1年間）が発生した場合、数百万レコードの取得により、MongoDBサーバーのメモリ枯渇・APIタイムアウト・フロントエンドのクラッシュを引き起こす。

**Evidence**:
- Section 5: `/api/farms/:farmId/sensor-history/:sensorId` 実装（line 152-165）
- Line 156-162: `.toArray()` で全レコードをメモリに読み込み、ページネーションなし

**Recommendation**:
- 必須ページネーション実装（limit/offset または cursor-based）:
```javascript
const limit = Math.min(parseInt(req.query.limit) || 1000, 10000);
const skip = parseInt(req.query.skip) || 0;
const readings = await mongodb.collection('sensor_readings')
  .find({ ... })
  .sort({ timestamp: 1 })
  .skip(skip)
  .limit(limit)
  .toArray();
```
- クエリ期間の最大制限（例: 最大90日間）の設定

---

## Pass 2: Significant Issues by Category

### 2a. I/O & Data Access Efficiency

#### P05: MongoDB sensor_readings コレクションのインデックス未定義
**Impact**: センサー履歴データ取得クエリ（timestamp範囲検索）が全コレクションスキャンとなり、データ増加に伴い指数関数的にレスポンス時間が悪化する。1000万レコード規模で秒単位の遅延が発生。

**Evidence**:
- Section 4: MongoDB スキーマにインデックス定義の記載なし
- Section 5: line 157-160 で `sensor_id` + `timestamp` の複合条件クエリを実行

**Recommendation**:
- 複合インデックス作成: `db.sensor_readings.createIndex({ sensor_id: 1, timestamp: -1 })`
- クエリパターンに応じた追加インデックス（例: farm_id による集約クエリがある場合）

---

#### P06: PostgreSQL外部キーカラムのインデックス不足
**Impact**: `farms.user_id`, `sensors.farm_id`, `irrigation_schedules.farm_id` にインデックスが存在しない場合、JOIN操作やコンサルタントユーザーによる複数圃場の一括取得時にフルテーブルスキャンが発生し、レスポンスが遅延する。

**Evidence**:
- Section 4: PostgreSQLテーブル定義にFOREIGN KEY制約のみ記載、インデックス定義なし
- Section 1: 農業コンサルタントは「複数クライアントの圃場を一括管理」

**Recommendation**:
- 外部キーカラムへのインデックス追加:
```sql
CREATE INDEX idx_farms_user_id ON farms(user_id);
CREATE INDEX idx_sensors_farm_id ON sensors(farm_id);
CREATE INDEX idx_irrigation_schedules_farm_id ON irrigation_schedules(farm_id);
```

---

### 2b. Real-Time Communication & Scalability

#### P07: MQTTブローカーの接続数上限・メッセージスループット仕様未定義
**Impact**: 大規模農業法人が200センサー/圃場×複数圃場を運用する場合、MQTTブローカーの接続数上限やメッセージ処理能力が不明なため、接続拒否やメッセージ損失のリスクがある。

**Evidence**:
- Section 2: MQTTブローカーの具体的な製品・構成の記載なし
- Section 7: "100センサー同時接続で秒間1000メッセージ処理" の要件はあるが、ブローカー側の能力保証が未定義

**Recommendation**:
- MQTTブローカーの選定と構成明示（例: AWS IoT Core、Eclipse Mosquitto、HiveMQ）
- 接続数上限・メッセージスループット・QoSレベルの明確化
- 負荷テストによる実測値の確認

---

#### P08: Data Ingestion Service の同期処理によるスループット制限
**Impact**: MQTTメッセージ受信時にMongoDBへの書き込みを同期的に実行すると、I/O待機によりスループットが制限され、秒間1000メッセージの要件達成が困難になる。

**Evidence**:
- Section 3: "Data Ingestion Service: MQTTブローカーからセンサーデータを受信し、MongoDBに保存"
- 実装詳細の記載なし（バッファリング・バッチ処理の言及なし）

**Recommendation**:
- メッセージキューイング（RabbitMQ既存）またはバッファリング機構の導入
- バッチ書き込み戦略（例: 100件単位でMongoDBの`insertMany()`実行）
- 非同期Worker Poolによる並列処理

---

### 2c. Caching & Memory Management

#### P09: ダッシュボード圃場情報・センサー一覧のキャッシュ未実装
**Impact**: 圃場情報やセンサー一覧は変更頻度が低いにも関わらず、ダッシュボードアクセスごとにPostgreSQLへクエリを発行するため、不要なDB負荷とレスポンス時間の増加を招く。

**Evidence**:
- Section 5: `/api/farms/:farmId/dashboard` 実装（line 122-125, 138-139）
- キャッシュ機構の記載なし

**Recommendation**:
- Redis導入による圃場・センサー情報のキャッシュ（TTL: 5-10分）
- センサー情報更新時のキャッシュ無効化戦略（Write-Through or Cache-Aside）
- センサー最新値のみRedisに保持し、MongoDB読み込みを削減

---

## Pass 3: Moderate Issues by Category

### 3a. Resource Management

#### P10: データベース接続プールの構成パラメータ未定義
**Impact**: PostgreSQL/MongoDB接続プールのサイズが不適切な場合、接続枯渇によるリクエスト失敗またはアイドル接続によるリソース浪費が発生する。

**Evidence**:
- Section 2: データベース接続ライブラリの記載なし
- 接続プール設定（最大接続数、タイムアウト、再接続戦略）の定義なし

**Recommendation**:
- PostgreSQL: pgライブラリの接続プール設定（max: 20, idleTimeoutMillis: 30000）
- MongoDB: MongoClientの接続プール設定（maxPoolSize: 50, minPoolSize: 5）
- 接続リーク検出のためのログ記録

---

#### P11: OpenWeatherMap API 呼び出しのタイムアウト・リトライ戦略未定義
**Impact**: 外部APIのレスポンス遅延やネットワーク障害時に、タイムアウト未設定のHTTPリクエストがハングし、アプリケーションスレッドを占有してシステム全体のレスポンス低下を招く。

**Evidence**:
- Section 2: "OpenWeatherMap API (気象データ取得)"
- Section 5: 収穫予測API実装の記載なし（タイムアウト・リトライ戦略の言及なし）

**Recommendation**:
- HTTPクライアント（axios等）のタイムアウト設定（connect: 5秒, response: 10秒）
- 指数バックオフによるリトライ戦略（最大3回）
- サーキットブレーカーパターンの検討（連続失敗時にフォールバック）

---

#### P12: Analytics Service と Report Generator の計算量・実行時間仕様未定義
**Impact**: 収穫予測や月次レポート生成が大量データ処理を伴う場合、実行時間が不明なため、RabbitMQワーカーのタイムアウトや並列実行数の設定が不適切になり、ジョブ失敗やリソース枯渇のリスクがある。

**Evidence**:
- Section 3: "Analytics Service: 収穫予測・傾向分析の実行"、"Report Generator: 週次・月次レポートの自動生成"
- 処理時間・データボリューム・並列実行戦略の記載なし

**Recommendation**:
- 各ジョブの想定実行時間とデータ量の明示（例: 月次レポート = 1圃場あたり2分、1GB）
- RabbitMQワーカーのタイムアウト設定（例: 10分）
- ジョブの優先度制御（農繁期の収穫予測を優先）

---

### 3b. Infrastructure & Monitoring

#### P13: パフォーマンスメトリクス監視・アラート戦略の未定義
**Impact**: システムが性能劣化しても検知できず、ユーザーからの苦情が発生するまで問題が放置される。特にダッシュボードレスポンス時間の3秒目標やセンサーデータ処理の秒間1000メッセージ目標の達成状況が不明。

**Evidence**:
- Section 6: ロギング戦略の記載あり（Winston）
- Section 7: パフォーマンス目標の記載あり
- 監視・メトリクス収集・アラート設定の記載なし

**Recommendation**:
- CloudWatch メトリクス収集（API レスポンスタイム、MQTT メッセージレート、DB接続数、エラー率）
- CloudWatch Alarms 設定（ダッシュボードP95レスポンス > 3秒、エラー率 > 1%）
- APMツール（New Relic, DataDog）導入の検討

---

#### P14: ダッシュボードレスポンスタイム3秒目標の根拠と測定方法未定義
**Impact**: 目標が抽象的なため、実装時にどの処理が目標内かの判断が困難。また、ネットワークレイテンシ・フロントエンド描画時間を含むか不明なため、バックエンドの最適化範囲が不明確。

**Evidence**:
- Section 7: "ダッシュボード表示: 3秒以内のレスポンス"
- サーバー側レスポンス時間のみか、エンドユーザー体感時間かの定義なし

**Recommendation**:
- レスポンスタイムの定義明確化（例: APIサーバー処理時間 < 1秒、エンドツーエンド < 3秒）
- P95またはP99パーセンタイルでの目標設定（全リクエストの95%が目標内）
- フロントエンドのパフォーマンス測定（Lighthouse, Web Vitals）

---

## Pass 4: Cross-Cutting Patterns

### P15: 灌水制御の並行実行制御・冪等性保証の欠如
**Impact**: 複数ユーザーまたはAPI呼び出しが同時に灌水実行をリクエストした場合、競合状態により重複実行や `last_executed_at` の不整合が発生し、水資源の無駄遣いやデータ不整合を招く。

**Evidence**:
- Section 5: `/api/farms/:farmId/irrigation/execute` エンドポイント定義のみ、実装なし
- Section 4: `irrigation_schedules.last_executed_at` の更新戦略未定義
- トランザクション分離レベル・楽観的ロック・冪等性キーの記載なし

**Recommendation**:
- PostgreSQL の行レベルロック（`SELECT ... FOR UPDATE`）による排他制御:
```sql
BEGIN;
SELECT * FROM irrigation_schedules WHERE farm_id = $1 FOR UPDATE;
-- 実行条件チェック + 灌水実行
UPDATE irrigation_schedules SET last_executed_at = NOW() WHERE id = $1;
COMMIT;
```
- 冪等性キー（リクエストID）によるリトライ時の重複実行防止
- 灌水実行ステータステーブルの導入（実行中/完了/失敗の明示的管理）

---

### P16: センサーデータ収集失敗時のリトライ・デッドレターキュー戦略未定義
**Impact**: MQTTメッセージ受信後のMongoDB書き込み失敗時、メッセージが失われるとセンサーデータの欠損が発生し、異常アラートの誤検知や収穫予測の精度低下を招く。

**Evidence**:
- Section 6: "センサー通信エラー時は MongoDB への書き込み失敗を記録し、手動再送機能を提供"
- 自動リトライ戦略・デッドレターキューの記載なし

**Recommendation**:
- RabbitMQデッドレターキュー（DLQ）の導入による失敗メッセージの自動再試行（最大3回）
- 再試行失敗後のDLQ保存と管理画面での確認・手動再処理機能
- センサーデータ欠損の監視アラート（特定センサーの24時間データ途絶検知）

---

### P17: JWT有効期限24時間とセッション管理の長期稼働リスク
**Impact**: JWT有効期限が24時間と長いため、トークン漏洩時の悪用期間が長く、セキュリティリスクが高い。また、リフレッシュトークン戦略が未定義のため、ユーザーは24時間ごとに再ログインが必要となり、ユーザビリティが低下する。

**Evidence**:
- Section 5: "JWT (JSON Web Token)、有効期限24時間"
- リフレッシュトークン・トークン無効化機構の記載なし

**Recommendation**:
- アクセストークン有効期限を短縮（15分）+ リフレッシュトークン（7日間）の導入
- リフレッシュトークンのローテーション戦略（1回使用後に新規発行）
- トークン無効化リスト（Redisブラックリスト）によるログアウト・セキュリティ侵害時の即座無効化

---

### P18: データバックアップ戦略の MongoDB 欠如と復旧手順未定義
**Impact**: PostgreSQL（RDS）は1日1回のバックアップが定義されているが、MongoDBのバックアップ戦略が未定義のため、DocumentDB障害時にセンサーデータの全損失リスクがある。また、復旧手順（RTO/RPO）が不明なため、障害時の復旧時間が予測不能。

**Evidence**:
- Section 7: "データバックアップ: RDS 自動バックアップ（1日1回）"
- MongoDBのバックアップ・ポイントインタイムリカバリの記載なし

**Recommendation**:
- DocumentDB自動バックアップの有効化（1日1回 + 7日間保持）
- ポイントインタイムリカバリ（PITR）の有効化（5分間隔のスナップショット）
- RTO/RPO目標の明示（例: RTO=4時間、RPO=1時間）と復旧手順書の作成

---

### P19: 長期データ増加によるクエリパフォーマンス劣化の予測・対策未計画
**Impact**: 1年後に数十億レコードのセンサーデータが蓄積された場合、既存のクエリパフォーマンスが劇的に低下し、ダッシュボードやレポート生成が実用不能になる。特に集約クエリ（月次レポート）は指数関数的に遅延する。

**Evidence**:
- Section 4: データアーカイブ・パーティショニング戦略の記載なし
- P02で指摘したTTLインデックスが未定義

**Recommendation**:
- MongoDBのTime Series Collectionsへの移行（MongoDB 5.0+）またはデータパーティショニング
- 月次集約データの事前計算とキャッシュ（マテリアライズドビュー相当）
- 長期データのコールドストレージ移行（S3 + Athena）による古いデータの読み取り専用化

---

### P20: システム全体のキャパシティプランニング未定義
**Impact**: ユーザー数・圃場数・センサー数の増加に対する具体的なスケーリング計画が不明なため、農業法人の大規模導入や急激な成長時に、インフラ容量不足による障害が発生する。

**Evidence**:
- Section 1: 対象ユーザーの規模記載（個人農家: 1-5センサー、農業法人: 50-200センサー）
- Section 7: "100センサー同時接続"の要件はあるが、成長予測・スケーリング計画なし

**Recommendation**:
- 1年後・3年後のユーザー数・圃場数・センサー数の成長予測の明示
- キャパシティプランニング（DB容量、EC2インスタンス数、ネットワーク帯域）
- スケーリングトリガーの定義（例: CPU使用率70%でスケールアウト、ストレージ使用率80%でアラート）
- ロードテストによる現在構成の限界値の測定（何センサーまで対応可能か）
