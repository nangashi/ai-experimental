# Scoring Template

You are scoring analysis sub-agent outputs against an answer key to measure the sub-agent's problem detection effectiveness.

## Inputs

Read the following files:
1. **Answer key**: `{answer_key_path}` — Expected problems and detection criteria
2. **Run 1 result**: `{run1_path}` — First analysis output
3. **Run 2 result**: `{run2_path}` — Second analysis output
4. **Analysis perspective**: `{perspective_path}` — For bonus/penalty scope judgment (the analysis dimension's perspective)
5. **Scoring rubric**: `.claude/skills/agent_audit2/scoring-rubric.md` — Section 1B and 2B

## Task

### For Each Run (run1 and run2):

**Step 1: Score each embedded problem**
For each problem P01-P{N} in the answer key:
- ○ (Detected) = 1.0 pt — Detection criteria fully met
- △ (Partial) = 0.5 pt — Related category mentioned but core issue not captured
- × (Not detected) = 0.0 pt — No relevant finding

**Step 2: Count bonuses**
- Valid findings NOT in the answer key but within the analysis dimension's scope: +0.5 pt each (max 5)

**Step 3: Count penalties**
- Out-of-scope findings (outside the analysis dimension) or factually incorrect analysis: -0.5 pt each

**Step 4: Calculate run score**
```
run_score = Σ(detection_scores) + (bonus_count × 0.5) - (penalty_count × 0.5)
```

### Aggregate Scores

```
mean = (run1_score + run2_score) / 2
sd = |run1_score - run2_score| / √2
```

### Stability Assessment
- SD ≤ 0.5: High stability
- 0.5 < SD ≤ 1.0: Medium stability
- SD > 1.0: Low stability

## Output

Save detailed scoring to: `{scoring_save_path}`

Scoring file format:
```markdown
# Scoring: {sub_agent_name} Round {round}

## Per-Problem Detection

| Problem | Severity | Run1 | Run2 | Notes |
|---------|----------|------|------|-------|
| P01: {title} | Critical | ○/△/× | ○/△/× | {brief note} |
...

## Bonus Findings
| Run | Finding | Valid | Score |
...

## Penalty Findings
| Run | Finding | Reason | Score |
...

## Summary
- Run 1: {score} ({bonus}B, {penalty}P)
- Run 2: {score} ({bonus}B, {penalty}P)
- **Mean: {mean}**
- **SD: {sd}**
- Stability: High/Medium/Low
```

Return exactly:
```
mean: {mean}
sd: {sd}
run1: {run1_score}
run2: {run2_score}
stability: high/medium/low
detected: {count of ○}
partial: {count of △}
missed: {count of ×}
```
