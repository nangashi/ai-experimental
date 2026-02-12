# Analysis Sub-Agent Execution

You are executing an analysis sub-agent template against a test agent definition to evaluate the sub-agent's problem detection capability.

## Inputs

Read the following files:
1. **Analysis sub-agent template**: `{sub_agent_path}` — The analysis template to execute (this defines what analysis to perform)
2. **Test agent definition**: `{test_agent_path}` — The agent definition to analyze (this is the input to the analysis)
3. **Design perspective** (if specified): `{design_perspective_path}` — The perspective file matching the test agent's domain

Optional (for blind-spots testing):
4. **Simulated scores**: `{simulated_scores_path}` — Historical score data
5. **Simulated scoring dir**: `{simulated_scoring_dir}` — Directory containing scoring files

## Task

### Step 1: Read the Analysis Template

Read `{sub_agent_path}` to understand what analysis to perform. This template defines:
- What to look for in the agent definition
- How to categorize findings
- What output format to produce

### Step 2: Prepare Inputs for the Template

Map the template's expected inputs to the actual files:
- `{agent_path}` in the template → `{test_agent_path}` (the test agent definition)
- `{perspective_path}` in the template → `{design_perspective_path}` (if available)
- `{scores_path}` in the template → `{simulated_scores_path}` (if available)
- `{test_docs_dir}` in the template → `{simulated_scoring_dir}` (if available)
- `{findings_save_path}` in the template → `{result_save_path}`

### Step 3: Execute the Analysis

Follow the analysis template's instructions precisely:
- Read all specified input files
- Perform the analysis as described
- Be thorough — examine every section of the test agent definition
- Stay within the analysis dimension's scope
- Report findings in the template's specified format

### Step 4: Save Results

Save the analysis output (findings) to: `{result_save_path}`

## Important Notes

- Execute the analysis template EXACTLY as written — do not add your own analysis dimensions
- If the template references optional files that don't exist, skip those sections (the template should handle this)
- Produce output in the EXACT format specified by the analysis template
- Do NOT look at any answer key — this is a blind evaluation

## Return Format

Return exactly:
```
status: complete
output_path: {result_save_path}
findings_count: {total number of findings reported}
critical: {count}
improvement: {count}
info: {count}
```
