# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 Step 4 のパス変数リストに {task_id}, {existing_perspectives_summary}, {target} を追加 | REG-1: 批評テンプレートのパス変数未定義（リグレッション） |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md（修正）
**対応フィードバック**: stability: REG-1: 批評テンプレートのパス変数未定義（リグレッション）

**変更内容**:
- Line 93-96: 批評エージェント（4並列）へのプロンプトのパス変数リスト

現在の記述:
```markdown
各エージェントへのプロンプト:
`.claude/skills/agent_bench_new/templates/perspective/{テンプレート名}` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective_path}`: Step 3 で保存した perspective ファイルの絶対パス
- `{agent_path}`: エージェント定義ファイルの絶対パス
```

改善後の記述:
```markdown
各エージェントへのプロンプト:
`.claude/skills/agent_bench_new/templates/perspective/{テンプレート名}` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective_path}`: Step 3 で保存した perspective ファイルの絶対パス
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{task_id}`: 各批評エージェントのタスクID（TaskUpdate で完了報告に使用）
- `{existing_perspectives_summary}`: 既存の観点定義リスト（critic-effectiveness.md で境界明確性検証に使用）
- `{target}`: エージェントの入力型（"design" / "code" / 等。critic-completeness.md で必須要素リスト作成に使用）
```

**追加実装ノート**:
- `{task_id}`: Phase 0 Step 4 で Task ツールを使って4つの批評エージェントを並列起動する際、各タスクのIDを取得して渡す必要がある
- `{existing_perspectives_summary}`: Phase 0 Step 2 で `.claude/skills/agent_bench_new/perspectives/design/*.md` および `perspectives/code/*.md` を Glob で列挙し、各ファイル名（拡張子なし）のリストを構成する。例: "design: security, performance, consistency, structural-quality, reliability / code: security, best-practices, consistency, maintainability, performance"
- `{target}`: Phase 0 Step 1 の agent_name 導出時に判定済み（`*-design-reviewer` → "design", `*-code-reviewer` → "code", パターン不一致の場合は agent_path から推定またはユーザーに確認）

## 新規作成ファイル
（該当なし）

## 削除推奨ファイル
（該当なし）

## 実装順序
1. SKILL.md のパス変数リスト更新（Line 93-96）
   - 理由: 単一ファイルの修正のみで依存関係なし。批評テンプレートが参照する変数を親スキルが渡すように修正することで、Phase 0 Step 4 の実行時エラーを防ぐ

## 注意事項
- Phase 0 Step 4 の実装部分で、{task_id}, {existing_perspectives_summary}, {target} の値を実際に渡すロジックを追加する必要がある
- {task_id} は Task ツールの戻り値から取得
- {existing_perspectives_summary} は Glob で perspectives/ 配下のファイルを列挙して構成
- {target} は Phase 0 Step 1 で導出済みの値を使用（未導出の場合はエージェント定義から推定）
