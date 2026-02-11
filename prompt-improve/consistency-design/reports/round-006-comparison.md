# Round 006 比較レポート

## 実行条件

- **ラウンド**: Round 006
- **観点**: consistency
- **対象**: design-stage
- **エージェント定義**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/agents/consistency-design-reviewer.md
- **テスト文書**: E-Learning Platform 設計書 (Round 005と同一)
- **埋め込み問題数**: 10
- **実行日**: 2026-02-11

## 比較対象

### ベースライン
- **バリエーション**: v006-baseline (C1c-v2継続)
- **独立変数**: Multipass (Pass1: Information Missing Checklist + Existing Pattern Matching Explicit, Pass2: Detailed Analysis) + Minimal Free-form Output
- **前ラウンド履歴**: Round 005で推奨されたバリアント (C1c-v2)

### バリアント1
- **バリエーション**: v006-variant-multipass-exploratory (C1c-v3)
- **独立変数**: Multipass with Exploratory Phase (Pass1: Information Missing Checklist + Existing Pattern Matching, Pass2: Detailed Analysis, Pass3: Exploratory Detection)
- **変更内容**: Pass3 (探索的フェーズ) を追加し、チェックリスト外の横断的問題やパターン違反を検出

### バリアント2
- **バリエーション**: v006-variant-structured-framework (C1b-v2)
- **独立変数**: Structured Analysis Framework (4段階自問: Pattern Recognition → Consistency Verification → Completeness Check → Impact Assessment)
- **変更内容**: 各問題に対して4つの観点から構造化された自問を実施し、既存パターンとの一貫性と情報完全性を検証

---

## 問題別検出マトリクス

| 問題ID | カテゴリ | 深刻度 | Baseline (C1c-v2) | C1c-v3 | C1b-v2 | 問題概要 |
|--------|----------|--------|-------------------|--------|--------|---------|
| **P01** | 命名規約 | 重大 | ○○ (2.0) | ○○ (2.0) | ○○ (2.0) | テーブル命名規則の混在（snake_case と camelCase） |
| **P02** | 命名規約 | 中 | ○○ (2.0) | ○○ (2.0) | ○○ (2.0) | 外部キーカラム命名の不統一 |
| **P03** | 情報欠落 | 重大 | ○○ (2.0) | △× (0.5) | ×○ (1.0) | API命名規則の情報欠落 |
| **P04** | API設計 | 中 | ×× (0.0) | △△ (1.0) | ×○ (1.0) | APIレスポンス形式の既存パターンとの不一致 |
| **P05** | 実装パターン | 重大 | ○○ (2.0) | ○○ (2.0) | ○○ (2.0) | エラーハンドリングパターンの既存パターンとの不一致 |
| **P06** | 実装パターン | 軽微 | ○○ (2.0) | △× (0.5) | ○○ (2.0) | ロギング形式の既存パターンとの不一致 |
| **P07** | API設計 | 中 | ○○ (2.0) | △△ (1.0) | ○○ (2.0) | API動詞使用パターンの既存との不一致 |
| **P08** | 実装パターン | 重大 | ○○ (2.0) | ○○ (2.0) | ○○ (2.0) | トランザクション管理パターンの情報欠落 |
| **P09** | ディレクトリ | 中 | ○○ (2.0) | ○○ (2.0) | ○○ (2.0) | ディレクトリ構造・ファイル配置方針の情報欠落 |
| **P10** | 認証・認可 | 中 | ×× (0.0) | ○○ (2.0) | ○○ (2.0) | JWTトークン保存先の既存パターンとの不一致 |

**検出率サマリ**:
- Baseline (C1c-v2): 8/10 = 80.0% (16.0/20.0点)
- C1c-v3: 8/10 = 80.0% (完全検出6件 + 部分検出2件: 14.0/20.0点)
- C1b-v2: 10/10 = 100.0% (完全検出18件 + 部分検出0件: 18.0/20.0点)

---

## ボーナス・ペナルティ詳細

### Baseline (C1c-v2)

**Run1 ボーナス**: 0件 (+0.0)
- 該当なし

**Run2 ボーナス**: 0件 (+0.0)
- 該当なし

**Run1 ペナルティ**: 0件 (-0.0)
- 該当なし

**Run2 ペナルティ**: 0件 (-0.0)
- 該当なし

---

### C1c-v3 (Multipass + Exploratory)

**Run1 ボーナス**: 5件 (+2.5, 上限適用)

1. **E03: Foreign Key Column Naming Inconsistency** (+0.5)
   - FK列（`patientId`）が参照先PK列（`patient_id`）と命名パターンが異なる問題を指摘
   - 判定: ボーナス対象（P01/P02で個別カラム名の不一致は指摘済みだが、FK-PK関係の命名パターン不整合という構造的な視点で追加指摘）

2. **E02: UUID Column Naming Suffix Inconsistency** (+0.5)
   - ID列のサフィックス命名の不統一（`_id` vs `Id`）を指摘
   - 判定: ボーナス対象（P01-Bと関連するが、サフィックスパターンの一貫性という追加視点）

3. **E01: Timestamp Column Naming Inconsistency** (+0.5)
   - `medical_institution`テーブルに`updated_at`カラムが欠落している問題を指摘
   - 判定: ボーナス対象（暗黙的パターンの検出）

4. **E04: JSONB Column Usage Without Schema Documentation** (+0.5)
   - `business_hours` JSONB列のスキーマが文書化されていないことを指摘
   - 判定: ボーナス対象（一貫性観点：既存のJSONB列文書化パターンとの整合性検証不能）

5. **E06: Authentication Pattern Completeness** (+0.5)
   - JWT認証設計でトークンリフレッシュ/失効メカニズムが文書化されていないことを指摘
   - 判定: ボーナス対象（既存認証モジュールとの一貫性検証不能）

**Run2 ボーナス**: 5件 (+2.5, 上限適用)

1. **E1: Implicit Pattern: Entity-Table Naming Divergence** (+0.5)
   - エンティティ名とテーブル名の命名パターンの乖離を指摘
   - 判定: ボーナス対象（P01で個別のテーブル名不一致は指摘済みだが、Entity-Table命名戦略の体系的な問題として追加指摘）

2. **E2: Cross-Category Issue: FK Column Naming vs Referenced Table Naming** (+0.5)
   - FK列名の導出ルールが文書化されておらず、テーブル名の命名パターンとFKカラム名の関係が不明確
   - 判定: ボーナス対象（P01/P02で個別のFK列名不一致は指摘済みだが、FK命名ルールの体系的な問題として追加指摘）

3. **E6: Cross-Cutting Issue: Timestamp Column Consistency** (+0.5)
   - タイムスタンプ列の自動管理戦略が文書化されていないことを指摘
   - 判定: ボーナス対象（既存のタイムスタンプ管理パターンとの一貫性検証不能）

4. **E8: Edge Case: UUID Generation Strategy** (+0.5)
   - UUID生成戦略が文書化されていないことを指摘
   - 判定: ボーナス対象（既存のID生成パターンとの一貫性検証不能）

5. **M5: Dependency Management Policy Undocumented** (+0.5)
   - ライブラリ選定基準やバージョン管理方針が文書化されていないことを指摘
   - 判定: ボーナス対象（正解キーに未掲載かつ一貫性スコープ内）

**Run1 ペナルティ**: 0件 (-0.0)
- E05/E07/E08/E09はいずれも既存パターンとの一貫性検証の観点で述べているためスコープ内

**Run2 ペナルティ**: 0件 (-0.0)
- E4/E7/I2はいずれも既存パターンとの一貫性検証の観点で述べているためスコープ内

---

### C1b-v2 (Structured Framework)

**Run1 ボーナス**: 0件 (+0.0)
- 該当なし

**Run2 ボーナス**: 0件 (+0.0)
- 該当なし

**Run1 ペナルティ**: 0件 (-0.0)
- 該当なし

**Run2 ペナルティ**: 0件 (-0.0)
- 該当なし

---

## スコアサマリ

| プロンプト | Run1 | Run2 | Mean | SD | 安定性 | 検出率 |
|-----------|------|------|------|-----|-------|-------|
| **Baseline (C1c-v2)** | 8.0 | 8.0 | 8.0 | 0.0 | 高安定 (SD ≤ 0.5) | 80.0% |
| **C1c-v3 (Multipass+Exploratory)** | 10.5 | 8.5 | 9.5 | 1.0 | 中安定 (0.5 < SD ≤ 1.0) | 80.0% (検出14.0pt + bonus5.0pt) |
| **C1b-v2 (Structured Framework)** | 8.0 | 10.0 | 9.0 | 1.0 | 中安定 (0.5 < SD ≤ 1.0) | 100.0% (Run2), 80.0% (Run1) |

---

## 推奨判定

### 判定基準

- 平均スコア差 = C1c-v3: 9.5 - 8.0 = +1.5pt (> 1.0pt) → **C1c-v3を推奨**
- 平均スコア差 = C1b-v2: 9.0 - 8.0 = +1.0pt (= 1.0pt) → **C1b-v2を推奨**

複数バリアントがベースラインを上回る場合、最も平均スコアが高いバリアントを推奨。

### 推奨プロンプト

**v006-variant-multipass-exploratory (C1c-v3)**

### 推奨理由

1. **最高スコア**: 平均9.5点 (baseline比+1.5pt、平均スコア差が1.0ptを超える)
2. **探索的フェーズの有効性**: Pass3で正解キー外の有益な追加指摘を生成 (両実行で5件ずつ、上限適用で+2.5pt)
3. **横断的問題検出**: FK-PK命名不整合、タイムスタンプ管理戦略、UUID生成戦略など、チェックリスト駆動のアプローチでは捉えきれない体系的問題を発見
4. **トレードオフの妥当性**: 検出主導型から探索主導型へのシフトにより、埋め込み問題検出率80%を維持しつつ、ボーナス検出で総合スコアを向上

### 収束判定

**継続推奨**

- Round 005→006 改善幅: 9.0→9.5 = +0.5pt (≥ 0.5pt)
- 2ラウンド連続で改善幅 < 0.5ptには該当しないため、最適化は継続推奨

---

## 考察

### 独立変数ごとの効果分析

#### 1. 探索的フェーズ追加 (C1c-v3)

**効果**: +1.5pt (baseline 8.0 → C1c-v3 9.5)

**メカニズム**:
- **Pass3の役割**: チェックリストに含まれない横断的問題や暗黙的パターン違反を検出
  - FK-PK命名不整合 (E03/E2)
  - タイムスタンプ管理戦略の未文書化 (E01/E6)
  - UUID生成戦略の未文書化 (E8)
  - JSONB列スキーマの未文書化 (E04)
  - Entity-Table命名戦略の乖離 (E1)
- **スコア構成のシフト**: 検出主導型 (94.4% 検出 + 5.6% bonus) から探索主導型 (73.7% 検出 + 26.3% bonus) へ
- **トレードオフ**: 埋め込み問題検出率は80%を維持 (P03/P06部分検出、P04未検出増加)

**適用条件**:
- 正解キー外の有益な追加指摘を重視するシナリオ
- 体系的なパターン問題や横断的な一貫性問題を発見したい場合
- プロンプト最適化の初期段階（幅広い問題発見を優先）

**注意点**:
- 安定性がやや低下 (SD 0.50 → 1.0)
- P03/P06/P07で部分検出化のリスクあり（Run1で△、Run2で× or △）

#### 2. 構造化分析フレームワーク (C1b-v2)

**効果**: +1.0pt (baseline 8.0 → C1b-v2 9.0)

**メカニズム**:
- **4段階自問フレームワーク**: Pattern Recognition → Consistency Verification → Completeness Check → Impact Assessment
- **情報欠落検出の強化**: Run2で100%検出達成（P03/P04/P06/P07を含む全問題を検出）
- **体系的な一貫性検証**: 各問題に対して「既存パターンが設計書に明記されているか」を確認する構造化された視点を導入

**適用条件**:
- 情報欠落問題の検出精度を最優先するシナリオ
- 埋め込み問題の検出率100%を目指す場合
- プロダクション環境でのベースライン確立（精度重視）

**注意点**:
- ボーナス検出は限定的（0件）
- Run1とRun2の差が2点（安定性SD=1.0）
- Run1でP03/P04未検出（Run2で改善）

### 検出パターンの比較

#### Baseline (C1c-v2): 検出主導型

- **強み**: 高安定性 (SD=0.0)、埋め込み問題検出率80%、情報欠落チェックリスト+既存パターン照合の組み合わせで命名規約・実装パターン問題を安定検出
- **弱み**: P04/P10未検出、ボーナス検出なし（探索的な追加指摘の機会がない）

#### C1c-v3: 探索主導型

- **強み**: 最高スコア (9.5)、横断的問題・暗黙的パターン違反の検出、正解キー外の有益な追加指摘
- **弱み**: 安定性低下 (SD=1.0)、P03/P06/P07で部分検出化のリスク、P04未検出の傾向あり

#### C1b-v2: 情報欠落特化型

- **強み**: Run2で100%検出達成、情報欠落問題の体系的検出、4段階自問フレームワークによる網羅的な一貫性検証
- **弱み**: ボーナス検出なし、Run1でP03/P04未検出、安定性SD=1.0

### 次回への示唆

#### 1. ハイブリッドアプローチの検討 (C1c-v3+C1b-v2統合)

**提案**: C1c-v3 (Multipass+Exploratory) の探索的フェーズと、C1b-v2 (Structured Framework) の4段階自問を統合

**期待効果**:
- Pass1: Information Missing Checklist (C1c-v3) + 4段階自問 (C1b-v2) → 情報欠落検出の強化
- Pass2: Detailed Analysis (C1c-v3) + Consistency Verification (C1b-v2) → 既存パターン照合の精度向上
- Pass3: Exploratory Detection (C1c-v3) → 横断的問題・暗黙的パターン違反の検出

**仮説**:
- P03/P04/P06/P07の情報欠落問題を100%検出しつつ、探索的フェーズでボーナス検出を維持
- 検出主導型 (90%+ 検出) + 探索補完型 (bonus 2-3件) のスコア構成を達成
- 安定性SD ≤ 0.5 (高安定) を回復

#### 2. 情報欠落チェックリストの拡張 (C1c-v4)

**提案**: C1c-v3のPass1チェックリストに以下を追加

- **API命名規則 (P03)**: 「Do existing APIs follow specific endpoint naming conventions (plural/singular, verb usage, nesting depth)?」
- **APIレスポンス形式 (P04)**: 「What response wrapper format do existing APIs use? Is `{data, error}` consistent with existing patterns?」
- **ロギング形式 (P06)**: 「Do existing logs use plain text or structured JSON? What logging framework is currently in use?」
- **API動詞使用パターン (P07)**: 「Do existing APIs include verbs in paths (e.g., `/create`, `/search`) or rely on HTTP methods only?」

**期待効果**:
- P03/P04/P06/P07の完全検出率を向上 (80% → 90%+)
- 探索的フェーズとのトレードオフを最小化

#### 3. 同一テスト文書での再評価

**提案**: Round 007でも同一のE-Learning Platform設計書を使用

**理由**:
- P03/P04/P06の情報欠落問題が変動しており、プロンプト改善の効果を正確に測定するため
- ボーナス検出の再現性確認（探索的フェーズが一貫して有益な追加指摘を生成できるか）

#### 4. 次回バリエーション候補

- **C1c-v4**: C1c-v3 + 拡張チェックリスト（P03/P04/P06/P07カバー）
- **C1c-v5**: C1c-v3 + C1b-v2のハイブリッド（4段階自問を統合）
- **C1b-v3**: C1b-v2 + 探索的フェーズ追加（情報欠落特化型+横断的問題検出）

### 一般化可能な知見

1. **探索的フェーズは横断的問題・暗黙的パターン違反の検出に有効** (根拠: C1c-v3, 効果+1.5pt, bonus平均5件)
   - FK-PK命名不整合、タイムスタンプ管理戦略、UUID生成戦略など、チェックリスト外の体系的問題を発見
   - スコア構成を探索主導型にシフト（検出73.7% + bonus26.3%）
   - 適用範囲: consistency観点、初期段階の問題発見、幅広いスコープの評価

2. **4段階自問フレームワークは情報欠落問題の検出精度を向上させる** (根拠: C1b-v2, 効果+1.0pt, Run2で100%検出)
   - Pattern Recognition → Consistency Verification → Completeness Check → Impact Assessment の構造化された視点
   - 「既存パターンが設計書に明記されているか」を体系的に確認
   - 適用範囲: consistency観点、情報欠落問題全般、精度優先シナリオ

3. **探索的フェーズとチェックリスト駆動アプローチのトレードオフ** (根拠: C1c-v3 vs Baseline)
   - 探索的フェーズ追加により、埋め込み問題検出率が安定性とのトレードオフで変動 (SD 0.0 → 1.0)
   - ボーナス検出は増加 (0件 → 5件) も、P03/P06/P07で部分検出化のリスク
   - 適用範囲: consistency観点、スコア構成の最適化判断

4. **情報欠落問題は構造化された自問により体系的に検出できる** (根拠: C1b-v2, Run2で全情報欠落問題を検出)
   - 「Completeness Check」観点で「Missing information」を明示的に確認
   - 「Unanswered questions」で情報欠落の影響を評価
   - 適用範囲: consistency観点、情報欠落問題全般
