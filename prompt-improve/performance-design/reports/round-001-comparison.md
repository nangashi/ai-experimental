# Round 001 Comparison Report: performance-design

**Generated**: 2026-02-11

---

## 1. Execution Conditions

- **Round**: 001
- **Agent**: performance-design-reviewer.md
- **Test Document**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/prompt-improve/performance-design/test-document.md
- **Baseline Prompt**: v001-baseline
- **Variants Tested**:
  - v001-variant-fewshot (Variation ID: S1a - Few-shot example in instructions)
  - v001-variant-scoring (Variation ID: C1a - Explicit scoring rubric in instructions)
- **Runs per Prompt**: 2

---

## 2. Comparison Matrix

### Score Summary

| Prompt Name | Mean Score | Standard Deviation | Stability | Run1 | Run2 |
|-------------|------------|-------------------|-----------|------|------|
| baseline | 9.5 | 0.0 | 高安定 | 9.5 | 9.5 |
| variant-fewshot | 8.75 | 0.25 | 高安定 | 8.5 | 9.0 |
| variant-scoring | 8.0 | 1.0 | 中安定 | 9.0 | 7.0 |

### Problem Detection Matrix

| Problem ID | Category | Severity | baseline | variant-fewshot | variant-scoring | 検出差分 |
|------------|----------|----------|----------|----------------|----------------|---------|
| P01 | I/O・ネットワーク効率 | 重大 | ○/○ | ○/○ | ○/○ | なし（全検出） |
| P02 | データベース設計 | 重大 | ○/○ | ○/○ | ○/○ | なし（全検出） |
| P03 | キャッシュ戦略 | 重大 | ○/○ | ○/○ | ○/○ | なし（全検出） |
| P04 | スケーラビリティ | 中 | ×/× | ○/○ | △/× | baseline劣位 |
| P05 | 並行処理 | 中 | ○/○ | ○/○ | △/△ | variant-scoring部分検出 |
| P06 | データベース設計 | 中 | △/△ | ×/○ | ○/○ | baseline部分検出 |
| P07 | スケーラビリティ | 中 | ○/○ | ○/○ | ○/○ | なし（全検出） |
| P08 | アルゴリズム効率性 | 軽微 | ×/× | ×/× | ×/× | なし（全未検出） |
| P09 | 監視 | 軽微 | ×/○ | ×/△ | ○/× | 不安定 |

**凡例**: ○=完全検出(1.0pt), △=部分検出(0.5pt), ×=未検出(0pt) | Run1/Run2の順

---

## 3. Bonus/Penalty Details

### Bonus Item Detection

| Bonus ID | Description | baseline | variant-fewshot | variant-scoring |
|----------|-------------|----------|----------------|----------------|
| B01 | バッチ登録API設計の提案 | 2/2 | 2/2 | 2/2 |
| B02 | センサー/フロアマスタキャッシュ | 2/2 | 2/1 | 2/0 |
| B03 | パーティショニング戦略の明示 | 2/2 | 2/2 | 2/2 |
| B04 | (未定義) | - | - | - |
| B05 | コネクションプール設計 | 2/2 | 2/2 | 2/2 |
| その他 | レート制限/非同期処理 | 4/4 | 2/0 | 0/0 |

**Total Bonus Points**:
- baseline: Run1=+3.0, Run2=+3.0 (平均+3.0)
- variant-fewshot: Run1=+2.5, Run2=+1.5 (平均+2.0)
- variant-scoring: Run1=+2.0, Run2=+1.5 (平均+1.75)

### Penalty Points

全プロンプトで0ペナルティ。スコープ外指摘や誤分析なし。

---

## 4. Score Breakdown

### baseline (9.5点)

| Component | Run1 | Run2 | Mean |
|-----------|------|------|------|
| Detection Score | 6.5 | 6.5 | 6.5 |
| Bonus | +3.0 | +3.0 | +3.0 |
| Penalty | 0 | 0 | 0 |
| **Total** | **9.5** | **9.5** | **9.5** |

**Strengths**:
- 完璧な安定性 (SD=0.0)
- ボーナス検出が両Runで上限に近い (6件/Run)
- 重大問題の100%検出

**Weaknesses**:
- P04 (容量設計) 両Run未検出
- P06 (読み書き分離) 両Run部分検出
- P08 (バリデーション処理) 両Run未検出

---

### variant-fewshot (8.75点)

| Component | Run1 | Run2 | Mean |
|-----------|------|------|------|
| Detection Score | 6.0 | 7.5 | 6.75 |
| Bonus | +2.5 | +1.5 | +2.0 |
| Penalty | 0 | 0 | 0 |
| **Total** | **8.5** | **9.0** | **8.75** |

**Strengths**:
- P04 (容量設計) を両Runで検出（baseline比+1.0pt優位）
- P06 (読み書き分離) をRun2で検出
- 高安定性 (SD=0.25)

**Weaknesses**:
- ボーナス検出数がbaselineより少ない (平均4項目 vs 6項目)
- P06 Run1で未検出（不安定性）
- P09 Run2でも部分検出のみ

---

### variant-scoring (8.0点)

| Component | Run1 | Run2 | Mean |
|-----------|------|------|------|
| Detection Score | 7.0 | 5.5 | 6.25 |
| Bonus | +2.0 | +1.5 | +1.75 |
| Penalty | 0 | 0 | 0 |
| **Total** | **9.0** | **7.0** | **8.0** |

**Strengths**:
- P06 (読み書き分離) を両Runで完全検出
- P09 (監視戦略) をRun1で検出
- P04 Run1で部分検出

**Weaknesses**:
- 中程度の不安定性 (SD=1.0) - 2.0pt差
- P04/P05/P09でRun間の検出差異が大きい
- ボーナス検出数が最少 (平均3.5項目)
- P05が両Runで部分検出のみ

---

## 5. Recommendation Judgement

### 推奨プロンプト: **baseline**

### 判定根拠

scoring-rubric.md Section 5の推奨判定基準に基づく:

```
baseline vs variant-fewshot: 平均スコア差 = 9.5 - 8.75 = +0.75pt (baseline優位)
baseline vs variant-scoring: 平均スコア差 = 9.5 - 8.0 = +1.5pt (baseline優位)
```

- **baseline vs variant-fewshot**: 平均スコア差0.75pt（0.5〜1.0pt範囲）→ 標準偏差が小さい方を推奨
  - baseline SD=0.0 vs variant-fewshot SD=0.25 → **baseline推奨**
- **baseline vs variant-scoring**: 平均スコア差1.5pt（>1.0pt）→ スコアが高い方を推奨
  - **baseline推奨**

### 収束判定: **継続推奨**

初回ラウンドのため収束判定は該当しない。次回ラウンドで改善幅<0.5ptが継続すれば収束の可能性を検討。

---

## 6. Analysis & Insights

### 独立変数ごとの効果分析

#### Variation S1a (Few-shot example): **効果限定的**

**期待**: Few-shot exampleが検出精度を向上させる

**結果**:
- **ポジティブ効果**: P04容量設計を両Runで検出（baseline比+1.0pt）
- **ネガティブ効果**: ボーナス検出数が減少（平均-1.0pt）、総合スコアで-0.75pt劣位

**分析**:
- Few-shot exampleが特定問題（容量設計）への注意を引きつけたが、同時に「テンプレート効果」によりexampleに含まれない問題（ボーナス項目）の検出率が低下した可能性
- P06でRun1未検出/Run2検出と不安定性も発生

**効果判定**: **限定的** - 一部改善はあるが総合スコアで劣位

---

#### Variation C1a (Explicit scoring rubric): **逆効果**

**期待**: 明示的な採点基準が構造化された分析を促進

**結果**:
- **ポジティブ効果**: P06読み書き分離を両Runで完全検出（baseline比+0.5pt）
- **ネガティブ効果**: Run間の不安定性増加（SD=1.0）、ボーナス検出数減少、P05が部分検出に留まる

**分析**:
- 採点基準の明示が「評価モード」を誘発し、詳細な技術分析よりも基準への適合性を優先させた可能性
- Run間で2.0ptの変動は、基準解釈のブレが大きいことを示唆
- ボーナス項目（基準外の創造的指摘）が減少したのは基準依存の副作用と推測

**効果判定**: **逆効果** - 不安定性増加と総合スコア低下

---

### Cross-cutting Observations

#### 1. Baseline優位性の要因
- **一貫したボーナス検出**: 両Run6項目（上限5件で計+3.0pt）を安定して検出
- **完璧な安定性**: SD=0.0は変更なしプロンプトの再現性を示す
- **Critical問題検出**: P01-P03を100%検出

#### 2. Variant共通の弱点
- **P08完全未検出**: 全プロンプトで0検出 → テスト文書に問題があるか、問題設定が評価スコープ外の可能性
- **P09不安定**: 監視戦略は各プロンプトで異なる検出パターン（×/○, ×/△, ○/×）
- **B02検出低下**: variant-fewshot(3/4), variant-scoring(2/4) vs baseline(4/4) - マスタキャッシュ言及が不安定化

#### 3. 構造化指示の逆説
- Few-shot/Rubric追加は「焦点の偏り」を生み、広範な技術分析（ボーナス検出）を阻害した
- Baseline（最小限の指示）が最も多様な問題検出を実現

---

## 7. Next Round Strategy

### 推奨アクション

1. **Baseline継続デプロイ**
   - 現バージョン (v001-baseline) を標準プロンプトとして維持
   - Round 002のベースラインとして使用

2. **新Variation探索方向**

#### 優先度1: P04/P06/P08の検出率向上
- **Variation候補**:
  - **S2a** (Capacity/Scalability focus): 容量設計とスケーリング方針に明示的なチェックリスト追加
  - **C2b** (Database-specific patterns): DB関連問題（読み書き分離、バリデーション処理）のパターン集追加

#### 優先度2: ボーナス検出の安定化
- **Variation候補**:
  - **N1a** (Exploratory analysis prompt): "Add insights beyond the checklist" 的な探索促進文言

#### 優先度3: 監視戦略検出の安定化
- **Variation候補**:
  - **S3b** (NFR checklist): 非機能要件（監視/アラート/メトリクス）の明示的チェック

3. **テスト文書の見直し**
   - P08（バリデーション処理）が全プロンプトで未検出 → 問題の明示性を強化するか、問題自体を再評価

4. **Broad評価の実施**
   - Round 002で複数カテゴリ（S2a, C2b, N1a, S3b）から2-3 Variationを並行テスト
   - 効果が確認されたカテゴリでDeep評価へ移行

### 学習事項 (Knowledge蓄積候補)

- **構造化指示の副作用**: Few-shot/Rubric追加は総合スコアを低下させた（S1a: -0.75pt, C1a: -1.5pt）
- **Baseline安定性**: 最小限指示が最高の安定性（SD=0.0）とボーナス検出（6項目/Run）を実現
- **容量設計検出**: S1a Few-shot effectがP04検出を改善（+1.0pt）- 継続検証価値あり
- **読み書き分離検出**: C1a Rubric effectがP06検出を改善（+0.5pt）- ただし不安定性増加のトレードオフあり

---

## Appendix: Variant Details

### variant-fewshot (v001-variant-fewshot)
- **Variation ID**: S1a
- **Independent Variable**: Few-shot example in instructions
- **Changes**: Added one example of performance analysis with severity categorization and quantitative reasoning

### variant-scoring (v001-variant-scoring)
- **Variation ID**: C1a
- **Independent Variable**: Explicit scoring rubric in instructions
- **Changes**: Embedded scoring criteria (critical/significant/moderate severity levels) directly in agent instructions

---

**Report End**
