### 安定性レビュー結果

#### 重大な問題
- [条件分岐の完全性: Phase 2 Step 2a で "Other" 入力時の処理が未定義]: [SKILL.md] [L193] [ユーザーが "Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める] → [AskUserQuestionツールは選択肢UIによる制御を行うため「Other」でのテキスト入力は構造的に発生しない。この記述を削除し、選択肢を4つ明示（承認/スキップ/残りすべて承認/キャンセル）のみとする] [impact: medium] [effort: low]

- [参照整合性: テンプレート内の未定義変数]: [templates/apply-improvements.md] [L4, L5] [{approved_findings_path}, {agent_path}] → [これらの変数はSKILL.md L20-29のパス変数リストで定義されているため問題なし。ただし、SKILL.md L233-236でサブエージェントprompt内で変数を展開している（「{実際の agent_path の絶対パス}」）が、テンプレート側では波括弧付きプレースホルダを期待している。このミスマッチを修正: SKILL.md L235-236の変数展開を削除し、テンプレート側で使用される`{agent_path}`と`{approved_findings_path}`をそのまま渡す] [impact: high] [effort: low]

- [出力フォーマット決定性: Phase 1サブエージェント返答の抽出ロジックが複雑]: [SKILL.md] [L138] [件数はファイル内の `## Summary` セクションから抽出する（抽出失敗時は Grep を使用して findings ファイル内の `^### {ID_PREFIX}-` パターンを検索し、マッチ数から推定する。両方失敗した場合は `critical: 0, improvement: 0, info: 0` を使用する）] → [サブエージェントの返答フォーマットを必須とし、「エージェント定義内の「Return Format」セクションに従って返答してください」(L130) を「以下のフォーマットで必ず返答してください: `dim: {ID}\ncritical: {N}\nimprovement: {M}\ninfo: {K}`」に置き換える。findings ファイル内容からの推定フォールバックは削除する（サブエージェント失敗時は L139 のエラーハンドリング経路に統一）] [impact: high] [effort: medium]

#### 改善提案
- [指示の具体性: 曖昧表現「簡易チェック」]: [SKILL.md] [L69] [ファイル内容の簡易チェック] → [具体的な処理内容は明示されているが、見出しに曖昧表現が残っている。「frontmatter存在確認」など具体的な表現に変更] [impact: low] [effort: low]

- [指示の具体性: 曖昧表現「深い分析」]: [SKILL.md] [L8] [グループに応じた分析次元セットで深い分析を行います] → [「多次元の品質分析」など定量的な表現に変更] [impact: low] [effort: low]

- [冪等性: 出力ディレクトリの再実行時挙動]: [SKILL.md] [L92] [出力ディレクトリを作成する: `mkdir -p .agent_audit/{agent_name}/`] → [`mkdir -p`は既存ディレクトリがあってもエラーにならないため冪等性は満たしているが、Phase 1で生成されるfindings ファイルが上書きされることへの言及がない。「既存のaudit-*.mdファイルは上書きされます」を追記] [impact: medium] [effort: low]

- [条件分岐の完全性: Phase 2 Step 2の選択肢処理]: [SKILL.md] [L176-178] [AskUserQuestion で承認方針を確認: 「1件ずつ確認」/「全て承認」/「キャンセル」] → [各選択肢に対応する処理フローは記載されているが、選択肢の分岐構造が箇条書きのみで条件分岐として明示されていない。「ユーザー選択に応じて以下のいずれかを実行:」などの明示的な分岐表現を追加] [impact: low] [effort: low]

- [参照整合性: Phase 1で参照される各次元エージェント定義のパス存在確認]: [SKILL.md] [L100-103] [dimensions テーブル] → [`.claude/skills/agent_audit_new/agents/` 配下の各次元エージェント定義ファイル（例: `shared/instruction-clarity.md`, `evaluator/criteria-effectiveness.md` 等）の存在は暗黙の前提となっている。分析結果から実在確認済みだが、SKILL.md内に「各次元のエージェント定義は `.claude/skills/agent_audit_new/agents/{dim_path}.md` に配置されている前提」を明記すると参照整合性が向上] [impact: low] [effort: low]

- [出力フォーマット決定性: Phase 3の条件分岐による出力差異]: [SKILL.md] [L262-297] [Phase 2がスキップされた場合/Phase 2が実行された場合で異なる出力フォーマット] → [現在の実装で問題はないが、両ケースで共通のフィールド（エージェント名、ファイル、グループ、分析次元）と差分フィールド（検出件数、承認、変更詳細）を明確に分離した構造にすると、出力パーサーの実装が容易になる] [impact: low] [effort: medium]

- [冪等性: バックアップファイル名の重複可能性]: [SKILL.md] [L229] [cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)] → [同一秒内に複数回実行すると上書きされる可能性がある。`date +%Y%m%d-%H%M%S-%N`（ナノ秒）を使用するか、既存ファイルがある場合の連番付与を検討] [impact: low] [effort: low]

#### 良い点
- [Phase 1の並列分析とファイル経由のデータフロー]: 3-5次元の分析をサブエージェント並列実行し、結果をファイルに保存する設計により、3ホップパターンを回避し親コンテキストを節約している
- [Phase 2の per-item 承認とバックアップ機構]: ユーザーが各 finding を個別に確認でき、改善適用前に自動バックアップを作成することで不可逆操作の安全性を確保している
- [Phase 1のエラーハンドリング]: 一部次元の分析失敗時も成功次元の結果を使用して処理を継続し、全次元失敗時のみ終了する部分完了許容設計が適切
