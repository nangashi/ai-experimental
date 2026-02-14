# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 に ID_PREFIX マッピングテーブル追加、部分失敗継続判定を排他的分岐に修正、group-classification.md パス絶対パス化、findings 抽出境界検出ルール明示、バックアップパス完全化、エラーハンドリング強化、成功基準明示化、バリデーション警告具体化、部分失敗時の対処選択肢追加 | C-1, C-2, C-3, C-5, C-6, I-4, I-5, I-6, I-7, I-8, I-9 |
| 2 | templates/apply-improvements.md | 修正 | timestamp 変数を削除し backup_path の説明を完全パスに変更 | C-6 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）

#### 変更1: Phase 0 に ID_PREFIX マッピングテーブル追加（C-1）
**対応フィードバック**: effectiveness: Phase 2 Step 1 での findings ID プレフィックス抽出ロジックが未定義

**変更内容**:
- L92-100 の分析次元セット決定テーブル: カラムを追加して ID_PREFIX を含める
  ```markdown
  現在:
  | agent_group | dimensions（エージェントファイルパス） |

  改善後:
  | agent_group | dimensions（エージェントファイルパス） | ID_PREFIX |
  |-------------|--------------------------------------|-----------|
  | `hybrid` | `shared/instruction-clarity` | IC |
  | `hybrid` | `evaluator/criteria-effectiveness` | CE |
  | `hybrid` | `evaluator/scope-alignment` | SA |
  | `hybrid` | `producer/workflow-completeness` | WC |
  | `hybrid` | `producer/output-format` | OF |
  | `evaluator` | `shared/instruction-clarity` | IC |
  | `evaluator` | `evaluator/criteria-effectiveness` | CE |
  | `evaluator` | `evaluator/scope-alignment` | SA |
  | `evaluator` | `evaluator/detection-coverage` | DC |
  | `producer` | `shared/instruction-clarity` | IC |
  | `producer` | `producer/workflow-completeness` | WC |
  | `producer` | `producer/output-format` | OF |
  | `producer` | `unclassified/scope-alignment` | SA |
  | `unclassified` | `shared/instruction-clarity` | IC |
  | `unclassified` | `unclassified/scope-alignment` | SA |
  | `unclassified` | `producer/workflow-completeness` | WC |
  ```

#### 変更2: Phase 1 部分失敗継続判定を排他的分岐に修正（C-2）
**対応フィードバック**: stability: Phase 1 部分失敗時の継続判定ロジックに未定義ケースが存在

**変更内容**:
- L145-149: 継続/中止判定ロジックを排他的に修正
  ```markdown
  現在:
  部分失敗の場合: 以下の判定基準に従って処理を継続するか決定する:
  - **継続条件**: 成功した次元数 ≧ 1、かつ（IC 次元が成功 または 成功数 ≧ 2）
  - **中止条件**: 成功数が 0、または（IC 次元が失敗 かつ 成功数 = 1）
  中止条件に該当する場合: ...
  継続条件に該当する場合: ...

  改善後:
  部分失敗の場合: 以下の判定基準に従って処理を継続するか決定する:
  - **中止条件**: 成功数が 0、または（IC 次元が失敗 かつ 成功数 = 1）の場合: 「Phase 1: 必須次元の分析に失敗しました。処理を中止します。失敗理由:\n- {次元名}: {エラー概要}\n（各失敗次元を列挙）」とエラー出力して終了する
  - **継続条件**: 上記以外の全てのケース（成功数 ≧ 1、かつ（IC 次元が成功 または 成功数 ≧ 2））の場合: Phase 2 へ進む
  ```

#### 変更3: group-classification.md パス絶対パス化（C-3）
**対応フィードバック**: stability: group-classification.md の参照パスが相対パスで記述され解決方法が不明

**変更内容**:
- L75: 相対パスから完全パス指定に変更
  ```markdown
  現在:
  判定基準の詳細は `group-classification.md` を参照する。
  `group-classification.md` が存在しない場合: 「✗ エラー: group-classification.md が見つかりません。スキルの初期化に失敗しました。」とテキスト出力して終了する。

  改善後:
  判定基準の詳細は `.claude/skills/agent_audit_new/group-classification.md` を参照する。
  `.claude/skills/agent_audit_new/group-classification.md` が存在しない場合: 「✗ エラー: .claude/skills/agent_audit_new/group-classification.md が見つかりません。スキルの初期化に失敗しました。」とテキスト出力して終了する。
  ```

#### 変更4: Phase 1 既存 findings 検出ロジック強化（C-4）
**対応フィードバック**: stability: Phase 1 の既存 findings ファイル検出で部分失敗時の再実行動作が未定義

**変更内容**:
- L115: 既存ファイル検出時の処理を拡張
  ```markdown
  現在:
  Glob で既存 findings ファイル（`.agent_audit/{agent_name}/audit-*.md`）を検索する。既存ファイルが1つ以上存在する場合、「⚠ 既存の findings ファイル {N}件を上書きします」とテキスト出力する。

  改善後:
  Glob で既存 findings ファイル（`.agent_audit/{agent_name}/audit-*.md`）を検索する。既存ファイルが1つ以上存在する場合、今回の分析対象次元の ID_PREFIX と照合する:
  - 今回分析対象外の ID_PREFIX を持つファイルが存在する場合: 「⚠ 過去の分析結果 {N}件（{ID_PREFIX リスト}）を発見。これらは今回の分析対象外のため残します」とテキスト出力
  - 今回分析対象の ID_PREFIX を持つファイルが存在する場合: 「⚠ 既存の findings ファイル {M}件（{ID_PREFIX リスト}）を上書きします」とテキスト出力
  ```

#### 変更5: Phase 2 Step 1 findings 境界検出ルール明示（C-5）
**対応フィードバック**: stability: Phase 2 Step 1 の findings 抽出における finding の境界検出ルールが不明

**変更内容**:
- L173-174: findings 抽出の詳細ルールを明示
  ```markdown
  現在:
  Phase 1 で成功した全次元の findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を Read する。
  各ファイルから severity が critical または improvement の finding（`###` ブロック単位）を抽出し、critical → improvement の順にソートする。

  改善後:
  Phase 1 で成功した全次元の findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を Read する。
  各ファイルから severity が critical または improvement の finding を以下のルールで抽出する:
  - **境界検出**: `### {ID}-{N}:` で始まる行（見出しレベル3）から次の `###` または `##` が出現するまで、またはファイル末尾までを1つの finding ブロックとする
  - **severity 抽出**: ブロック内の `- severity: {value}` 行から抽出。`critical` または `improvement` のみを対象とする（`info` は除外）
  - **title 抽出**: 見出し行の `: ` 以降、`[` より前の部分（例: `### CE-1: 曖昧な基準の検出不足 [effectiveness]` → title は `曖昧な基準の検出不足`）
  - **次元名抽出**: 見出し行の `[` と `]` で囲まれた部分（例: `[effectiveness]` → 次元名は `effectiveness`）

  抽出した finding を critical → improvement の順にソートする。
  ```

#### 変更6: バックアップパス完全化（C-6）
**対応フィードバック**: stability: templates/apply-improvements.md で使用される変数 {timestamp} が未定義

**変更内容**:
- L209: バックアップパス生成を完全パスとして記録
  ```markdown
  現在:
  **バックアップ作成**: 改善適用前に Bash で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、`{backup_path}` を記録する。

  改善後:
  **バックアップ作成**: 改善適用前に Bash で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、生成された完全な絶対パスを `{backup_path}` として記録する（例: `/path/to/agent.md.backup-20260213-123456`）。
  ```

- L214-217: パス変数の説明を更新
  ```markdown
  現在:
  パス変数:
  - `{agent_path}`: {実際の agent_path の絶対パス}
  - `{approved_findings_path}`: {実際の .agent_audit/{agent_name}/audit-approved.md の絶対パス}
  - `{backup_path}`: {実際の {agent_path}.backup-{timestamp} の絶対パス}

  改善後:
  パス変数:
  - `{agent_path}`: {実際の agent_path の絶対パス}
  - `{approved_findings_path}`: {実際の .agent_audit/{agent_name}/audit-approved.md の絶対パス}
  - `{backup_path}`: {Step 4 で生成されたバックアップファイルの完全な絶対パス（例: /path/to/agent.md.backup-20260213-123456）}
  ```

#### 変更7: analysis.md 依存関係の明示（I-4）
**対応フィードバック**: effectiveness: analysis.md 生成ステップの依存関係を明示

**変更内容**:
- L21-27: 期待される成果物セクションに analysis.md を追加
  ```markdown
  現在:
  ## 期待される成果物

  - `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`: 各次元の分析結果
  - `.agent_audit/{agent_name}/audit-approved.md`: 承認済み findings
  - `{agent_path}.backup-{timestamp}`: 変更前のバックアップ（改善適用時）
  - 変更済みエージェント定義: `{agent_path}`（承認された改善が適用済み）

  改善後:
  ## 期待される成果物

  - `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`: 各次元の分析結果
  - `.agent_audit/{agent_name}/audit-approved.md`: 承認済み findings
  - `{agent_path}.backup-{timestamp}`: 変更前のバックアップ（改善適用時）
  - 変更済みエージェント定義: `{agent_path}`（承認された改善が適用済み）

  ## 前提条件

  このスキルは `/skill_audit` スキルによって生成された以下のファイルに依存します:
  - `.skill_audit/{skill_name}/run-{timestamp}/analysis.md`: スキル構造分析（外部参照、ファイルインベントリ等）

  analysis.md が存在しない場合でも実行可能ですが、以下の制限があります:
  - グループ分類は正常に動作
  - 各次元の分析は正常に動作
  - ただし、外部参照の整合性検証は実施されない
  ```

#### 変更8: 成功基準の明示化（I-5）
**対応フィードバック**: effectiveness: 成功基準を明示化

**変更内容**:
- L1-10: スキル説明の後に成功基準セクションを追加
  ```markdown
  位置: L10（「入力はエージェント定義ファイル1つのみ。外部データへの依存なく、常に同じ分析を実行します。」の後）

  追加内容:

  ## 成功基準

  agent_audit の実行が成功したと判定される条件:

  ### Phase 1 成功基準
  - 少なくとも1つの次元の分析が成功している
  - かつ、以下のいずれかを満たす:
    - IC（指示明確性）次元が成功している
    - または、2つ以上の次元が成功している

  ### Phase 2 成功基準
  - 承認された findings が全て適用されている（部分適用の場合、skipped に理由が記録されている）
  - かつ、改善適用後のエージェント定義が構造検証をパスしている（YAML frontmatter 存在、見出し行存在）

  ### 全体成功基準
  - Phase 1, Phase 2 の両方が成功基準を満たしている
  - または、Phase 1 成功 + Phase 2 で対象 findings が 0 件の場合（改善不要判定）
  ```

#### 変更9: バリデーション警告の具体化（I-6）
**対応フィードバック**: ux: バリデーション警告の具体性向上

**変更内容**:
- L67: 警告メッセージを具体化
  ```markdown
  現在:
  3. ファイル先頭に YAML frontmatter（`---` と `description:` を含む）が存在するか確認する。存在しない場合、警告を出力するが処理は継続する

  改善後:
  3. ファイル先頭に YAML frontmatter（`---` と `description:` を含む）が存在するか確認する。存在しない場合、以下の警告を出力するが処理は継続する:
     - 「⚠ 警告: YAML frontmatter が見つかりません。エージェント定義には以下の形式の frontmatter が推奨されます:\n```yaml\n---\nallowed-tools: [ツールリスト]\ndescription: エージェントの説明\n---\n```」
  ```

#### 変更10: Phase 1 部分失敗時の対処選択肢追加（I-7）
**対応フィードバック**: ux: Phase 1 部分失敗時の対処選択肢を提供

**変更内容**:
- L145-159: 継続判定前に AskUserQuestion を追加
  ```markdown
  位置: L150（「継続条件に該当する場合: Phase 2 へ進む。」の前）

  修正内容:
  継続条件に該当する場合: AskUserQuestion で継続/中止をユーザーに確認する:
  - 質問: 「Phase 1 で {失敗次元数}次元が失敗しました。失敗した次元:\n{各失敗次元と理由を列挙}\n\n成功した次元（{成功数}件）のみで Phase 2 へ進みますか？」
  - 選択肢: 「継続する」「中止する」
  - 「継続する」選択時: Phase 2 へ進む
  - 「中止する」選択時: 処理を終了する
  ```

#### 変更11: Phase 1 エラーハンドリングの代替処理明確化（I-8）
**対応フィードバック**: stability: Phase 1 エラーハンドリングの「エラー概要」抽出ロジックを明確化

**変更内容**:
- L141: エラー概要抽出の代替処理を追加
  ```markdown
  現在:
  - findings ファイルが存在しない、または空（0バイトまたは `## Summary` セクションが存在しない） → 失敗。Task ツールの返答から例外情報（エラーメッセージの要約。返答から "Error:" または "Exception:" を含む最初の文を抽出する）を抽出し、該当次元は「分析失敗（{エラー概要}）」として扱う。エラー概要が抽出できない場合は「不明なエラー」とする

  改善後:
  - findings ファイルが存在しない、または空（0バイトまたは `## Summary` セクションが存在しない） → 失敗。Task ツールの返答から例外情報を以下の順序で抽出する:
    1. "Error:" または "Exception:" を含む最初の文を抽出
    2. 抽出失敗時: Task 返答の最初の段落（最初の空行まで、または最初の100文字）を抽出
    3. それも失敗時: 「Task 失敗（詳細不明）」とする

    抽出した情報を該当次元の「分析失敗（{エラー概要}）」として記録する。
  ```

#### 変更12: Phase 2 Step 4 バックアップ作成失敗時の処理明示（I-9）
**対応フィードバック**: effectiveness: Phase 2 Step 4 でのバックアップ作成失敗時の処理を明示

**変更内容**:
- L209: バックアップ作成のエラーハンドリング追加
  ```markdown
  現在:
  **バックアップ作成**: 改善適用前に Bash で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、生成された完全な絶対パスを `{backup_path}` として記録する（例: `/path/to/agent.md.backup-20260213-123456`）。

  改善後:
  **バックアップ作成**: 改善適用前に Bash で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、生成された完全な絶対パスを `{backup_path}` として記録する（例: `/path/to/agent.md.backup-20260213-123456`）。

  **バックアップ失敗時の処理**: cp コマンドが失敗した場合（終了コード非0）:
  - 「✗ エラー: バックアップ作成に失敗しました: {エラー詳細}\n改善適用を中止します。」とエラー出力
  - Phase 3 へ直行する（改善適用なしとして扱う）
  ```

#### 変更13: Phase 2 検証ステップの拡張（I-3）
**対応フィードバック**: architecture: Phase 2 検証ステップの検証範囲を拡張

**変更内容**:
- L225-230: 検証ステップを拡張
  ```markdown
  現在:
  改善適用完了後、以下の検証を実行する:

  1. Read で `{agent_path}` を再読み込み
  2. YAML frontmatter の存在確認（ファイル先頭が `---` で始まり、`description:` を含む）およびファイル内に `## ` で始まる見出し行が1つ以上存在することを確認する
  3. 検証成功時: 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
  4. 検証失敗時: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力し、`{validation_failed} = true` を記録

  改善後:
  改善適用完了後、以下の検証を実行する:

  1. Read で `{agent_path}` を再読み込み
  2. 構造検証:
     - YAML frontmatter の存在確認（ファイル先頭が `---` で始まり、`description:` を含む）
     - ファイル内に `## ` で始まる見出し行が1つ以上存在することを確認
  3. セクション参照整合性検証（analysis.md が存在する場合のみ実施）:
     - analysis.md の「外部参照の検出」テーブルを Read で取得
     - 各外部参照パスが {agent_path} 内に記載されているか確認（文字列検索）
     - 記載がない参照が存在する場合: 「⚠ 警告: 外部参照の欠落を検出: {パスリスト}」とテキスト出力（警告のみ、検証は継続）
  4. 検証成功時: 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
  5. 検証失敗時: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力し、`{validation_failed} = true` を記録
  ```

#### 変更14: Phase 1 findings カウント処理の委譲（I-2）
**対応フィードバック**: efficiency: Phase 1 findings カウント処理の冗長性削減

**変更内容**:
- L126-132: Task prompt を更新してカウントをサブエージェント返答に含める
  ```markdown
  現在:
  > 分析完了後、以下の4行フォーマットで返答してください:
  > ```
  > dim: {次元名}
  > critical: {N}
  > improvement: {M}
  > info: {K}
  > ```

  改善後:
  > 分析完了後、以下の4行フォーマットで返答してください（件数は findings ファイルに保存した実際の件数を記載すること）:
  > ```
  > dim: {次元名}
  > critical: {N}
  > improvement: {M}
  > info: {K}
  > ```
  ```

- L140: カウント処理のフォールバックを簡略化
  ```markdown
  現在:
  - 対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在し、空でない（0バイトでなく、かつ `## Summary` セクションを含む） → 成功。件数はサブエージェント返答から抽出する（正規表現 `critical: (\d+)` 等で抽出し、抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数をカウントして推定する）

  改善後:
  - 対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在し、空でない（0バイトでなく、かつ `## Summary` セクションを含む） → 成功。件数はサブエージェント返答から抽出する（正規表現 `critical: (\d+)` 等で抽出）。抽出失敗時は「件数取得失敗」として記録し、Phase 2 Step 1 で findings ファイルから直接件数を再取得する
  ```

#### 変更15: Phase 2 Step 1 findings 収集の委譲（I-1）
**対応フィードバック**: efficiency: Phase 2 Step 1 の findings 収集を委譲してコンテキスト削減

**変更内容**:
- L171-176: findings 収集をサブエージェントに委譲
  ```markdown
  現在:
  #### Step 1: Findings の収集

  Phase 1 で成功した全次元の findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を Read する。
  各ファイルから severity が critical または improvement の finding を以下のルールで抽出する:
  ...

  改善後:
  #### Step 1: Findings の収集（サブエージェントに委譲）

  Task ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  > Phase 1 で成功した全次元の findings ファイルから critical および improvement の findings を収集し、`.agent_audit/{agent_name}/findings-summary.md` に保存してください。
  >
  > 対象ファイル: {成功した次元の findings ファイルパスリスト（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` 形式）}
  >
  > 以下のルールで抽出してください:
  > - **境界検出**: `### {ID}-{N}:` で始まる行（見出しレベル3）から次の `###` または `##` が出現するまで、またはファイル末尾までを1つの finding ブロックとする
  > - **severity 抽出**: ブロック内の `- severity: {value}` 行から抽出。`critical` または `improvement` のみを対象とする（`info` は除外）
  > - **title 抽出**: 見出し行の `: ` 以降、`[` より前の部分（例: `### CE-1: 曖昧な基準の検出不足 [effectiveness]` → title は `曖昧な基準の検出不足`）
  > - **次元名抽出**: 見出し行の `[` と `]` で囲まれた部分（例: `[effectiveness]` → 次元名は `effectiveness`）
  >
  > 抽出した finding を critical → improvement の順にソートし、findings-summary.md に以下のフォーマットで保存してください:
  > ```markdown
  > # Findings Summary
  >
  > total: {N}
  > critical: {C}
  > improvement: {I}
  >
  > ## Findings List
  > | # | ID | severity | title | 次元 |
  > |---|-----|----------|-------|------|
  > | 1 | {ID} | {severity} | {title} | {次元名} |
  > ...
  > ```
  >
  > 返答は以下の3行フォーマットで返答してください:
  > ```
  > total: {N}
  > critical: {C}
  > improvement: {I}
  > ```

  サブエージェント完了後、`findings-summary.md` を Read で読み込み、`{total}` を取得する。

  **部分適用時の整合性チェック**: Phase 1 で部分失敗が発生していた場合（失敗次元が存在する場合）、収集された findings に失敗次元の ID プレフィックスを含む finding が存在しないことを確認する。存在する場合は「⚠ 内部エラー: 失敗次元 {次元名} の findings が含まれています。処理を中止します。」とエラー出力して終了する。
  ```

### 2. templates/apply-improvements.md（修正）
**対応フィードバック**: C-6: templates/apply-improvements.md で使用される変数 {timestamp} が未定義

**変更内容**:
- L4: {timestamp} を削除し、backup_path の説明を完全パスに変更
  ```markdown
  現在:
  - `{backup_path}`: バックアップファイルのパス（`{agent_path}.backup-{timestamp}`）

  改善後:
  - `{backup_path}`: バックアップファイルの完全な絶対パス（例: `/path/to/agent.md.backup-20260213-123456`）
  ```

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序

1. **templates/apply-improvements.md の修正**（変更2）
   - 理由: パス変数の定義を修正。SKILL.md からの参照があるため、先に修正する

2. **SKILL.md の修正**（変更1: 全15箇所）
   - 理由: メインワークフロー定義の修正。全ての変更を一度に適用する（相互依存が多いため）
   - 変更順序（SKILL.md 内）:
     a. L21-27: 前提条件セクション追加（I-4）
     b. L10 後: 成功基準セクション追加（I-5）
     c. L67: バリデーション警告具体化（I-6）
     d. L75: group-classification.md パス絶対パス化（C-3）
     e. L92-100: ID_PREFIX マッピングテーブル追加（C-1）
     f. L115: 既存 findings 検出ロジック強化（C-4）
     g. L126-132, L140: findings カウント処理委譲（I-2）
     h. L141: エラーハンドリング代替処理明確化（I-8）
     i. L145-159: 部分失敗継続判定修正+対処選択肢追加（C-2, I-7）
     j. L171-176: findings 収集委譲（I-1）
     k. L173-174: findings 境界検出ルール明示（C-5）
     l. L209: バックアップパス完全化+失敗時処理明示（C-6, I-9）
     m. L214-217: パス変数説明更新（C-6）
     n. L225-230: 検証ステップ拡張（I-3）

## 注意事項

- 全ての変更は既存のワークフローを維持する
- Phase 0-3 の基本構造は変更しない
- サブエージェント委譲の追加（I-1）により親コンテキスト削減を実現
- エラーハンドリングの強化により安定性が向上
- ID_PREFIX マッピングの明示化により Phase 2 の実装が明確化
- バックアップパスの完全化により apply-improvements.md との整合性を確保
- analysis.md への依存を明示化したが、存在しない場合でも動作可能な設計を維持
