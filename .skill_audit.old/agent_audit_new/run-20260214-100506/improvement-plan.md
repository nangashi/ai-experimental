# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 2 Step 4 にバックアップ検証ロジックを追加 | C-1: 不可逆操作のガード欠落 |
| 2 | templates/phase1-parallel-analysis.md | 新規作成 | Phase 1 並列サブエージェント指示をテンプレート化 | I-1: Phase 1 並列サブエージェント指示のテンプレート外部化 |
| 3 | SKILL.md | 修正 | Phase 1 指示をテンプレート参照に置換 | I-1: Phase 1 並列サブエージェント指示のテンプレート外部化 |
| 4 | SKILL.md | 修正 | 「使い方」セクションに成果物を明示 | I-2: 目的の明確性: 成果物の明示不足 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1: 不可逆操作のガード欠落: バックアップ作成失敗時の続行

**変更内容**:
- Phase 2 Step 4（217行目）: バックアップ作成コマンドの直後に検証ロジックを追加
  - 現在の記述:
    ```
    **バックアップ作成**: 改善適用前に Bash で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、`{backup_path}` を記録する。
    ```
  - 改善後の記述:
    ```
    **バックアップ作成**: 改善適用前に Bash で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、`{backup_path}` を記録する。

    **バックアップ検証**: Bash で `test -f {backup_path} && echo 'OK' || echo 'FAILED'` を実行する。
    - 出力が `OK` の場合: バックアップ成功。改善適用に進む
    - 出力が `FAILED` の場合: AskUserQuestion で「バックアップ作成に失敗しました。続行しますか？」と確認し、「続行」選択時のみ改善適用に進む。「キャンセル」選択時は Phase 3 へ直行する
    ```

### 2. templates/phase1-parallel-analysis.md（新規作成）
**対応フィードバック**: I-1: Phase 1 並列サブエージェント指示のテンプレート外部化

**変更内容**:
- 新規テンプレートファイルの作成:
  ```markdown
  # Phase 1: 並列分析テンプレート

  `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。

  ## パス変数
  - `{agent_path}`: 分析対象エージェント定義ファイルの絶対パス
  - `{agent_name}`: エージェント名（出力ディレクトリ特定用）
  - `{findings_save_path}`: findings の保存先絶対パス（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）

  ## 返答フォーマット
  分析完了後、以下のフォーマットで返答してください:
  ```
  dim: {次元名}, critical: {N}, improvement: {M}, info: {K}
  ```
  ```

### 3. SKILL.md（修正）
**対応フィードバック**: I-1: Phase 1 並列サブエージェント指示のテンプレート外部化

**変更内容**:
- Phase 1（113-118行目）: インライン指示をテンプレート参照に置換
  - 現在の記述:
    ```
    各次元について、以下の Task prompt を使用する:

    > `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
    > 分析対象: `{agent_path}`, agent_name: `{agent_name}`
    > findings の保存先: `{findings_save_path}`（= `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
    > 分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
    ```
  - 改善後の記述:
    ```
    各次元について、以下の Task prompt を使用する:

    > `.claude/skills/agent_audit_new/templates/phase1-parallel-analysis.md` を Read で読み込み、その内容に従って処理を実行してください。
    > パス変数:
    > - `{dim_path}`: {実際の dim_path}（例: `evaluator/criteria-effectiveness`）
    > - `{agent_path}`: {実際の agent_path の絶対パス}
    > - `{agent_name}`: {実際の agent_name}
    > - `{findings_save_path}`: {実際の .agent_audit/{agent_name}/audit-{ID_PREFIX}.md の絶対パス}
    ```

### 4. SKILL.md（修正）
**対応フィードバック**: I-2: 目的の明確性: 成果物の明示不足

**変更内容**:
- 「使い方」セクション（12-18行目）: 成果物の説明を追加
  - 現在の記述:
    ```
    ## 使い方

    ```
    /agent_audit <file_path>    # エージェント定義ファイルを指定して監査
    ```

    - `file_path`: エージェント定義ファイルのパス（必須）
    ```
  - 改善後の記述:
    ```
    ## 使い方

    ```
    /agent_audit <file_path>    # エージェント定義ファイルを指定して監査
    ```

    - `file_path`: エージェント定義ファイルのパス（必須）

    **成果物**:
    - `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`: 各分析次元の詳細 findings
    - `.agent_audit/{agent_name}/audit-approved.md`: 承認された改善内容
    - `{agent_path}.backup-{timestamp}`: 改善適用前のバックアップ（改善適用時のみ）
    - 改善適用されたエージェント定義ファイル（承認時のみ）
    ```

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase1-parallel-analysis.md | Phase 1 サブエージェント指示の外部化。SKILL.md のコンテキスト負荷削減 | I-1 |

## 削除推奨ファイル
（なし）

## 実装順序
1. **templates/phase1-parallel-analysis.md（新規作成）**: Phase 1 サブエージェント指示のテンプレート化。SKILL.md の変更（#3）がこのファイルを参照するため、先に作成する必要がある
2. **SKILL.md（変更 #1: バックアップ検証）**: Phase 2 Step 4 にバックアップ検証ロジックを追加。他の変更と独立しているため、テンプレート作成後すぐに実施可能
3. **SKILL.md（変更 #3: Phase 1 テンプレート参照）**: Phase 1 指示をテンプレート参照に置換。#1 で作成した templates/phase1-parallel-analysis.md を参照するため、#1 の後に実施
4. **SKILL.md（変更 #4: 成果物の明示）**: 「使い方」セクションに成果物を明示。他の変更と独立しているため、任意のタイミングで実施可能

## 注意事項
- 変更によって既存のワークフローが壊れないこと
- テンプレート外部化の場合、SKILL.md の参照箇所も同時に更新すること
- 新規テンプレートのパス変数が SKILL.md で定義されていること
