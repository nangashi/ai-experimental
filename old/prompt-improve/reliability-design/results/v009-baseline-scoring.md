# Scoring Results: v009-baseline

## Run 1 Detailed Scoring

### Embedded Problems Detection

| ID | Problem | Detection | Score | Notes |
|----|---------|-----------|-------|-------|
| P01 | サーキットブレーカーのフォールバック戦略が不明確 | △ | 0.5 | C-4で「Graceful Degradation Strategies」として触れているが、「全プロバイダー障害時の最終的なフォールバック戦略の欠如」を明確に指摘していない |
| P02 | 予約確定フローにおけるトランザクション整合性が未保証 | ○ | 1.0 | C-1で決済成功後のPostgreSQL更新失敗・Kafkaイベント発行失敗時の整合性問題を明確に指摘、Transactional Outbox Pattern提案あり |
| P03 | 決済リトライのべき等性が未設計 | ○ | 1.0 | C-2で「Missing Idempotency Keys for External Provider API Calls」として指摘。S-6で「Payment Idempotency and Duplicate Charge Prevention Insufficient」としても詳細に分析 |
| P04 | 外部プロバイダーAPIのタイムアウト設定が不十分 | ○ | 1.0 | C-4で個々の外部APIへの接続/読み取りタイムアウトの未定義を明確に指摘 |
| P05 | Kafkaイベント消費の障害回復戦略が未定義 | ○ | 1.0 | C-5で「Kafka Consumer Group Rebalancing and Poison Message Handling Not Addressed」として明確に指摘、DLQ戦略・重複検出メカニズム提案あり |
| P06 | RDS Multi-AZフェイルオーバー時のアプリケーション側対応が未定義 | △ | 0.5 | S-5で接続プールの設定・リトライについて触れているが、「RDSフェイルオーバー時のアプリケーション側接続リトライ」を明示的に指摘していない |
| P07 | バックグラウンドジョブ（フライトステータスポーリング）の障害回復が未設計 | ○ | 1.0 | S-5で「SPOF in Background Flight Status Polling Job」として明確に指摘、リトライ戦略・冪等性設計の欠如を分析 |
| P08 | SLO監視に対応するアラート戦略の詳細が不足 | ○ | 1.0 | M-1で「SLO/SLA Definitions Lack Error Budget and Actionable Alerting Thresholds」として明確に指摘 |
| P09 | データベースマイグレーションのロールバック互換性が未考慮 | ○ | 1.0 | S-4で「Database Migration Backward Compatibility Not Explicitly Addressed」として明確に指摘、Expand-Contractパターン提案あり |

**Detection Subtotal**: 8.0/9.0

### Bonus Points

| ID | Category | Detected Issue | Score | Justification |
|----|----------|----------------|-------|---------------|
| B01 | 可用性・冗長性 | MongoDB (DocumentDB) の冗長性設計が未記載 | +0.5 | C-3 Countermeasures 5「MongoDB Disaster Recovery」でレプリカセット提案あり |
| B03 | 障害回復設計 | Redis (ElastiCache) クラスターのフェイルオーバー時のセッション喪失リスク | +0.5 | Minor Improvements 1で「Redis Persistence Configuration」として指摘 |
| B06 | 可用性・冗長性 | ECS Auto Scalingのスケールアウト速度と突発的なトラフィック増加への対応 | +0.5 | M-3「Capacity Planning and Load Testing Strategy Missing」で詳細に分析 |
| B08 | 障害回復設計 | Kafka プロデューサーの送信失敗時のリトライ設定とアプリケーション側のエラーハンドリング | +0.5 | C-1 Countermeasures 1でTransactional Outbox Pattern提案、C-5でKafka設定詳細あり |
| B10 | 可用性・冗長性 | 関連予約の整合性チェック（ホテルチェックイン日 < フライト到着日）における分散トランザクションの実現方法 | +0.5 | C-6「No Conflict Resolution Strategy for Concurrent Booking Modifications」として明確に指摘 |

**Additional valid bonuses**:
- M-7でRDS Read Replicaのスケーリング欠如を指摘（関連: 可用性・冗長性） +0.5
- M-6でConfiguration Management and Secret Rotation欠如を指摘（運用性） +0.5

**Bonus Subtotal**: +3.5 (上限5件なので上位5件採用: B01, B03, B06, B08, B10)

### Penalty Points

**スコープ外指摘のチェック**:
- M-6「Configuration Management and Secret Rotation Strategy Missing」→ 運用性の範囲内、ペナルティなし
- 「Security Considerations: PCI DSS compliance...」は肯定的評価であり、ペナルティ対象外
- すべての指摘がreliability観点に該当、スコープ外指摘なし

**Penalty Subtotal**: 0

### Run 1 Total Score
**8.0 (detection) + 2.5 (bonus) - 0 (penalty) = 10.5**

---

## Run 2 Detailed Scoring

### Embedded Problems Detection

| ID | Problem | Detection | Score | Notes |
|----|---------|-----------|-------|-------|
| P01 | サーキットブレーカーのフォールバック戦略が不明確 | ○ | 1.0 | C3で「フォールバック条件の曖昧さ（何を持って「可能」と判断するか）」および「全プロバイダー障害時の最終的なフォールバック戦略の欠如」を明確に指摘 |
| P02 | 予約確定フローにおけるトランザクション整合性が未保証 | ○ | 1.0 | C1で決済成功後のPostgreSQL更新失敗・Kafkaイベント発行失敗時の整合性問題を明確に指摘、Saga Pattern提案あり |
| P03 | 決済リトライのべき等性が未設計 | ○ | 1.0 | C2で「No Idempotency Guarantees for Booking Confirmation」として指摘、C4でも決済リトライについて触れている |
| P04 | 外部プロバイダーAPIのタイムアウト設定が不十分 | ○ | 1.0 | C3で「個々の外部プロバイダーAPI（Amadeus, Expedia等）に対する接続タイムアウト、読み取りタイムアウト、リトライポリシーが未定義」を明確に指摘 |
| P05 | Kafkaイベント消費の障害回復戦略が未定義 | ○ | 1.0 | S1で「Missing Dead Letter Queue for Kafka Event Processing Failures」として明確に指摘、DLQ戦略・リトライ詳細あり |
| P06 | RDS Multi-AZフェイルオーバー時のアプリケーション側対応が未定義 | △ | 0.5 | S5で接続プールの設定・リトライについて触れているが、「RDSフェイルオーバー時のアプリケーション側接続リトライ」を明示的に指摘していない |
| P07 | バックグラウンドジョブ（フライトステータスポーリング）の障害回復が未設計 | △ | 0.5 | S4で「No Exponential Backoff for Amadeus Flight Status Polling」として触れているが、冪等性設計やリトライ戦略について明示的な指摘がない（主にレート制限とポーリング最適化に焦点） |
| P08 | SLO監視に対応するアラート戦略の詳細が不足 | ○ | 1.0 | M3で「Missing Error Budget Tracking」として明確に指摘、バーンレートベースのアラート提案あり |
| P09 | データベースマイグレーションのロールバック互換性が未考慮 | ○ | 1.0 | S6で「No Rollback Testing for Database Migrations」として明確に指摘、Expand-Contractパターン提案あり |

**Detection Subtotal**: 8.0/9.0

### Bonus Points

| ID | Category | Detected Issue | Score | Justification |
|----|----------|----------------|-------|---------------|
| B01 | 可用性・冗長性 | MongoDB (DocumentDB) の冗長性設計が未記載 | +0.5 | C5 Countermeasures 5「MongoDB Disaster Recovery」でレプリカセット提案あり |
| B06 | 可用性・冗長性 | ECS Auto Scalingのスケールアウト速度と突発的なトラフィック増加への対応 | +0.5 | M4「Missing Capacity Planning and Load Testing Baseline」で詳細に分析 |
| B08 | 障害回復設計 | Kafka プロデューサーの送信失敗時のリトライ設定とアプリケーション側のエラーハンドリング | +0.5 | C1 Countermeasures 2でTransactional Outbox Pattern提案、C4でも関連言及 |
| B10 | 可用性・冗長性 | 関連予約の整合性チェック（ホテルチェックイン日 < フライト到着日）における分散トランザクションの実現方法 | +0.5 | C6「No Conflict Resolution Strategy for Concurrent Booking Modifications」として明確に指摘 |

**Additional valid bonuses**:
- M7でRDS Read Replicaのスケーリング欠如を指摘（関連: 可用性・冗長性） +0.5
- M6でConfiguration Management and Secret Rotation欠如を指摘（運用性） +0.5

**Bonus Subtotal**: +3.0 (上限5件なので上位5件採用: B01, B06, B08, B10, M7, M6から5件 = +2.5)

### Penalty Points

**スコープ外指摘のチェック**:
- M6「Missing Configuration Management and Versioning」→ 運用性の範囲内、ペナルティなし
- すべての指摘がreliability観点に該当、スコープ外指摘なし

**Penalty Subtotal**: 0

### Run 2 Total Score
**8.0 (detection) + 2.5 (bonus) - 0 (penalty) = 10.5**

---

## Overall Summary

| Metric | Run 1 | Run 2 |
|--------|-------|-------|
| Detection Score | 8.0 | 8.0 |
| Bonus | +2.5 | +2.5 |
| Penalty | -0 | -0 |
| **Total Score** | **10.5** | **10.5** |
| **Mean** | | **10.5** |
| **SD** | | **0.0** |

### Score Breakdown Details

**Run 1**:
- Detection: 8.0 (P01=0.5, P02=1.0, P03=1.0, P04=1.0, P05=1.0, P06=0.5, P07=1.0, P08=1.0, P09=1.0)
- Bonus: +2.5 (B01, B03, B06, B08, B10)
- Penalty: 0
- **Total: 10.5**

**Run 2**:
- Detection: 8.0 (P01=1.0, P02=1.0, P03=1.0, P04=1.0, P05=1.0, P06=0.5, P07=0.5, P08=1.0, P09=1.0)
- Bonus: +2.5 (B01, B06, B08, B10, M7)
- Penalty: 0
- **Total: 10.5**

### Notable Differences

**Run 1 vs Run 2 trade-offs**:
- **P01** (サーキットブレーカーのフォールバック戦略): Run 2の方が明確に「全プロバイダー障害時の最終的なフォールバック戦略の欠如」を指摘 (△→○)
- **P07** (バックグラウンドジョブの障害回復): Run 1の方がリトライ戦略・冪等性設計の欠如を明確に指摘 (○→△)

両者とも埋め込み問題9問中8問を検出し、ボーナス5件を獲得。最終スコアは同点。
