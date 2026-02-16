# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | .claude/skills/agent_bench_new/SKILL.md | 修正 | テンプレート読み込みパスを8箇所修正 | C-1/R-1: テンプレート読み込みパスの未修正 |

## 各ファイルの変更詳細

### 1. .claude/skills/agent_bench_new/SKILL.md（修正）
**対応フィードバック**: C-1/R-1: テンプレート読み込みパスの未修正 [stability, architecture]

**変更内容**:
- 123行: `.claude/skills/agent_bench/templates/knowledge-init-template.md` → `.claude/skills/agent_bench_new/templates/knowledge-init-template.md`
- 145行: `.claude/skills/agent_bench/templates/phase1a-variant-generation.md` → `.claude/skills/agent_bench_new/templates/phase1a-variant-generation.md`
- 163行: `.claude/skills/agent_bench/templates/phase1b-variant-generation.md` → `.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md`
- 182行: `.claude/skills/agent_bench/templates/phase2-test-document.md` → `.claude/skills/agent_bench_new/templates/phase2-test-document.md`
- 247行: `.claude/skills/agent_bench/templates/phase4-scoring.md` → `.claude/skills/agent_bench_new/templates/phase4-scoring.md`
- 270行: `.claude/skills/agent_bench/templates/phase5-analysis-report.md` → `.claude/skills/agent_bench_new/templates/phase5-analysis-report.md`
- 322行: `.claude/skills/agent_bench/templates/phase6a-knowledge-update.md` → `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md`
- 334行: `.claude/skills/agent_bench/templates/phase6b-proven-techniques-update.md` → `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md`

## 新規作成ファイル
なし

## 削除推奨ファイル
なし

## 実装順序
1. SKILL.md の8箇所のパス修正（依存関係なし、単一ファイルの修正のため1ステップで完了）

## 注意事項
- この修正により、Phase 0 knowledge初期化、Phase 1A/1B/2/4/5/6A/6B のサブエージェント委譲で正しいテンプレートファイルが読み込まれるようになる
- 既存のワークフロー構造は変更されず、パス参照のみの修正のため影響範囲は限定的
- 全8箇所とも同一パターンの修正（`agent_bench` → `agent_bench_new`）のため、一貫性が保たれる
