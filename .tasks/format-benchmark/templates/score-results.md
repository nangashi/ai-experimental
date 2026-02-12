# Scoring Template

## Task

Read all detection result files and answer keys, then score each detection run against the planted problems.

## Input Files

### Answer Keys
{answer_key_files}

### Detection Results
{result_files}

## Scoring Method

For each planted problem in each answer key, determine whether the corresponding detection result identified it:

- **○ (detected)**: A finding clearly identifies this specific problem, referencing the same section/text and describing the same issue type
- **△ (partial)**: A finding touches on related concerns in the same area but doesn't precisely identify the core problem
- **× (missed)**: No finding addresses this problem

Also identify:
- **False Positives**: Findings that don't correspond to any planted problem AND aren't legitimate new discoveries
- **Bonus**: Legitimate problems discovered that aren't in the answer key (real issues the test agent has)

## Scoring for Each Run

For each (answer-key, result) pair:
1. Read the answer key to get the list of planted problems
2. Read the result file to get the list of findings
3. For each planted problem, search the findings for a match
4. Count false positives and bonus discoveries

## Output

Save the complete scoring to `{scoring_save_path}`:

```markdown
# Format Benchmark Scoring Report

## Run-by-Run Results

### {run_name}
- Detector: {style} ({dimension})
- Test Agent: {agent_name}
- Result File: {path}

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| {id} | {type} | ○/△/× | {finding_id or N/A} | {brief notes} |

Metrics:
- Planted: {N}
- Detected (○): {N}
- Partial (△): {N}
- Missed (×): {N}
- False Positives: {N}
- Bonus Discoveries: {N}
- Recall: {detected/planted}
- Recall (lenient, ○+△): {(detected+partial)/planted}

(repeat for all runs)

## Comparative Summary

### CE Dimension: audit-style vs design-style

| Metric | audit-style (alpha) | design-style (alpha) | audit-style (beta) | design-style (beta) |
|--------|-------------------|---------------------|-------------------|---------------------|
| Recall (strict) | | | | |
| Recall (lenient) | | | | |
| False Positives | | | | |
| Bonus | | | | |

### SA Dimension: audit-style vs design-style

(same table format)

### Overall

| Metric | audit-style avg | design-style avg |
|--------|----------------|-----------------|
| Recall (strict) | | |
| Recall (lenient) | | |
| False Positives | | |
| Bonus | | |

## Conclusion

{Which style performed better overall? What patterns emerge? Specific strengths/weaknesses of each style?}
```
