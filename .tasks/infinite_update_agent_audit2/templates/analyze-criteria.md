# Criteria Effectiveness Analysis

You are analyzing the effectiveness of evaluation criteria in an agent definition.

## Inputs

Read the following files:
1. **Agent definition**: `{agent_path}` — The agent to analyze
2. **Perspective** (if exists): `{perspective_path}` — Evaluation scope reference
3. **Per-agent scores** (if exists): `{scores_path}` — Historical performance data
4. **Improvement history** (if exists): `{improvement_history_path}` — Past changes

## Analysis Method

### For each evaluation criterion/instruction in the agent definition:

**a. Instruction Specificity**
- Detect vague expressions: "appropriately", "as needed", "consider", "if necessary"
- Detect contradictions between different sections
- Rate: Specific / Somewhat vague / Vague

**b. Signal-to-Noise Ratio (H/M/L)**
- HIGH: Targets frequent problems, low false positives, actionable
- MEDIUM: Interpretation varies, moderate utility
- LOW: Rare problems, noisy results → recommend deletion or reformulation

**c. Executability (E/D/I)**
- EXECUTABLE: Clear judgment criteria, mechanically checkable
- DIFFICULT: Depends on AI reasoning, unstable results
- INFEASIBLE: Requires unavailable context → recommend replacement

**d. Cost-Effectiveness (H/M/L)**
- HIGH: Low-medium context cost, high-value detection
- MEDIUM: Reasonable tradeoff
- LOW: High cost (extensive tracing required), low value

### If historical data exists:
- Cross-reference with improvement history to identify which criteria contributed to score gains/losses
- Identify criteria that have never contributed to detection improvements

## Output

Save findings to: `{findings_save_path}`

Format:
```markdown
# Criteria Effectiveness Analysis: {agent_name}

## Evaluation Table
| Criterion | Specificity | S/N | Executability | Cost-Eff | Judgment |
|-----------|------------|-----|--------------|----------|----------|

## Findings

### CE-01: {Title}
- **Severity**: critical/improvement/info
- **Description**: {What is wrong}
- **Recommendation**: {What to change}
- **Expected Impact**: {Why this helps}

### CE-02: ...
```

Return exactly:
```
dim: criteria_effectiveness
critical: {count}
improvement: {count}
info: {count}
```
