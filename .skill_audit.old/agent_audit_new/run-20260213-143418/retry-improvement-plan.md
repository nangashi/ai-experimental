# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | `{findings_save_path}` のパス変数定義を実際の使用形式に一致させる | I-2: テンプレート内の未定義プレースホルダ（部分的解決） |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md（修正）
**対応フィードバック**: I-2: テンプレート内の未定義プレースホルダ（部分的解決） [stability]

**変更内容**:
- パス変数セクション（35行目）: `{findings_save_path}` の定義を更新
  - 現在: `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md の絶対パス`
  - 変更後: `.agent_audit/{agent_name}/run-{timestamp}/audit-{ID_PREFIX}.md の絶対パス`
  - 理由: Phase 0 Step 6 で実際に使用されるパス形式（`run-$(date +%Y%m%d-%H%M%S)/` サブディレクトリを含む）と定義を一致させる

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序
1. SKILL.md のパス変数定義を修正（依存関係なし、単独変更）

依存関係の検出方法:
- 本改善は単一ファイルの修正のみで完結する
- 他ファイルへの影響なし（パス変数の定義のみの変更）

## 注意事項
- 変更箇所は定義セクションのみで、実際の使用箇所（Phase 1 の Task prompt、Phase 2 Step 1 の Read 等）には影響しない
- 変更後も既存のワークフロー（Phase 0 → Phase 1 → Phase 2 → Phase 3）は変更なく動作する
- `{timestamp}` はプレースホルダとして記載（実際の値は `$(date +%Y%m%d-%H%M%S)` で生成される）
