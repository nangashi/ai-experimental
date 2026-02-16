# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 外部参照パスを agent_audit から agent_audit_new に修正（3箇所） | C-1, C-2 |
| 2 | SKILL.md | 修正 | 「静的」の定義を明示 | C-5 |
| 3 | SKILL.md | 修正 | Phase 0 の出力に判定根拠を追加 | C-4 |
| 4 | SKILL.md | 修正 | Phase 1 のブロック数推定ロジックを明示、フォールバック処理を定義 | C-3 |
| 5 | SKILL.md | 修正 | Phase 1 の返答フォーマット指示をエージェント定義に一元化 | I-2 |
| 6 | SKILL.md | 修正 | Phase 2 の承認選択肢の順序を変更（「1件ずつ確認」を先頭に） | I-3 |
| 7 | SKILL.md | 修正 | frontmatter 検証の具体的な基準を明示 | I-5 |
| 8 | SKILL.md | 新規作成 | パス変数セクションを追加 | I-1 |
| 9 | SKILL.md | 修正 | Phase 2 Step 4 のエラーハンドリングを定義 | I-4 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1（外部参照パス不整合）、C-2（テンプレートパスの不整合）

**変更内容**:
- L64: `.claude/skills/agent_audit/group-classification.md` → `.claude/skills/agent_audit_new/group-classification.md`
- L115: `.claude/skills/agent_audit/agents/{dim_path}.md` → `.claude/skills/agent_audit_new/agents/{dim_path}.md`
- L221: `.claude/skills/agent_audit/templates/apply-improvements.md` → `.claude/skills/agent_audit_new/templates/apply-improvements.md`

### 2. SKILL.md（修正）
**対応フィードバック**: C-5（「静的」の定義の曖昧性）

**変更内容**:
- L6: `エージェント定義ファイルのコンテンツ（評価基準、スコープ、指示の品質）を静的に分析し、構造最適化（agent_bench）では解決できない内容レベルの問題を特定・改善します。` → `エージェント定義ファイルのコンテンツ（評価基準、スコープ、指示の品質）を静的に分析し、構造最適化（agent_bench）では解決できない内容レベルの問題を特定・改善します。「静的分析」とは、コード生成・実行を伴わず、エージェント定義ファイルの内容のみを対象とする分析を指します。`

### 3. SKILL.md（修正）
**対応フィードバック**: C-4（agent_group の判定根拠が出力されない）

**変更内容**:
- L96-103: Phase 0 のテキスト出力に判定根拠を追加
  - 現在:
    ```
    ## Phase 0: 初期化
    - エージェント: {agent_name} ({agent_path})
    - グループ: {agent_group}
    - 分析次元: {dim_count}件（{各次元名のカンマ区切り}）
    - 出力先: .agent_audit/{agent_name}/
    ```
  - 改善後:
    ```
    ## Phase 0: 初期化
    - エージェント: {agent_name} ({agent_path})
    - グループ: {agent_group}
      - 判定根拠: evaluator特徴 {N}個（{検出された特徴のカンマ区切り}）、producer特徴 {M}個（{検出された特徴のカンマ区切り}）
    - 分析次元: {dim_count}件（{各次元名のカンマ区切り}）
    - 出力先: .agent_audit/{agent_name}/
    ```

### 4. SKILL.md（修正）
**対応フィードバック**: C-3（Phase 1 サブエージェント失敗時の件数推定ロジック）

**変更内容**:
- L126: 以下の詳細を追加
  - 現在: `（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）`
  - 改善後: `（抽出失敗時は Grep を使用して findings ファイル内の `^### {ID_PREFIX}-` パターンを検索し、マッチ数から推定する。両方失敗した場合は `critical: 0, improvement: 0, info: 0` を使用する）`

### 5. SKILL.md（修正）
**対応フィードバック**: I-2（Phase 1 返答フォーマットの暗黙的依存）

**変更内容**:
- L115-118: Task prompt の返答指示を簡略化
  - 現在:
    ```
    > `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
    > 分析対象: `{agent_path}`, agent_name: `{agent_name}`
    > findings の保存先: `{findings_save_path}`（= `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
    > 分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
    ```
  - 改善後:
    ```
    > `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
    > 分析対象: `{agent_path}`, agent_name: `{agent_name}`
    > findings の保存先: `{findings_save_path}`（= `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
    > 分析完了後、エージェント定義内の「Return Format」セクションに従って返答してください。
    ```

### 6. SKILL.md（修正）
**対応フィードバック**: I-3（承認粒度: per-item承認のデフォルト化）

**変更内容**:
- L163-166: 承認方針の選択肢順序を変更
  - 現在:
    ```
    続けて `AskUserQuestion` で承認方針を確認:
    - **「全て承認」**: 全 findings を承認として Step 3 へ進む
    - **「1件ずつ確認」**: Step 2a の per-item 承認ループに入る
    - **「キャンセル」**: 改善適用なしで Phase 3 へ直行する
    ```
  - 改善後:
    ```
    続けて `AskUserQuestion` で承認方針を確認:
    - **「1件ずつ確認」**: Step 2a の per-item 承認ループに入る
    - **「全て承認」**: 全 findings を承認として Step 3 へ進む
    - **「キャンセル」**: 改善適用なしで Phase 3 へ直行する
    ```

### 7. SKILL.md（修正）
**対応フィードバック**: I-5（「簡易チェック」の基準が曖昧）

**変更内容**:
- L58: frontmatter 検証の具体的な基準を明示
  - 現在: `ファイル内容の簡易チェック: ファイル先頭に YAML frontmatter（`---` で囲まれたブロック内に `description:` を含む）が存在するか確認する。`
  - 改善後: `ファイル内容の簡易チェック: ファイル先頭10行以内に `---` で始まる行があり、その後の100行以内に `description:` を含む行が存在するか確認する（Grep または Read+パターンマッチング）。`

### 8. SKILL.md（新規作成）
**対応フィードバック**: I-1（テンプレートプレースホルダの未定義変数）

**変更内容**:
- L12（「## 使い方」セクションの直後）に新規セクションを追加:
  ```markdown
  ## パス変数

  このスキルおよび関連テンプレートで使用される変数:

  - `{agent_path}`: エージェント定義ファイルの絶対パス
  - `{agent_name}`: エージェント名（`.claude/` 配下の場合は `.claude/` からの相対パス、それ以外はプロジェクトルートからの相対パス、いずれも拡張子除去）
  - `{agent_group}`: グループ分類結果（`hybrid` / `evaluator` / `producer` / `unclassified`）
  - `{findings_save_path}`: 各次元の findings ファイル保存先（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
  - `{approved_findings_path}`: 承認済み findings ファイルのパス（`.agent_audit/{agent_name}/audit-approved.md` の絶対パス）
  - `{backup_path}`: 改善適用前のバックアップファイルパス
  ```

### 9. SKILL.md（修正）
**対応フィードバック**: I-4（Phase 2 Step 4のエラーハンドリング未定義）

**変更内容**:
- L226（サブエージェント完了後）に以下を追加:
  - 現在: `サブエージェント完了後、返答内容（変更サマリ）をテキスト出力する。`
  - 改善後:
    ```
    サブエージェント完了後、返答内容（変更サマリ）をテキスト出力する。

    **エラーハンドリング**: 変更サマリに「modified: 0件」「skipped: {全件数}件」が含まれる場合、改善適用が全て失敗したと判定する。この場合、以下をテキスト出力する:
    - 「⚠ 改善適用に失敗しました。スキップ理由を確認してください。」
    - スキップ理由の詳細（サブエージェントの返答から抽出）
    - 「バックアップ: {backup_path}」

    部分的に成功した場合（modified > 0 かつ skipped > 0）、警告として「一部の改善がスキップされました。詳細は上記のスキップ理由を参照してください。」をテキスト出力する。
    ```

## 新規作成ファイル
なし（SKILL.md 内に新規セクションを追加）

## 削除推奨ファイル
なし

## 実装順序
1. **SKILL.md: パス変数セクション追加**（I-1） — 他の変更の前提となる定義を整備
2. **SKILL.md: 外部参照パス修正**（C-1, C-2） — 即座に影響する critical な不整合を修正
3. **SKILL.md: 「静的」の定義明示**（C-5） — スキル説明の明確化
4. **SKILL.md: Phase 0 判定根拠追加**（C-4） — 初期化フェーズの出力改善
5. **SKILL.md: Phase 1 ブロック数推定ロジック明示**（C-3） — エラーハンドリングの明確化
6. **SKILL.md: Phase 1 返答フォーマット一元化**（I-2） — エージェント定義との整合性向上
7. **SKILL.md: Phase 2 承認選択肢順序変更**（I-3） — UX 改善
8. **SKILL.md: frontmatter 検証基準明示**（I-5） — バリデーションロジックの明確化
9. **SKILL.md: Phase 2 Step 4 エラーハンドリング追加**（I-4） — 改善適用の堅牢性向上

依存関係の検出方法:
- パス変数セクション（1）は他の変更で参照される可能性があるため最初に実施
- 外部参照パス修正（2）は即座にスキルの実行可能性に影響するため優先度が高い
- 他の変更は独立しているため、論理的な順序（Phase 0 → Phase 1 → Phase 2）で実施

## 注意事項
- 全ての変更は SKILL.md の単一ファイルに対するもので、既存のワークフローを変更しない
- 外部参照パスの修正（C-1, C-2）は、エージェント定義ファイルやテンプレートファイルの実際の配置場所と一致させる必要がある
- Phase 1 の返答フォーマット変更（I-2）により、SKILL.md の指示がエージェント定義の「Return Format」セクションに依存するようになる（既存のエージェント定義はすでに Return Format を持っているため互換性あり）
