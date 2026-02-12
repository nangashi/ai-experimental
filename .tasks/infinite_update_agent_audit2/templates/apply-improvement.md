# Apply Improvement to Analysis Sub-Agent Template

You are applying a specific improvement to an analysis sub-agent template's working copy.

## Inputs

Read the following files:
1. **Current sub-agent template**: `{sub_agent_path}` — The current working copy of the analysis template
2. **Improvement specification**: The improvement to apply (provided below)

## Improvement to Apply

```
{improvement_description}
```

## Task

### Step 1: Understand the Change
- Read the current analysis sub-agent template carefully
- Identify the exact sections/lines affected by the improvement
- Understand the intent of the change

### Step 2: Apply the Change
- Use the Edit tool to modify the analysis sub-agent template
- Make ONLY the change described in the improvement specification
- Do NOT make additional changes, improvements, or refactoring
- Preserve the overall structure and formatting of the template

### Step 3: Validate
- Verify the change was applied correctly
- Verify no unintended side effects (e.g., broken markdown, lost sections)
- Verify the template is still valid and complete (all required sections present)

## Output

Save the modified template to: `{sub_agent_path}` (overwrite the working copy)

Return exactly:
```
status: applied
sections_modified: {list of section names}
lines_changed: {approximate count}
change_summary: {one-line description of what was changed}
```
