# エージェントプロンプト設計ガイドライン

本ドキュメントは、`prompt-improve/` 以下の9観点・60+ラウンドの実験結果と `.claude/skills/` 内の知見を体系的にまとめたものである。エージェント定義プロンプトを設計・改善する際の実践的なリファレンスとして使用する。

---

## 1. バリアントカタログ

プロンプト改善アプローチは **4カテゴリ → テクニック → バリエーション** の3階層で管理される。

### ID命名規則

- カテゴリ: 大文字1文字 (S, C, N, M)
- テクニック: カテゴリ文字 + 番号 (S1, C2, ...)
- バリエーション: テクニック + 小文字 (S1a, S1b, ...)

### Structural (S) — プロンプト構造の変更

| テクニック | 説明 | バリエーション |
|-----------|------|---------------|
| **S1: Few-shot Examples** | 具体的な出力例を2-3個追加 | S1a(基本), S1b(ドメイン特化), S1c(敵対的), S1d(否定例), S1e(段階的難易度) |
| **S2: Scoring Criteria** | 5段階スコアリング表を追加 | S2a(基本5段階), S2b(カテゴリ重み付き), S2c(深刻度アンカリング) |
| **S3: Output Format** | 詳細テンプレートをセクション名+1行説明に簡素化 | S3a(セクション名のみ), S3b(最小自由記述), S3c(テーブル中心) |
| **S4: Sub-item Reduction** | 評価項目の説明を核心の1行に圧縮 | S4a(1行要約化), S4b(階層簡略化) |
| **S5: Detection Hints** | 「問題を検出し出力に反映する」旨の明示的指示を追加 | S5a(カテゴリリスト), S5b(アンチパターン), S5c(欠落検出) |

### Cognitive (C) — 推論方法の変更

| テクニック | 説明 | バリエーション |
|-----------|------|---------------|
| **C1: Chain-of-Thought** | 分析を段階的に構造化 | C1a(基本段階的分析), C1b(自問式), C1c(マルチパスレビュー) |
| **C2: Role Framing** | 特定のペルソナ・視点を設定 | C2a(専門家ペルソナ), C2b(攻撃者視点), C2c(二重役割) |
| **C3: Priority Ordering** | 報告順序を制御 | C3a(深刻度優先), C3b(リスクベース), C3c(カテゴリ→深刻度) |

### Content (N) — ドメイン知識・内容の変更

| テクニック | 説明 | バリエーション |
|-----------|------|---------------|
| **N1: Checklist Enrichment** | ドメイン固有チェック項目を追加 | N1a(標準ベース), N1b(アンチパターン集), N1c(観点間境界) |
| **N2: Prompt Language** | プロンプトの言語を変更 | N2a(全文英語), N2b(混合言語), N2c(全文日本語) |
| **N3: Prompt Length** | プロンプトの情報量を増減 | N3a(50%圧縮), N3b(50%拡張), N3c(選択的最適化) |

### Meta (M) — プロンプト構成方法の変更

| テクニック | 説明 | バリエーション |
|-----------|------|---------------|
| **M1: Prompt Decomposition** | 分析フェーズを明示的に分離 | M1a(事前分析+本レビュー), M1b(検出+報告分離) |
| **M2: Constraint Manipulation** | 出力制約を変更 | M2a(最低検出数制約), M2b(制約緩和), M2c(確信度注釈) |

---

## 2. 定量的な効果データ

### 2.1 実証済み効果テクニック

5エージェント・26+ラウンドの実験から抽出された、ベースライン構築時に適用推奨のテクニック。

| テクニック | 効果 | 安定性(SD) | 根拠 | 出典 |
|-----------|------|-----------|------|------|
| 英語指示 (N2a) | +1.5〜+2.75pt | 0.0 | 全観点で一貫して効果あり。LLMの事前学習データとの整合性が高い | security:R4,R16, performance:R4, sq:R4 |
| テーブル/マトリクス構造 (S3c) | +2.5〜+3.0pt | 0.0〜0.25 | コンポーネント×評価軸のマトリクスが網羅的カバレッジを強制 | security:R8,R16, performance:R4, sq:R4 |
| ドメイン固有チェックリスト (N1) | +2.0〜+3.0pt | 0.0〜0.5 | NFRチェックリスト+3.0pt、データライフサイクル+2.25pt。3-4領域まで効果的 | security:R16, performance:R2,R3 |
| 明示的タスク指示 (S5) | +0.75〜+2.5pt | 0.0〜0.25 | 「何を見つけるべきか」の方向性を明確化。検出率向上に直結 | security:R5,R16, performance:R4, sq:R4 |
| 自由形式+テーブル混合構造 (S6c) | +3.0pt | 0.25 | 自由形式で認知負荷軽減+テーブルで体系的カバレッジの両立 | security:R10 |
| 出力形式簡素化 (S3a) | +0.75pt | 0.25 | 詳細テンプレート削除でモデルの自律的分析能力を引き出す | security:R1 |
| Few-shot 1-2例（多様な難易度） (S1a) | +2.87pt | 0.14 | 具体的パターン提示で多次元分析の深度が向上 | critic-clarity:R1 |
| タスクチェックリスト+段階的分析 (C1a) | +1.15〜+2.91pt | 0.00〜0.14 | 4フェーズの構造的タスク分解で見落とし防止 | critic-clarity:R1, critic-completeness:R1 |

### 2.2 回避すべきアンチパターン

| テクニック | 効果 | 失敗メカニズム | 出典 |
|-----------|------|--------------|------|
| Few-shot 2例以上（複雑タスク） | -0.5〜-3.75pt | テンプレートバイアスで注意が偏り、基本検出すら低下 | security:R3, completeness:R1 |
| 明示的重み付け採点 | -2.5pt | 「存在確認」モードに退化させるポジティブフレーミングバイアス | security:R12 |
| 敵対的視点フレーミング (C2b) | -2.0pt | スコープ外の推測を誘発しペナルティ累積 | security:R12 |
| 厳格なカテゴリ分類 | -4.25〜-4.5pt | 横断的思考を抑制し中程度問題を系統的に見逃す | security:R16, sq:R4 |
| 明示的スコープ境界制約 | -4.25pt | 境界ケースの検出を不安定化、ボーナス発見を減少 | security:R16 |
| Scoring Rubric（プロンプト内） | -0.5〜-1.5pt | 「評価モード」を誘発し探索的思考を抑制 | performance:R1, sq:R4 |

### 2.3 条件付きテクニック

効果がタスク特性に依存するテクニック。適用前に条件を確認すること。

| テクニック | 効果的な条件 | 逆効果な条件 | 効果範囲 |
|-----------|-------------|-------------|---------|
| Few-shot 2-3例 | 明確なタスク出力パターンがある場合 | 創造的・探索的タスクの場合 | +6.0pt 〜 -0.75pt |
| Chain-of-Thought (C1) | 論理的推論が核心のタスク | ボーナス発見・創造的探索が重要なタスク | +0.25pt 〜 -4.5pt |
| 単一領域チェックリスト | 特定問題の確実な検出が必要な場合 | 網羅的な分析が必要な場合 | 視野狭窄リスク大 |
| サブ項目圧縮 (S4, 50%) | 冗長な説明が多いプロンプト | 横断的要件が重要なプロンプト | +4.25pt 〜 -1.0pt |
| 重大度階層化 (C3a) | 安定性重視の場合 | 中程度問題の検出が重要な場合 | +1.5pt 〜 -0.25pt |

### 2.4 観点別の実験サマリ

以下、各観点の実験で得られた主要な知見を要約する。

#### consistency-design（9ラウンド）

最終スコア 11.0pt (SD=0.0)。3-phase分析 (C1a) が+8.25ptの最大効果。専門家ペルソナ (C2a) も+3.0ptで安定。情報損失チェックリスト付きマルチパス (C1c-v2) が安定的ベースライン。標準ベースチェックリスト (N1a) はパターン比較能力を弱め逆効果 (-22.2pt検出率低下)。

#### security-design（17ラウンド、最多）

最終スコア 7.25pt (SD=0.25)。英語化 (N2a) +2.75pt、テーブル中心構造 (S6a) +2.5pt、自由+テーブル混合 (S6c) +3.0ptが特に高効果。Few-shot (S1b) は重大検出率100%→0%の壊滅的逆効果 (-3.75pt)。重み付き採点とSTRIDE敵対的フレーミングも大幅マイナス。インフラ・テーブル拡張 (S6a extended) でConfigMaps検出0%→100%を達成。

#### performance-design（11ラウンド）

最終スコア 8.5pt (SD=1.0)。NFRチェックリスト (N1a) +3.0pt、英語化 (L1b) +1.5ptが効果的。検出ヒント数には閾値があり、2ヒントが最適。4ヒントで-2.75ptの逆効果（満足バイアス限界超過）。Few-shot (-0.75pt)、Scoring Rubric (-1.5pt) は効果なし。

#### reliability-design（6ラウンド）

最終スコア 7.25pt (SD=0.75)。包括的チェックリスト (C2c) +3.75pt (SD=0.0) が最大効果。2フェーズ分解 (M2a) +2.25ptも有効。階層化カテゴリ (C2d) はブラインドスポット解消に貢献 (+1.25pt, SD=0.0)。Round 6で性能プラトーに到達、直交的な最適化が必要。

#### structural-quality-design（7ラウンド）

最終スコア 9.0pt (SD=0.0)。6フェーズ分解 (M1a) +1.75ptが安定的に最良。深刻度優先 (S1e) は-4.5ptの壊滅的逆効果（41%検出損失）。スコープ境界 (N3b) も-4.25pt。基本CoT (C1a) は+0.25ptで初の成功的CoT。M1aが3ラウンド連続で最適を維持し収束。

#### critic-clarity（2ラウンド）

最終スコア 10.00pt (SD=0.00、完全スコア）。Few-shot例 (S1a) +2.87pt、タスクチェックリスト+段階的分析 (C1a+S2a) +2.91ptが効果的。知識ベース改善 (N1a) は境界ケース分析を劣化 (-0.42pt)。ベースラインが完全スコアに到達したため収束。

#### critic-completeness（1ラウンド）

タスクチェックリスト (C1a) で完全スコア 10.00pt (SD=0.00) を達成 (+1.15pt)。Few-shot例 (S1a) は高難易度タスクで-1.85ptの逆効果（認知オーバーヘッド）。

#### critic-effectiveness（実験データなし）

knowledge.md は初期テンプレートの状態。実験未実施。

#### skill-improve-skill_improve（定性的データのみ）

knowledge.md なし。analysis.md, findings.md, improvement-plan.md に定性的な知見あり。定量的スコアデータは未蓄積。

---

## 3. 推奨プロンプト構成

### 3.1 レビューエージェント向け推奨構成

```
[YAML frontmatter: name, description, tools, model]
[ロール定義（英語、1-2文）]
[評価プロセス / 検出戦略（重大度優先 or 2フェーズ分析）]
[評価項目（5項目、各項目はタイトル+核心1-2文 — S4適用）]
  └ 問題検出指示を含む（S5適用）
[評価の姿勢（3-4項目）]
[出力ガイドライン（セクション名+1行説明のみ — S3適用）]
```

### 3.2 汎用エージェント向け推奨構成

```
[YAML frontmatter: name, description, tools, model]
[ロール定義（英語、1-2文）]
[実行優先順位（重要度順）]
[実行基準（番号付きセクション、テーブル/マトリクス構造）]
[行動姿勢（3-4項目、箇条書き）]
[出力ガイドライン（セクション名+1行説明のみ）]
```

### 3.3 設計根拠

各セクションの配置理由と適用テクニックの根拠を以下にまとめる。

**YAML frontmatter**
- `name`, `description`, `tools`, `model` を定義。フレームワークが読み取るメタデータ。
- 変更不可。

**ロール定義（英語、1-2文）**
- 英語指示は全観点で+1.5pt以上の効果と完全な安定性 (SD=0.0)。LLMの事前学習データとの整合性が高いため。
- 1-2文に抑えるのは、冗長なペルソナ設定が検出能力に寄与しないため（C2a専門家ペルソナは+3.0ptだが、これはペルソナの長さではなく「専門家として振る舞え」の1文が効果的）。

**評価プロセス / 検出戦略**
- 2フェーズ分析（検出→整理）: 検出フェーズで全問題を洗い出し、報告フェーズで整理する。検出と報告の分離 (M1b) は+2.5pt (SD=0.0)。早期フィルタリングによる見落としを防止。
- 重大度優先検出: 重大→重要→中→軽微の4パスで検出。重大度優先は+1.5pt〜+1.75ptの効果。出力長制約によるクリティカル問題の切り捨てを防止。

**評価項目（5項目、核心1-2文）**
- サブ項目圧縮 (S4): 冗長な説明を削減し+4.25ptの効果。1項目あたり2行以上の説明は認知負荷となりモデルの自律的分析を阻害する。
- 5項目は相互排他的（重複なし）で、高レベル（アーキテクチャ）→低レベル（実装詳細）の順序。
- 問題検出指示 (S5): 「問題がある場合は指摘し改善案を出力に反映する」旨の明示的指示。ベースラインの低スコア (4.0/10) の主因がこの指示の欠如であった。

**評価の姿勢（3-4項目）**
- エージェントの視点・バイアスを明確化。「何を重視するか」「どう判断するか」のガイダンス。
- 3-4項目に抑える。過剰な制約は探索的検出を阻害する（厳格なカテゴリ分類: -4.25〜-4.5pt）。

**出力ガイドライン（セクション名+1行説明のみ）**
- 出力形式簡素化 (S3a): 詳細テンプレートの削除で+0.75pt。モデルが自律的に最適な出力構造を選択できる。
- 過剰な構造指定は分析能力を阻害する（実験で確認済み: 詳細テンプレート使用時4.0pt、セクション名のみ9.0pt）。

**Few-shot例を推奨構成から除外した理由**
- レビュー系タスクではFew-shotは条件付きテクニック。複雑な探索タスクでは-3.75ptの壊滅的逆効果のリスクがある。
- 有効な条件（明確な出力パターン、critic系タスク）を満たす場合のみ追加を検討。
- 追加する場合は1-2例に厳守し、出力ガイドラインの直後に配置。

---

## 4. エージェントプロンプトの具体例

### 4.1 解説付き具体例: security-design-reviewer

以下は、実験を通じて最適化された `security-design-reviewer.md` の全文に、各セクションの設計根拠をアノテーションとして付記したものである。

```markdown
# --- YAML frontmatter ---
# フレームワークが読み取るメタデータ。tools は使用可能なツールを制限する。
---
name: security-design-reviewer
description: An agent that performs architecture-level security evaluation of
  design documents to identify security issues and missing countermeasures
  through threat modeling, authentication/authorization design, data protection,
  input validation, and infrastructure security assessment.
tools: Glob, Grep, Read, WebFetch, WebSearch, BashOutput, KillBash
model: inherit
---

# --- ロール定義（英語、2文） ---
# [N2a: 英語指示] 全文英語で+1.5〜+2.75ptの効果。
# [C2a: 専門家ペルソナ] 簡潔な専門家設定。冗長な経歴は不要。
You are a security architect with expertise in application security
and threat modeling.
Evaluate design documents at the **architecture and design level**,
identifying security issues and missing countermeasures.

# --- 評価プロセス: 重大度優先検出 ---
# [C3a: 深刻度優先] 4段階の重大度で検出順序を制御。
# 出力長制約によるクリティカル問題の切り捨てを防止する。
## Evaluation Priority

Prioritize detection and reporting by severity:
1. First, identify **critical issues** that could lead to data breach,
   privilege escalation, or complete system compromise
2. Second, identify **significant issues** with high likelihood of
   attack in production
3. Third, identify **moderate issues** exploitable under specific conditions
4. Finally, note **minor improvements** and positive aspects

Report findings in this priority order. Ensure critical issues are
never omitted due to length constraints.

# --- 評価項目（5項目、各1-2文） ---
# [S4: サブ項目圧縮] 各項目はタイトル+核心説明のみ。詳細な箇条書きは削除。
# [S5: 問題検出指示] 各項目の説明に「何を評価するか」を明示。
## Evaluation Criteria

### 1. Threat Modeling (STRIDE)
Evaluate design-level considerations for each threat category:
Spoofing (authentication mechanisms), Tampering (data integrity
verification), Repudiation (audit logging), Information Disclosure
(data classification and encryption), Denial of Service (rate limiting
and resource restrictions), Elevation of Privilege (authorization
checks). Assess whether countermeasures for each threat are explicitly
designed.

### 2. Authentication & Authorization Design
Evaluate whether authentication flows are designed, whether the
authorization model (RBAC/ABAC, etc.) is appropriately selected, and
whether API access control and session management design have security
issues. Check for explicit design of token storage mechanisms, session
timeout policies, and permission models.

### 3. Data Protection
Evaluate whether protection methods for sensitive data at rest and in
transit (encryption algorithms, key management) are appropriate,
whether PII classification, retention periods, and deletion policies
are designed, and whether privacy requirements are addressed.

### 4. Input Validation & Attack Defense
Evaluate whether external input validation policies are designed,
whether countermeasures against injection attacks
(SQL/NoSQL/Command/XSS) exist, whether output escaping, CORS/origin
control, and CSRF protection are designed.

### 5. Infrastructure, Dependencies & Audit
Evaluate whether vulnerability management policies for third-party
libraries exist, whether secret management design is appropriate,
whether secret leakage prevention and permission control during
deployment are considered, and whether security audit logging design
for critical operations exists.

# --- 評価の姿勢（4項目） ---
# エージェントの視点・判断基準を明確化。3-4項目に制限。
## Evaluation Stance

- Actively identify security measures **not explicitly described**
  in the design document
- Provide recommendations appropriate to the scale and risk level
  of the design
- Explain not only "what" is dangerous but also "why"
- Propose specific and feasible countermeasures

# --- 出力ガイドライン ---
# [S3a: 出力形式簡素化] セクション名+説明のみ。テンプレートなし。
# 「whichever structure best communicates」でモデルの自律的構造選択を許容。
## Output Guidelines

Present your security evaluation findings in a clear, well-organized
manner. Organize your analysis logically—by severity, by evaluation
criterion, or by architectural component—whichever structure best
communicates the security risks identified.

Include the following information in your analysis:
- Detailed description of identified security issues
- Impact analysis explaining the potential consequences
- Specific, actionable countermeasures
- References to relevant sections of the design document

Prioritize critical and significant issues in your report. Ensure
that the most important security concerns are prominently featured.
```

### 4.2 より複雑な例: 2フェーズ分析パターン

より複雑な観点（一貫性、信頼性など）では、検出と報告を明示的に2フェーズに分離するパターンが有効。`consistency-design-reviewer.md` で使用されている構造:

```markdown
## Phase 1: Comprehensive Problem Detection

**Objective**: Identify all inconsistencies without concern for output
format or organization.

Read the entire design document and systematically detect problems
using multiple detection strategies:

### Detection Strategy 1: Structural Analysis & Pattern Extraction
[パターン抽出の具体的手順]

### Detection Strategy 2: Pattern-Based Detection
[パターンベースの検出手順]

### Detection Strategy 3: Cross-Reference Detection
[セクション間の整合性チェック]

### Detection Strategy 4: Gap-Based Detection
[欠落情報の影響評価]

### Detection Strategy 5: Exploratory Detection
[暗黙的パターン・エッジケースの探索]

**Phase 1 Output**: Create an unstructured, comprehensive list of all
problems detected. Focus on completeness over organization.

---

## Phase 2: Organization & Reporting

**Objective**: Take the comprehensive problem list from Phase 1 and
organize it into a clear, prioritized report.

### 2.1 Severity Classification
[重大→重要→中→軽微の4段階分類]

### 2.2 Evidence Collection
[各問題の根拠収集]

### 2.3 Final Report Assembly
[最終レポートの組み立て]
```

このパターンの効果:
- 検出と報告の分離 (M1b): +2.5pt (SD=0.0)
- 5つの検出戦略による網羅性確保
- Phase 1で完全性を優先し、Phase 2で整理することで早期フィルタリングを防止

### 4.3 アンチパターンチェックリスト活用例

`performance-design-reviewer.md` では、ドメイン固有のアンチパターンチェックリストを含めることで検出率を向上させている:

```markdown
## Common Performance Antipatterns to Detect

Check for the following typical performance antipatterns in the design:

**Data Access Antipatterns:**
- N+1 query problem (iterative queries in loops instead of batch fetching)
- Missing database indexes on frequently queried columns
- Unbounded queries without pagination or result limits

**Resource Management Antipatterns:**
- Missing connection pooling for databases/external services
- Synchronous I/O in high-throughput paths
- Missing timeout configurations for external calls

**Architectural Antipatterns:**
- Missing NFR specifications (SLA, latency targets, throughput requirements)
- Long-running operations blocking user-facing requests

**Scalability Antipatterns:**
- Stateful designs preventing horizontal scaling
- Missing data lifecycle management (archival, retention policies)
```

このパターンの効果:
- ドメイン固有チェックリスト (N1): +2.0〜+3.0pt
- 4カテゴリに分類（3-4領域が最適、それ以上は逓減）
- 各項目は括弧書きで具体例を付記し、検出方向を明確化

---

## 5. 設計原則のまとめ

実験結果から導出された、エージェントプロンプト設計の7つの原則。

### 原則1: 英語で書く
全観点で+1.5pt以上の効果と完全な安定性 (SD=0.0)。技術用語の意味解釈がLLMの事前学習データと整合する。

### 原則2: 構造で網羅性を保証する
テーブル/マトリクス構造はコンポーネント×評価軸の網羅的カバレッジを強制し、+2.5〜+3.0pt。暗黙的な「漏れなく確認せよ」より明示的構造が効果的。

### 原則3: 「評価」ではなく「検出」を指示する
「問題を検出し出力に反映せよ」のフレーミングが効果的。「評価」「採点」の指示は探索的思考を抑制し-0.5〜-2.5pt。

### 原則4: 出力形式は最小限にする
詳細テンプレートは分析能力を阻害する。セクション名+1行説明で十分。モデルの自律的な構造選択を許容する。

### 原則5: 制約は少なく、方向性は明確に
厳格なカテゴリ分類 (-4.25pt)、スコープ境界制約 (-4.25pt) は逆効果。代わりに「何を見つけるべきか」の方向性を示す。

### 原則6: Few-shotは慎重に
1-2例で+2.87pt、4例以上で-3.75ptのリスク。探索的タスクでは避ける。使う場合は異なる難易度・カテゴリをカバーし、出力フォーマットに完全準拠させる。

### 原則7: チェックリストには閾値がある
ドメイン固有チェックリストは3-4領域まで効果的。検出ヒント数も2が最適で、4以上は満足バイアスを引き起こし逆効果 (-2.75pt)。
