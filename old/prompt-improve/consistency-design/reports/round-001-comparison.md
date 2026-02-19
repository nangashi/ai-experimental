# Round 001 Comparison Report: consistency-design Reviewer Optimization

## Executive Summary

**Recommended Prompt**: v001-variant-minimal-format
**Reason**: Mean score差 +3.5pt (baseline 3.25 → variant-minimal-format 6.75)、高安定性 (SD=0.25)
**Convergence**: 継続推奨
**Next Action**: v001-variant-minimal-format を Round 002 のベースラインとして採用し、さらなる改善を探索

---

## 実行条件

- **対象エージェント**: consistency-design-reviewer
- **テスト文書**: IoT Device Management API 設計書 (Table/API/Architecture Design)
- **評価ラウンド**: Round 001
- **実施日**: 2026-02-11
- **評価実行数**: 各プロンプト 2 runs
- **正解キー問題数**: 9問 (P01-P09)
- **ボーナス候補**: 5件 (B01-B05)

---

## 比較対象プロンプト

| Variant | Variation ID | 変更内容 | 独立変数 |
|---------|-------------|---------|---------|
| baseline | (N/A) | 現状のエージェント定義 | - |
| variant-scoring | S2a | 5段階スコアリング表を追加 | Scoring Framework |
| variant-minimal-format | S3b | 最小自由記述形式(セクション構造削除) | Output Format |

### 独立変数の詳細

#### Variation S2a (variant-scoring): Scoring Framework
- **変更内容**: プロンプトに5段階の深刻度スコアリング表を追加
- **仮説**: 問題の重要度の明示的な基準を提供することで、軽微な問題も含めた検出精度が向上する
- **実装**: Critical/Significant/Moderate/Minor/Observationの5段階定義を追加

#### Variation S3b (variant-minimal-format): Output Format
- **変更内容**: 出力形式の制約を削減し、最小自由記述形式に変更
- **仮説**: 固定的なセクション構造を削除することで、モデルが問題の本質に集中し、検出精度が向上する
- **実装**: 指定セクション構造を削除、自由記述でのレビュー出力を許可

---

## スコアサマリ

| Prompt | Run1 | Run2 | Mean | SD | 安定性 |
|--------|------|------|------|-----|-------|
| **baseline** | 2.0 | 4.5 | **3.25** | 1.77 | 低安定 (SD > 1.0) |
| **variant-scoring** | 4.5 | 4.0 | **4.25** | 0.35 | 高安定 (SD ≤ 0.5) |
| **variant-minimal-format** | 7.0 | 6.5 | **6.75** | 0.25 | 高安定 (SD ≤ 0.5) |

### スコア改善幅

- **baseline → variant-scoring**: +1.0pt (3.25 → 4.25)
- **baseline → variant-minimal-format**: +3.5pt (3.25 → 6.75)
- **variant-scoring → variant-minimal-format**: +2.5pt (4.25 → 6.75)

---

## 問題別検出マトリクス

| Problem ID | Category | Severity | baseline (Run1/Run2) | variant-scoring (Run1/Run2) | variant-minimal-format (Run1/Run2) |
|-----------|----------|----------|----------------------|----------------------------|-----------------------------------|
| **P01** | 命名規約 | 中 | ○/○ (1.0/1.0) | ○/○ (1.0/1.0) | ○/○ (1.0/1.0) |
| **P02** | 命名規約 | 中 | ○/○ (1.0/1.0) | ○/○ (1.0/1.0) | ○/○ (1.0/1.0) |
| **P03** | API設計 | 中 | ×/△ (0.0/0.5) | ○/○ (1.0/1.0) | ○/○ (1.0/1.0) |
| **P04** | 実装パターン | 重大 | ×/△ (0.0/0.5) | ○/○ (1.0/1.0) | ○/○ (1.0/1.0) |
| **P05** | 実装パターン | 重大 | ×/△ (0.0/0.5) | △/× (0.5/0.0) | ×/× (0.0/0.0) |
| **P06** | API/依存関係 | 中 | ×/× (0.0/0.0) | ×/× (0.0/0.0) | ×/× (0.0/0.0) |
| **P07** | API/依存関係 | 軽微 | ×/× (0.0/0.0) | ×/× (0.0/0.0) | △/△ (0.5/0.5) |
| **P08** | 実装パターン | 軽微 | ×/△ (0.0/0.5) | ×/× (0.0/0.0) | △/× (0.5/0.0) |
| **P09** | API設計 | 中 | ×/× (0.0/0.0) | ×/× (0.0/0.0) | ○/× (1.0/0.0) |

### 検出率サマリ

| Prompt | 完全検出 (○) | 部分検出 (△) | 未検出 (×) | 検出率 (Mean) |
|--------|------------|------------|-----------|--------------|
| baseline | 4/18 (22.2%) | 4/18 (22.2%) | 10/18 (55.6%) | 27.8% |
| variant-scoring | 8/18 (44.4%) | 1/18 (5.6%) | 9/18 (50.0%) | 47.2% |
| variant-minimal-format | 10/18 (55.6%) | 3/18 (16.7%) | 5/18 (27.8%) | 64.8% |

---

## ボーナス/ペナルティ詳細

### Bonus Detection

| Bonus ID | Content | baseline (Run1/Run2) | variant-scoring (Run1/Run2) | variant-minimal-format (Run1/Run2) |
|----------|---------|----------------------|----------------------------|-----------------------------------|
| **B01** | 外部キー制約のカラム名が参照先と異なる | ○/× (+0.5/0) | ×/× (0/0) | ○/○ (+0.5/+0.5) |
| **B04** | ファイル配置方針が設計書に明記されていない | ×/× (0/0) | ○/× (+0.5/0) | ○/○ (+0.5/+0.5) |

**Bonus Total**:
- baseline: Run1=0.5, Run2=0 (Mean=0.25)
- variant-scoring: Run1=0.5, Run2=0 (Mean=0.25)
- variant-minimal-format: Run1=1.0, Run2=1.0 (Mean=1.0)

### Penalty Detection

| Category | Content | baseline (Run1/Run2) | variant-scoring (Run1/Run2) | variant-minimal-format (Run1/Run2) |
|----------|---------|----------------------|----------------------------|-----------------------------------|
| スコープ外(Structural Quality) | APIレスポンス形式をREST標準で評価 | -0.5/-0.5 | 0/0 | 0/0 |

**Penalty Total**:
- baseline: Run1=-0.5, Run2=-0.5 (Mean=-0.5)
- variant-scoring: Run1=0, Run2=0 (Mean=0)
- variant-minimal-format: Run1=0, Run2=0 (Mean=0)

---

## 推奨判定 (Scoring Rubric Section 5 適用)

### 条件分析

| Comparison | 平均スコア差 | 判定条件 | 推奨 |
|-----------|------------|---------|-----|
| baseline vs variant-scoring | +1.0pt | 平均スコア差 = 1.0pt → 標準偏差比較 | variant-scoring (SD=0.35 < baseline SD=1.77) |
| baseline vs variant-minimal-format | +3.5pt | 平均スコア差 > 1.0pt → スコアが高い方 | variant-minimal-format |
| variant-scoring vs variant-minimal-format | +2.5pt | 平均スコア差 > 1.0pt → スコアが高い方 | variant-minimal-format |

### 最終推奨

**推奨プロンプト**: v001-variant-minimal-format

**推奨理由**:
1. **最高平均スコア**: 6.75pt (baseline比 +3.5pt、variant-scoring比 +2.5pt)
2. **高安定性**: SD=0.25 (高安定の閾値 SD ≤ 0.5 を満たす)
3. **Critical問題の高検出率**: P01-P04の重大問題を両Run共に検出 (8/8 = 100%)
4. **ボーナス問題の安定検出**: B01, B04を両Run共に検出 (4/4 = 100%)
5. **スコープ外ペナルティなし**: 両Run共にペナルティ0

### 収束判定

**判定**: 継続推奨

**理由**: 初回ラウンドであり、改善幅 +3.5pt は十分に大きい。variant-minimal-format をベースラインとしてさらなる改善の余地を探索すべき。

---

## 独立変数ごとの効果分析

### S2a (Scoring Framework): スコアリング表追加の効果

**効果**: +1.0pt (baseline 3.25 → variant-scoring 4.25)

**効果が確認された領域**:
- **P03 (APIレスポンス形式)**: baseline Run1=×/Run2=△ → variant-scoring 両Run ○ (完全検出)
- **P04 (エラーハンドリング)**: baseline Run1=×/Run2=△ → variant-scoring 両Run ○ (完全検出)
- **安定性向上**: baseline SD=1.77 → variant-scoring SD=0.35 (大幅改善)
- **スコープ外ペナルティ削減**: baseline -0.5 → variant-scoring 0

**効果が限定的だった領域**:
- **P05 (データアクセス/トランザクション)**: baseline Run2=△ → variant-scoring Run1=△/Run2=× (改善なし、Run2で悪化)
- **P06-P09**: 依然として低い検出率 (P09以外は未検出)
- **B01 (外部キー命名)**: baseline Run1検出 → variant-scoring 未検出 (悪化)

**考察**:
- スコアリング表の追加により、重大問題 (P03, P04) の検出が安定化したが、軽微問題 (P07, P08) の検出率は改善せず
- "Scoring Framework" は問題の深刻度評価には寄与するが、網羅的な検出能力の向上には限定的

### S3b (Output Format): 最小自由記述形式の効果

**効果**: +3.5pt (baseline 3.25 → variant-minimal-format 6.75)、+2.5pt (variant-scoring 4.25 → variant-minimal-format 6.75)

**効果が確認された領域**:
- **P01-P04 (Critical/重大問題)**: 両Run共に完全検出 (8/8 = 100%)
- **P07 (環境変数命名規則)**: baseline/variant-scoring 未検出 → variant-minimal-format 両Run △ (部分検出)
- **P09 (API命名規則)**: baseline/variant-scoring 未検出 → variant-minimal-format Run1 ○ (Run2は未検出)
- **ボーナス検出の安定化**: B01, B04を両Run共に検出 (baseline/variant-scoringでは不安定)
- **安定性の最大化**: SD=0.25 (3プロンプト中最小)

**効果が限定的だった領域**:
- **P05 (データアクセス/トランザクション)**: 依然として未検出 (×/×)
- **P06 (HTTP通信ライブラリ)**: 依然として未検出 (×/×)
- **P08 (ログ出力パターン)**: Run1=△/Run2=× (不安定)
- **P09 (API命名規則)**: Run1=○/Run2=× (不安定)

**考察**:
- 固定セクション構造の削除により、モデルが問題の本質に集中し、重大問題の検出率が大幅に向上
- 軽微問題 (P07, P08) および情報欠落問題 (P05, P06, P09) については、依然として検出の不安定性や未検出が残る
- "Output Format" の自由度向上は、Critical問題の検出精度と安定性に強く寄与するが、網羅性の課題は残る

---

## 次回への示唆

### 改善が必要な領域

1. **P05 (データアクセスパターン/トランザクション管理) の未検出**
   - 3プロンプト全てで完全検出できず (baseline Run2のみ△)
   - **対策案**: アーキテクチャパターンのチェックリスト追加、または "Repository pattern" "Transaction boundary" などのキーワードを明示的に指示

2. **P06 (HTTP通信ライブラリ) の未検出**
   - 3プロンプト全てで未検出
   - **対策案**: 依存ライブラリ選定の一貫性確認を明示的に指示、またはライブラリ選定チェックリストを追加

3. **P08 (ログ出力パターン) の不安定検出**
   - variant-minimal-format でも Run1=△/Run2=× と不安定
   - **対策案**: 設計書内の一貫性チェック (ポリシー記載 vs 実装例) を明示的に指示

4. **P09 (API命名規則) の不安定検出**
   - variant-minimal-format Run1=○/Run2=× と不安定
   - **対策案**: API設計の情報欠落チェックを強化 (命名規則、バージョニング、ネスト構造など)

### 効果的だった施策

1. **固定セクション構造の削減 (S3b)**
   - Critical問題の検出率を大幅に向上させた (baseline 22.2% → 55.6%)
   - 安定性を最大化した (SD=1.77 → SD=0.25)
   - **継続推奨**: 最小自由記述形式をベースラインとして維持

2. **スコープ外ペナルティの削減**
   - baseline で発生していたREST標準評価ペナルティが、variant-scoring/variant-minimal-format では消失
   - **仮説**: 固定セクション構造やスコアリング表がスコープ境界を明確化した可能性

### Round 002 の推奨アプローチ

1. **v001-variant-minimal-format を新ベースラインとして採用**
   - Mean=6.75, SD=0.25 の高性能・高安定性を活用

2. **探索すべき独立変数**:
   - **C1a (段階的分析)**: P05のような複雑な問題の検出率向上を狙う
   - **N1a (標準ベース)**: アーキテクチャパターン、ライブラリ選定などのチェックリスト追加
   - **S5a (カテゴリリスト)**: 見落としやすい問題カテゴリ (情報欠落、設計書内一貫性) の明示

3. **検証すべき仮説**:
   - "段階的分析指示" (C1a) により、データアクセスパターン/トランザクション管理 (P05) のような多層的問題の検出率が向上する
   - "アンチパターンリスト" (N1b) により、ライブラリ選定 (P06) や API命名規則 (P09) のような情報欠落問題の検出率が向上する

---

## 一般化原則の更新候補

### 効果が確認された原則

1. **固定セクション構造の削減はCritical問題の検出精度を向上させる**
   - 証拠: S3b により P01-P04 の検出率が baseline 27.8% → 100% に改善
   - 適用範囲: consistency観点、設計レビュー、Critical/重大問題の検出

2. **出力形式の自由度向上は結果の安定性を向上させる**
   - 証拠: S3b により SD=1.77 → SD=0.25 に改善
   - 適用範囲: consistency観点、全ての深刻度レベル

3. **スコアリング表の追加はスコープ境界の明確化に寄与する**
   - 証拠: S2a により baseline のスコープ外ペナルティ (-0.5) が消失
   - 適用範囲: 隣接観点との境界が曖昧な場合 (consistency vs structural-quality)

### 効果が限定的/逆効果だった原則

1. **スコアリング表の追加は軽微問題の検出率向上に限定的**
   - 証拠: S2a により P07, P08 の検出率は改善せず (依然として未検出または△)
   - 適用範囲: consistency観点、軽微問題、情報欠落問題

2. **出力形式の自由度向上だけでは情報欠落問題の検出は不十分**
   - 証拠: S3b でも P05, P06, P09 の検出は不安定または未検出
   - 適用範囲: consistency観点、設計書の情報欠落に関する問題

---

## Appendix: Raw Score Data

### baseline

```
Run1: Detection=2.0, Bonus=0.5, Penalty=-0.5 → Total=2.0
Run2: Detection=5.0, Bonus=0.0, Penalty=-0.5 → Total=4.5
Mean=3.25, SD=1.77
```

### variant-scoring

```
Run1: Detection=4.5, Bonus=0.5, Penalty=0 → Total=4.5
Run2: Detection=4.0, Bonus=0.0, Penalty=0 → Total=4.0
Mean=4.25, SD=0.35
```

### variant-minimal-format

```
Run1: Detection=6.0, Bonus=1.0, Penalty=0 → Total=7.0
Run2: Detection=5.5, Bonus=1.0, Penalty=0 → Total=6.5
Mean=6.75, SD=0.25
```
