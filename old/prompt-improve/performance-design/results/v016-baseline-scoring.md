# Scoring Report: v016-baseline

## Run 1 Scoring

### Detection Matrix

| Problem ID | Category | Detection | Score | Notes |
|-----------|----------|-----------|-------|-------|
| P01 | パフォーマンス要件 | ○ | 1.0 | C-3で具体的なSLA未定義を指摘、レスポンスタイム目標(p95 < 200ms等)の必要性を明示 |
| P02 | I/O・ネットワーク効率 | × | 0.0 | getEventStats実装のN+1問題を指摘していない。S-2でクエリ分離を指摘しているが、これはregistrations+users JOINとsurvey_responses別クエリの問題を捉えておらず、アプリ内集計の非効率性のみ指摘 |
| P03 | キャッシュ・メモリ管理 | ○ | 1.0 | M-1でRedis利用可能だがキャッシュ戦略未定義を指摘、イベント詳細・ダッシュボード統計等の具体的キャッシュ対象を提示 |
| P04 | レイテンシ・スループット設計 | ○ | 1.0 | C-1で参加申込の競合状態を指摘、トランザクション分離レベル・行ロック・楽観的ロックの必要性を明示 |
| P05 | I/O・ネットワーク効率 | ○ | 1.0 | C-2でリマインダーバッチのN+1問題を指摘、userRepository.findById()の繰り返し実行とJOIN/バッチ取得の必要性を明示 |
| P06 | レイテンシ・スループット設計 | ○ | 1.0 | S-3でメール送信の同期処理を指摘、非同期処理(SQS)の必要性とAPI応答時間への影響を明示 |
| P07 | レイテンシ・スループット設計 | ○ | 1.0 | S-2でregistrations.event_id, registrations.user_id, survey_responses.event_id等の具体的なインデックス欠如を指摘 |
| P08 | スケーラビリティ設計 | ○ | 1.0 | S-5で履歴データの無期限保持による長期的なクエリパフォーマンス劣化とストレージコストへの影響を指摘、アーカイブ・パーティショニング戦略の必要性を明示 |
| P09 | 監視 | ○ | 1.0 | M-4でパフォーマンス固有のメトリクス(APIレスポンスタイム、スループット、DBクエリ時間、キャッシュヒット率)の収集設計欠如を指摘 |

**Detection Subtotal**: 8.0 / 9.0

### Bonus Analysis

| ID | Category | Valid? | Score | Justification |
|----|----------|--------|-------|---------------|
| B06 | リソース管理 | Yes | +0.5 | S-4でデータベース接続プール設定の未定義を指摘、接続数・タイムアウト設定の必要性を明示 |
| B05 | API効率 | Yes | +0.5 | S-2/M-3でダッシュボード統計取得のSQL集約関数(COUNT, GROUP BY)活用を提案、アプリ内集計→DB集計への改善を明示 |
| B01 | I/O効率 | Yes | +0.5 | S-1でイベント一覧取得API(GET /api/events)のページネーション欠如を指摘、月間500イベント蓄積時の効率悪化を明示 |
| B07 | スケーラビリティ | Yes | +0.5 | Positive Design Decisionsセクション項目3でECS Auto Scaling CPU 70%閾値に言及し、request-rate based scalingで補完すべきと提案(C-3でも関連言及) |

**Bonus Subtotal**: +2.0

### Penalty Analysis

| Issue | Category | Score | Justification |
|-------|----------|-------|---------------|
| C-1 Title Misleading | 指摘の正確性 | -0.5 | C-1のタイトルは「Race Condition in Registration Capacity Check」だが、C-2のタイトルは「N+1 Query Antipattern in Reminder Batch」であり、C-1とC-2が逆。しかしC-1の内容は正しく並行制御欠如を指摘しているため、タイトル誤りのみペナルティ対象 |
| Positive Aspects in Minor Section | 構造の逸脱 | -0.5 | 「Minor Observations and Positive Aspects」セクションで肯定的側面を5件列挙しているが、これは問題検出ではなくレビュー範囲外のポジティブフィードバック。パフォーマンス観点での問題検出に集中すべき |

**Penalty Subtotal**: -1.0

### Run 1 Total Score
```
Detection: 8.0
Bonus: +2.0
Penalty: -1.0
Total: 9.0
```

---

## Run 2 Scoring

### Detection Matrix

| Problem ID | Category | Detection | Score | Notes |
|-----------|----------|-----------|-------|-------|
| P01 | パフォーマンス要件 | ○ | 1.0 | C-3で具体的なSLA未定義を指摘、レスポンスタイム目標(p95 < 200ms等)の必要性を明示 |
| P02 | I/O・ネットワーク効率 | × | 0.0 | getEventStats実装のN+1問題を指摘していない。S-2で言及しているのはアプリ内集計の非効率性のみで、クエリ分離(registrations+users JOINとsurvey_responses別クエリ)の問題を捉えていない |
| P03 | キャッシュ・メモリ管理 | ○ | 1.0 | S-5でRedis利用可能だがキャッシュ戦略未定義を指摘、イベント詳細・ユーザープロファイル・ダッシュボード統計等の具体的キャッシュ対象を提示 |
| P04 | レイテンシ・スループット設計 | ○ | 1.0 | C-2で参加申込の競合状態を指摘、トランザクション・行ロック・楽観的ロックの必要性を明示 |
| P05 | I/O・ネットワーク効率 | ○ | 1.0 | S-1でリマインダーバッチのN+1問題を指摘、userRepository.findById()の繰り返し実行とバッチ取得・非同期処理の必要性を明示 |
| P06 | レイテンシ・スループット設計 | ○ | 1.0 | S-4でメール送信の同期処理を指摘、非同期処理(SQS)の必要性とAPI応答時間への影響を明示 |
| P07 | レイテンシ・スループット設計 | ○ | 1.0 | S-3でregistrations.event_id, registrations.event_status, events.start_datetime等の具体的なインデックス欠如を指摘 |
| P08 | スケーラビリティ設計 | ○ | 1.0 | M-3で履歴データの無期限保持による長期的なクエリパフォーマンス劣化とストレージコストへの影響を指摘、アーカイブ・パーティショニング戦略の必要性を明示 |
| P09 | 監視 | ○ | 1.0 | M-4でパフォーマンス固有のメトリクス(DBクエリ実行時間、APIレイテンシp50/p95/p99、キャッシュヒット/ミス率、キュー処理遅延)の収集設計欠如を指摘 |

**Detection Subtotal**: 8.0 / 9.0

### Bonus Analysis

| ID | Category | Valid? | Score | Justification |
|----|----------|--------|-------|---------------|
| B06 | リソース管理 | Yes | +0.5 | M-1でデータベース接続プール設定の未定義を指摘、プールサイズ・タイムアウト設定の必要性を明示 |
| B05 | API効率 | Yes | +0.5 | S-2でダッシュボード統計取得のSQL集約関数(COUNT, GROUP BY)活用を提案、アプリ内集計→DB集計への改善を明示 |
| B01 | I/O効率 | Yes | +0.5 | C-1でイベント一覧取得API(GET /api/events)のページネーション欠如を指摘、年間6,000+イベント蓄積時の効率悪化を明示 |

**Bonus Subtotal**: +1.5

### Penalty Analysis

No penalties detected in Run 2.

**Penalty Subtotal**: 0.0

### Run 2 Total Score
```
Detection: 8.0
Bonus: +1.5
Penalty: 0.0
Total: 9.5
```

---

## Summary Statistics

| Metric | Run 1 | Run 2 | Mean | SD |
|--------|-------|-------|------|-----|
| Detection Score | 8.0 | 8.0 | 8.0 | 0.00 |
| Bonus Count | 4 | 3 | 3.5 | 0.50 |
| Penalty Count | 2 | 0 | 1.0 | 1.00 |
| Total Score | 9.0 | 9.5 | 9.25 | 0.25 |

### Key Observations

1. **Consistent Core Detection**: Both runs successfully detected 8/9 embedded problems with identical detection patterns. Only P02 (ダッシュボード統計取得のN+1問題) was consistently missed.

2. **P02 Analysis**: Both runs identified performance issues in `getEventStats` but focused on application-layer aggregation inefficiency (S-2/M-3) rather than the query-layer N+1 problem (registrations+users JOIN followed by separate survey_responses query). The detection criteria require identifying the specific N+1 pattern of query separation, which neither run achieved.

3. **High Stability**: SD=0.25 indicates excellent consistency between runs. The minor variation comes from:
   - Run 1: 4 bonuses, 2 penalties → net +2.0 adjustment
   - Run 2: 3 bonuses, 0 penalties → net +1.5 adjustment

4. **Bonus Consistency**: 3 bonuses (B01, B05, B06) appeared in both runs. Only B07 (auto-scaling閾値検証) was unique to Run 1.

5. **Penalty Pattern**: Run 1's penalties were both structural/format issues rather than factual errors:
   - Misleading section title ordering (C-1/C-2 swap)
   - Inclusion of positive feedback in "Minor Observations"

6. **Strengths**:
   - Comprehensive coverage of race conditions, N+1 patterns (in reminders), synchronous blocking, indexing, caching strategy absence
   - Specific remediation guidance with code examples
   - Clear severity categorization

7. **Weakness**:
   - Difficulty detecting N+1 patterns when they involve query separation across multiple queries (P02) vs. nested loop patterns (P05)
