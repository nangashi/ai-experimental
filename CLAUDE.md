# CLAUDE.md

## General Guidelines

- **Clarify first**: Always use the AskUserQuestion tool to confirm unclear or ambiguous requirements before proceeding.
- **Minimal changes only**: Make only the changes explicitly requested. Do not refactor, reorganize, or add features beyond the scope of the current task. Reuse existing components and conventions.
- **No unauthorized changes to project config**: Do not install additional tools/daemons, modify dependency files, CI/CD configs, or database schemas without asking first. When something fails, report the issue and ask for guidance.
- **Stop after repeated failures**: If a fix fails twice, stop and report what you've tried instead of continuing to attempt different approaches.
- **Self-review before completing**: Before reporting a task as done, critically review your own changes for edge cases, missing error handling, and unintended side effects.
- **Verify changes**: After implementation, run the project's existing lint, format, and test commands to confirm correctness.
