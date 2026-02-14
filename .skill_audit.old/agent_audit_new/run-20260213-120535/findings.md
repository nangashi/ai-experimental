## 重大な問題

### C-1: 外部参照パス不整合 [architecture, efficiency, stability, effectiveness]
- 対象: SKILL.md:64, 221
- 内容: `.claude/skills/agent_audit/` への参照が存在するが、実際のファイルは `.claude/skills/agent_audit_new/` に配置されている。Phase 0 のグループ分類基準参照 (L64: `.claude/skills/agent_audit/group-classification.md`) と Phase 2 Step 4 のテンプレート読み込み (L221: `.claude/skills/agent_audit/templates/apply-improvements.md`) が失敗する。サブエージェント起動時にファイル不在エラーが発生し、エラーハンドリング処理の往復が発生する
- 推奨: `.claude/skills/agent_audit/` を `.claude/skills/agent_audit_new/` に修正する
- impact: high, effort: low

### C-2: 参照整合性: テンプレートパスの不整合 [stability]
- 対象: SKILL.md:115
- 内容: `.claude/skills/agent_audit/agents/{dim_path}.md` を参照しているが、正しいパスは `.claude/skills/agent_audit_new/agents/{dim_path}.md` である。dim_path の例として evaluator/criteria-effectiveness が使われているが、このパスプレフィックスがスキルディレクトリ名と異なる
- 推奨: `.claude/skills/agent_audit/agents/` を `.claude/skills/agent_audit_new/agents/` に修正する
- impact: high, effort: low

### C-3: 条件分岐の完全性: Phase 1 サブエージェント失敗時の件数推定ロジック [stability]
- 対象: SKILL.md:126
- 内容: 「抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する」とあるが、推定処理の具体的な実装方法が明示されていない。また、Summary セクションからの抽出とブロック数推定の両方が失敗した場合のフォールバック処理が不明確
- 推奨: ブロック数の数え方（Grep または Read+パターンマッチング）を明示し、両方失敗した場合のデフォルト値（例: `critical: 0, improvement: 0, info: 0` または「件数不明」）を定義する
- impact: medium, effort: low

### C-4: 欠落ステップ検出: agent_group の判定根拠が出力されない [effectiveness]
- 対象: SKILL.md:96-103 (Phase 0)
- 内容: 「使い方」セクションで暗黙的に期待される成果物として、グループ分類の判定根拠（どの特徴が何個検出されたか）がある。Phase 0 のテキスト出力には判定結果のみが含まれ、判定根拠が記録されない。ユーザーが判定の妥当性を検証できない
- 推奨: Phase 0 Step 4 の出力に判定根拠（検出された特徴のリストと件数）を含める
- impact: medium, effort: medium

### C-5: 目的の明確性: 「静的に分析」の曖昧性 [effectiveness]
- 対象: SKILL.md:6
- 内容: SKILL.md の冒頭説明で「静的に分析」と記述されているが、「静的」の定義が明示されていない。agent_bench との対比で推定可能だが、スキル単体で読んだときに「何をしない分析か」が推定不能。「外部データへの依存なく」という記述とも重複し混乱を招く
- 推奨: 「静的」の定義を明示する（例: 「コード生成・実行を伴わず、エージェント定義ファイルの内容のみを分析」）
- impact: medium, effort: low

## 改善提案

### I-1: 参照整合性: テンプレートプレースホルダの未定義変数 [stability]
- 対象: templates/apply-improvements.md:3-5
- 内容: `{approved_findings_path}` と `{agent_path}` はパス変数として使用されているが、SKILL.md のパス変数リストには明示されていない
- 推奨: SKILL.md に「パス変数」セクションを追加し、全テンプレートで使用されるプレースホルダを一覧化する
- impact: medium, effort: low

### I-2: データフロー妥当性: Phase 1 返答フォーマットの暗黙的依存 [effectiveness]
- 対象: SKILL.md:118 (Phase 1)
- 内容: サブエージェントに「dim: {次元名}, critical: {N}, improvement: {M}, info: {K}」形式での返答を要求しているが、各次元のエージェント定義（agents/*/**.md）には「Return Format」セクションが存在し、そちらで返答形式が明示されている。SKILL.md の指示とエージェント定義の指示が重複・矛盾する可能性がある
- 推奨: エージェント定義側に返答形式を一元化し、SKILL.md は「その指示に従って返答してください」とすべき
- impact: medium, effort: low

### I-3: 承認粒度: per-item承認のデフォルト化 [ux]
- 対象: SKILL.md Phase 2 Step 2
- 内容: 「全て承認」を選択肢の先頭に配置すると、ユーザーが詳細を確認せずに一括承認するリスクがある
- 推奨: 「1件ずつ確認」を先頭（デフォルト的位置）に配置し、「全て承認」を最後にすることで、慎重な確認を促す
- impact: medium, effort: low

### I-4: Phase 2 Step 4のエラーハンドリング未定義 [efficiency]
- 対象: analysis.md Section F
- 内容: analysis.md Section Fで「Phase 2 Step 4: 返答内容（変更サマリ）をテキスト出力するのみ（失敗時の明示的なハンドリングは未定義）」と記載されている。改善適用が失敗した場合の処理フローが未定義
- 推奨: 改善適用失敗時の処理フロー（エラー表示+ロールバック提示、または継続可否の確認）を定義する
- impact: medium, effort: medium

### I-5: 指示の具体性: 「簡易チェック」の基準が曖昧 [stability]
- 対象: SKILL.md:58
- 内容: 「ファイル先頭に YAML frontmatter」とあるが、ファイル先頭の定義（先頭N行以内、空行を含むか等）が不明確
- 推奨: 具体的な検証方法を明示する（例: 「先頭10行以内に `---` で始まる行があり、その後の100行以内に `description:` を含む行がある」）
- impact: low, effort: low
