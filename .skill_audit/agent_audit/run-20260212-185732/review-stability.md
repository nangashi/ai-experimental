### 安定性レビュー結果

#### 重大な問題

- [出力フォーマット決定性: サブエージェント返答フォーマット未明示]: [SKILL.md] [Phase 1 行128-129] [「`.claude/skills/agent_audit/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。」] → [サブエージェント返答の行数・フィールド名を明示すべき。例: 「分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`」] [impact: high] [effort: low]

- [参照整合性: テンプレート内プレースホルダ未定義]: [templates/apply-improvements.md] [行3-4] [{approved_findings_path} および {agent_path} が SKILL.md のパス変数リストで定義されていない] → [SKILL.md Phase 2 Step 4 の Task 起動箇所（行228-233）で「パス変数:」として明示すべき。`{approved_findings_path}`: `.agent_audit/{agent_name}/audit-approved.md` の絶対パス, `{agent_path}`: エージェント定義ファイルの絶対パス] [impact: high] [effort: low]

- [条件分岐の完全性: else 節未定義]: [SKILL.md] [Phase 0 行88-92] [「`agent_path` が `.claude/` 配下の場合: ... それ以外の場合: ...」の分岐があるが、プロジェクトルートが不明な場合の処理が未定義] → [プロジェクトルートの検出ロジック（git root または pwd）を明示し、検出失敗時のデフォルト処理（エラー出力 or カレントディレクトリをルートとする）を追加すべき] [impact: medium] [effort: medium]

- [冪等性: 再実行時のファイル重複]: [SKILL.md] [Phase 0 行93] [`mkdir -p .agent_audit/{agent_name}/` は冪等だが、Phase 2 Step 4 行226 のバックアップ作成 `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` は再実行のたびに新規ファイルを作成する] → [バックアップファイルが既に存在する場合（例: 前回のバックアップがあり再実行中）の処理を明示すべき。例: 「既存バックアップがある場合は上書きせず新規作成する」または「最新1件のみ保持する」] [impact: medium] [effort: low]

- [条件分岐の完全性: 暗黙的条件]: [SKILL.md] [Phase 1 行149] [「全次元の critical + improvement の合計が 0 の場合、Phase 2 をスキップして Phase 3 へ直行する」だが、合計が 1 以上の場合の処理が明示されていない] → [「合計が 1 以上の場合は Phase 2 へ進む」を明記すべき] [impact: low] [effort: low]

#### 改善提案

- [指示の具体性: 曖昧表現]: [SKILL.md] [Phase 0 行62] [「エージェント定義の **主たる機能** に注目して分類する」の「主たる機能」が曖昧] → [「フロントマター description フィールドおよび本文の最初の3段落（または使い方セクション）に記載された機能を評価対象とする」等、評価範囲を具体化すべき] [impact: medium] [effort: low]

- [指示の具体性: 数値基準なし]: [SKILL.md] [Phase 0 行78-82] [「evaluator 特徴が3つ以上 **かつ** producer 特徴が3つ以上 → **hybrid**」だが、特徴の判定基準（「評価基準・チェックリストが定義されている」をどう確認するか）が未定義] → [各特徴の判定方法を例示すべき。例: 「評価基準が定義されている: 本文に「基準」「チェックリスト」「検出」「評価項目」等のキーワードを含む段落が存在する」] [impact: medium] [effort: medium]

- [出力フォーマット決定性: フォーマット例未提供]: [templates/apply-improvements.md] [行24-32] [返答フォーマットは指定されているが、具体例がない] → [フォーマット例を追加すべき。例: 「modified: 2件\n  - /path/to/agent.md: 評価基準を3件追加\nskipped: 1件\n  - CE-001: 既に修正済み」] [impact: medium] [effort: low]

- [冪等性: フェーズ途中再開の可否不明]: [SKILL.md] [全体] [Phase 1 失敗後に Phase 1 のみ再実行できるか、Phase 2 完了後に Phase 3 のみ再実行できるか等、途中再開の可否が明示されていない] → [各フェーズの冪等性を明記すべき。例: 「Phase 1 は findings ファイルが既に存在する場合は上書きする（冪等）」「Phase 2 は audit-approved.md が既に存在する場合はユーザーに上書き確認を行う」] [impact: medium] [effort: medium]

- [参照整合性: 未使用変数]: [SKILL.md] [Phase 1 行132] [`{ID_PREFIX}` は Phase 1 で定義されているが、各次元の ID_PREFIX（CE, IC, SA, DC, WC, OF）の対応表が SKILL.md に記載されていない] → [Phase 0 の次元マッピングテーブル（行97-104）に ID_PREFIX カラムを追加すべき] [impact: low] [effort: low]

- [指示の具体性: 曖昧表現]: [SKILL.md] [Phase 1 行137] [「件数はファイル内の `## Summary` セクションから抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）」の「抽出失敗」が曖昧] → [「Summary セクションが存在しない、またはフォーマットが期待形式（critical: N, improvement: M, info: K）に一致しない場合」と具体化すべき] [impact: low] [effort: low]

- [条件分岐の完全性: デフォルト処理未定義]: [SKILL.md] [Phase 2 Step 4 行228-235] [サブエージェント完了後の返答内容検証が「Phase 1: 返答フォーマット不一致」と異なり明示的処理なし] → [返答が期待形式（modified: N件, skipped: K件）に一致しない場合の処理を追加すべき。例: 「フォーマット不一致の場合は警告を出力し、返答内容をそのまま表示する」] [impact: low] [effort: low]

#### 良い点

- [冪等性: ディレクトリ作成]: Phase 0 で `mkdir -p` を使用しており、ディレクトリが既に存在する場合もエラーにならない設計（行93）
- [参照整合性: テンプレートファイル実在確認]: SKILL.md で言及された全テンプレートファイル（agents/*/**.md, templates/apply-improvements.md）がスキルディレクトリ内に実在する
- [出力フォーマット決定性: サマリ行数明示]: Phase 3 の完了サマリフォーマットが具体的に記載されており、条件分岐（Phase 2 スキップ時 vs 実行時）ごとの出力パターンが明確（行240-278）
