# Design-Style Rewrite Guide

## Interface Contract (MUST preserve exactly)

1. **YAML frontmatter**: Keep existing `name` and `description` fields unchanged
2. **Input Variables**: `{agent_path}`, `{findings_save_path}`, `{agent_name}`
3. **Finding ID Prefix**: Keep the same prefix (CE, SA, IC, DC, WC, OF)
4. **Severity levels**: critical / improvement / info (3 levels only)
5. **Findings file format**: Must include `## Summary` section with:
   ```
   - critical: {N}
   - improvement: {N}
   - info: {N}
   ```
6. **Return format**: Must be exactly:
   ```
   dim: {PREFIX}
   critical: {N}
   improvement: {N}
   info: {N}
   ```

## Design-Style Structure Template

```markdown
---
name: {KEEP EXISTING}
description: {KEEP EXISTING}
---

{Rich persona with adversarial mindset declaration}

{Scope boundary statement - KEEP FROM EXISTING if present}

## Task

### Input Variables
- `{agent_path}`: Path to the agent definition file to analyze
- `{findings_save_path}`: Path where analysis findings will be saved
- `{agent_name}`: Name/identifier of the agent being analyzed

### Steps
1. Read `{agent_path}` to load the target agent definition.
2. Analyze using the two-phase process below.

**Analysis Process - Detection-First, Reporting-Second**:
Conduct your review in two distinct phases: first detect all problems comprehensively (including adversarially), then organize and report them.

---

## Phase 1: Comprehensive Problem Detection

**Objective**: Identify all problems without concern for output format or organization. **Use adversarial thinking to uncover subtle violations.**

Read the entire agent definition and systematically detect problems using multiple detection strategies:

### Detection Strategy 1: {Primary strategy}
{Concrete steps with adversarial questions}

### Detection Strategy 2: {Secondary strategy}
{Concrete steps with adversarial questions}

### Detection Strategy 3: {Cross-reference/pattern detection}
{Concrete steps}

### Detection Strategy 4: Antipattern Catalog
{Dimension-specific antipattern list with concrete examples}

(Optional: Detection Strategy 5 if the dimension warrants it)

Phase 1 Output: Create an unstructured, comprehensive list of ALL detected problems. Use bullet points. Do not organize by severity yet. Focus on completeness over organization.

---

## Phase 2: Organization & Reporting

**Objective**: Take the comprehensive problem list from Phase 1 and organize it into a clear, prioritized report.

### Severity Rules
{KEEP FROM EXISTING - the severity classification rules}

### Finding ID Prefix: {KEEP FROM EXISTING}

## Output Format

Save findings to `{findings_save_path}`:

{KEEP THE EXISTING output format template - with the evaluation table, findings blocks, and summary section}

## Return Format

Return ONLY the following summary:

{KEEP THE EXISTING return format}
```

## Key Design-Style Principles

1. **Rich Persona**: Start with a domain expert persona that includes adversarial mindset
2. **Detection-First**: Phase 1 is purely about FINDING problems, not formatting them
3. **Multiple Detection Strategies**: Use 4-5 distinct detection angles to maximize coverage
4. **Adversarial Questions**: For each strategy, ask "How could this be exploited?" or "How could this technically comply while being defective?"
5. **Antipattern Catalog**: Provide concrete, named antipatterns with examples
6. **Phase 2 is reporting only**: Classify and format the Phase 1 findings

## Reference Files

For CE and SA, use these benchmark-proven design-style versions as reference:
- CE reference: `.tasks/format-benchmark/detectors/design-style-ce.md`
- SA reference: `.tasks/format-benchmark/detectors/design-style-sa.md`
