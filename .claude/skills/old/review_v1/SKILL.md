---
allowed-tools: Grep, Read, WebFetch, TodoWrite, WebSearch
description: Review specified files or directories
---

Review the specified file(s) or directory.

## Usage

The user specifies a target file path or directory path as an argument. Multiple paths can be specified separated by spaces. If no argument is given, ask the user for the target path.

## Process

1. Determine whether each specified path is a file or a directory.
   - **File**: Read the file directly.
   - **Directory**: List the files in the directory (non-recursively by default; if the user requests recursive review, include subdirectories).
2. Read each file and perform a comprehensive review using subagents for key areas:

- code-quality-reviewer
- performance-reviewer
- test-coverage-reviewer
- documentation-accuracy-reviewer
- security-code-reviewer

3. Instruct each subagent to only provide noteworthy feedback. Once they finish, consolidate the feedback and present only the feedback that you also deem noteworthy.

## Output

- Report findings per file, grouped by review area.
- Use specific file paths and line numbers when referencing issues.
- Keep feedback concise and actionable.
- Provide a summary at the end with overall observations.