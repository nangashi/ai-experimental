# Scoring Results: v002-baseline

## Detection Matrix

| Problem ID | Run1 | Run2 | Criteria |
|-----------|------|------|----------|
| P01: Kafka Streams障害時のデータ損失リスク | ○ | ○ | Kafka Streams処理の障害時におけるデータ損失リスク、またはTimescaleDB書き込み失敗時のリトライ/デッドレターキュー戦略の欠如 |
| P02: ファームウェア更新のトランザクション整合性欠如 | × | × | firmware_updatesとdevice_update_status間のトランザクション整合性の欠如、または複数テーブル更新における部分失敗時の不整合リスク |
| P03: デバイス認証トークン検証失敗時のフォールバック未定義 | × | × | AWS IoT Core認証サービス障害時のフォールバック戦略の欠如、またはデバイス認証失敗時のグレースフルデグラデーション設計の必要性 |
| P04: PostgreSQLとTimescaleDBの障害分離境界が不明確 | × | × | PostgreSQLとTimescaleDBの障害分離境界の不明確さ、または一方のDB障害が他方に波及するリスク |
| P05: ファームウェア更新のべき等性設計欠如 | △ | ○ | ファームウェア更新リクエストのべき等性欠如、または重複リクエスト処理の設計不足 |
| P06: API Gatewayのタイムアウト設計未定義 | × | × | API Gatewayのタイムアウト設計の欠如、または長時間実行クエリに対するタイムアウト戦略の必要性 |
| P07: Redisキャッシュ障害時のフォールバック戦略欠如 | ○ | ○ | Redis障害時のフォールバック戦略の欠如、またはRedisのSPOFリスク |
| P08: SLO/SLAに対応する具体的な監視・アラート設計の欠如 | △ | △ | SLO/SLA目標に対応する具体的な監視指標・アラート閾値の欠如、またはエラーバジェットベースの監視設計の必要性 |
| P09: データベースバックアップ戦略の詳細欠如 | ○ | ○ | データベースバックアップ戦略の欠如、またはRPO/RTO定義の必要性 |
| P10: Rolling Updateのロールバック計画欠如 | ○ | ○ | Rolling Updateのロールバック計画の欠如、またはデプロイ後の問題発生時の対応手順の必要性 |

## Detection Score Details

### Run1 Detection Breakdown
- P01: ○ (1.0) - C-2 "TimescaleDB Write Path Has No Fault Isolation" で、デッドレターキュー（DLQ）の必要性を明示的に指摘
- P02: × (0.0) - トランザクション整合性の具体的な指摘なし。C-3はロールバックの不整合だが、作成時の複数テーブル更新の整合性には言及していない
- P03: × (0.0) - AWS IoT Core認証サービス障害時のフォールバック戦略の指摘なし。S-2はMQTTブローカー障害だがデバイス認証検証の具体的なフォールバックに触れていない
- P04: × (0.0) - PostgreSQLとTimescaleDBの障害分離境界についての明示的な指摘なし
- P05: △ (0.5) - M-1 "No Specification for Idempotent Firmware Update Status Writes" でべき等性に言及しているが、リクエストレベルの重複検出ではなくステータス書き込みの重複に焦点
- P06: × (0.0) - API Gatewayの具体的なタイムアウト設計の指摘なし
- P07: ○ (1.0) - S-3 "Redis Cache Failure Degrades to Unspecified Behavior" でRedis障害時のフォールバック戦略の欠如を明示的に指摘
- P08: △ (0.5) - M-1 "No Explicit SLO Definitions" でSLO定義の欠如に言及しているが、監視・アラート閾値との具体的な紐付けは部分的
- P09: ○ (1.0) - S-3 "Incomplete Backup Strategy for PostgreSQL" でRPO/RTO定義の必要性を明示的に指摘
- P10: ○ (1.0) - M-3 "Deployment Rollback Procedure Not Documented" でロールバック計画の欠如を明示的に指摘

**Detection Score: 6.0**

### Run2 Detection Breakdown
- P01: ○ (1.0) - C-2 "Missing Circuit Breaker Configuration for TimescaleDB Writes" で、デッドレターキュー（S3）への書き込みを含むフォールバック戦略を明示的に指摘
- P02: × (0.0) - トランザクション整合性の具体的な指摘なし。C-3はロールバック時の不整合、C-1はべき等性の問題だが、ファームウェア更新作成時の複数テーブル更新の整合性には触れていない
- P03: × (0.0) - AWS IoT Core認証サービス障害時のフォールバック戦略の指摘なし
- P04: × (0.0) - PostgreSQLとTimescaleDBの障害分離境界についての指摘なし
- P05: ○ (1.0) - C-1 "No Idempotency Design for Firmware Updates" で、べき等性設計の欠如と重複リクエスト処理の設計不足を明示的に指摘
- P06: × (0.0) - API Gatewayの具体的なタイムアウト設計の指摘なし
- P07: ○ (1.0) - M-2 "Insufficient Detail on Redis Cache Invalidation" でRedis障害時のフォールバック戦略の欠如を指摘
- P08: △ (0.5) - M-1 "No Explicit SLO Definitions" でSLO定義の欠如に言及しているが、監視・アラート閾値との具体的な紐付けは部分的
- P09: ○ (1.0) - S-3 "Incomplete Backup Strategy for PostgreSQL" でRPO/RTO定義の必要性を明示的に指摘
- P10: ○ (1.0) - C-3 "No Rollback Design for Data Migrations" およびS-2 "No Graceful Shutdown for In-Flight Stream Processing" でデプロイロールバック計画の欠如を指摘

**Detection Score: 6.5**

## Bonus/Penalty Analysis

### Run1 Bonuses
1. **C-1: Kafka Streams State Store Recovery Not Designed** (+0.5)
   - Category: 障害回復設計（State Store Recovery）
   - Justification: 正解キーに含まれないが、perspective.mdのスコープ内。Kafka Streamsの状態ストア回復設計の欠如はデータ損失リスク（P01）とは異なる観点で、RTO目標達成への影響を指摘

2. **C-3: Firmware Update Rollback Lacks Atomicity Guarantee** (+0.5)
   - Category: 障害回復設計（Rollback Atomicity）
   - Justification: P10（Rolling Updateのロールバック）とは異なり、ファームウェア更新の部分的ロールバック失敗に焦点。デバイスフリート全体の整合性リスクを指摘

3. **C-4: Single-Region Deployment Creates Data Loss Risk** (+0.5)
   - Category: 可用性・冗長性・災害復旧（Multi-Region）
   - Justification: ボーナスリストB01に相当。リージョン障害時のSPOFリスクとRPO/RTO定義の必要性を指摘

4. **S-1: PostgreSQL Connection Pool Exhaustion Not Mitigated** (+0.5)
   - Category: 障害回復設計（Bulkhead Pattern）
   - Justification: 正解キーに含まれないが、障害分離境界（バルクヘッドパターン）はperspective.mdのスコープ内。コネクションプール枯渇による部分障害の波及リスクを指摘

5. **S-2: MQTT Broker Failure Behavior Undefined** (+0.5)
   - Category: 障害回復設計（Device Retry Behavior）
   - Justification: ボーナスリストB03に相当。MQTT再接続時のリトライポリシーとデバイスローカルバッファの未定義を指摘（QoS設定には触れていないが、デバイスオフライン時のデータ欠損リスクは同一スコープ）

**Bonus Count: 5 (上限5件に達したため、これ以降のボーナス対象は加点しない)**

### Run1 Penalties
1. **S-4: JWT Token Revocation Mechanism Missing** (-0.5)
   - Reason: セキュリティ脆弱性（悪意ある攻撃への耐性）はperspective.mdのスコープ外。「compromised admin token」「emergency revocation procedure」などの文言から、悪意ある攻撃シナリオを前提としている

2. **I-2: No Mention of Rate Limiting for API Endpoints** (-0.5)
   - Reason: 「abusive clients」の記載から攻撃防御目的のレート制限と判断。perspective.mdの判定指針では、自己保護（バックプレッシャー）目的はスコープ内だが、攻撃防御目的はsecurityで扱う

**Penalty Count: 2**

### Run2 Bonuses
1. **C-4: Undefined Kafka Consumer Group Recovery Behavior** (+0.5)
   - Category: 障害回復設計（Kafka Streams Recovery）
   - Justification: 正解キーP01とは異なる観点。P01はTimescaleDB書き込み失敗時のデータ損失リスクだが、C-4はKafka Streams自体の障害回復（リバランス、状態ストア回復、オフセット管理）に焦点

2. **S-2: No Graceful Shutdown for In-Flight Stream Processing** (+0.5)
   - Category: デプロイ・ロールバック（Graceful Shutdown）
   - Justification: 正解キーP10（Rolling Updateのロールバック計画）とは異なる観点。デプロイ時のストリーム処理中断リスクと exactly-once保証の維持を指摘

3. **S-4: Missing Rate Limiting for Device Data Ingestion** (+0.5)
   - Category: 障害回復設計（Backpressure/Self-Protection Rate Limiting）
   - Justification: 「malfunction devices」「thundering herd」の記載から、偶発的な障害シナリオに焦点。攻撃防御ではなく自己保護目的のレート制限としてスコープ内

4. **M-4: Missing Kafka Topic Partition Strategy** (+0.5)
   - Category: 可用性・冗長性・災害復旧（Replication Factor）
   - Justification: Kafkaトピックのレプリケーション係数（3）とパーティション戦略は、ブローカー障害時の可用性設計として正当。スループット最適化ではなく障害耐性に焦点

5. **M-3: No Firmware Rollback Retry Strategy** (+0.5)
   - Category: 障害回復設計（Firmware Rollback Retry）
   - Justification: 正解キーP10（Rolling Updateのロールバック）とは異なり、ファームウェアロールバック失敗時のリトライ戦略に焦点。部分的なロールバック失敗の運用リスクを指摘

**Bonus Count: 5 (上限5件に達したため、これ以降のボーナス対象は加点しない)**

### Run2 Penalties
1. **I-1: Consider Adding Deployment Canary Analysis** (-0.5)
   - Reason: 「Canary Analysis」はデプロイ戦略の選定根拠に関する設計原則であり、perspective.mdの判断指針によれば structural-quality で扱うべき内容。具体的なロールバックトリガー閾値の定義ではない

2. **I-2: Add Structured Logging Correlation IDs** (-0.5)
   - Reason: 「Trace IDs for distributed tracing (e.g., AWS X-Ray)」の記載から、ログフォーマット・トレーシング設計に関する内容と判断。perspective.mdでは「分散トレーシング・相関ID → 障害調査のための運用ツールとしてスコープ内、ログフォーマット・レベル設計は structural-quality」とあり、この指摘はログ設計の原則に焦点を当てているためスコープ外

**Penalty Count: 2**

## Score Summary

### Run1
- Detection: 6.0
- Bonus: +2.5 (5件)
- Penalty: -1.0 (2件)
- **Total: 7.5**

### Run2
- Detection: 6.5
- Bonus: +2.5 (5件)
- Penalty: -1.0 (2件)
- **Total: 8.0**

### Statistics
- **Mean: 7.75**
- **SD: 0.25**
- **Stability: 高安定 (SD ≤ 0.5)**
