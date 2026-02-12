# Meta-Review: Self-Improvement of prompt.md

You are reviewing the effectiveness of the agent_audit2 self-improvement system and potentially improving its main prompt.

## Architecture Context

agent_audit2 optimizes its own analysis sub-agents (analyze-criteria, analyze-scope, analyze-blind-spots, analyze-domain-knowledge). Each iteration:
1. Generates a test agent definition with embedded analysis issues
2. Runs an analysis sub-agent against it (2x for stability)
3. Scores detection effectiveness
4. Analyzes detection gaps
5. Applies improvements to the sub-agent template
6. Re-evaluates to measure improvement

The goal is to improve each sub-agent's ability to detect issues in agent definitions.

## Inputs

Read the following files:
1. **History**: `.task/infinite_update_agent_audit2/history.md` — Last 10-15 entries
2. **Knowledge**: `.task/infinite_update_agent_audit2/knowledge.md` — Accumulated insights
3. **Current prompt**: `.task/infinite_update_agent_audit2/prompt.md` — The prompt to review
4. **Meta-review log**: `.task/infinite_update_agent_audit2/meta-review-log.md` — Past changes

## Analysis

### Step 1: Pattern Detection
From the last 10+ history entries, identify:
- Success rate per state (which states fail most?)
- Improvement effectiveness by sub-agent (which sub-agents improve most?)
- Score trends across sub-agents (improving? plateauing?)
- Common error patterns
- Average improvement effect size

### Step 2: Process Assessment
Evaluate:
- Are test agent definitions discriminating enough? (baseline SD, score variance across sub-agents)
- Is the detection gap analysis finding actionable issues? (ratio of findings to effective improvements)
- Are improvements being applied correctly to templates? (revert rate)
- Is knowledge accumulating usefully? (patterns reused in later improvements)
- Is convergence happening too fast or too slow?

### Step 3: Identify Improvement Opportunities
Consider modifying prompt.md in these **MODIFIABLE** areas:
- Detection gap analysis guidance (what to look for in gaps)
- Improvement selection heuristics (priority formula)
- Test agent definition generation guidance (problem difficulty, domain selection)
- Convergence thresholds
- State transition conditions
- Template references (add new templates if needed)

**IMMUTABLE** areas (NEVER modify):
- Safety Constraints section
- State machine structure (state names and basic transitions)
- File path conventions
- Quick Start section
- META_REVIEW section and this template
- History log format

### Step 4: Apply Changes (if warranted)
- Only make changes supported by evidence from history
- Each change must have: what, why (evidence), expected effect, risk
- Make small, targeted changes (not wholesale rewrites)
- Record all changes in meta-review-log.md

## Output

### If changes are made to prompt.md:
Update `.task/infinite_update_agent_audit2/meta-review-log.md` with:

```markdown
## Meta-Review #{N} (Iteration {X}, {timestamp})

### Data Summary
- Iterations analyzed: {range}
- Sub-agents evaluated: {list with counts}
- Average improvement: {pt}
- State failure rate: {percentage}

### Changes Applied
1. {Change description}
   - Evidence: {from history}
   - Before: `{old text snippet}`
   - After: `{new text snippet}`
   - Expected effect: {description}

### No Changes Made
(If no changes warranted, explain why)
```

Return exactly:
```
changes_made: {count}
changes_description: {brief summary or "none"}
iterations_analyzed: {count}
overall_assessment: {one-line assessment of system health}
```
