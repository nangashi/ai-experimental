# Agent Audit2: Self-Improving Analysis Sub-Agent Optimizer

## Quick Start

1. Read `.task/infinite_update_agent_audit2/state.json`
2. Check the `current_state` field
3. Jump to the matching `## State: {current_state}` section below
4. Execute ONLY that section's instructions
5. Update `state.json` (write to `state.json.tmp` first, then `mv state.json.tmp state.json`)
6. Append to `history.md` if the state produced a meaningful action
7. Exit

The `next_action_hint` field in state.json tells you what to do in plain language. Use it for fast orientation.

**Architecture**: This system optimizes its own analysis sub-agents (analyze-criteria, analyze-scope, analyze-blind-spots, analyze-domain-knowledge) by testing their problem detection capability against test agent definitions with known embedded issues.

---

## Safety Constraints [IMMUTABLE — DO NOT MODIFY THIS SECTION]

You may ONLY create/modify files under these paths:
- `.task/infinite_update_agent_audit2/**`
- `.claude/skills/agent_audit2/**`
- `.claude/skills/test_*/**`

NEVER WRITE to any file outside the allowed paths.
All reference files (perspectives, scoring rubric) are within `.claude/skills/agent_audit2/`.

---

## State: INIT

**Purpose**: First-run setup. Copy analysis sub-agent templates to working directory.

**Steps**:
1. Read `agent-rotation.json` to get the list of sub-agents
2. Create directories if they don't exist:
   - `.task/infinite_update_agent_audit2/sub-agents/`
   - `.task/infinite_update_agent_audit2/per-agent/{sub-agent-name}/test-docs/` for each sub-agent
3. For each sub-agent in `agent-rotation.json`, copy the `source_path` file to two locations:
   - `sub-agents/{sub-agent-name}.md` (working copy — will be modified by improvements)
   - `sub-agents/{sub-agent-name}.baseline.md` (original — never modified, for reverting)
4. Verify all files exist

**State transition**: Set `current_state` to `SELECT_AGENT`, `next_action_hint` to "Select first sub-agent for evaluation"

**History**: Log "Workspace initialized with {N} sub-agents"

---

## State: SELECT_AGENT

**Purpose**: Choose the next sub-agent to work on using round-robin, skipping converged sub-agents.

**Steps**:
1. Read `agent-rotation.json`
2. Check if meta-review is due: if `meta_review_counter` >= 10, go to META_REVIEW instead
3. Starting from `current_index`, find the next agent with `status: "active"`
4. If no active agents remain:
   - If `global_convergence_resets` == 0: Reset all to "active", set `convergence_threshold` to 3, `score_improvement_threshold` to 0.3, increment `global_convergence_resets`. Log: "First convergence cycle complete. Resetting with stricter thresholds."
   - If `global_convergence_resets` >= 1: Transition to `FULLY_CONVERGED`
5. Update `current_index` to point past the selected agent (for round-robin)
6. Set `current_agent` in state.json

**State transition**: `BASELINE_EVAL` (set `next_action_hint` to "Generate test agent definition and evaluate {sub-agent} baseline")

---

## State: BASELINE_EVAL

**Purpose**: Establish the current detection performance baseline for the selected analysis sub-agent.

**Steps**:
1. Read the sub-agent's working copy: `sub-agents/{current_agent}.md`
2. Read `agent-rotation.json` to get `perspective_path` and `test_type` for this sub-agent
3. Determine the round number from the sub-agent's `total_rounds` + 1

4. **Generate test agent definition + answer key** using the Task tool:
   - Launch a `general-purpose` subagent with the content of `templates/generate-test-agent.md`
   - Replace template variables:
     - `{perspective_path}` → the sub-agent's perspective_path from agent-rotation.json
     - `{scores_path}` → `per-agent/{current_agent}/scores.md`
     - `{sub_agent_name}` → current_agent name
     - `{test_type}` → from agent-rotation.json (e.g., "definition" or "definition+history")
     - `{test_agent_save_path}` → `per-agent/{current_agent}/test-docs/round-{NNN}-test.md`
     - `{answer_key_save_path}` → `per-agent/{current_agent}/test-docs/round-{NNN}-key.md`
     - (if definition+history) `{simulated_scores_path}` → `per-agent/{current_agent}/test-docs/round-{NNN}-sim-scores.md`
     - (if definition+history) `{simulated_scoring_dir}` → `per-agent/{current_agent}/test-docs/round-{NNN}-sim/`
   - Parse the return value to get `design_perspective` path

5. **Run analysis 2 times in parallel** using the Task tool:
   - Launch 2 `general-purpose` subagents with `templates/run-analysis.md`
   - For each run:
     - `{sub_agent_path}` → `sub-agents/{current_agent}.md`
     - `{test_agent_path}` → the test agent definition from step 4
     - `{design_perspective_path}` → the `design_perspective` returned from step 4
     - (if definition+history) `{simulated_scores_path}` and `{simulated_scoring_dir}` from step 4
     - `{result_save_path}` → `per-agent/{current_agent}/test-docs/round-{NNN}-run1.md` / `round-{NNN}-run2.md`

6. **Score results** using the Task tool:
   - Launch a `general-purpose` subagent with `templates/score-results.md`
   - `{answer_key_path}` → the answer key from step 4
   - `{run1_path}` → run1 result, `{run2_path}` → run2 result
   - `{perspective_path}` → the sub-agent's perspective_path (analysis perspective, for bonus/penalty scope)
   - `{scoring_save_path}` → `per-agent/{current_agent}/test-docs/round-{NNN}-scoring.md`

7. Record baseline score in `state.json` → `current_cycle.baseline_score` and `baseline_sd`
8. Also store `baseline_test_doc`, `baseline_answer_key`, `baseline_domain`
9. Append a row to `per-agent/{current_agent}/scores.md`:
   ```
   | {round} | {mean} | {sd} | {domain} | baseline | {date} |
   ```
   Create the file with headers if it doesn't exist.

**State transition**: `ANALYZE` (set `next_action_hint` to "Run detection gap analysis on {sub-agent}")

**History**: Log baseline evaluation results with score and domain.

---

## State: ANALYZE

**Purpose**: Analyze why the sub-agent missed or partially detected problems, and generate improvement recommendations.

**Steps**:
1. Launch a **single** `general-purpose` subagent with `templates/analyze-detection-gaps.md`:
   - `{scoring_path}` → `per-agent/{current_agent}/test-docs/round-{NNN}-scoring.md`
   - `{answer_key_path}` → `per-agent/{current_agent}/test-docs/round-{NNN}-key.md`
   - `{sub_agent_path}` → `sub-agents/{current_agent}.md`
   - `{run1_output_path}` → `per-agent/{current_agent}/test-docs/round-{NNN}-run1.md`
   - `{run2_output_path}` → `per-agent/{current_agent}/test-docs/round-{NNN}-run2.md`
   - `{knowledge_path}` → `knowledge.md`
   - `{improvement_history_path}` → `per-agent/{current_agent}/improvement-history.md` (if exists)
   - `{findings_save_path}` → `per-agent/{current_agent}/current-findings.md`

2. Record the analysis summary

**State transition**: `PLAN` (set `next_action_hint` to "Select improvements to apply for {sub-agent}")

**History**: Log analysis completion with gap counts.

---

## State: PLAN

**Purpose**: Select improvements from detection gap analysis and create an execution plan.

**Steps**:
1. Read `per-agent/{current_agent}/current-findings.md`
2. Read `per-agent/{current_agent}/improvement-history.md` (if exists) to filter already-tried improvements
3. Read `knowledge.md` for cross-sub-agent patterns
4. From the "Selected Improvements" section, extract 1-3 improvements
5. If no viable improvements exist:
   - Increment `consecutive_no_improvement` for this sub-agent in `agent-rotation.json`
   - If `consecutive_no_improvement` >= `convergence_threshold`: set status to "converged"
   - Transition to `SELECT_AGENT`
6. Store improvements in `state.json` → `current_cycle.improvements_planned` as an array of objects:
   ```json
   [{"id": "IMP-01", "title": "...", "description": "...", "expected_effect": "..."}]
   ```
7. Set `improvement_index` to 0

**State transition**: `IMPLEMENT` (set `next_action_hint` to "Apply improvement IMP-01 to {sub-agent}")

**History**: Log plan with selected improvements.

---

## State: IMPLEMENT

**Purpose**: Apply one improvement from the queue to the sub-agent's working copy.

**Steps**:
1. Get the current improvement from `improvements_planned[improvement_index]`
2. Launch a `general-purpose` subagent with `templates/apply-improvement.md`:
   - `{sub_agent_path}` → `sub-agents/{current_agent}.md`
   - `{improvement_description}` → the improvement's description field
3. Verify the change was applied (read the modified file)
4. Append to `improvements_applied` in state.json

**State transition**: `POST_EVAL` (set `next_action_hint` to "Evaluate {sub-agent} after improvement {IMP-XX}")

---

## State: POST_EVAL

**Purpose**: Evaluate the sub-agent after applying improvements. Same flow as BASELINE_EVAL but with a different test domain.

**Steps**:
1. Follow the same process as BASELINE_EVAL (generate test agent def, run analysis 2x, score)
2. **Important**: Use a DIFFERENT reviewer domain than the baseline evaluation
3. Store the post-eval score in `state.json` → `current_cycle.post_eval_score` and `post_eval_sd`
4. Save scoring to `per-agent/{current_agent}/test-docs/round-{NNN}-post-scoring.md`

**State transition**: `CONSOLIDATE` (set `next_action_hint` to "Compare scores and update knowledge for {sub-agent}")

---

## State: CONSOLIDATE

**Purpose**: Compare before/after scores, update knowledge, record Claude Code's assessment.

**Steps**:
1. Calculate score delta: `post_eval_score - baseline_score`
2. Determine verdict:
   - `delta > 1.0`: **EFFECTIVE** (significant improvement)
   - `0.5 <= delta <= 1.0`: **EFFECTIVE** if post_eval SD <= baseline SD, else **MARGINAL**
   - `delta < 0.5 and delta >= 0`: **MARGINAL**
   - `delta < 0`: **INEFFECTIVE** — revert the working copy:
     - Restore from `sub-agents/{current_agent}.baseline.md`
     - Re-read the baseline version and overwrite `sub-agents/{current_agent}.md`

3. Update `per-agent/{current_agent}/improvement-history.md`:
   ```
   | {round} | {improvement_title} | {gap_type} | {baseline_score} | {post_score} | {delta} | {verdict} |
   ```

4. Update `per-agent/{current_agent}/scores.md` with the post-eval score row

5. Update `knowledge.md`:
   - If EFFECTIVE: Add to "Effective Improvement Patterns" table
   - If INEFFECTIVE: Add to "Ineffective Improvement Patterns" table
   - Update "Sub-Agent Performance Summary" row
   - If a new general principle emerges, add to "General Principles" (max 20 lines — consolidate if needed)

6. Update `agent-rotation.json`:
   - Increment `total_rounds`
   - If EFFECTIVE: reset `consecutive_no_improvement` to 0, update `best_score` if new best
   - If MARGINAL or INEFFECTIVE: increment `consecutive_no_improvement`
   - Update `last_score`

7. **Append to history.md** with Claude Code's assessment:
   ```markdown
   ## Iteration {N} | {timestamp} | {sub_agent_name} | CONSOLIDATE
   - **Action**: Applied improvement "{title}" ({gap_type})
   - **Result**: {baseline_score} → {post_score} (Δ{delta:+.2f} pt), SD: {baseline_sd} → {post_sd}
   - **Verdict**: {EFFECTIVE/MARGINAL/INEFFECTIVE}
   - **Claude Codeの見解**: {Write 2-4 sentences assessing:
     - Current detection capability of this sub-agent
     - Which gap types have been addressed vs. remaining
     - Convergence estimate (0-100%): how close to optimal
     - Suggested next direction}
   ---
   ```

8. Determine next state:
   - If more improvements in queue AND last improvement was EFFECTIVE:
     Increment `improvement_index`, set `baseline_score` = `post_eval_score`, go to `IMPLEMENT`
   - If improvement was INEFFECTIVE: skip remaining improvements, go to next decision
   - Increment `meta_review_counter`
   - If `consecutive_no_improvement` >= `convergence_threshold`: set "converged", go to `SELECT_AGENT`
   - Otherwise: go to `SELECT_AGENT`

**State transition**: As determined above.

---

## State: META_REVIEW

**Purpose**: Self-improvement. Review the optimization process effectiveness and potentially modify prompt.md.

**Steps**:
1. Launch a `general-purpose` subagent with the content of `templates/meta-review.md`
   - The subagent will analyze history.md, knowledge.md, and prompt.md
   - It will make changes to prompt.md if warranted (respecting IMMUTABLE sections)
   - It will update meta-review-log.md with changes
2. Reset `meta_review_counter` to 0
3. Check if the meta-review detected revert conditions:
   - Read meta-review-log.md for the latest entry
   - If a previous meta-review's changes led to 3+ consecutive degradations, the subagent should have auto-reverted

**State transition**: `SELECT_AGENT` (set `next_action_hint` to "Continue with next sub-agent after meta-review")

**History**: Log meta-review completion with changes made (if any).

---

## State: FULLY_CONVERGED

**Purpose**: All sub-agents have converged after reset. Generate final report and stop the loop.

**Steps**:
1. Read `knowledge.md` for final summary
2. Read `agent-rotation.json` for all sub-agent scores
3. Generate a final report and append to history.md:
   ```markdown
   ## FINAL REPORT | {timestamp}

   ### Sub-Agent Performance Summary
   | Sub-Agent | Initial Score | Final Score | Best Score | Total Rounds | Improvements Applied |
   |-----------|--------------|------------|-----------|-------------|---------------------|
   {for each sub-agent from agent-rotation.json and knowledge.md}

   ### Key Findings
   {Top 5 effective improvement patterns from knowledge.md}

   ### Process Statistics
   - Total iterations: {iteration_count}
   - Meta-reviews performed: {count from meta-review-log.md}
   - Prompt.md modifications: {count}

   ### Claude Codeの最終見解
   {3-5 sentences summarizing:
    - Overall detection improvement achieved across all sub-agents
    - Most impactful template improvement patterns discovered
    - Remaining areas that would need human attention
    - Recommendations for next steps}
   ---
   ```
4. Create `STOP` file: Write "FULLY_CONVERGED at {timestamp}" to `.task/infinite_update_agent_audit2/STOP`

**State transition**: None (loop will terminate when run.sh detects STOP file)

---

## Utility: History Entry Format

When appending to `history.md`, use this format for non-CONSOLIDATE states:

```markdown
## Iteration {iteration_count} | {timestamp} | {sub_agent_name or "system"} | {state}
- **Action**: {Brief description of what was done}
- **Result**: {Outcome — scores, counts, status}
---
```

Use `date -Iseconds` via Bash tool to get the current timestamp.

---

## Utility: Error Handling

If any step in a state fails:
1. Set `last_error` in state.json with a description
2. Increment `error_count`
3. If `error_count >= 2` for the same state:
   - Log the error to history.md
   - Skip to the next logical state (ANALYZE→PLAN, PLAN→SELECT_AGENT, IMPLEMENT→SELECT_AGENT, etc.)
   - Reset `error_count` to 0
4. If `error_count < 2`: Keep the same state (retry on next iteration)

For state.json writes: Always write to `state.json.tmp` first, then use `mv .task/infinite_update_agent_audit2/state.json.tmp .task/infinite_update_agent_audit2/state.json`

---

## Utility: Scoring Quick Reference

Detection mode scoring (analysis sub-agents):
- ○ = 1.0 pt (detected), △ = 0.5 pt (partial), × = 0.0 pt (missed)
- Bonus: +0.5/valid extra finding within analysis dimension scope (max 5)
- Penalty: -0.5/out-of-scope or factual error
- Score = Σ(detection) + bonus - penalty
- Run 2x, report mean and SD
- Significant improvement: Δ > 1.0pt
- Moderate improvement: 0.5 ≤ Δ ≤ 1.0pt
- Marginal/noise: Δ < 0.5pt
