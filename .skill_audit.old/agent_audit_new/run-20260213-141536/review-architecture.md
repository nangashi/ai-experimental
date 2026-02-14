### アーキテクチャレビュー結果

#### 重大な問題
なし

#### 改善提案
- [テンプレート外部化の過剰適用]: [templates/apply-improvements.md] 40行のテンプレートは7行超の基準を満たすが、内容の80%が変更適用ルール（二重適用チェック、優先順序、ツール選択）の詳細であり、サブエージェントが Read で毎回取得するには冗長。SKILL.md Phase 2 Step 4 に主要ルール（5-7行）をインライン化し、テンプレートを削除するか、テンプレートを参照カタログとして `.claude/skills/agent_audit_new/reference/` に移動する方が効率的 [impact: medium] [effort: low]

- [知見蓄積の不在]: [SKILL.md] スキルは反復的な最適化ループを持たない（1回実行で完結）が、同一エージェント定義に対して複数回 `/agent_audit` が実行される可能性がある。現在は `.agent_audit/{agent_name}/audit-approved.md` に承認結果を保存するが、次回実行時に前回の指摘を参照する仕組みがない。`resolved-issues.md` の existence check + 重複検出ロジックがあるが、これは resolved-issues.md が手動管理される前提。自動蓄積（ラウンド間での approved findings の統合）がないため、ユーザーが同じ指摘を繰り返し承認する可能性がある。改善案: Phase 0 で `.agent_audit/{agent_name}/audit-approved.md` を Read し、前回承認済み findings を resolved-issues.md 形式で次元エージェントに渡す [impact: medium] [effort: medium]

- [サブエージェントモデル指定の最適化]: [SKILL.md Phase 1, Phase 2 Step 4] 全サブエージェントに `model: "sonnet"` を指定しているが、Phase 2 Step 4 の改善適用サブエージェントは以下の理由で haiku で十分: (1) 入力は構造化された findings リスト、(2) 処理は Edit による機械的な文字列置換が主体、(3) 判断が必要なのは適用順序決定と矛盾チェックのみ。Phase 1 の次元エージェントは深い推論が必要なため sonnet が適切 [impact: low] [effort: low]

- [バックアップ検証の不完全性]: [SKILL.md Phase 2 Step 4] バックアップ作成後の検証が `test -f {backup_path}` のみ。ファイルが 0 bytes で作成された場合や cp コマンドが部分的に失敗した場合を検出できない。`test -s {backup_path}` (非空確認) または `diff -q {agent_path} {backup_path}` (内容一致確認) の追加を推奨 [impact: low] [effort: low]

- [Phase 1 エラーハンドリングの曖昧性]: [SKILL.md Phase 1] findings ファイルが「空でない」の定義が不明確。0 bytes を除外するのか、frontmatter のみのファイルを除外するのか、Summary セクションが存在すれば OK なのか。`test -s` による非空確認と、Summary セクション行数確認（最小 5 行など）の二段階検証を推奨 [impact: low] [effort: low]

- [次元エージェントのパス変数渡し方式の非効率]: [SKILL.md Phase 1] 各次元エージェントへの Task prompt で `agent_path`, `findings_save_path`, `agent_name` を3つの変数として渡しているが、次元エージェント定義ファイル内で `{agent_path}`, `{findings_save_path}`, `{agent_name}` をパス変数として期待している。これは「Read template + path variables」パターンに準拠しているが、Task prompt 内でパス変数を列挙するのではなく、次元エージェント定義ファイル自体に「パス変数」セクションを設け、SKILL.md から渡す方が一貫性が高い。現状でも動作するため、重要度は低い [impact: low] [effort: low]

- [構造検証の範囲不足]: [SKILL.md Phase 2 検証ステップ] 改善適用後の検証が YAML frontmatter の存在確認のみ。以下の構造破壊を検出できない: (1) Findings セクションの消失（次元エージェント定義の場合）、(2) Workflow Phase セクションの消失（SKILL.md の場合）、(3) 必須フィールド（name, description）の削除。改善案: エージェントグループに応じた必須セクション/フィールドリストを定義し、検証ステップで確認する [impact: medium] [effort: medium]

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 部分的 | apply-improvements.md (40行) は基準を満たすが、内容の80%が詳細ルールで冗長。インライン化または参照カタログ化を推奨 |
| サブエージェント委譲 | 準拠 | 「Read template + follow instructions + path variables」パターンを一貫して使用。次元エージェント（Phase 1）と改善適用（Phase 2 Step 4）の両方で適用 |
| ナレッジ蓄積 | 部分的 | 反復ループなし（1回実行完結型）だが、同一エージェントへの複数回実行で前回 approved findings を参照する仕組みが不在。resolved-issues.md は手動管理前提 |
| エラー耐性 | 準拠 | 主要なエラーパス（全次元失敗、バックアップ失敗、検証失敗）は定義済み。部分失敗時の続行ロジックも明示（Phase 1: 一部成功で続行、Phase 2: 承認0件で Phase 3 直行） |
| 成果物の構造検証 | 部分的 | Phase 2 検証ステップで YAML frontmatter のみ確認。必須セクション/フィールドの存在確認がないため、構造破壊を検出できないケースがある |
| ファイルスコープ | 準拠 | 全参照がスキル内部（`.claude/skills/agent_audit_new/` 配下）で完結。外部参照なし |

#### 良い点
- [3ホップパターンの回避]: Phase 1 で各次元エージェントが findings をファイルに保存し、Phase 2 Step 1 で親が Read で収集する設計。親が次元エージェントの返答を改善適用サブエージェントに中継する非効率なパターンを回避している
- [サブエージェントの粒度]: Phase 1 で 3-5 次元を並列起動する設計は適切。各次元が独立した分析軸（CE, SA, IC, WC, OF, DC）を持ち、並列化による効率化が明確
- [パス変数の一貫性]: 全サブエージェント（次元エージェント、改善適用）で `{variable_name}` 形式のパス変数を使用し、SKILL.md でパス生成ロジックを一元管理。テンプレート内に暗黙的なパス構築ロジックがない
