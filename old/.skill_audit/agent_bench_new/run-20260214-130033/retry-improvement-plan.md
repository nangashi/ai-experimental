# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | テンプレートファイル参照パスを `.claude/skills/agent_bench/` から `.claude/skills/agent_bench_new/` に変更 | I-1 |

## 変更ステップ

### Step 1: I-1: 参照整合性: 外部スキルディレクトリへの依存
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- 行85: `.claude/skills/agent_bench/templates/perspective/generate-perspective.md` → `.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md`
- 行96: `.claude/skills/agent_bench/templates/perspective/{テンプレート名}` → `.claude/skills/agent_bench_new/templates/perspective/{テンプレート名}`
- 行128: `.claude/skills/agent_bench/templates/knowledge-init-template.md` → `.claude/skills/agent_bench_new/templates/knowledge-init-template.md`
- 行150: `.claude/skills/agent_bench/templates/phase1a-variant-generation.md` → `.claude/skills/agent_bench_new/templates/phase1a-variant-generation.md`
- 行170: `.claude/skills/agent_bench/templates/phase1b-variant-generation.md` → `.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md`
- 行188: `.claude/skills/agent_bench/templates/phase2-test-document.md` → `.claude/skills/agent_bench_new/templates/phase2-test-document.md`
- 行253: `.claude/skills/agent_bench/templates/phase4-scoring.md` → `.claude/skills/agent_bench_new/templates/phase4-scoring.md`
- 行276: `.claude/skills/agent_bench/templates/phase5-analysis-report.md` → `.claude/skills/agent_bench_new/templates/phase5-analysis-report.md`
- 行325: `.claude/skills/agent_bench/templates/phase6a-knowledge-update.md` → `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md`
- 行337: `.claude/skills/agent_bench/templates/phase6b-proven-techniques-update.md` → `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md`

## 新規作成ファイル
（該当なし）

## 削除推奨ファイル
（該当なし）
