# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | パス変数セクションの追加、グループ抽出エラーハンドリング、findings抽出ロジック明示、Phase 1インライン指示削除、Phase 2インライン指示削除、冪等性確保手順追加、dim_summaries活用最適化、前回比較機能追加 | I-2, I-4, I-5, I-6, I-1, I-3, I-8, I-9 |
| 2 | templates/apply-improvements.md | 修正 | パス変数のプレースホルダ削除（SKILL.mdで定義済みのため不要） | I-2 |
| 3 | agents/shared/analysis-framework.md | 修正 | 返答フォーマットセクションの追加 | I-6 |
| 4 | agents/evaluator/criteria-effectiveness.md | 修正 | analysis-framework.mdへの参照削除（親が要約提供） | I-7 |
| 5 | agents/evaluator/scope-alignment.md | 修正 | analysis-framework.mdへの参照削除（親が要約提供） | I-7 |
| 6 | agents/evaluator/detection-coverage.md | 修正 | analysis-framework.mdへの参照削除（親が要約提供） | I-7 |
| 7 | agents/producer/workflow-completeness.md | 修正 | analysis-framework.mdへの参照削除（親が要約提供） | I-7 |
| 8 | agents/producer/output-format.md | 修正 | analysis-framework.mdへの参照削除（親が要約提供） | I-7 |
| 9 | agents/shared/instruction-clarity.md | 修正 | analysis-framework.mdへの参照削除（親が要約提供） | I-7 |
| 10 | agents/unclassified/scope-alignment.md | 修正 | analysis-framework.mdへの参照削除（親が要約提供） | I-7 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: I-2（パス変数未定義）, I-4（グループ抽出未定義）, I-5（findings抽出未定義）, I-6（Phase 1インライン指示）, I-1（Phase 2インライン指示）, I-3（冪等性確保）, I-8（findings抽出冗長性）, I-9（前回比較未実装）

**変更内容**:

#### 変更1: パス変数セクションの追加（I-2対応）
- 挿入位置: `## コンテキスト節約の原則` の直前（行26付近）
- 内容:
```markdown
## パス変数

以下のパス変数が各フェーズで使用されます:
- `{agent_path}`: 分析対象エージェント定義ファイルの絶対パス（引数から取得）
- `{agent_name}`: エージェント名（.claude/配下は.claude/からの相対パス、それ以外はcwdからの相対パス、拡張子除去）
- `{agent_group}`: エージェントグループ（hybrid/evaluator/producer/unclassified）
- `{dim_path}`: 次元エージェントの相対パス（例: evaluator/criteria-effectiveness）
- `{ID_PREFIX}`: 次元のFinding ID Prefix（CE/IC/SA/DC/WC/OF）
- `{findings_save_path}`: .agent_audit/{agent_name}/audit-{ID_PREFIX}.md の絶対パス
- `{approved_findings_path}`: .agent_audit/{agent_name}/audit-approved.md の絶対パス
- `{previous_approved_path}`: .agent_audit/{agent_name}/audit-approved.md の絶対パス
- `{backup_path}`: {agent_path}.backup-YYYYmmdd-HHMMSS の絶対パス
```

#### 変更2: グループ抽出エラーハンドリング（I-4対応）
- 対象: Phase 0 Step 4（行69-75）
- 現在の記述: 「サブエージェント完了後、返答から `{agent_group}` を抽出する。」のみ
- 改善後の記述:
```markdown
サブエージェント完了後、返答から `{agent_group}` を以下の方法で抽出する:
- 返答内に `group: {value}` の形式で記載された行を探す
- `{value}` が `hybrid`, `evaluator`, `producer`, `unclassified` のいずれかであることを確認
- 抽出失敗時（形式不一致、不正な値、複数行存在）は、`{agent_group} = "unclassified"` をデフォルト値として使用し、警告を表示: 「⚠ グループ分類結果の抽出に失敗しました。デフォルト値 "unclassified" を使用します。」
```

#### 変更3: Phase 0 Step 6 冪等性確保手順（I-3対応）
- 対象: Phase 0 Step 6（行84）
- 現在の記述: 「既に存在する場合、既存の findings ファイルが上書きされる可能性があることに注意」
- 改善後の記述:
```markdown
6. 出力ディレクトリの作成（冪等性確保）:
   - タイムスタンプ付きサブディレクトリを使用: `.agent_audit/{agent_name}/run-$(date +%Y%m%d-%H%M%S)/`
   - Bash で以下を実行: `RUN_DIR=".agent_audit/{agent_name}/run-$(date +%Y%m%d-%H%M%S)" && mkdir -p "$RUN_DIR"`
   - `{run_dir}` = 作成したディレクトリパス（環境変数から取得）
   - findings ファイルの保存先は `{run_dir}/audit-{ID_PREFIX}.md` に変更
   - 注: `audit-approved.md` は `{run_dir}/` 直下ではなく `.agent_audit/{agent_name}/` 直下に保存（履歴管理のため最新版のみ保持）
```

#### 変更4: Phase 1 共通フレームワーク要約の追加（I-7対応）
- 挿入位置: Phase 1 テキスト出力の直後（行117付近）
- 内容:
```markdown
**共通フレームワーク要約の準備**:
1. Read で `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` を読み込む
2. 以下の要約を抽出（各次元エージェントに渡す）:
   - 2段階分析プロセス（Phase 1: 包括的問題検出、Phase 2: 整理と報告）
   - Severity 分類基準（critical/improvement/info）
   - Detection Strategies の概念
   - 敵対的思考（Adversarial Mindset）
```

#### 変更5: Phase 1 インライン指示の削除とテンプレート参照への変更（I-6対応）
- 対象: Phase 1 Task prompt（行122-127）
- 現在の記述: 8行のインライン指示
- 改善後の記述:
```markdown
各次元について、以下の Task prompt を使用する:

> `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
>
> パス変数:
> - `{agent_path}`: {実際の agent_path の絶対パス}
> - `{agent_name}`: {実際の agent_name}
> - `{previous_approved_path}`: {実際の .agent_audit/{agent_name}/audit-approved.md の絶対パス}（存在しない場合は空とみなす）
> - `{findings_save_path}`: {実際の .agent_audit/{agent_name}/run-YYYYMMDD-HHMMSS/audit-{ID_PREFIX}.md の絶対パス}
>
> 共通フレームワーク要約:
> {analysis-framework.md から抽出した要約テキストをここに展開}
```

#### 変更6: Phase 2 Step 1 findings抽出ロジックの明示（I-5対応）
- 対象: Phase 2 Step 1（行155-158）
- 現在の記述: 「各ファイルから severity が critical または improvement の finding（`###` ブロック単位）を抽出し、critical → improvement の順にソートする。」
- 改善後の記述:
```markdown
#### Step 1: Findings の収集

Phase 1 で成功した全次元の findings ファイル（`.agent_audit/{agent_name}/run-YYYYMMDD-HHMMSS/audit-{ID_PREFIX}.md`）を Read する。

各ファイルから以下の方法で finding を抽出する:
1. `### {ID}: {title} [{severity}]` 形式の行をブロック開始マーカーとして検出
2. 次の `###` 行または `##` 行までをブロックとして抽出
3. ブロック内の必須フィールド（`- 内容:`, `- 根拠:`, `- 推奨:`）を抽出
4. 必須フィールドが1つでも欠落している場合、その finding はスキップし、警告を表示: 「⚠ {ファイル名} の {ID} は必須フィールドが欠落しているためスキップしました。」
5. severity が `critical` または `improvement` の finding のみを対象とする
6. 抽出した findings を severity 順（critical → improvement）にソートする

`{total}` = 対象 finding の合計件数（critical と improvement の件数は抽出結果から集計）
```

#### 変更7: Phase 2 Step 1 冗長性の削減（I-8対応）
- 対象: Phase 2 Step 1（行158）
- 現在の記述: 「`{total}` = 対象 finding の合計件数。critical と improvement の件数は `{dim_summaries}` から集計する。」
- 改善後の記述（上記変更6と統合済み）: 「`{total}` = 対象 finding の合計件数（critical と improvement の件数は抽出結果から集計）」
- 注: dim_summaries からの件数取得は削除（抽出ロジック明示により冗長）

#### 変更8: Phase 2 Step 4 インライン指示の削除とテンプレート参照への変更（I-1対応）
- 対象: Phase 2 Step 4（行231-261）
- 現在の記述: 29行のインライン指示
- 改善後の記述:
```markdown
#### Step 4: 改善適用（サブエージェントに委譲）

テキスト出力: `改善を適用しています...`

**バックアップ作成**: 改善適用前に Bash で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、`{backup_path}` を記録する。バックアップ作成後、`test -f {backup_path}` で存在確認を行う。ファイルが存在しない場合、「✗ バックアップ作成に失敗しました。改善適用を中止します。」とエラー出力し、Phase 3 へ直行する。

**最終確認**: 改善適用前に AskUserQuestion で最終確認を行う。選択肢: "Proceed"（続行）、"Cancel"（キャンセル）。キャンセル選択時は Phase 3 へ直行する。

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

> `.claude/skills/agent_audit_new/templates/apply-improvements.md` を Read し、その指示に従って改善を適用してください。
>
> パス変数:
> - `{agent_path}`: {実際の agent_path の絶対パス}
> - `{approved_findings_path}`: {実際の .agent_audit/{agent_name}/audit-approved.md の絶対パス}

サブエージェント完了後、返答内容（変更サマリ）をテキスト出力する。
```

#### 変更9: Phase 3 前回比較機能の追加（I-9対応）
- 対象: Phase 3（行282-321）
- 挿入位置: バックアップ表示行の直後
- 内容:
```markdown
- 前回比較:
  - 前回承認数: {previous_approved_count}件
  - 今回承認数: {approved}件
  - 変化: {approved - previous_approved_count > 0 の場合 "増加", = 0 の場合 "変化なし", < 0 の場合 "減少"}
  - 解決済み指摘: {前回承認済みで今回検出されなかった finding ID のリスト}
  - 新規指摘: {今回承認済みで前回存在しなかった finding ID のリスト}
```

### 2. templates/apply-improvements.md（修正）
**対応フィードバック**: I-2（未定義プレースホルダ）

**変更内容**:
- 対象: パス変数セクション（行4-5）
- 削除内容: `{approved_findings_path}` と `{agent_path}` のプレースホルダ表記
- 理由: SKILL.md のパス変数セクションで定義済みのため、テンプレート内での再定義は不要

### 3. agents/shared/analysis-framework.md（修正）
**対応フィードバック**: I-6（Phase 1インライン指示のテンプレート化）

**変更内容**:
- 挿入位置: ファイル末尾
- 内容:
```markdown

## 返答フォーマット

分析完了後、以下のフォーマットで返答してください:
```
dim: {次元名}, critical: {N}, improvement: {M}, info: {K}
```

- `{次元名}`: この次元の名前（例: Criteria Effectiveness, Instruction Clarity）
- `{N}`: critical severity の finding 件数
- `{M}`: improvement severity の finding 件数
- `{K}`: info severity の finding 件数
```

### 4-10. 全次元エージェント（修正）
**対応フィードバック**: I-7（並列実行時の共通フレームワーク重複読み込み）

**対象ファイル**:
- agents/evaluator/criteria-effectiveness.md
- agents/evaluator/scope-alignment.md
- agents/evaluator/detection-coverage.md
- agents/producer/workflow-completeness.md
- agents/producer/output-format.md
- agents/shared/instruction-clarity.md
- agents/unclassified/scope-alignment.md

**変更内容**（全ファイル共通）:
- 対象: 行6付近の analysis-framework.md への参照行
- 現在の記述: `分析を開始する前に、`.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` を Read し、共通の分析フレームワークを確認してください。`
- 改善後の記述:
```markdown
## 共通フレームワーク

以下は全次元共通の分析フレームワークです（親エージェントから提供）:

{親エージェントが analysis-framework.md から抽出した要約がここに展開されます}
```

## 新規作成ファイル

なし

## 削除推奨ファイル

なし

## 実装順序

1. **SKILL.md（変更1: パス変数セクション追加）** — 他の変更の前提となる定義を先に配置
2. **templates/apply-improvements.md** — パス変数定義後、テンプレート側の重複を削除
3. **agents/shared/analysis-framework.md** — 返答フォーマットセクションを追加（Phase 1変更の前提）
4. **全次元エージェント（agents/配下の7ファイル）** — 並列実行可能（独立した変更）
5. **SKILL.md（変更2-9: 残りの変更）** — Phase 0, 1, 2, 3 の順に変更を適用

依存関係:
- 変更1（パス変数セクション）→ 変更2（テンプレート側の削除）: パス変数が SKILL.md で定義されていることを前提に、テンプレート側の重複を削除
- 変更3（analysis-framework.md）→ 変更4-10（次元エージェント）: 返答フォーマットセクションが存在することを前提に、次元エージェント側の参照方法を変更
- 変更3, 4-10 → 変更5（Phase 1インライン指示削除）: 次元エージェントに返答フォーマットが含まれることを前提に、SKILL.md のインライン指示を削除

## 注意事項
- SKILL.md の変更は行番号が大きく変動するため、変更1を先に適用し、その後の変更は新しい行番号に基づいて実施すること
- Phase 0 Step 6 の冪等性確保（変更3）により、findings ファイルのパスが `.agent_audit/{agent_name}/audit-*.md` から `.agent_audit/{agent_name}/run-YYYYMMDD-HHMMSS/audit-*.md` に変更されるため、Phase 1, 2 の該当箇所も同時に更新すること
- Phase 1 の共通フレームワーク要約（変更4）は、analysis-framework.md の全文ではなく、要点のみを抽出してサブエージェントに渡すこと（コンテキスト節約）
- Phase 3 の前回比較機能（変更9）は、`{previous_approved_count}` と `{previous_approved_path}` が Phase 0 Step 6a で既に取得されていることを前提とする
