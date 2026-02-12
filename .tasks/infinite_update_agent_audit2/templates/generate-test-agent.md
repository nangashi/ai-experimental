# Test Agent Definition & Answer Key Generation

You are generating a test agent definition with embedded analysis issues and an answer key for evaluating an analysis sub-agent.

## Inputs

Read the following files:
1. **Analysis perspective**: `{perspective_path}` — Contains problem categories and examples for the target analysis dimension
2. **Sub-agent scores** (if exists): `{scores_path}` — Check past domains to avoid repetition
3. **Sub-agent name**: `{sub_agent_name}` — The analysis sub-agent being tested
4. **Test type**: `{test_type}` — "definition" or "definition+history"

## Task

### Step 1: Choose Domain

Pick a **reviewer agent domain** NOT used in previous rounds (check scores file for history).
Example domains: security reviewer, performance reviewer, consistency reviewer, reliability reviewer, code-quality reviewer, accessibility reviewer, API-design reviewer, data-modeling reviewer, testing-strategy reviewer

### Step 2: Generate Test Agent Definition

Create a realistic agent definition (100-200 lines) for the chosen reviewer domain. The definition should look like a genuine design review agent with:
- Role description and purpose
- Evaluation scope and criteria
- Out-of-scope section (may be incomplete as a problem)
- Detection strategies or checklists
- Output format instructions
- Severity classification guidelines

**Embed 8-10 problems** naturally into the definition:
- **Severity distribution**: Critical(3), Medium(4), Minor(3)
- **Category distribution**: Perspective-specific problems(6-7) + Adjacent areas(2-3) + Subtle issues(1)
- Problems must read naturally within the agent definition — not obviously planted
- Include cross-section problems (issues visible only when reading multiple sections together)

**IMPORTANT**: The embedded problems are issues that the analysis sub-agent should DETECT when analyzing this agent definition. For example:
- For criteria-effectiveness: embed vague criteria, contradictions, infeasible checks
- For scope-alignment: embed missing scope boundaries, ambiguous overlaps
- For blind-spots-detection: embed patterns in simulated history data showing systematic misses
- For domain-knowledge: embed knowledge gaps, outdated recommendations

### Step 3: Generate Answer Key

```markdown
# Answer Key

## Execution Conditions
- **Analysis Dimension**: {sub_agent_name}
- **Test Agent Domain**: {chosen domain} reviewer
- **Embedded Problems**: N

## Embedded Problems List

### P01: {Title}
- **Category**: {category from analysis perspective}
- **Severity**: Critical/Medium/Minor
- **Location**: Section name or description of where the problem is embedded
- **Problem Description**: {What the analysis issue is and why it's a problem}
- **Detection Criteria**:
  - ○ (Detected): {Specific condition — the analysis sub-agent identifies this exact issue}
  - △ (Partial): {Related issue mentioned but core problem not identified}
  - × (Not detected): {No relevant finding about this issue}

## Bonus Problem List
| ID | Category | Content | Bonus Condition |
```

### Step 4: Generate Simulated History (only if test_type = "definition+history")

For analyze-blind-spots testing, also generate:

**a. Simulated scores.md** (2-3 rounds):
```markdown
# Score History

| Round | Mean | SD | Domain | Type | Date |
|-------|------|----|--------|------|------|
| 1 | 8.5 | 0.5 | e-commerce | baseline | 2026-01-01 |
| 2 | 9.0 | 0.0 | healthcare | post | 2026-01-15 |
| 3 | 8.0 | 1.0 | fintech | baseline | 2026-02-01 |
```

**b. Simulated scoring files** (per round, with ○/△/× per problem category):
- Include deliberate blind spot patterns: certain categories consistently scored × across rounds
- Include false positive patterns: categories that appear to be blind spots but have valid △ detections
- Save to `{simulated_scores_path}` and `{simulated_scoring_dir}/`

### Step 5: Quality Validation

Verify:
- [ ] Agent definition is 100-200 lines
- [ ] 8-10 problems embedded
- [ ] Severity: Critical(3), Medium(4), Minor(3)
- [ ] Perspective problems: 6-7
- [ ] Adjacent problems: 2-3
- [ ] Natural embedding (not obviously planted)
- [ ] Detection criteria are specific and unambiguous
- [ ] Bonus list included
- [ ] (If definition+history) Simulated data contains clear blind spot patterns

## Output

Save files:
1. Test agent definition → `{test_agent_save_path}`
2. Answer key → `{answer_key_save_path}`
3. (If definition+history) Simulated scores → `{simulated_scores_path}`
4. (If definition+history) Simulated scoring files → `{simulated_scoring_dir}/round-{N}-scoring.md`

## Return Format

Return exactly:
```
domain: {chosen reviewer domain}
lines: {line count of test agent definition}
problems: {count}
distribution: critical={N}, medium={N}, minor={N}
perspective_problems: {N}
adjacent_problems: {N}
test_type: {definition or definition+history}
design_perspective: {path to the design perspective matching the chosen domain, e.g., .claude/skills/agent_audit2/perspectives/design/security.md}
```
