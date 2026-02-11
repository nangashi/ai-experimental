# Round 004 Comparison Report

## 実行条件

- **ラウンド**: Round 004
- **観点**: structural-quality
- **対象**: design
- **テスト対象**: Ticketing System Design (Event ticketing platform with payment integration)
- **埋め込み問題数**: 9問 (重大×3, 中×4, 軽微×2)
- **比較対象プロンプト**: baseline, cot (S3a), scope-boundary

---

## 問題別検出マトリクス

| 問題ID | カテゴリ | 重要度 | baseline | cot | scope-boundary |
|--------|---------|--------|----------|-----|----------------|
| P01 | SRP違反 (TicketSalesEngine) | 重大 | ○/○ | ○/○ | ○/○ |
| P02 | 直接的データアクセス層バイパス | 重大 | ○/○ | ○/○ | ○/○ |
| P03 | データ冗長性 (events/tickets) | 重大 | ○/○ | ○/○ | ○/○ |
| P04 | トランザクション境界未定義 | 中 | ○/○ | ○/○ | ×/× |
| P05 | JWT不適切保存 | 中 | ○/○ | ×/× | ×/○ |
| P06 | 単体テスト方針欠如・DI不在 | 中 | ○/○ | ○/○ | ○/○ |
| P07 | RESTful API設計原則違反 | 中 | ○/○ | ○/○ | ○/○ |
| P08 | 環境固有設定管理の脆弱性 | 軽微 | ○/○ | ○/○ | ○/○ |
| P09 | 直接的コンポーネント結合 | 軽微 | ○/○ | ○/○ | ○/○ |

**表記**: ○/○ = (Run1/Run2), ○ = 検出 (1.0pt), △ = 部分検出 (0.5pt), × = 未検出 (0.0pt)

---

## ボーナス・ペナルティ詳細

### ボーナス検出

| ボーナスID | 内容 | baseline | cot | scope-boundary |
|----------|------|----------|-----|----------------|
| B01 | Auth/Authz分離 | ×/× | ×/× | ×/× |
| B02 | エラー分類戦略 | ○/○ | ×/× | ×/× |
| B03 | APIバージョニング | ○/○ | ×/× | ○/○ |
| B04 | 同時実行制御 | ○/○ | ×/× | ×/× |
| B05 | エラーケーステスト | ×/× | ×/× | ×/× |
| Additional 1 | Resilience patterns (baseline), Cache invalidation (baseline), Idempotency (scope-boundary) | ○/× | ×/× | ×/○ |
| Additional 2 | Distributed tracing (baseline) | ○/○ | ×/× | ×/× |
| Additional 3 | Idempotency (baseline) | ○/× | ×/× | ×/× |
| Additional 4 | Domain layer design (baseline) | ○/× | ×/× | ×/× |
| Additional 5 | Cache invalidation (baseline) | ○/× | ×/× | ×/× |

### ペナルティ

| プロンプト | Run1 | Run2 | 主な違反内容 |
|----------|------|------|-------------|
| baseline | 0 | 0 | なし |
| cot | 0 | 0 | なし |
| scope-boundary | 0 | 0 | なし |

---

## スコアサマリ

| プロンプト | Run1 | Run2 | Mean | SD | 安定性 |
|----------|------|------|------|-----|--------|
| baseline | 13.0 | 12.0 | **12.5** | 0.5 | 高安定 |
| cot | 8.0 | 8.0 | **8.0** | 0.0 | 高安定 |
| scope-boundary | 7.5 | 9.0 | **8.25** | 1.06 | 低安定 |

### スコア内訳

- **baseline**: 検出9.0/9.0, ボーナス+4.0/+3.0 (Run1/Run2), ペナルティ0
- **cot**: 検出8.0/8.0, ボーナス0/0, ペナルティ0
- **scope-boundary**: 検出7.0/8.0, ボーナス+0.5/+1.0, ペナルティ0

---

## 推奨判定

### 判定基準適用

| バリアント | 平均スコア | baseline差分 | 判定 |
|----------|----------|-------------|------|
| baseline | 12.5 | - | ベースライン |
| cot | 8.0 | -4.5 | 劣位 |
| scope-boundary | 8.25 | -4.25 | 劣位 |

**平均スコア差**:
- cot vs baseline: -4.5pt
- scope-boundary vs baseline: -4.25pt

**推奨判定**: **baseline**

両バリアントがベースラインを大幅に下回る (-4.5pt, -4.25pt)。scoring-rubric.md Section 5 の判定基準により、**baseline を推奨**。

### 収束判定

| 条件 | 判定 |
|------|------|
| Round 003 改善幅 | 0.0pt (baseline=10.0 vs cot=9.25, checklist=10.0) |
| Round 004 改善幅 | -4.5pt (baseline=12.5 vs cot=8.0, scope-boundary=8.25) |

**収束判定**: **継続推奨**

Round 004で平均スコア差が-4.5ptと拡大しており、これは新しいテスト文書（Event ticketing domain）に対するbaselineの検出力向上と、バリアントのボーナス発見保守化が顕著になった結果。2ラウンド連続で改善幅<0.5ptという収束条件は満たさない。

---

## 考察

### 1. 独立変数ごとの効果分析

#### Chain-of-Thought reasoning (S3a: cot)

**効果**: -4.5pt (検出-1.0pt, ボーナス-3.5pt)

**検出パターン変化**:
- **P05 (JWT不適切保存)**: 両Run未検出 (baseline: 両Run検出)
  - セキュリティ観点とのスコープ境界判定が保守化
  - CoT構造が「ステップ2: 構造設計の分析」で状態管理を扱うが、セキュリティリスクを主理由とする指摘を抑制

**ボーナス発見の保守化**:
- baseline: 8/6件 (Run1/Run2) → cot: 0/0件
- Round 003と同じ傾向: CoT構造が段階的分析を強制することで、正解キー外の創造的探索が制約される
- baseline Run1で検出された以下のボーナスがcotで未検出:
  - B02: エラー分類戦略
  - B03: APIバージョニング
  - B04: 同時実行制御
  - Additional 1-5: Resilience patterns, Distributed tracing, Idempotency, Domain layer, Cache invalidation

**安定性向上**:
- SD: 0.5 (baseline) → 0.0 (cot)
- Round 003と同じパターン: CoT構造が実行間の変動を完全に抑制

**知見の再確認**:
- Chain-of-Thoughtは安定性を極大化するが、ボーナス発見を大幅に犠牲にする
- 「段階的分析」と「創造的探索」のトレードオフが再現された
- Round 003: -0.75pt (検出差0, ボーナス-1.0pt)
- Round 004: -4.5pt (検出-1.0pt, ボーナス-3.5pt)
- テスト文書のボーナス機会が多いほど、CoTの制約が顕著に現れる

#### Scope-boundary approach

**効果**: -4.25pt (検出-1.0pt [Run1], +0.0pt [Run2], ボーナス+0.5/+1.0pt)

**検出パターン**:
- **P04 (トランザクション境界未定義)**: 両Run未検出 (baseline: 両Run検出)
  - エラー分類戦略の欠如のみを指摘し、補償トランザクション設計（Saga等）に踏み込まず
  - スコープ境界の明示化が、アプリケーションレベルのリカバリー戦略検討を抑制した可能性
- **P05 (JWT不適切保存)**: Run1未検出/Run2検出 (baseline: 両Run検出)
  - スコープ境界の判定がRun間で不安定 (SD=1.06)
  - 正解キーにも「本問題はセキュリティ観点のためスコープ外の可能性あり」と記載

**ボーナス発見の部分的改善**:
- Run1: 1件 (B03 APIバージョニング)
- Run2: 2件 (B03 + Idempotency)
- baselineより少ないが、cotより多い（cot: 0件）

**安定性低下**:
- SD: 0.5 (baseline) → 1.06 (scope-boundary)
- P05のスコープ判定不安定性とボーナス検出のばらつきが主因

**知見**:
- スコープ境界の明示化は、境界線上の問題（P04アプリケーション・レベルのリカバリー戦略、P05セキュリティ寄りの状態管理）の検出を不安定化させる
- ボーナス発見は部分的に保持されるが、baselineの創造的探索には及ばない
- スコープ境界の明示化自体がペナルティを削減する効果は確認できず（全プロンプトでペナルティ0）

### 2. Baselineの強み再確認

**完璧な検出**: 全9問を両Runで検出 (9.0/9.0)

**豊富なボーナス発見**: 8/6件 (Run1/Run2)
- エラー分類戦略、APIバージョニング、同時実行制御、Resilience patterns、Distributed tracing、Idempotency、Domain layer design、Cache invalidation

**適度な安定性**: SD=0.5 (高安定)
- ボーナス発見のばらつき（8件 vs 6件）があるが、検出スコアは完全に安定

**Round 003との比較**:
- Round 003 baseline: 10.0 (SD=0.5) = 検出9.0 + ボーナス1.0
- Round 004 baseline: 12.5 (SD=0.5) = 検出9.0 + ボーナス3.5 (平均)
- テスト文書のボーナス機会増加に応じて、baselineの探索能力が発揮された

### 3. テスト文書特性の影響

**Round 004テスト文書**: Ticketing System Design (Event ticketing platform with payment integration)
- **ボーナス機会が豊富**: 9問の埋め込み問題に対し、8件のボーナス問題をbaselineが発見
- **横断的問題が多い**: Distributed tracing, Idempotency, Resilience patterns, Domain layer design等

**Round 003テスト文書**: Payment System Design
- **ボーナス機会が少ない**: 9問の埋め込み問題に対し、1件のボーナス問題をbaselineが発見
- **SOLID原則中心**: P01-P03, P06-P09はSOLID違反またはAPI/データモデル設計

**知見**:
- ボーナス機会が多いテスト文書では、CoTとscope-boundaryの制約が顕著に現れる
- baselineの創造的探索能力は、ボーナス機会に応じてスケールする
- 構造化アプローチ（CoT, scope-boundary）は、ボーナス機会の多さに関わらず保守的な検出パターンを維持

### 4. P05検出パターンの考察

**P05**: JWTトークンの不適切な保存先（localStorage → httpOnly Cookie推奨）

| プロンプト | Run1 | Run2 | スコープ判定 |
|----------|------|------|-------------|
| baseline | ○ | ○ | セキュリティリスクを含むが状態管理の問題として検出 |
| cot | × | × | セキュリティ観点として除外 |
| scope-boundary | × | ○ | Run間で判定不安定 |

**スコープ境界の曖昧性**:
- perspective.mdでは「状態管理（ステートレス/ステートフル、グローバル状態の制御）」がスコープ内
- しかし「セキュリティ脆弱性（認証・認可、暗号化等）→ security で扱う」とも記載
- P05は両方の性質を持つ境界問題

**プロンプト別の判定傾向**:
- **baseline**: セキュリティリスクを言及しつつ、状態管理の問題として扱う（Issue 8: "identifies localStorage risk for JWT tokens, recommends httpOnly cookies with CSRF protection"）
- **cot**: CoT構造のステップ2で状態管理を扱うが、セキュリティリスクを主理由とする指摘を避ける
- **scope-boundary**: スコープ境界の明示化により、判定がRun間で不安定化（Run1: セキュリティ観点として除外、Run2: 状態管理の問題として検出）

**知見**:
- スコープ境界の明示化は、境界線上の問題の検出を不安定化させる可能性がある
- baselineの「スコープ内で扱える角度を探す」アプローチが、境界問題の検出に有効

### 5. 次回への示唆

#### 収束していない理由

Round 003とRound 004で異なる結果が出た理由:
1. **テスト文書のボーナス機会の差**: Round 003は1件、Round 004は8件
2. **バリアントの制約がボーナス機会に依存して顕著化**: CoTとscope-boundaryは、ボーナス機会が多いほどbaselineとの差が拡大

#### 次回検証すべき仮説

1. **CoTとscope-boundaryの統合**: 段階的分析による安定性と、スコープ内の創造的探索のバランス
   - 候補: M1a (Multi-tier CoT with explorative step), M2a (CoT + explicit bonus discovery phase)

2. **ボーナス発見の明示的促進**: CoT構造にボーナス発見フェーズを追加
   - 候補: N1a (Bonus discovery checklist), C1a (Contextual variation)

3. **境界問題の扱い方の明示化**: P05のような境界問題を、複数観点からの分析で扱う
   - 候補: S1b (Few-shot examples with scope boundary cases)

4. **テスト文書のバリエーション**: ボーナス機会の少ないテスト文書でのCoT/scope-boundary検証
   - Round 003のような「SOLID原則中心」のテスト文書で、CoTが検出-0.75ptだった理由を再検証

#### 優先順位

1. **最優先**: M1a/M2aによるCoT改善（安定性保持+ボーナス発見復活）
2. **中優先**: S1bによる境界問題の扱い方明示化（P05等の不安定性解消）
3. **低優先**: scope-boundary単体の改善（効果がCo Tよりマイルドなため）

---

## まとめ

**推奨プロンプト**: baseline
**推奨理由**: 完璧な検出（9.0/9.0）と豊富なボーナス発見（平均3.5件）により、両バリアントを+4.25pt〜+4.5pt上回る

**主要知見**:
1. Chain-of-Thought (S3a)は安定性を極大化（SD=0.0）するが、ボーナス発見を大幅に犠牲にする（-3.5pt）
2. Scope-boundary approachは検出を部分的に抑制（P04未検出）し、境界問題の判定を不安定化（P05, SD=1.06）
3. Baselineの創造的探索能力は、ボーナス機会の多いテスト文書でスケールする（Round 003: +1.0pt → Round 004: +3.5pt）
4. テスト文書のボーナス機会の量が、バリアント間の差を増幅する（Round 003: -0.75pt vs Round 004: -4.5pt）

**次回検証課題**:
- M1a/M2a: CoT構造にボーナス発見フェーズを追加し、安定性と探索能力を両立
- S1b: Few-shot examplesで境界問題の扱い方を明示化し、P05等の不安定性を解消
- テスト文書バリエーション: ボーナス機会の少ないテスト文書でのCoT検証（Round 003の-0.75ptの再現性確認）
