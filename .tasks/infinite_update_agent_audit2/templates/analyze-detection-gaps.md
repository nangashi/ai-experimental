# Detection Gap Analysis

You are diagnosing why an analysis sub-agent missed or partially detected known problems, and generating prioritized improvement recommendations for the sub-agent's template.

## Inputs

Read the following files:
1. **Scoring results**: `{scoring_path}` — Per-problem ○/△/× scores and summary
2. **Answer key**: `{answer_key_path}` — Expected problems with detection criteria
3. **Sub-agent template**: `{sub_agent_path}` — The analysis template being evaluated
4. **Analysis output (run 1)**: `{run1_output_path}` — What the sub-agent actually found (first run)
5. **Analysis output (run 2)**: `{run2_output_path}` — What the sub-agent actually found (second run)
6. **Cross-agent knowledge**: `{knowledge_path}` — Effective/ineffective patterns from other sub-agents
7. **Improvement history** (if exists): `{improvement_history_path}` — Past improvement attempts

## Analysis Method

### Step 1: Gap Identification

For each problem in the answer key, compare expected detection with actual results:

**Missed problems (×)**:
- Read the answer key's detection criteria for this problem
- Search both run outputs for any mention of this issue
- Identify which section/instruction in the sub-agent template SHOULD have caught this
- Classify the gap: `instruction_missing` (no relevant instruction), `instruction_vague` (instruction exists but too vague), `instruction_wrong` (instruction contradicts detection)

**Partially detected problems (△)**:
- Identify what the sub-agent DID find vs. what was expected
- Determine what additional specificity in the template would elevate △ to ○
- Classify: `insufficient_detail` (instruction lacks specific indicators), `wrong_focus` (instruction targets adjacent but not core issue)

**False positives (penalty findings)**:
- For each out-of-scope or factually incorrect finding
- Trace back to which template instruction caused the scope drift
- Classify: `scope_too_broad` (instruction encourages out-of-scope analysis), `missing_constraint` (no guard against this type of false positive)

### Step 2: Pattern Analysis

- Group gaps by template section (which parts of the template need the most improvement?)
- Identify recurring gap types (e.g., "multiple misses due to vague language in section X")
- Cross-reference with knowledge.md for patterns that worked on other sub-agents

### Step 3: Generate Improvement Recommendations

For each identified gap pattern, formulate a concrete template improvement:

**Priority calculation**: Priority = (Impact × Confidence) / Effort
- **Impact** (1-5): Number of problems affected × severity weight
- **Confidence** (1-5): How certain the improvement will help (higher if similar pattern worked before)
- **Effort** (1-5): Lines of template change required

### Step 4: Select Top Improvements

Select 1-3 improvements:
- Prioritize by score
- Prefer critical > high-confidence > independent changes
- Filter out improvements already tried (check improvement_history_path)
- Each must be independently applicable (no dependencies between improvements)

## Output

Save findings to: `{findings_save_path}`

Format:
```markdown
# Detection Gap Analysis: {sub_agent_name}

## Gap Summary
| Problem | Severity | Run1 | Run2 | Gap Type | Template Section | Notes |
|---------|----------|------|------|----------|-----------------|-------|

## Gap Patterns
- {Pattern 1}: {N} problems affected, template section "{section}", type: {gap_type}
- {Pattern 2}: ...

## Selected Improvements (Top 1-3)

### IMP-01: {Title} (from gap pattern: {pattern})
- **Priority Score**: {score}
- **Gap Type**: instruction_missing / instruction_vague / scope_too_broad / ...
- **Affected Problems**: P01, P05, P08
- **Template Section**: {specific section name/location to modify}
- **What to Change**: {Precise edit description — what text to add/modify/remove}
- **Expected Effect**: {Which problems this should fix, estimated score improvement}
- **Risk**: {What could go wrong}

### IMP-02: ...

## Deferred Improvements
| ID | Title | Priority | Reason for Deferral |
```

## Return Format

Return exactly:
```
dim: detection_gaps
total_gaps: {count of × and △}
false_positives: {count of penalty findings}
selected_improvements: {count}
deferred: {count}
already_tried: {count}
top_improvement: {brief description}
```
