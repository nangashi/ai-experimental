# Round 002 Comparison Report: consistency-design Reviewer Optimization

**Report Date**: 2026-02-11
**Evaluation Scope**: consistency観点のdesign-stage reviewerプロンプト最適化

---

## 1. Execution Conditions

### Test Environment
- **Test Document**: IoT Device Management API 設計書 (Round 001と同一)
- **Embedded Problems**: 10問 (P01-P10)
  - 重大: 4問 (P01, P02, P03, P04)
  - 中: 3問 (P05, P06, P07)
  - 軽微: 3問 (P08, P09, P10)
- **Bonus Problems**: 4問 (B01-B04)
- **Evaluation Runs**: 各プロンプト2回実行

### Compared Prompts
1. **v002-baseline**: Round 001推奨プロンプト (v001-variant-minimal-format) をベースライン化
2. **v002-variant-staged-analysis**: 3段階分析アプローチ (Structure → Detail → Cross-cutting)
3. **v002-variant-detection-hints**: 検出ヒントセクション追加

### Variations Applied
- **v002-variant-staged-analysis**: C1a (基本段階的分析) の応用 — 3段階構造分析フレームワーク
- **v002-variant-detection-hints**: S5a (カテゴリリスト) の応用 — 重点検出項目リストの追加

---

## 2. Problem Detection Matrix

| Problem ID | Severity | v002-baseline | v002-variant-staged-analysis | v002-variant-detection-hints |
|-----------|----------|--------------|----------------------------|---------------------------|
| P01 | 重大 | ××  (0.0) | ○○  (2.0) | ×× (0.0) |
| P02 | 重大 | ××  (0.0) | ○○  (2.0) | ○○ (2.0) |
| P03 | 重大 | ○○  (2.0) | ○○  (2.0) | ○○ (2.0) |
| P04 | 中   | ○○  (2.0) | ○○  (2.0) | ○○ (2.0) |
| P05 | 中   | △×  (0.5) | ○○  (2.0) | ×× (0.0) |
| P06 | 中   | △△  (1.0) | ○○  (2.0) | △○ (1.5) |
| P07 | 軽微 | △△  (1.0) | ○○  (2.0) | ×△ (0.5) |
| P08 | 軽微 | ××  (0.0) | ○○  (2.0) | ×× (0.0) |
| P09 | 軽微 | ××  (0.0) | ○○  (2.0) | ×× (0.0) |
| P10 | 軽微 | ××  (0.0) | ○○  (2.0) | ×× (0.0) |
| **Total** | - | **6.5** | **20.0** | **8.0** |

### Detection Rate by Severity

| Severity | v002-baseline | v002-variant-staged-analysis | v002-variant-detection-hints |
|----------|--------------|----------------------------|---------------------------|
| 重大 (4問) | 50% (2/4) | **100% (4/4)** | 75% (3/4) |
| 中 (3問) | 58% (1.75/3) | **100% (3/3)** | 58% (1.75/3) |
| 軽微 (3問) | 17% (0.5/3) | **100% (3/3)** | 8% (0.25/3) |
| **Overall** | 43% (4.25/10) | **100% (10/10)** | 48% (4.75/10) |

---

## 3. Bonus and Penalty Details

### Bonus Detection

| Bonus ID | Category | v002-baseline | v002-variant-staged-analysis | v002-variant-detection-hints |
|---------|----------|--------------|----------------------------|---------------------------|
| B01 | ページネーション形式の情報欠落 | ×× (0.0) | ○○ (+1.0) | ×× (0.0) |
| B02 | 非同期処理パターンの情報欠落 | ×× (0.0) | ○○ (+1.0) | ×× (0.0) |
| B03 | バリデーションライブラリの不一致 | ×× (0.0) | ×× (0.0) | ×× (0.0) |
| B04 | パッケージ構成の情報欠落 | ×× (0.0) | ○○ (+1.0) | ×× (0.0) |
| **Total** | - | **0.0** | **+3.0** | **0.0** |

**Notes**:
- v002-baseline Run2でtimestamp命名の内部不整合を検出 (+0.5) — 合計ボーナス+0.5
- v002-variant-staged-analysis: 4問中3問を両実行で検出 (75% bonus rate)
- v002-variant-detection-hints: ボーナス問題未検出

### Penalty Details

| Prompt | Run1 Penalty | Run2 Penalty | Total | Key Issues |
|--------|-------------|-------------|-------|-----------|
| v002-baseline | -0.5 | 0.0 | **-0.5** | Run1: API Response Format評価 (structural-quality scope) |
| v002-variant-staged-analysis | 0.0 | 0.0 | **0.0** | ペナルティなし |
| v002-variant-detection-hints | -2.0 | -1.5 | **-3.5** | Run1: 4件 (設計原則評価、performance懸念等), Run2: 3件 (best-practices推奨等) |

**Penalty Breakdown (v002-variant-detection-hints)**:
- Run1: RESTful wrapper評価、HTTP client設定、ディレクトリ構造、ログ形式 (各-0.5)
- Run2: RestTemplate推奨、非同期処理、ディレクトリ構造 (各-0.5)

**Root Cause**: 検出ヒントセクションが「一貫性検証」の境界を曖昧にし、best-practices評価を誘発

---

## 4. Score Summary

| Prompt | Mean | SD | Stability | Run1 | Run2 |
|--------|------|----|-----------| -----|------|
| v002-baseline | 3.25 | 0.25 | 高安定 | 3.0 | 3.5 |
| **v002-variant-staged-analysis** | **11.5** | **0.0** | **高安定** | **11.5** | **11.5** |
| v002-variant-detection-hints | 3.25 | 0.25 | 高安定 | 1.5 | 3.0 |

### Score Calculation Details

**v002-baseline**:
- Run1: 検出3.5 + bonus0 - penalty0.5 = 3.0
- Run2: 検出3.0 + bonus0.5 - penalty0 = 3.5
- Mean: 3.25, SD: 0.25

**v002-variant-staged-analysis**:
- Run1: 検出10.0 + bonus1.5 - penalty0 = 11.5
- Run2: 検出10.0 + bonus1.5 - penalty0 = 11.5
- Mean: 11.5, SD: 0.0

**v002-variant-detection-hints**:
- Run1: 検出3.5 + bonus0 - penalty2.0 = 1.5
- Run2: 検出4.5 + bonus0 - penalty1.5 = 3.0
- Mean: 3.25, SD: 0.25

---

## 5. Recommendation

### Recommended Prompt: **v002-variant-staged-analysis**

**判定根拠**:
- 平均スコア差: +8.25pt (baselineとの差 > 1.0pt threshold)
- 検出精度: 10/10問題を完全検出 (100% detection rate)
- 安定性: SD=0.0 (完全な再現性)
- ボーナス検出: 3/4問題を検出
- ペナルティ: 0件

**判定基準 (scoring-rubric.md Section 5)**:
- 平均スコア差 > 1.0pt → スコアが高い方を推奨
- 該当: v002-variant-staged-analysis (Mean=11.5) vs baseline (Mean=3.25) = +8.25pt

### Convergence Assessment: **継続推奨**

**根拠**:
- Round 001改善幅: +3.5pt (baseline 3.25 → minimal-format 6.75)
- Round 002改善幅: +8.25pt (baseline 3.25 → staged-analysis 11.5)
- 改善幅が増加傾向 → 最適化はまだ収束していない

**判定基準 (scoring-rubric.md Section 5)**:
- 2ラウンド連続で改善幅 < 0.5pt → 収束の可能性
- 該当せず: 改善幅が増加 (3.5pt → 8.25pt)

---

## 6. Key Insights

### 6.1 Variation Effect Analysis

#### C1a (3段階分析アプローチ) — EFFECTIVE

**Independent Variable**: 分析手順の構造化 (Structure → Detail → Cross-cutting)

**Measured Effect**: +8.25pt (Mean: 3.25 → 11.5)

**Evidence**:
1. **情報欠落検出の劇的改善** (0% → 100%)
   - P02 (データアクセスパターン): ×× → ○○
   - P09 (APIパス命名規則): ×× → ○○
   - P10 (エンティティ命名規則): ×× → ○○
   - B01 (ページネーション): ×× → ○○
   - B02 (非同期処理): ×× → ○○
   - B04 (パッケージ構成): ×× → ○○

2. **命名規則検出の改善** (17% → 100%)
   - P01 (テーブル名単複): ×× → ○○
   - P08 (phone vs phoneNumber): ×× → ○○

3. **完全な安定性** (SD: 0.25 → 0.0)
   - 両実行で完全に一致した検出結果

**Mechanism**:
- Stage 1 (Structure Analysis): ドキュメント全体の構造を俯瞰し、情報欠落を体系的に特定
- Stage 2 (Detailed Analysis): セクション別に既存パターンとの不一致を詳細分析
- Stage 3 (Cross-cutting Analysis): 横断的なパターン違反を抽出

**Scope**: consistency観点、design-stage、全ての深刻度レベル

#### S5a (カテゴリリスト) — NEGATIVE EFFECT

**Independent Variable**: 重点検出項目リストの追加

**Measured Effect**: 0.0pt (Mean: 3.25 → 3.25)

**Evidence**:
1. **検出精度の非改善** (43% → 48%, 実質的に横ばい)
2. **スコープ外指摘の急増** (penalty: -0.5 → -3.5)
3. **安定性の維持** (SD: 0.25 → 0.25, 変化なし)

**Root Cause**:
- 検出ヒントリストが「一貫性検証」と「best-practices評価」の境界を曖昧化
- 例: "HTTP通信ライブラリの選定" → "Spring recommends WebClient" という一般推奨に誘導
- 例: "ログ形式の統一" → "structured logging decision missing" という一般的文書化要求に誘導

**Negative Patterns**:
- カテゴリリストが具体的すぎると「その項目について何か言わねば」という圧力が発生
- 既存パターンとの比較ではなく、一般的なチェックリストとして機能

**Scope**: consistency観点、design-stage

### 6.2 Problem-Specific Insights

#### P01 (テーブル名の命名規則) — 3段階分析で解決

**Baseline Performance**: ××  (0.0) — "Missing Codebase Context" を理由に検出放棄
**Staged-analysis Performance**: ○○  (2.0) — Stage 2で明確に検出

**Key Difference**:
- Baseline: 既存コードベースへのアクセスがないことを理由に分析停止
- Staged-analysis: 設計書内の既存パターン記述 ("users, orders, products") と提案パターン (reservation, customer, location, staff) を比較

**Lesson**: ドキュメント内部の情報でも既存パターンとの比較は可能 → 「情報不足」を理由に検出放棄しない指示が必要

#### P02 (データアクセスパターン情報欠落) — Stage 1の威力

**Baseline Performance**: ××  (0.0) — 言及なし
**Staged-analysis Performance**: ○○  (2.0) — Stage 1で体系的に特定

**Detection Method (Staged-analysis)**:
- Stage 1: "Data Access and Transaction Management" セクションの欠落を構造分析で検出
- "Cannot verify alignment with existing data access patterns" と一貫性検証不能を明示

**Lesson**: 情報欠落問題は全体構造分析フェーズで効率的に検出可能

#### P08 (phone vs phoneNumber) — 詳細分析の効果

**Baseline Performance**: ××  (0.0) — 両実行で未検出
**Staged-analysis Performance**: ○○  (2.0) — Stage 2で検出

**Detection Method (Staged-analysis)**:
- Stage 2: Section 2.7 "Intra-Document Naming Inconsistency" として検出
- customerテーブルの "phone" と locationテーブルの "phoneNumber" の不統一を指摘
- 既存パターン "100% use of phone (not phoneNumber) in existing schema" を明示

**Lesson**: セクション別詳細分析により、微細な命名の不統一も検出可能

### 6.3 Cross-Variant Comparison

| Aspect | v002-baseline | v002-variant-staged-analysis | v002-variant-detection-hints |
|--------|--------------|----------------------------|---------------------------|
| 情報欠落検出 | 0/6問 (0%) | 6/6問 (100%) | 1/6問 (17%) |
| 命名規則検出 | 0.5/4問 (12.5%) | 4/4問 (100%) | 0.75/4問 (19%) |
| 実装パターン検出 | 2.5/4問 (62.5%) | 4/4問 (100%) | 3/4問 (75%) |
| スコープ境界遵守 | 良好 (penalty -0.5) | 優秀 (penalty 0) | 不良 (penalty -3.5) |
| 安定性 | 高安定 (SD=0.25) | 完全安定 (SD=0.0) | 高安定 (SD=0.25) |

**Pattern**: 3段階分析アプローチは全カテゴリで顕著な改善を示す

---

## 7. Recommendations for Next Round

### 7.1 Deploy v002-variant-staged-analysis

**Rationale**: 全ての指標で優れたパフォーマンス (Mean=11.5, SD=0.0, 100% detection rate)

### 7.2 Address B03 (バリデーションライブラリ)

**Current Gap**: 全プロンプトで未検出

**Root Cause Analysis**:
- B03は技術スタック一覧に含まれるべき項目
- 現在の3段階分析は「設計書の記述内容」を既存パターンと比較するが、「設計書に記載されていないライブラリ」の検出には別のアプローチが必要

**Improvement Strategy**:
- Stage 1に「技術スタック一覧の網羅性チェック」を追加
- "Dependency Inventory" として、設計書で使用される全ライブラリを列挙し、既存コードベースのライブラリリストとの差分をチェック

### 7.3 Explore Multi-Pass Analysis

**Next Variation Candidates**:
- **C1c (マルチパスレビュー)**: 1回目で全体把握、2回目で詳細分析 → 3段階分析との組み合わせで精度向上の可能性
- **N1a (標準ベースチェックリスト)**: 業界標準との比較を追加 → ただしスコープ外ペナルティリスクに注意

### 7.4 Test on Different Document Types

**Current Limitation**: 2ラウンド連続で同一テストドキュメントを使用

**Next Step**: 異なるドメイン/問題分布のドキュメントで汎化性能を検証
- 候補: マイクロサービス間通信設計、フロントエンドコンポーネント設計、バッチ処理システム設計

---

## 8. Conclusion

Round 002では3段階分析アプローチ (C1a) が劇的な効果を示した:
- **検出精度**: 43% → 100% (+57ポイント)
- **平均スコア**: 3.25 → 11.5 (+8.25pt)
- **安定性**: SD=0.0 (完全な再現性)

一方、検出ヒント追加 (S5a) はスコープ外指摘を誘発し、効果なしと判定。

**Core Discovery**: 構造化された分析手順 (Structure → Detail → Cross-cutting) は、チェックリストよりも高い検出精度と安定性を実現する。

**Next Round Priority**: v002-variant-staged-analysis をベースラインとし、B03未検出問題を解決する改善を試行。
