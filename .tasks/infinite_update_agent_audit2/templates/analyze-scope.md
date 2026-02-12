# Scope Alignment Analysis

You are analyzing whether the scope boundaries of an agent definition are clear and appropriate.

## Inputs

Read the following files:
1. **Agent definition**: `{agent_path}` — The agent to analyze
2. **Perspective** (if exists): `{perspective_path}` — Expected scope reference
3. **Per-agent scores** (if exists): `{scores_path}` — For penalty pattern analysis
4. **Recent scoring files** (if exist): Check `{test_docs_dir}` for scoring files with penalty data

## Analysis Method

### Static Analysis (always)
1. Check for explicit "out of scope" documentation
2. Verify boundary case documentation (what is/isn't covered)
3. Assess scope breadth: narrow enough to be actionable, broad enough to be useful
4. Identify overlapping scope with other reviewer perspectives
5. Check for implicit scope assumptions that should be made explicit

### Data-Driven Analysis (if scoring data exists)
1. Aggregate penalty patterns from scoring results
2. Cross-reference with perspective's "out of scope" section
3. Identify recurring out-of-scope violations
4. Identify ambiguous boundary areas where the agent inconsistently applies scope

## Output

Save findings to: `{findings_save_path}`

Format:
```markdown
# Scope Alignment Analysis: {agent_name}

## Scope Assessment
- Explicit scope defined: Yes/No/Partial
- Out-of-scope documented: Yes/No/Partial
- Boundary clarity: Clear/Ambiguous/Missing

## Findings

### SA-01: {Title}
- **Severity**: critical/improvement/info
- **Description**: {What is wrong with the scope}
- **Recommendation**: {How to fix}
- **Expected Impact**: {Why this matters}

### SA-02: ...
```

Return exactly:
```
dim: scope_alignment
critical: {count}
improvement: {count}
info: {count}
```
