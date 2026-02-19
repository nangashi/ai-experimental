# Round 004 Comparison Report

**Date**: 2026-02-11
**Perspective**: performance (design review)
**Test Domain**: オフィス検温システム（health monitoring platform）
**Embedded Problems**: 10

---

## 実行条件

### 比較対象プロンプト

| Prompt Name | Variation ID | 変更内容 |
|------------|--------------|----------|
| baseline | - | 最小限の指示（データライフサイクルチェックリスト統合版） |
| variant-english | L1b | 英語指示への変更（全セクション英語化、テンプレート変更なし） |
| variant-scoring | S2a (Run1) / S2b (Run2) | 構造化Scoring Rubric導入（5カテゴリ+評価基準明示） |

### テスト対象ドメイン
- **対象システム**: オフィス検温システム（health monitoring platform）
- **主要ユースケース**: デバイスからのバイタルデータ収集、ダッシュボード表示、アラート通知、レポート生成
- **主要技術スタック**: Spring Boot, PostgreSQL, WebSocket, Redis, CloudWatch

### 埋め込み問題カテゴリ (10問)
- **重大**: P01 (ダッシュボードポーリング), P02 (N+1問題), P03 (データ増大)
- **中**: P04 (レポートタイムアウト), P05 (ページネーション), P06 (インデックス設計), P07 (再接続ストーム), P08 (アラート遅延)
- **軽微**: P09 (並行書き込み), P10 (監視メトリクス)

---

## 問題別検出マトリクス

| Problem ID | baseline Run1 | baseline Run2 | variant-english Run1 | variant-english Run2 | variant-scoring Run1 | variant-scoring Run2 | Category |
|-----------|--------------|--------------|---------------------|---------------------|---------------------|---------------------|----------|
| P01 | ○ | ○ | ○ | ○ | ○ | ○ | I/O・ネットワーク効率 |
| P02 | △ | × | × | × | × | × | I/O・ネットワーク効率 |
| P03 | ○ | ○ | ○ | ○ | ○ | ○ | データベース設計・容量計画 |
| P04 | × | △ | ○ | ○ | × | ○ | 並行処理・レイテンシ設計 |
| P05 | × | × | × | × | × | × | データベース設計・I/O効率 |
| P06 | △ | ○ | ○ | ○ | ○ | ○ | データベース設計 |
| P07 | × | × | △ | △ | × | × | スケーラビリティ・ネットワーク効率 |
| P08 | × | △ | ○ | ○ | × | × | レイテンシ設計・並行処理 |
| P09 | ○ | ○ | ○ | ○ | ○ | ○ | 並行処理・データベース設計 |
| P10 | △ | × | × | × | × | × | 監視・パフォーマンス要件 |

### 検出率サマリ

| Prompt | 完全検出 (○) | 部分検出 (△) | 未検出 (×) | 検出スコア合計 |
|--------|------------|------------|----------|------------|
| baseline Run1 | 4 | 3 | 3 | 4.5 |
| baseline Run2 | 5 | 3 | 2 | 5.0 |
| variant-english Run1 | 6 | 1 | 3 | 6.5 |
| variant-english Run2 | 6 | 1 | 3 | 6.5 |
| variant-scoring Run1 | 4 | 0 | 6 | 4.0 |
| variant-scoring Run2 | 5 | 0 | 5 | 5.0 |

---

## ボーナス/ペナルティ詳細

### ボーナス検出数

| Prompt | Run1 Bonus | Run2 Bonus | 主要カテゴリ |
|--------|-----------|-----------|------------|
| baseline | 4件 (+2.0pt) | 8件 (+2.5pt, 上限5件制限) | キャッシュ、リードレプリカ、TimescaleDB、コネクションプール、非同期キュー、マテリアライズドビュー、WebSocketリソース管理 |
| variant-english | 5件 (+2.5pt) | 5件 (+2.5pt) | Redis caching, read replica, pre-aggregation, connection state management, connection pool sizing, TimescaleDB, message queue, hourly summary table |
| variant-scoring | 5件 (+2.5pt) | 5件 (+2.5pt) | Redis caching, read replica, write-behind queue, downsampling, WebSocket scaling, multi-tier caching, connection pool, micro-batching |

### ボーナスカテゴリ分布

| Category | baseline | variant-english | variant-scoring |
|----------|----------|----------------|----------------|
| B01 (キャッシュ) | 両実行で検出 | 両実行で検出 | 両実行で検出 |
| B03 (リードレプリカ) | 両実行で検出 | 両実行で検出 | Run1のみ検出 |
| B04 (非同期キュー) | Run2のみ検出 | Run2のみ検出 | 両実行で検出 |
| B05 (WebSocketスケーラビリティ) | Run2のみ検出 | Run1で検出 | 両実行で検出 |
| B07 (TimescaleDB) | 両実行で検出 | Run2のみ検出 | なし |
| B09 (プリコンピューテーション) | Run2のみ検出 | 両実行で検出 | なし |
| B10 (コネクションプール) | 両実行で検出 | 両実行で検出 | Run2のみ検出 |

### ペナルティ

全プロンプトで **ペナルティ0件** を達成。スコープ外問題（セキュリティ等）への言及なし。

---

## スコアサマリ

| Prompt | Mean | SD | Run1 Score | Run2 Score | Stability |
|--------|------|-----|-----------|-----------|-----------|
| baseline | **7.5** | 0.5 | 7.0 | 8.0 | 高安定 (SD ≤ 0.5) |
| variant-english | **9.0** | 0.0 | 9.0 | 9.0 | 高安定 (SD ≤ 0.5) |
| variant-scoring | **7.0** | 0.5 | 6.5 | 7.5 | 高安定 (SD ≤ 0.5) |

### スコア構成内訳

| Prompt | Detection (Avg) | Bonus (Avg) | Penalty | Total |
|--------|----------------|-------------|---------|-------|
| baseline | 4.75 | +2.25 | -0.0 | 7.5 |
| variant-english | 6.5 | +2.5 | -0.0 | 9.0 |
| variant-scoring | 4.5 | +2.5 | -0.0 | 7.0 |

---

## 推奨判定

### 推奨プロンプト: **variant-english**

### 判定根拠

scoring-rubric.md Section 5の推奨判定基準に基づき判定:

1. **平均スコア差の評価**:
   - variant-english vs baseline: 9.0 - 7.5 = **+1.5pt差** (> 1.0pt)
   - variant-english vs variant-scoring: 9.0 - 7.0 = **+2.0pt差** (> 1.0pt)
   - **判定**: 平均スコア差 > 1.0ptのため、**variant-englishを推奨**

2. **安定性の確認**:
   - variant-english: SD = 0.0 (完全安定)
   - baseline: SD = 0.5 (高安定)
   - variant-scoring: SD = 0.5 (高安定)
   - **判定**: variant-englishは完全安定性を達成

3. **検出精度の向上**:
   - P04 (レポートタイムアウト): baseline △/× → variant-english ○/○
   - P06 (インデックス設計): baseline △/○ → variant-english ○/○
   - P08 (アラート遅延): baseline ×/△ → variant-english ○/○
   - **判定**: 基礎検出スコアが+1.75pt向上（4.75 → 6.5）

### 収束判定: **継続推奨**

- Round 003 → Round 004 改善幅:
  - baseline系統: 6.75 → 7.5 (+0.75pt)
  - best variant: 9.0 → 9.0 (Round 003 data-lifecycle 9.0 → Round 004 variant-english 9.0)
- 改善幅 < 0.5ptではないため、収束条件（2ラウンド連続 < 0.5pt）には該当せず
- **判定: 継続推奨**

---

## 考察

### 独立変数ごとの効果分析

#### 1. 英語化の効果 (L1b: variant-english)

**効果**: +1.5pt改善 (7.5 → 9.0)

**主要な検出精度向上**:
- P04 (レポートタイムアウト): baseline ×/△ → variant-english ○/○
  - 英語指示により「async job queue」概念がより明確に伝達された
  - baselineではP04検出が不安定（Run1未検出）だったが、英語化により両実行で安定検出
- P06 (インデックス設計): baseline △/○ → variant-english ○/○
  - 複合インデックスの具体的な設計（CREATE INDEX文）が安定して出力された
- P08 (アラート遅延): baseline ×/△ → variant-english ○/○
  - "Alert Service Design Lacks Throttling and Deduplication"として明確に問題を分類

**安定性の向上**:
- SD = 0.5 → 0.0 (完全安定性達成)
- Run間の検出パターンのばらつきが完全に排除された

**ボーナス検出の安定化**:
- baseline: Run1 4件 / Run2 8件（変動大）
- variant-english: Run1 5件 / Run2 5件（完全一致）
- ボーナスカテゴリの出力が予測可能になり、多様性は維持しつつ安定性が向上

**推論されるメカニズム**:
- 英語指示により、LLMの事前学習データに最も頻繁に出現する「技術文書の標準的な表現パターン」を活用できた
- 「async job queue」「throttling」「deduplication」などの技術用語が、日本語訳（「非同期ジョブキュー」「スロットリング」「重複排除」）よりも直接的に意味解釈された
- 構造化指示（NFRチェックリスト、データライフサイクル観点）が英語で記述されることで、各項目の意図がより明確に伝わった

#### 2. Scoring Rubricの効果 (S2a/S2b: variant-scoring)

**効果**: -0.5pt劣化 (7.5 → 7.0)

**検出精度の変化**:
- **改善点**: P06インデックス設計が完全検出（○/○）に安定化
- **劣化点**: P02 (N+1), P10 (監視メトリクス) が完全未検出（△/× → ×/×）

**Scoring Rubricの副作用**:
- Run1 (S2a Broad Mode) vs Run2 (S2b Deep Mode) でP04検出に差異（×/○）
  - Broad ModeはNFRチェックリスト重視、Deep Modeは実装詳細分析重視
  - モード依存により安定性が低下
- 採点基準の明示により「評価モード」が誘発され、部分検出（△）が消失
  - P02 N+1問題: baseline △/× → variant-scoring ×/×
  - 「関連する指摘はあるが核心を捉えていない」→「指摘自体が消失」に変化

**過去の知見との整合性**:
- Round 001でC1a (Explicit Scoring Rubric) が -1.5pt劣化、SD=1.0の不安定性を示した
- Round 004のS2a/S2bは採点基準を5カテゴリに構造化したことで安定性は改善（SD=0.5）したが、検出精度の劣化は解消されなかった

**推論されるメカニズム**:
- 明示的な採点基準が「設計書を評価する」モードを誘発し、「問題を発見する」探索的思考を抑制
- 5カテゴリの構造化により「カテゴリ外の問題」（N+1はIssue A Dashboard N+1として誤分類、P10は監視カテゴリに未対応）が見落とされた
- カテゴリ分解は検出を強制するが、柔軟な問題発見（ボーナス検出の多様性）を阻害する可能性

#### 3. 日本語vs英語の比較（baseline vs variant-english）

**共通点**:
- 両方とも重大問題（P01, P03）を確実に検出
- データライフサイクルチェックリスト（M2b統合版）が有効に機能
- ペナルティ0件達成

**差異**:
| 観点 | baseline (日本語) | variant-english (英語) |
|------|------------------|----------------------|
| 検出精度 | 4.75 (avg) | 6.5 (+1.75pt) |
| 安定性 | SD=0.5 | SD=0.0 |
| ボーナス多様性 | Run1 4件, Run2 8件 | Run1 5件, Run2 5件 |
| P04検出 | 不安定 (×/△) | 安定 (○/○) |
| P06検出 | 不安定 (△/○) | 安定 (○/○) |
| P08検出 | 不安定 (×/△) | 安定 (○/○) |

**推論されるメカニズム**:
- LLMの事前学習データにおける「パフォーマンスレビュー文書」の出現頻度が英語で圧倒的に多い
- 技術用語の標準化: 英語では「async job queue」が単一の概念として学習されているが、日本語では「非同期ジョブキュー」「非同期処理キュー」「バックグラウンドジョブ」等の表現揺れがある
- NFRチェックリストや評価観点の記述が英語で統一されることで、各項目の意味解釈が一貫性を持つ

### 次回への示唆

#### 1. 英語化の優位性を活用
- **推奨アクション**: 他の観点（security, consistency等）でもL1b英語化バリエーションを優先的にテスト
- **根拠**: +1.5pt改善と完全安定性（SD=0.0）達成の実績
- **注意点**: ユーザーとのコミュニケーションは日本語で、内部処理のみ英語化する設計が必要

#### 2. Scoring Rubricの慎重な扱い
- **推奨アクション**: 明示的な採点基準の導入は避け、問題発見モードを維持
- **根拠**: S2a/S2bで-0.5pt劣化、C1aで-1.5pt劣化の一貫した傾向
- **代替案**: 「発見すべき問題カテゴリのヒント」ではなく「評価観点の深掘り方法」を示す

#### 3. N+1問題の検出難易度
- **現状**: 全プロンプトでP02 (N+1) を完全未検出
- **推奨アクション**: N2a (Query Pattern Detection) バリエーションのテスト
  - approach-catalog.md N2aは「Detect problematic query patterns (N+1, missing JOINs)」を明示
- **期待効果**: P02検出により+1.0pt改善、総合9.0 → 10.0の可能性

#### 4. ページネーション・監視メトリクスの検出強化
- **現状**: P05 (ページネーション), P10 (監視メトリクス) を全プロンプトで未検出
- **推奨アクション**:
  - P05: N2c (API Performance Requirements) バリエーションでページネーション要件を明示
  - P10: monitoring.md perspectives追加でパフォーマンス監視の観点を強化
- **期待効果**: +1.0pt改善 (各+0.5pt)

#### 5. 英語化の副作用検証
- **検証事項**: 英語化により日本語特有の表現（「N+1問題」「データライフサイクル」等）の意味が変化していないか
- **推奨アクション**: Round 005でL1b英語化baselineを再テスト、P02検出状況を確認
- **懸念**: 英語化により「N+1 problem」が一般的すぎて見落とされる可能性

#### 6. データライフサイクルチェックリストの有効性確認
- **現状**: Round 003でM2bが+2.25pt改善、Round 004でも全プロンプトでP03完全検出
- **推奨アクション**: M2bデータライフサイクルチェックリストをbaselineに統合済みのため、次ラウンドも維持
- **期待効果**: P03 (データ増大) の安定検出を継続

#### 7. 収束判定の継続監視
- **現状**: Round 004で+0.75pt改善（6.75 → 7.5 baseline系統）
- **次回判定条件**: Round 005で改善幅 < 0.5ptとなった場合、収束の可能性を判定
- **推奨アクション**: N2a (Query Pattern Detection) で新たな改善の余地を探索

---

## 推奨デプロイ情報

### デプロイ対象プロンプト
- **Prompt Name**: variant-english
- **Variation ID**: L1b (Language Localization - English)
- **独立変数**: 指示言語の英語化（全セクション英語化、テンプレート構造は維持）

### デプロイ先
- **ファイルパス**: `/home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/agents/performance-design-reviewer.md`
- **バックアップ**: 現在のbaseline版を `performance-design-reviewer-baseline-round004.md` として保存

### デプロイ理由
1. 平均スコア+1.5pt改善 (7.5 → 9.0)
2. 完全安定性達成 (SD = 0.0)
3. P04/P06/P08の検出精度向上
4. ボーナス検出の安定化（5件/Run）

### 期待される効果
- 他の観点（security, consistency, best-practices, maintainability）でも同様の改善（+1.0~1.5pt）が期待される
- NFRチェックリストやデータライフサイクル観点が英語で記述されることで、各項目の意図がより明確に伝わる

---

## 次回実験の推奨

### 優先度1: N2a (Query Pattern Detection) の導入
- **目的**: P02 (N+1問題) の検出強化
- **期待効果**: +1.0pt改善（P02完全検出）
- **リスク**: 基礎検出が充実するとボーナス検出が減少する可能性（Round 002 N3aの教訓）

### 優先度2: 英語化の他観点への展開
- **対象**: security-design-reviewer, consistency-design-reviewer, best-practices-design-reviewer
- **期待効果**: 各観点で+1.0~1.5pt改善、SD低下

### 優先度3: P05/P10の検出強化
- **P05**: N2c (API Performance Requirements) でページネーション要件明示
- **P10**: monitoring.md perspectives追加でパフォーマンス監視観点強化
- **期待効果**: +1.0pt改善

### 非推奨: Scoring Rubricの再導入
- **理由**: 2回連続で劣化（C1a -1.5pt, S2a/S2b -0.5pt）
- **代替案**: 問題発見モードを維持し、評価観点の深掘り方法を示す方向で改善

---

## 総括

Round 004では、英語化（L1b）が+1.5pt改善と完全安定性（SD=0.0）達成により、最も有効な改善手法であることが確認された。Scoring Rubric（S2a/S2b）は検出精度の劣化（-0.5pt）を示し、明示的な採点基準が問題発見モードを阻害することが再確認された。次回はN2a (Query Pattern Detection) を導入し、P02 (N+1問題) の検出強化を図ることで、総合スコア10.0を目指す。
