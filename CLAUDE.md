# CLAUDE.md

Prompt/agent definition files for Claude Code skills and subagents. Primary artifacts are markdown, not application code.

## Conventions

- `old/` subdirectories contain deprecated files. Do not reference or modify them.

## Workflow

### Before Starting
- **Clarify first**: Confirm unclear or ambiguous requirements before proceeding.
- **Echo understanding**: List your understanding of the requirements as bullet points before starting work.

### While Working
- **Per-item approval**: When suggesting multiple changes, present each item individually with its problem, risk, importance, and proposed fix. Wait for the user's response before applying or moving to the next item. Do not use AskUserQuestion.

## Instructions

| file | use-when |
|------|----------|
| `.claude/instructions/agent-utilization-guide.md` | Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate |
| `.claude/instructions/prompt-engineering-findings.md` | Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection) |
| `.claude/instructions/llm-evaluation-design.md` | LLM出力の評価ワークフローやルブリックを設計するとき |
| `.claude/instructions/ai-coding-antipatterns.md` | Generating or editing code (self-check for dead code, design principle boundaries, and over-abstraction) |
| `.claude/instructions/ai-workflow-design.md` | スキルやマルチステップのAIワークフローを設計するとき |
