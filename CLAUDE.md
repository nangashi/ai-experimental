# CLAUDE.md

Prompt/agent definition files for Claude Code skills and subagents. Primary artifacts are markdown, not application code.

## Conventions

- `old/` subdirectories contain deprecated files. Do not reference or modify them.
- `.agent_bench/`, `.agent_audit/`, `.skill_audit/` are transient skill output directories, not edit targets.

## Workflow

### Before Starting
- **Clarify first**: Use the AskUserQuestion tool to confirm unclear or ambiguous requirements before proceeding. This project develops prompt/agent definitions where misinterpreted intent leads to wasted iteration cycles.
- **Echo understanding**: When receiving complex or multi-step instructions, list your understanding of the requirements as bullet points before starting work. Wait for user confirmation before proceeding. Skip this for simple, unambiguous single-step tasks.

### While Working
- **One proposal at a time**: When suggesting multiple independent changes, present them individually and use the AskUserQuestion tool to get user approval for each before proceeding. Do not batch unrelated proposals into a single action.

### On Compaction
- When compacting, preserve: current skill/agent file paths being worked on, phase progress state, and any user decisions made during the session.

## Knowledge

| file | use-when |
|------|----------|
| `.claude/knowledge/agent-utilization-guide.md` | Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate |
| `.claude/knowledge/prompt-engineering-findings.md` | Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance) |
| `.claude/knowledge/ai-coding-antipatterns.md` | Generating or editing code (self-check for dead code accumulation and adjacent code alteration) |
