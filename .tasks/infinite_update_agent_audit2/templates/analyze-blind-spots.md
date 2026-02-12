# Blind Spot Detection Analysis

You are identifying systematic detection failures in an agent definition based on historical evaluation data.

**Note**: This analysis requires historical scoring data with 2+ rounds. If insufficient data exists, return zero findings.

## Inputs

Read the following files:
1. **Agent definition**: `{agent_path}` — The agent to analyze
2. **Perspective**: `{perspective_path}` — Expected detection categories
3. **Per-agent scores**: `{scores_path}` — Historical score data
4. **Scoring files**: Read all scoring files in `{test_docs_dir}` to aggregate per-problem detection rates

## Analysis Method

### Step 1: Aggregate Detection Rates
For each problem category in the perspective:
- Count total problems presented across all rounds
- Count detection rate (○ count / total)
- Count partial rate (△ count / total)
- Count miss rate (× count / total)

### Step 2: Classify Blind Spots

**Persistent Blind Spot** (severity: improvement):
- Detection rate < 50% across 2+ rounds
- The agent consistently misses this category

**Structural Blind Spot** (severity: critical):
- Detection rate = 0% across ALL available rounds
- No variant of the agent has ever detected this category
- This requires content-level change, not structural optimization

### Step 3: Map to Agent Definition
For each blind spot:
- Identify what is missing/inadequate in the agent definition
- Determine if it's a criteria gap, knowledge gap, or instruction gap

## Output

Save findings to: `{findings_save_path}`

Format:
```markdown
# Blind Spot Analysis: {agent_name}

## Detection Rate Summary
| Category | Total Presented | ○ Rate | △ Rate | × Rate | Status |
|----------|----------------|--------|--------|--------|--------|

## Findings

### BS-01: {Title}
- **Severity**: critical (structural) / improvement (persistent)
- **Category**: {affected category}
- **Detection Rate**: {X}% across {N} rounds
- **Root Cause**: {What's missing in agent definition}
- **Recommendation**: {Specific content to add/change}

### BS-02: ...
```

Return exactly:
```
dim: blind_spots
rounds_analyzed: {count}
critical: {count}
improvement: {count}
info: {count}
```
