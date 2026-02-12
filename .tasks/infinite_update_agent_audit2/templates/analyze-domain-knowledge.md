# Domain Knowledge Adequacy Analysis

You are verifying that the agent definition contains adequate domain knowledge for effective detection.

**Note**: This analysis benefits from historical data. Without it, perform static-only analysis.

## Inputs

Read the following files:
1. **Agent definition**: `{agent_path}` — The agent to analyze
2. **Perspective**: `{perspective_path}` — Expected domain knowledge reference
3. **Cross-agent knowledge** (if exists): `{knowledge_path}` — Patterns from other agents
4. **Per-agent scores** (if exists): `{scores_path}` — Historical performance data

## Analysis Method

### Static Analysis (always)
1. Identify domain-specific terms and concepts the agent should know
2. Check if the agent definition includes relevant checklists or heuristics
3. Verify the agent has enough context to make informed judgments
4. Compare domain knowledge breadth against the perspective's scope

### Data-Driven Analysis (if historical data exists)
1. Identify knowledge.md insights NOT reflected in the agent definition
2. Detect domain-specific regression patterns (detection drops in specific domains)
3. Check for counterproductive instructions (knowledge suggests they harm performance)
4. Cross-reference effective patterns from other agents that could apply

## Output

Save findings to: `{findings_save_path}`

Format:
```markdown
# Domain Knowledge Analysis: {agent_name}

## Knowledge Coverage Assessment
- Perspective categories covered: {N}/{total}
- Missing domain areas: {list}
- Counterproductive instructions: {count}

## Findings

### DK-01: {Title}
- **Severity**: improvement (all DK findings are improvement-level)
- **Description**: {What domain knowledge is missing or incorrect}
- **Evidence**: {From historical data or static analysis}
- **Recommendation**: {Specific knowledge to add/modify}

### DK-02: ...
```

Return exactly:
```
dim: domain_knowledge
critical: 0
improvement: {count}
info: {count}
```
