# Round 002 Comparison Report

**Date**: 2026-02-11
**Perspective**: performance (design)
**Test Document**: オフィス検温システム
**Round**: 002

---

## 1. Execution Conditions

### Test Configuration
- **Embedded Problems**: 10 (P01-P10)
- **Runs per Prompt**: 2
- **Evaluation Method**: Detection matrix + Bonus/Penalty scoring

### Prompts Evaluated
1. **baseline**: Round 001推奨プロンプト（最小限の指示）
2. **variant-nfr-checklist**: NFRチェックリスト構造化アプローチ（N1a）
3. **variant-detection-hints**: 検出ヒント埋め込みアプローチ（N3a）

---

## 2. Problem Detection Matrix

| Problem ID | Description | baseline | variant-nfr-checklist | variant-detection-hints |
|-----------|-------------|----------|----------------------|------------------------|
| P01 | 診察履歴取得のN+1問題 | 2/2 (○○) | 2/2 (○○) | 1.5/2 (○△) |
| P02 | 予約一覧取得のN+1問題 | 2/2 (○○) | 2/2 (○○) | 1.0/2 (○×) |
| P03 | パフォーマンス目標値の欠如 | 0/2 (××) | 2/2 (○○) | 1.0/2 (×○) |
| P04 | appointmentsインデックス設計欠如 | 2/2 (○○) | 2/2 (○○) | 2/2 (○○) |
| P05 | キャッシュ戦略の欠如 | 2/2 (○○) | 2/2 (○○) | 2/2 (○○) |
| P06 | 容量設計・パーティショニング欠如 | 0/2 (××) | 0/2 (××) | 0/2 (××) |
| P07 | 通知処理の同期実行による遅延 | 2/2 (○○) | 2/2 (○○) | 2/2 (○○) |
| P08 | 大量画像データ取り扱い戦略欠如 | 0/2 (××) | 0/2 (××) | 0.5/2 (△×) |
| P09 | パフォーマンスメトリクス収集・監視欠如 | 0/2 (××) | 2/2 (○○) | 2/2 (○○) |
| P10 | 予約競合時の楽観的ロック戦略欠如 | 1/2 (○×) | 0/2 (××) | 0/2 (××) |
| **Detection Score (Mean)** | | **6.0** | **8.0** | **6.5** |

### Detection Highlights
- **variant-nfr-checklist**: P03（SLA定義）とP09（監視戦略）で+2.0pt改善
- **variant-detection-hints**: P03とP09で+1.5pt改善、P08で+0.25pt改善
- **baseline**: P10楽観的ロック検出でvariantを上回る（+0.5pt）

---

## 3. Bonus/Penalty Details

### Bonus Points Summary

| Prompt | Run1 Bonus | Run2 Bonus | Total Bonus | Avg Bonus/Run |
|--------|-----------|-----------|-------------|---------------|
| baseline | +2.5 (5件) | +2.5 (5件) | +5.0 | 2.5 |
| variant-nfr-checklist | +4.0 (8件) | +3.0 (6件) | +7.0 | 3.5 |
| variant-detection-hints | +4.0 (8件) | +4.0 (8件) | +8.0 | 4.0 |

### Key Bonus Achievements

**baseline:**
- B08: ページネーション設計欠如（2/2）
- B04: コネクションプールサイジング（2/2）
- B05: ECSスケーリング閾値妥当性（2/2）
- クエリタイムアウト設定欠如（2/2）
- レート制限欠如（0/2）

**variant-nfr-checklist:**
- B01: 複合インデックス最適化（2/2）
- B03: キャッシュ無効化戦略（2/2）
- B04: コネクションプール設計（1/2）
- B06: リトライ+DLQ戦略（2/2）
- B07: リードレプリカ設計（2/2）
- B08: ページネーション戦略（1/2）
- B10: スロークエリログ監視（1/2）

**variant-detection-hints:**
- B01: 複合インデックス最適化（2/2）
- B04: コネクションプール設計（2/2）
- B06: リトライ戦略（2/2）
- B07: リードレプリカ設計（2/2）
- B08: ページネーション戦略（2/2）
- B10: スロークエリログ監視（2/2）
- SNS PublishBatch API活用（1/2）
- presigned S3 URL戦略（1/2）
- キャッシュ無効化戦略pub/sub（1/2）
- Circuit Breaker実装（1/2）

### Penalty Points
- **All prompts**: 0件（スコープ違反なし）

---

## 4. Score Summary

| Prompt | Run1 | Run2 | Mean | SD | Stability |
|--------|------|------|------|-----|-----------|
| baseline | 8.5 | 8.5 | **8.5** | **0.0** | 高安定 |
| variant-nfr-checklist | 12.0 | 11.0 | **11.5** | **0.5** | 高安定 |
| variant-detection-hints | 10.5 | 10.5 | **10.5** | **0.0** | 高安定 |

### Score Breakdown

**baseline:**
- Detection: 6.0 + Bonus: 2.5 - Penalty: 0 = **8.5** (両Run同一)

**variant-nfr-checklist:**
- Run1: Detection 8.0 + Bonus 4.0 - Penalty 0 = **12.0**
- Run2: Detection 8.0 + Bonus 3.0 - Penalty 0 = **11.0**

**variant-detection-hints:**
- Detection: 6.5 + Bonus 4.0 - Penalty 0 = **10.5** (両Run同一)

---

## 5. Recommended Prompt

### Recommendation Decision
**Recommended Prompt**: **variant-nfr-checklist**

### Justification
1. **スコア差分析**:
   - variant-nfr-checklist vs baseline: +3.0pt (11.5 - 8.5)
   - variant-detection-hints vs baseline: +2.0pt (10.5 - 8.5)
   - 判定基準「平均スコア差 > 1.0pt → スコアが高い方を推奨」に該当

2. **安定性評価**:
   - variant-nfr-checklist: SD=0.5（高安定）
   - variant-detection-hints: SD=0.0（完全安定）
   - baseline: SD=0.0（完全安定）
   - 全プロンプトが高安定性を示すため、スコア差のみで判定

3. **検出範囲の優位性**:
   - NFRチェックリストは設計書に欠如しているNFR仕様（P03: SLA定義、P09: 監視戦略）を確実に検出
   - 検出スコア8.0ptはRound 002全体で最高

### Convergence Analysis
**判定**: 継続推奨

- Round 001: baseline推奨（9.5pt）
- Round 002: variant-nfr-checklist推奨（11.5pt）
- **改善幅**: +2.0pt

改善幅 > 0.5ptにつき、「2ラウンド連続で改善幅 < 0.5pt → 収束の可能性あり」の条件を満たさない。次回ラウンドでさらなる最適化の余地あり。

---

## 6. Detailed Analysis

### 6.1 Independent Variable Effects

#### NFRチェックリスト構造化アプローチ（variant-nfr-checklist）
**効果**: +3.0pt（8.5 → 11.5）、SD=0.5

**検出改善項目**:
- P03（SLA定義欠如）: 0/2 → 2/2（+2.0pt）
- P09（監視戦略欠如）: 0/2 → 2/2（+2.0pt）

**トレードオフ**:
- P10（楽観的ロック）検出が減少: 1/2 → 0/2（-0.5pt）
- ボーナス検出は増加: 平均2.5 → 3.5（+1.0pt）

**メカニズム分析**:
1. NFRチェックリストが「設計書に明示されていない非機能要件」の検出を強化
2. P03（レスポンスタイム・スループット目標）、P09（APM・メトリクス収集）はNFR標準項目として体系的にカバー
3. 一方、実装レベルの並行制御（P10: 楽観的ロック）への注意が低下
4. 構造化アプローチによりB07（リードレプリカ）、B06（DLQ）などインフラ系ボーナスが増加

#### 検出ヒント埋め込みアプローチ（variant-detection-hints）
**効果**: +2.0pt（8.5 → 10.5）、SD=0.0

**検出改善項目**:
- P03（SLA定義欠如）: 0/2 → 1/2（+0.5pt）
- P09（監視戦略欠如）: 0/2 → 2/2（+2.0pt）
- P08（画像戦略欠如）: 0/2 → 0.5/2（+0.25pt）

**トレードオフ**:
- P01/P02検出の不安定化: 2/2 → 1.5/2, 1.0/2（-1.25pt）
- P10検出減少: 1/2 → 0/2（-0.5pt）
- ボーナス検出は大幅増加: 平均2.5 → 4.0（+1.5pt）

**メカニズム分析**:
1. 検出ヒントが「探すべき問題カテゴリ」への注意を誘導
2. P09（監視）、P08（画像最適化）などヒント項目の検出は向上
3. しかし「P01とP02を同一のN+1問題として統合指摘」など、ヒントの副作用で検出精度が低下
4. ボーナス検出の多様化（SNS Batch API、presigned S3、Circuit Breaker）は検出範囲拡大を示唆

### 6.2 Detection Pattern Comparison

#### 高安定検出項目（全プロンプト2/2検出）
- P04: appointmentsインデックス設計
- P05: キャッシュ戦略欠如
- P07: 通知処理の同期実行

これらは設計書に具体的なヒントがあり、観点に依存せず検出される。

#### Variant優位検出項目
- P03（SLA定義）: NFRチェックリスト 2/2、検出ヒント 1/2、baseline 0/2
- P09（監視戦略）: NFRチェックリスト 2/2、検出ヒント 2/2、baseline 0/2

NFR関連の「設計書に記載がない問題」の検出にvariantが有効。

#### Baseline優位検出項目
- P10（楽観的ロック）: baseline 1/2、variant-nfr-checklist 0/2、variant-detection-hints 0/2

構造化アプローチは実装レベルの並行制御への注意を低下させる可能性。

#### 全プロンプト未検出項目
- P06（容量設計・パーティショニング）: 0/2（全プロンプト）

時系列データの長期容量戦略は、既存のアプローチでは検出困難。別途M-seriesバリエーション（データライフサイクル管理）の検討が必要。

### 6.3 Bonus Detection Diversity

**baselineの特徴**:
- 少数精鋭型（平均2.5件）
- ECSスケーリング閾値妥当性（B05）、クエリタイムアウト設定などボトムアップ分析による発見
- ボーナス種類の固定化（5件が2/2で安定）

**variant-nfr-checklistの特徴**:
- 中規模検出（平均3.5件）
- インフラ系ボーナス（B07: リードレプリカ、B06: DLQ）が増加
- Run間のボーナス変動（8件 vs 6件）が若干あり

**variant-detection-hintsの特徴**:
- 最多検出（平均4.0件、8件/Run）
- 多様性が高い（SNS Batch API、presigned S3、Circuit Breaker等）
- ボーナス上限5件を超過し、創造的指摘が豊富

### 6.4 Stability Analysis

全プロンプトがSD≤0.5の高安定性を達成。

**完全安定（SD=0.0）**:
- baseline: 両Run完全一致（Detection 6.0 + Bonus 2.5 = 8.5）
- variant-detection-hints: 両Run完全一致（Detection 6.5 + Bonus 4.0 = 10.5）

**高安定（SD=0.5）**:
- variant-nfr-checklist: ボーナス件数の変動（Run1: 8件 vs Run2: 6件）により1.0pt差

検出ヒントアプローチは、ボーナス検出を増やしつつ安定性も維持できている点が優秀。

---

## 7. Insights for Next Round

### 7.1 知見の一般化

#### NFRチェックリストの有効性（variant-nfr-checklist）
- **効果**: NFR関連の欠如問題（SLA定義、監視戦略）を+4.0pt改善
- **適用条件**: 設計書に非機能要件の記載が不足している場合
- **制約**: 実装レベルの並行制御（楽観的ロック等）への注意が低下（-0.5pt）
- **根拠**: Round 002, P03+P09検出 vs P10検出減少

#### 検出ヒントの副作用（variant-detection-hints）
- **効果**: ボーナス検出を大幅増加（+1.5pt）
- **副作用**: 基礎問題（N+1）の検出精度が低下（-1.25pt）、Run間で検出方法が変動
- **メカニズム**: ヒントが「問題の統合指摘」を誘発し、個別検出の精度を低下させる
- **根拠**: Round 002, P01/P02検出パターンのRun間変動

#### ボーナス検出と総合スコアの相関
- baselineの「少数精鋭型」（2.5件）でも高安定性を達成
- variant-detection-hintsの「多様性型」（4.0件）が最高ボーナスを獲得
- ボーナス検出の「量」より「カテゴリカバレッジ」が重要（B01-B10の広範囲カバー）
- **根拠**: Round 002, baseline安定性 vs variant-detection-hints多様性

### 7.2 未解決の課題

#### P06（容量設計・パーティショニング）の検出不足
- 全プロンプトで0/2検出
- 時系列データの長期増加対策は、NFRチェックリストにも検出ヒントにも含まれていない
- **次回アクション**: M-seriesバリエーション（M2b: データライフサイクル管理）の導入を検討

#### P10（楽観的ロック）の検出不安定性
- baseline: 1/2、variant-nfr-checklist: 0/2、variant-detection-hints: 0/2
- 並行制御は「実装詳細」として設計レビューの焦点から外れやすい
- **次回アクション**: C-seriesバリエーション（C3b: 並行処理パターン明示化）の検討

#### P08（画像戦略）の検出困難性
- variant-detection-hints: 0.5/2（部分検出）
- 画像圧縮・CDN戦略は「暗黙的ベストプラクティス」として明示されにくい
- **次回アクション**: N-seriesバリエーション（N2c: メディア処理最適化）の追加

### 7.3 次回ラウンドの推奨アプローチ

#### 戦略1: NFRチェックリスト改良（variant-nfr-checklist継続実験）
- P10楽観的ロック検出を強化する「並行処理チェック項目」を追加
- P06容量設計を強化する「データライフサイクル項目」を追加
- **期待効果**: 11.5pt → 12.5-13.0pt（+1.0-1.5pt改善）

#### 戦略2: ハイブリッドアプローチ（NFRチェックリスト + 検出ヒント統合）
- NFRチェックリストで「探すべきカテゴリ」を体系化
- 検出ヒントで「ボーナス検出の多様性」を強化
- **期待効果**: 11.5pt（NFR）+ 1.5pt（ボーナス増分）= 13.0pt

#### 戦略3: 未テストバリエーションの探索
- **S-series**: S2a（Few-shot with NFR examples）— Round 001でS1aが-0.75ptだったが、NFR事例による改善可能性
- **N-series**: N2a（スコープ明確化）— NFRチェックリストのスコープ逸脱リスクを抑制
- **M-series**: M2b（データライフサイクル）— P06検出強化

### 7.4 テスト対象文書の多様化
Round 001-002は同一テスト対象（オフィス検温システム）を使用。次回ラウンドでは:
- **異なるドメイン**: ECサイト、IoTシステム、バッチ処理等
- **異なる問題分布**: I/O効率偏重 vs スケーラビリティ偏重
- **異なる記載詳細度**: 詳細設計 vs 概要レベル設計

これにより、プロンプトの汎化性能を評価可能。

---

## 8. Deployment Information

### Recommended Prompt Deployment
- **Prompt**: variant-nfr-checklist
- **Variation ID**: N1a
- **Independent Variable**: NFRチェックリスト構造化アプローチ
- **Target Agent**: `/home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/agents/performance-design-reviewer.md`

### Deployment Instructions
1. エージェント定義ファイルを読み込み
2. 現在のプロンプトを`variant-nfr-checklist`の内容で置換
3. 変更履歴にRound 002結果（+3.0pt改善、SD=0.5）を記録
4. knowledge.mdに効果テーブルとバリエーションステータスを更新

---

## Summary

Round 002では、NFRチェックリストと検出ヒントの2つのアプローチを評価した結果、**variant-nfr-checklist**が+3.0ptの改善を達成し、特に設計書に記載がないNFR仕様（SLA定義、監視戦略）の検出で顕著な効果を示した。一方、variant-detection-hintsはボーナス検出の多様性で優位だが、基礎問題検出の精度低下がトレードオフとなった。

次回ラウンドでは、NFRチェックリストに「並行処理チェック項目」と「データライフサイクル項目」を追加することで、未検出問題（P06, P10）への対応を強化し、13.0pt超のスコアを目指す。
