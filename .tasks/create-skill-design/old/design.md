# skill_design 設計書

## 概要

Claude Code スキルを AI 主導で設計するスキル。対話的要件定義 → 評価基準策定 → 複数案生成 → 攻撃者議論 → 実装 → テスト → 改善のサイクルを、セッション分離＋ファイルベース引き継ぎで実行する。

## 設計判断と根拠

### D1: セッション分離単位の設計

**決定**: 3つのコマンドに分離する。

| コマンド | 対応セッション | 内容 |
|---------|-------------|------|
| `/skill_design` | セッション1 | スキル定義（要件→評価基準→案出し→選定→攻撃者議論） |
| `/skill_design_impl` | セッション2 | 初回実装・テスト・失敗分析 |
| `/skill_design_improve` | セッション3+ | 改善ラウンド（繰り返し可能） |

**根拠**:
- 参考設計書のセッション分離原則に従い、コンテキストウィンドウの圧迫を防止する
- 単一スキル内でのセッション分岐（「前回の続きか新規か」の判定）は状態管理が複雑になる
- 既存スキルの粒度と一致する（`requirement_elicit` → `requirement_define` → `arch_design` の分離パターン）
- 各コマンドは作業ディレクトリのファイル有無で前提条件を検証できる

**代替案**: 単一スキル `/skill_design` で resume フラグにより分岐
- 却下理由: Phase 0A〜3 と Phase 4〜6 では必要なツール・コンテキスト・対話パターンが大きく異なる。単一スキルにすると SKILL.md が肥大化し、各セッションで不要な定義がコンテキストを消費する

### D2: フル版/軽量版の実現方式

**決定**: `/skill_design` に `--light` フラグを設け、フラグに応じてフェーズをスキップ・圧縮する。`/skill_design_impl` と `/skill_design_improve` は軽量版では使用しない（`/skill_design --light` が1セッションで完結する）。

**根拠**:
- 参考設計書の運用バリエーション（フル版/軽量版）を忠実に実装
- 軽量版は1セッション完結のため、セッション分離が不要
- フラグ方式により、スキルファイルの重複を防ぐ

**軽量版で省略/圧縮されるフェーズ**:
| フル版フェーズ | 軽量版での扱い |
|-------------|-------------|
| Phase 0A: 対話的要件定義（4ステップ、各2-3往復） | 1往復に圧縮（「目的・成功イメージ・最も避けたい失敗の3点を教えてください」） |
| Phase 0B: 評価基準・テストケース生成 | 維持（ただし自己点検ステップを省略） |
| Phase 1: 案出し（3案） | 維持（AIが簡易比較表を出力） |
| Phase 2: 人間が2案に選定 | 人間が1案を直接選定 |
| Phase 3: 攻撃者議論 | 省略 |
| Phase 4: 実装 | Phase 2 直後に実行 |
| Phase 5: テスト・評価 | 維持（人間が確認） |
| Phase 6: 失敗分析 | 省略（改善ラウンドなし） |

### D3: 評価基準の二段階策定

**決定**: Phase 0B で AI が帰納的に基準原案を生成した後、AI 自身に「抜けている観点はないか」を問い直す自己点検ステップを設ける。

**根拠**:
- 参考設計書の「自己評価バイアスの多層的補正」原則に従う
- AI は文章の流暢さなど自分が得意な軸に偏り、ドメイン固有の正確性を見落とす傾向がある
- 二段階にすることで、1回目の出力を批判的に再検討する機会を構造的に作る
- 人間の承認ステップと組み合わせることで、バイアス補正の確度を上げる

### D4: 攻撃者議論のサブエージェント構成

**決定**: 攻撃者・擁護者・判定者の3ロールを、サブエージェントとしてシーケンシャルに実行する。

```
攻撃者A（Task/sonnet）→ A案の弱点3点を出力（ファイル保存）
擁護者A（Task/sonnet）→ 弱点への反論を出力（ファイル保存）
攻撃者B（Task/sonnet）→ B案の弱点3点を出力（ファイル保存）
擁護者B（Task/sonnet）→ 弱点への反論を出力（ファイル保存）
判定者（Task/sonnet）→ 統合・推奨を出力（ファイル保存）
```

**根拠**:
- 攻撃者A/B は並列実行可能（互いに独立）
- 擁護者は対応する攻撃者の出力に依存するため、攻撃者→擁護者はシーケンシャル
- 判定者は全ロールの出力に依存するため、最後に実行
- 各ロールの出力はファイル経由で受け渡し（親コンテキスト中継パターンを回避）

**実行順の最適化**:
```
[攻撃者A, 攻撃者B] → 並列
[擁護者A, 擁護者B] → 並列（各攻撃者完了後）
[判定者] → シーケンシャル
```

### D5: テスト実行の設計

**決定**: テストケースごとにサブエージェントを起動し、スキル本体を「プロンプト」として入力し、テストケースの入力に対する出力を生成させる。評価は別のサブエージェントが行う。

**根拠**:
- スキルのテスト = 「スキル定義をプロンプトとして与えた場合の出力品質を測定する」
- 生成と評価を分離することで、自己評価バイアスを構造的に防止する
- テストケース間は独立のため並列実行可能

### D6: 比較評価方式（改善ラウンド）

**決定**: R2以降は、同一テストケースに対する前ラウンドの出力と今ラウンドの出力を並べて比較判定する。加えて最低品質ライン（各基準で○点以上）も併用する。

**根拠**:
- 参考設計書の「差分の検出によるより正確な評価」原則に従う
- 単独出力への絶対評価は AI が甘くなるバイアスがある
- 比較評価のみだと絶対的な品質水準がわからなくなるため、最低品質ラインを併用

### D7: テンプレート/リファレンス分離

**決定**: 以下の分離方針に従う。

| 種別 | 配置 | 用途 |
|------|------|------|
| references/ | 定義・基準（読み取り専用） | 評価ルーブリック、出力テンプレート |
| templates/ | サブエージェント実行指示 | 攻撃者/擁護者/判定者プロンプト、テスト実行指示、評価指示、失敗分析指示 |

**根拠**: 既存スキル（adr_create, arch_design, agent_audit_reviewer）の分離パターンと一致

---

## アーキテクチャ

### ファイル構成

```
.claude/skills/skill_design/
  SKILL.md                    # /skill_design コマンド（セッション1: スキル定義）
  references/
    evaluation-rubric.md      # 評価ルーブリックのフォーマット定義
    output-schemas.md         # 各中間ファイルのスキーマ定義
  templates/
    generate-candidates.md    # Phase 1: 案出し サブエージェント指示
    attacker.md               # Phase 3: 攻撃者ロール指示
    defender.md               # Phase 3: 擁護者ロール指示
    judge.md                  # Phase 3: 判定者ロール指示

.claude/skills/skill_design_impl/
  SKILL.md                    # /skill_design_impl コマンド（セッション2: 実装・テスト）
  templates/
    implement-skill.md        # Phase 4: 実装サブエージェント指示
    run-test.md               # Phase 5: テスト実行サブエージェント指示
    evaluate-output.md        # Phase 5: 評価サブエージェント指示
    analyze-failures.md       # Phase 6: 失敗分析サブエージェント指示

.claude/skills/skill_design_improve/
  SKILL.md                    # /skill_design_improve コマンド（セッション3+: 改善ラウンド）
  templates/
    improve-skill.md          # 改善実装サブエージェント指示
    compare-evaluate.md       # 比較評価サブエージェント指示
```

### 作業ディレクトリ構造

```
.skill_output/skill_design/{skill_slug}/
  requirements.md             # Phase 0A 出力: 要件定義
  evaluation.md               # Phase 0B 出力: 評価基準・テストケース
  candidates.md               # Phase 1-3 出力: 案の比較・攻撃者議論・推奨案・実装方針
  skill.md                    # Phase 4 出力: スキル本体（実装後）
  test-results-r1.md          # Phase 5 出力: テスト結果・スコア（ラウンド1）
  test-results-r2.md          # Phase 5 出力: テスト結果・スコア（ラウンド2、累積）
  improvements-r1.md          # Phase 6 出力: 失敗分析・改善提案
  improvements-r2.md          # 改善ラウンドN の失敗分析・改善提案
  work/                       # サブエージェントの中間ファイル
    attacker-a.md
    defender-a.md
    attacker-b.md
    defender-b.md
    judge.md
    test-output-tc{N}.md      # テスト実行の出力
    eval-tc{N}.md             # 評価結果
```

### データフロー

```
セッション1 (/skill_design)
  ユーザー対話 → requirements.md
  requirements.md → evaluation.md
  evaluation.md → [3案生成] → candidates.md (Phase 1)
  ユーザー選定 → candidates.md 更新 (Phase 2)
  candidates.md → [攻撃者議論] → candidates.md 更新 (Phase 3)

セッション2 (/skill_design_impl)
  candidates.md 読込 → [実装] → skill.md (Phase 4)
  evaluation.md + skill.md → [テスト] → test-results-r1.md (Phase 5)
  test-results-r1.md → [失敗分析] → improvements-r1.md (Phase 6)

セッション3+ (/skill_design_improve)
  improvements-rN.md + skill.md → [改善実装] → skill.md 更新
  evaluation.md + skill.md → [テスト] → test-results-r{N+1}.md
  test-results-r{N+1}.md → [失敗分析] → improvements-r{N+1}.md
```

---

## /skill_design ワークフロー詳細

Phase 0A（対話的要件定義）→ 0B（評価基準・テストケース生成）→ 1（案出し）→ 2（人間選定）→ 3（攻撃者議論＋判定）→ 出力

### Phase 0A: 対話的要件定義

**目的**: スキルの目的・利用文脈・品質基準を、人間と AI の構造化された対話で明確にする

**軽量版の場合**: 1往復に圧縮。「目的・成功イメージ・最も避けたい失敗の3点を教えてください」と質問し、回答を基に要件を構造化。Step 4 へ直接進む。

#### Step 1: 目的と利用文脈の確認

ユーザーに以下を質問する:
- 「このスキルは誰が、どんな場面で、何のために使いますか？」

AI は回答の不明点を質問する。2-3往復を上限とする。

#### Step 2: 成功・失敗イメージの具体化

ユーザーに以下を質問する:
- 「理想的な出力はどんなものですか？具体的に教えてください」
- 「絶対に避けたい失敗はどんなものですか？」

ここで出た成功・失敗の具体例は、Phase 0B の評価基準を帰納的に導出するための素材となる。

#### Step 3: 優先順位の確認

Phase 0A の回答から想定されるトレードオフを AI が提示し、人間の価値判断を明示化する。

例: 「正確性と読みやすさが衝突したらどちらを優先しますか？」「網羅性と簡潔さではどちらが重要ですか？」

#### Step 4: 要件の整理と確認

対話で出た内容を AI が以下の形式で構造化して提示する:

```
### Phase 0A サマリ
- **目的**: {スキルの目的}
- **利用者**: {誰が使うか}
- **利用文脈**: {どんな場面で}
- **成功イメージ**: {理想的な出力の具体例}
- **失敗イメージ**: {避けたい失敗の具体例}
- **優先順位**: {トレードオフ判断}

修正があればお知らせください。問題なければ「ok」と回答してください。
```

承認後、`{work_dir}/requirements.md` に Write で保存する。

### Phase 0B: 評価基準・テストケース生成

**目的**: Phase 0A の要件を入力として、評価基準とテストケースを生成する

**軽量版の場合**: 自己点検ステップ（Step 2）を省略。

#### Step 1: 評価基準の原案生成

Phase 0A の成功・失敗イメージから帰納的に評価基準の原案を生成する:

1. 成功イメージから「達成すべき品質属性」を抽出する
2. 失敗イメージから「回避すべき品質欠陥」を抽出する
3. 各品質属性/欠陥に対して、ルーブリック形式（1-5点、各レベルの具体例付き）で基準を定義する

正解のない領域（文章のトーン調整、創造的タスクなど）では、各レベルの境界を具体例で明確にする。

#### Step 2: 自己点検（バイアス補正）

生成した評価基準に対して、AI 自身に以下を問い直す:
- 「この評価基準で抜けている観点はないか？」
- 「AI が得意な軸（流暢さ、形式的正しさ）に偏っていないか？」
- 「ドメイン固有の正確性や実用性の観点は十分か？」

追加すべき基準があれば原案に追加する。

#### Step 3: テストケースの設計

評価基準に基づき、以下の種別でテストケースを設計する:
- **正常系**: 典型的な入力パターン
- **異常系**: 不正・不完全な入力パターン
- **境界値**: 基準の境界を突くパターン

各テストケースには以下を定義する:
- テストケースID（TC-01, TC-02, ...）
- 入力（スキルに与えるシナリオ・コンテキスト）
- 期待される出力の品質属性（どの評価基準でどのレベル以上を期待するか）

設計後、AI に「このテストケース群でカバーできていないシナリオは何か」を自己点検させる。

#### Step 4: ユーザー確認

評価基準とテストケースをユーザーに提示する:

```
### 評価基準（{N}項目）

| # | 基準名 | 説明 | 最低品質ライン |
|---|-------|------|-------------|
| E-1 | {基準名} | {説明} | {N}/5 |

### テストケース（{N}件）

| # | 種別 | 入力概要 | 検証する基準 |
|---|------|---------|------------|
| TC-01 | 正常系 | {概要} | E-1, E-3 |

修正があればお知らせください。問題なければ「ok」と回答してください。
```

承認後、`{work_dir}/evaluation.md` に Write で保存する。

### Phase 1: 案出し

**目的**: AI が3案を生成する。うち少なくとも1案は根本的に異なるアプローチとする

#### Step 1: 候補生成（サブエージェントに委譲）

Task（sonnet）で候補生成サブエージェントを起動:

```
`{skill_dir}/templates/generate-candidates.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
```

サブエージェントは `{work_dir}/work/candidates-raw.md` に3案を保存し、件数サマリーを返す。

#### Step 2: ユーザーへの提示

`{work_dir}/work/candidates-raw.md` を Read し、各案の概要・アプローチ・根本的な違いをユーザーに提示する。

```
### 案A: {名前}
{概要}

### 案B: {名前}
{概要}

### 案C: {名前}
{概要}
※ この案は他の案と {差異の説明} の点で根本的に異なります

Phase 2 で有望な案を2案に絞ります。
```

### Phase 2: 人間による選定

**目的**: 人間が有望な案を2案に絞る

**軽量版の場合**: 1案を直接選定。Phase 3 をスキップし、選定案で Phase 4（実装）に進む。

#### Step 1: 選定

AskUserQuestion で2案を選定させる:
- 選択肢: 案A, 案B, 案C（multiSelect: true, 2件選択を求める）

`{selected_candidates}` を記録する。

### Phase 3: 攻撃者議論＋判定

**目的**: 各案の弱点を攻撃者ロールが洗い出し、判定者が統合・推奨を出す

**軽量版の場合**: 省略。

#### Step 1: 攻撃者（並列実行）

2つの Task（sonnet）を並列に起動する:

```
`{skill_dir}/templates/attacker.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {target_candidate}: {A or B}
- {evaluation_path}: {work_dir}/evaluation.md
- {candidates_path}: {work_dir}/work/candidates-raw.md
- {output_path}: {work_dir}/work/attacker-{a or b}.md
```

各サブエージェントは攻撃結果をファイルに保存し、件数サマリーを返す。

#### Step 2: 擁護者（並列実行）

2つの Task（sonnet）を並列に起動する:

```
`{skill_dir}/templates/defender.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {target_candidate}: {A or B}
- {attack_path}: {work_dir}/work/attacker-{a or b}.md
- {candidates_path}: {work_dir}/work/candidates-raw.md
- {output_path}: {work_dir}/work/defender-{a or b}.md
```

#### Step 3: 判定者

Task（sonnet）を起動する:

```
`{skill_dir}/templates/judge.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {attacker_a_path}: {work_dir}/work/attacker-a.md
- {defender_a_path}: {work_dir}/work/defender-a.md
- {attacker_b_path}: {work_dir}/work/attacker-b.md
- {defender_b_path}: {work_dir}/work/defender-b.md
- {evaluation_path}: {work_dir}/evaluation.md
- {output_path}: {work_dir}/work/judge.md
```

判定者は以下を出力する:
1. 各案の「防御しきれなかった弱点」の整理
2. 統合案の検討
3. 推奨の明示（A案/B案/統合案）と理由
4. 実装方針の指針

#### Step 4: 結果のユーザー提示

判定者の出力をユーザーに提示し、推奨に同意するか確認する。

#### Step 5: candidates.md の生成

Phase 1-3 の全結果を統合して `{work_dir}/candidates.md` に Write で保存する。

### 完了出力

```
## skill_design 完了
- 要件定義: {work_dir}/requirements.md
- 評価基準: {work_dir}/evaluation.md（基準 {N}項目、テストケース {M}件）
- 候補比較: {work_dir}/candidates.md（推奨: {推奨案名}）

次のステップ: `/skill_design_impl` で実装・テストに進んでください。
```

---

## /skill_design_impl ワークフロー詳細

Phase 4（実装）→ 5（テスト実行・評価）→ 6（失敗分析・改善提案）

### Phase 4: 実装

**目的**: candidates.md の推奨案＋実装方針に基づきスキルを実装する

#### Step 1: 入力検証

以下のファイルの存在を確認する:
- `{work_dir}/requirements.md`
- `{work_dir}/evaluation.md`
- `{work_dir}/candidates.md`

不在の場合: 「先に `/skill_design` を実行してください」と出力して終了。

#### Step 2: 実装（サブエージェントに委譲）

Task（sonnet）で実装サブエージェントを起動:

```
`{skill_dir}/templates/implement-skill.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {requirements_path}: {work_dir}/requirements.md
- {candidates_path}: {work_dir}/candidates.md
- {output_path}: {work_dir}/skill.md
```

サブエージェントは `{work_dir}/skill.md` にスキル本体を Write で保存する。

#### Step 3: ユーザー確認

実装結果をユーザーに提示し、修正があれば反映する。

### Phase 5: テスト実行・評価

**目的**: evaluation.md のテストケースに基づきスキルをテストし、評価基準に沿ってスコアリングする

#### Step 1: テスト実行（並列）

evaluation.md の各テストケースについて Task（sonnet）を並列に起動:

```
`{skill_dir}/templates/run-test.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {skill_path}: {work_dir}/skill.md
- {test_case_id}: TC-{N}
- {test_input}: {テストケースの入力}
- {output_path}: {work_dir}/work/test-output-tc{N}.md
```

#### Step 2: 評価（並列）

各テスト出力について Task（sonnet）を並列に起動:

```
`{skill_dir}/templates/evaluate-output.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {evaluation_path}: {work_dir}/evaluation.md
- {test_output_path}: {work_dir}/work/test-output-tc{N}.md
- {test_case_id}: TC-{N}
- {output_path}: {work_dir}/work/eval-tc{N}.md
```

#### Step 3: 結果集約

各評価結果を集約して `{work_dir}/test-results-r1.md` に Write で保存する。

#### Step 4: 人間によるスコアリング校正

**初回は必須**。テスト結果をユーザーに提示し、AI のスコアリングの粒度・甘辛を確認する:

```
### テスト結果（ラウンド1）

| TC | E-1 | E-2 | E-3 | 総合 |
|----|-----|-----|-----|------|
| TC-01 | 4/5 | 3/5 | 5/5 | 4.0 |
| TC-02 | 2/5 | 4/5 | 3/5 | 3.0 |

以下の点を確認してください:
1. スコアリングの甘辛は適切ですか？
2. 評価基準自体に追加・修正は必要ですか？

校正指示があればお知らせください。問題なければ「ok」と回答してください。
```

校正結果を反映して `test-results-r1.md` と必要に応じて `evaluation.md` を更新する。

### Phase 6: 失敗分析・改善提案

**目的**: 低評価テストケースの原因分析に基づく改善提案を出す

#### Step 1: 失敗分析（サブエージェントに委譲）

最低品質ライン未達のテストケースを入力として Task（sonnet）を起動:

```
`{skill_dir}/templates/analyze-failures.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {test_results_path}: {work_dir}/test-results-r1.md
- {skill_path}: {work_dir}/skill.md
- {evaluation_path}: {work_dir}/evaluation.md
- {output_path}: {work_dir}/improvements-r1.md
```

サブエージェントは以下を出力する:
1. 低評価テストケースの出力と期待との差分
2. 差分の原因仮説
3. 原因仮説ごとの改善案
4. 各改善案を「微調整/再設計」に分類

#### Step 2: ユーザーへの提示

失敗分析結果をユーザーに提示する。

### 完了出力

```
## skill_design_impl 完了
- スキル本体: {work_dir}/skill.md
- テスト結果: {work_dir}/test-results-r1.md
- 改善提案: {work_dir}/improvements-r1.md

次のステップ:
- 改善が必要な場合: `/skill_design_improve` で改善ラウンドに進んでください
- 完了の場合: {work_dir}/skill.md をスキルディレクトリにデプロイしてください
```

---

## /skill_design_improve ワークフロー詳細

改善実装 → テスト実行・比較評価 → 失敗分析・改善提案

### 初期化

#### Step 1: 入力検証

以下のファイルの存在を確認する:
- `{work_dir}/skill.md`
- `{work_dir}/evaluation.md`
- `{work_dir}/test-results-r{latest}.md`（最新のラウンドを自動検出）
- `{work_dir}/improvements-r{latest}.md`

不在の場合: 「先に `/skill_design_impl` を実行してください」と出力して終了。

#### Step 2: ラウンド番号の決定

`{work_dir}/test-results-r*.md` をスキャンし、最新ラウンド番号 + 1 を `{current_round}` とする。

#### Step 3: 改善方向性の確認

前ラウンドの `improvements-r{N}.md` をユーザーに提示し、方向性を選択させる:

AskUserQuestion:
- 「どの改善案を採用しますか？」
- 選択肢: improvements-r{N}.md 内の各改善案（微調整案/再設計案）

### 改善実装

Task（sonnet）で改善実装サブエージェントを起動:

```
`{skill_dir}/templates/improve-skill.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {skill_path}: {work_dir}/skill.md
- {improvement_path}: {work_dir}/improvements-r{N}.md
- {selected_improvements}: {ユーザーが選択した改善案のID}
```

サブエージェントは `{work_dir}/skill.md` を更新する。

### テスト実行・比較評価

Phase 5 と同様にテスト実行後、比較評価を行う:

Task（sonnet）で比較評価サブエージェントを起動:

```
`{skill_dir}/templates/compare-evaluate.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- {work_dir}: {値}
- {skill_dir}: {値}
- {evaluation_path}: {work_dir}/evaluation.md
- {prev_results_path}: {work_dir}/test-results-r{N}.md
- {current_round}: {N+1}
```

比較評価は以下を出力する:
- 各テストケースの「前ラウンド vs 今ラウンド」判定
- 改善された基準/悪化した基準
- スコア推移テーブル（全ラウンド累積）

### 失敗分析・改善提案

Phase 6 と同様の手順で `improvements-r{N+1}.md` を生成する。

### 完了出力

```
## skill_design_improve 完了（ラウンド {N+1}）
- スキル本体: {work_dir}/skill.md（更新済み）
- テスト結果: {work_dir}/test-results-r{N+1}.md
- 改善提案: {work_dir}/improvements-r{N+1}.md
- スコア推移: {推移サマリ}

次のステップ:
- さらに改善する場合: `/skill_design_improve` を再実行してください
- 完了の場合: {work_dir}/skill.md をスキルディレクトリにデプロイしてください
```

---

## 人間の関与ポイント

| タイミング | 関与内容 | 必須/任意 |
|-----------|---------|----------|
| Phase 0A | 対話的要件定義への参加 | 必須 |
| Phase 0B Step 4 | 評価基準・テストケースの承認 | 必須 |
| Phase 2 | 案の選定 | 必須 |
| Phase 3 Step 4 | 攻撃者議論の結果・推奨の確認 | 必須 |
| セッション1→2の間 | 出力ファイルの確認 | 必須 |
| Phase 5 Step 4（初回） | スコアリングの校正 | 必須 |
| 改善ラウンド開始判断 | test-results/improvements を見て判断 | 必須 |
| 改善方向性の選択 | 微調整/再設計の選択 | 必須 |
| Phase 5（2回目以降） | 比較評価結果の確認 | 任意 |

---

## コンテキスト節約の原則

1. **参照ファイルは使用する Phase でのみ読み込む**（先読みしない）
2. **大量コンテンツの生成はサブエージェントに委譲する**（Phase 1, 3, 4, 5, 6）
3. **サブエージェントからの返答は最小限にする**（詳細はファイルに保存させる）
4. **親コンテキストには要約・メタデータのみ保持する**
5. **サブエージェント間のデータ受け渡しはファイル経由で行う**（親を中継しない）

---

## エラーハンドリング

- **サブエージェント失敗**: エラー内容をユーザーに提示し、AskUserQuestion で「リトライ」/「中止」を選択させる。リトライは1回のみ。2回目の失敗でスキル終了
- **評価基準の不足**: テスト実行中に評価基準でカバーされないケースが判明した場合、evaluation.md への追加を提案する
- **改善ラウンドの発散**: 3ラウンド連続でスコアが改善しない場合、「アプローチ自体の限界の可能性があります。要件定義からやり直しますか？」とユーザーに提案する
