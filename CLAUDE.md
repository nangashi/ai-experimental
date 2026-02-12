# CLAUDE.md

## General Guidelines

### Before Starting
- **Clarify first**: Always use the AskUserQuestion tool to confirm unclear or ambiguous requirements before proceeding.
- **Echo understanding**: When receiving complex or multi-step instructions, list your understanding of the requirements as bullet points before starting work. Wait for user confirmation before proceeding. Skip this for simple, unambiguous single-step tasks.

### While Working
- **Minimal changes only**: Make only the changes explicitly requested. Do not refactor, reorganize, or add features beyond the scope of the current task. Reuse existing components and conventions.
- **One proposal at a time**: When suggesting multiple independent changes, present them individually and use the AskUserQuestion tool to get user approval for each before proceeding. Do not batch unrelated proposals into a single action.
- **No unauthorized changes**: Do not install tools/daemons, modify dependency files, CI/CD configs, or database schemas without asking first. When something fails, report the issue and ask for guidance.
- **Stop after repeated failures**: If a fix fails twice, stop and report what you've tried instead of continuing to attempt different approaches.

### Before Completing
- **Self-review and verify**: Before reporting a task as done, critically review your changes for edge cases, missing error handling, and unintended side effects. Run the project's existing lint, format, and test commands to confirm correctness.
