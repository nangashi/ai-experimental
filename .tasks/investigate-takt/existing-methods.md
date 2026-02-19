# AI-Assisted Development Methodologies: Comprehensive Survey

This document surveys five prominent approaches to AI-assisted software development as of early 2026, analyzing their core philosophies, workflows, quality mechanisms, and trade-offs.

---

## 1. Spec-Driven Development (SDD)

### Core Philosophy and Workflow

Spec-Driven Development treats the **specification, not the code, as the primary artifact**. The core idea is "documentation first": write a structured specification that captures what the software must do, then let AI agents generate implementation plans and code from that specification. Code becomes a disposable, reproducible output of the spec, rather than the source of truth.

SDD typically follows a three-phase pipeline:

1. **Specify** -- Capture requirements as structured user stories, acceptance criteria, and constraints. The human defines the "what" and "why."
2. **Plan** -- Generate a technical design document describing architecture, components, dependencies, and data flows. The AI translates requirements into a blueprint.
3. **Implement** -- Break the plan into discrete tasks and generate code. Each task traces back to a design decision, which traces back to a requirement.

#### Major Tools

**Kiro (AWS):** Generates `requirements.md`, `design.md`, and `tasks.md` files in sequence. Requirements use EARS (Easy Approach to Requirements Syntax) notation -- e.g., `WHEN [condition] THE SYSTEM SHALL [behavior]` -- to produce testable statements. Design documents include sequence diagrams and component interactions. Implementation tasks are broken into sub-tasks with descriptions, expected outcomes, and dependencies. When Kiro begins coding, it references these specification documents rather than conversation history.

**spec-kit (GitHub):** Provides three slash commands -- `/speckit.specify`, `/speckit.plan`, `/speckit.tasks` -- that drive the workflow. A "constitution" document (`.specify/memory/constitution.md`) establishes non-negotiable project principles that the agent references during all phases. The tool creates branch-per-feature directory structures with automatic numbering. spec-kit is agent-agnostic and works with Claude Code, Cursor, Copilot, and others.

**Tessl:** Uses "steering tiles" -- markdown files installed into a `.tessl/` directory that become part of the agent's context via MCP. The agent follows the tile's methodology: it interviews the developer about requirements (one question at a time), writes specs before implementation, and pauses for approval. Tessl's Spec Registry contains 10,000+ pre-built specs for open-source libraries, each describing capabilities, tests, and API usage patterns, reducing hallucination of library APIs.

### How Requirements Are Communicated

Requirements are captured in versioned, structured markdown documents. The spec is explicit, reviewable, and committed alongside the code. AI agents read the spec files directly rather than relying on conversational context. Human intent flows through the spec, not through ad-hoc prompts.

### How Quality Is Ensured

- **Traceability:** Every line of code traces back through tasks to design to requirements. Changes to requirements propagate through the chain.
- **Drift detection:** SDD systems can continuously compare claimed behavior against actual behavior through contracts and validation checks.
- **Acceptance criteria:** Requirements are written in testable EARS notation, enabling automated verification.
- **Spec versioning:** Specs are version-controlled alongside code, creating an audit trail of decisions.

### Human Oversight

Humans own the specification. The human writes or approves requirements, reviews the generated design, and can modify the task breakdown before implementation begins. The AI proposes; the human validates at each gate. This creates natural approval checkpoints between phases.

### Reproducibility and Auditability

SDD's strongest quality. Specs are deterministic inputs; given the same spec, the same (or functionally equivalent) code can be regenerated. The spec-requirements-design-tasks chain provides complete auditability. Every decision is documented and traceable. Generated code is explicitly disposable -- it can be regenerated from specs without losing intent.

### Strengths

- Clear separation of concerns between requirements, design, and implementation
- Strong traceability from requirement to code
- Specifications are human-readable and reviewable by non-engineers
- Reduces "lost context" problem across sessions since specs are persistent files
- Works well for greenfield projects and well-defined features
- Agent-agnostic: specs can be consumed by any AI tool

### Weaknesses

- Upfront specification effort can feel heavyweight, especially for exploratory work
- Critics compare it to waterfall: the sequential specify-plan-implement pipeline can be rigid
- Iterative discovery (learning requirements through building) is not the natural mode
- Spec maintenance becomes a burden if requirements change frequently
- The specify phase requires skill in writing good requirements -- garbage-in, garbage-out still applies
- Less effective for brownfield/legacy codebases where the existing code IS the spec

---

## 2. Rules-Based Approach (CLAUDE.md / .cursorrules / AGENTS.md)

### Core Philosophy and Workflow

The rules-based approach embeds project-specific instructions, conventions, and constraints into files that AI coding agents automatically read at session start. Instead of re-explaining project context in every conversation, developers maintain persistent instruction files that serve as an "onboarding manual" for the AI agent. The agent follows these rules throughout its work, producing output consistent with the project's standards.

The key files in this ecosystem:

- **CLAUDE.md** -- Used by Claude Code. Automatically loaded at session start. Can exist at project root and in subdirectories for scoped instructions.
- **.claude/rules/** -- Directory of focused rule files, all auto-loaded. Allows modular organization.
- **.cursorrules** -- Used by Cursor. Similar purpose, tool-specific format.
- **.github/copilot-instructions.md** -- Used by GitHub Copilot.
- **AGENTS.md** -- An open standard backed by Google, OpenAI, Factory, Sourcegraph, and Cursor. Provides a single, tool-agnostic file that any agent can read. Standard markdown, no schema or lock-in. Supports monorepo patterns (nearest file in directory tree takes precedence).

#### The Fragmentation Problem

Before AGENTS.md, each tool had its own format: CLAUDE.md for Claude, .cursor/rules/ for Cursor, .github/copilot-instructions.md for Copilot, JULES.md for Google Jules. AGENTS.md aims to consolidate these into a single source of truth. As of early 2026, Claude Code still primarily uses CLAUDE.md, while most other tools have adopted AGENTS.md.

### How Requirements Are Communicated

Requirements are not directly communicated through rules files. Instead, rules files communicate **how** the agent should work: coding standards, architectural patterns, testing requirements, naming conventions, build commands, and project structure. Requirements for specific features are communicated through conversation or, optionally, through separate spec files referenced in the rules.

A well-structured rules file typically includes:
- **Tech stack and project structure** -- A map of the codebase
- **Build/test commands** -- `npm run test`, `cargo build`, etc.
- **Code style guidelines** -- "Use ES modules, not CommonJS"; "Always use functional components"
- **Architectural patterns** -- "State management via Zustand; see src/stores"
- **What NOT to do** -- Explicit prohibitions
- **Reference to instruction files** -- Pointers to deeper guidance loaded on-demand

### How Quality Is Ensured

- **Consistency:** Rules enforce uniform coding style, architectural patterns, and testing practices across all agent interactions.
- **Guardrails:** Explicit prohibitions prevent common mistakes (e.g., "never use `any` type in TypeScript").
- **Delegation to deterministic tools:** A key best practice is "never send an LLM to do a linter's job." Rules should point the agent to linters, formatters, and type checkers rather than relying on the LLM to enforce style.
- **Layered specificity:** Root-level rules for universal standards, subdirectory rules for component-specific patterns.

### Human Oversight

The rules file itself is the oversight mechanism -- it encodes the team's decisions about how work should be done. The human reviews and maintains the rules file, and can update it as the project evolves. However, the agent's compliance with rules is not formally verified; it depends on the LLM's instruction-following capability.

Practical limits exist: frontier models can follow approximately 150-200 instructions with reasonable consistency. Overloading the rules file degrades compliance.

### Reproducibility and Auditability

Rules files are version-controlled, so the instructions given to the agent at any point in time are auditable. However, reproducibility of outputs is limited: the same rules + the same prompt may produce different code across sessions due to LLM non-determinism. Rules ensure consistency of style and patterns, not deterministic output.

### Strengths

- Low overhead: a single markdown file, no tooling required
- Persistent across sessions: no need to re-explain context
- Compositional: root rules + subdirectory rules for layered specificity
- Improves with iteration: teams refine rules over time based on observed agent behavior
- Works with any type of task (not limited to greenfield development)
- Familiar format: just markdown, easy for any team member to read and edit

### Weaknesses

- No formal link between rules and output quality: compliance depends on the LLM's attention
- Rules are prescriptive ("how to work") but not descriptive ("what to build") -- they complement but don't replace requirements
- Can become bloated if not actively pruned; excessive rules degrade compliance
- No built-in mechanism to verify the agent actually followed the rules
- Fragmentation across tools (CLAUDE.md vs. AGENTS.md vs. .cursorrules) creates maintenance burden in multi-tool teams
- Rules capture implicit knowledge but can't capture all of it -- complex architectural decisions still require human judgment in context

---

## 3. Agentic Coding (Claude Code / Cursor / Copilot Agent Mode)

### Core Philosophy and Workflow

Agentic coding places an AI agent at the center of the development loop. The agent doesn't just suggest code -- it **plans, writes, tests, and iterates** autonomously across multiple files, executing multi-step tasks with minimal human intervention. The human provides high-level intent; the agent handles execution, error recovery, and verification.

The core execution pattern is an **agentic loop**: receive task, gather context (read files, search codebase), take action (edit files, run commands), verify results (run tests, check output), and iterate until the task is complete or the agent needs human input.

#### Tool-Specific Implementations

**Claude Code (Anthropic):** Terminal-first agent. Operates via a `while(tool_call)` loop -- the agent continues using tools (read, write, execute, search) until it produces a text response without tool calls. Can read any file, edit files, run shell commands, search the web, and interact with external services via MCP. Supports sub-agents via the Task tool for parallel workstreams. The loop naturally terminates when the agent judges the task complete.

**Cursor (Anysphere):** IDE-first agent. Cursor 2.0 introduced Composer, an agentic coding model that searches repos, edits multiple files, runs terminal commands, and iterates on errors. The agent interface presents changes like pull request diffs, making review natural. Supports up to 8 parallel agents working on the same project in isolated environments. Background agents can operate asynchronously, creating branches and PRs.

**GitHub Copilot Agent Mode:** Integrated into VS Code, JetBrains, Eclipse, and Xcode. Analyzes codebases, proposes multi-file edits, runs terminal commands and tests, and auto-corrects in a loop. Workspace-scoped: the agent can only modify files within the current workspace. Excels at low-to-medium complexity tasks in well-tested codebases.

### How Requirements Are Communicated

Requirements are communicated **conversationally**: the developer describes what they want in natural language, and the agent interprets and executes. This can range from a single sentence ("add pagination to the user list endpoint") to multi-paragraph descriptions with acceptance criteria.

The quality of the output depends heavily on prompt quality. Context augmentation comes from:
- Rules files (CLAUDE.md, AGENTS.md)
- Codebase analysis (the agent reads relevant files)
- Conversation history within a session
- External tools (web search, documentation via MCP)

### How Quality Is Ensured

- **Test-driven iteration:** Agents run tests after making changes and iterate until tests pass.
- **Self-correction:** Agents detect build failures, lint errors, and test failures, then attempt to fix them autonomously.
- **Diff-based review:** Changes are presented as diffs for human review before merging.
- **CI integration:** Changes go through standard CI pipelines (build, test, lint) before merging.
- **Permission model:** In interactive mode, agents request permission before executing potentially destructive operations (file deletion, shell commands).

### Human Oversight

Human oversight varies by mode:

- **Interactive mode:** The developer watches the agent work in real-time, can interrupt at any point to redirect, and approves destructive actions. The agent requests permission for operations like file writes and command execution.
- **Background/headless mode:** The agent works asynchronously (e.g., on a GitHub issue), creating a branch and PR. The human reviews the PR through standard code review practices.
- **Review discipline:** Regardless of mode, the human is expected to review diffs carefully, run critical tests independently, and verify architectural alignment before merging.

Current best practice treats AI agents as "super-assistants" rather than autonomous developers. Even the best agents (Claude Opus at 80.9% on SWE-bench) require human intervention on 1 in 5 tasks.

### Reproducibility and Auditability

Limited reproducibility: the same prompt may produce different implementations across sessions due to LLM non-determinism and varying context windows. Auditability is provided by:
- Git history (commits, branches, PRs)
- Conversation logs (session transcripts)
- Diff review (what changed and why)

There is no formal trace from requirements to implementation unless combined with SDD or other spec-based approaches.

### Strengths

- Highest developer productivity for well-scoped tasks: the agent handles implementation details
- Natural language interface: low barrier to entry
- Self-correcting: agents iterate on errors without human prompting
- Works on existing codebases: agents read and understand the codebase in context
- Flexible: can handle anything from one-line fixes to multi-file refactors
- Integrates with existing workflows (git, CI, code review)

### Weaknesses

- Output quality is highly variable: depends on task complexity, codebase clarity, and prompt quality
- Accuracy drops significantly on complex tasks (16% on hard Terminal-Bench tasks)
- Can introduce subtle bugs that pass tests but violate unstated invariants
- Context window limitations: agents may miss distant but relevant code
- "Code churn" -- AI-generated code is rewritten shortly after merging at nearly double historical rates
- Security vulnerabilities: AI co-authored code shows 2.74x higher rates of security issues
- Experienced developers report being 19% slower in some studies (July 2025), suggesting productivity gains are not universal
- No inherent mechanism for architectural consistency across multiple agent sessions

---

## 4. Multi-Agent Frameworks (LangGraph / CrewAI / AutoGen / OpenAI Agents SDK)

### Core Philosophy and Workflow

Multi-agent frameworks orchestrate **multiple specialized AI agents** to collaborate on tasks that exceed the capability of a single agent. Instead of one monolithic agent, work is decomposed across agents with distinct roles, tools, and responsibilities. The frameworks differ primarily in their **orchestration model**: how agents coordinate, communicate, and hand off work.

As of 2026, 72% of enterprise AI projects involve multi-agent architectures (up from 23% in 2024).

#### Framework Architectures

**LangGraph (LangChain)** -- **State machine model.** Agents are nodes in a directed graph with edges defining transitions. State flows through the graph; conditional edges enable branching logic. Provides checkpointing, rollback, and explicit error handling via error edges.
- **Key abstraction:** Graph with nodes (agents/functions), edges (transitions), and state
- **Orchestration:** Deterministic graph traversal with conditional routing
- **Error recovery:** Failure encoded directly in the graph; nodes branch to error edges, trigger compensating actions, or roll back to checkpoints
- **Best for:** Complex, multi-step workflows requiring fine-grained control, auditability, and debugging

**CrewAI** -- **Role-based model.** Agents are defined like team members with roles, goals, and tool access. A "manager" agent delegates tasks to specialists and aggregates results. Two-layer architecture: Crews (dynamic role-based collaboration) + Flows (deterministic event-driven orchestration).
- **Key abstraction:** Crew of agents with roles, goals, and backstories
- **Orchestration:** Manager delegates to specialists; supports sequential and parallel task execution
- **Error recovery:** Task-level error boundaries; the manager can reassign or escalate without restarting the entire crew
- **Best for:** Production systems with clear role decomposition and hierarchical task delegation

**AutoGen (Microsoft)** -- **Conversation-based model.** Everything is framed as asynchronous conversation among agents. Each agent (assistant, tool executor, or human proxy) posts messages, waits, and reacts. Structured turn-taking enables iterative refinement loops.
- **Key abstraction:** Agents as conversation participants exchanging messages
- **Orchestration:** Asynchronous message-passing; supports group chat, nested conversations, and flexible routing
- **Error recovery:** Conversation-level retry and human escalation
- **Best for:** Iterative refinement tasks (code generation + review cycles), scenarios with external waits
- **Note:** Microsoft merged AutoGen with Semantic Kernel into a unified "Microsoft Agent Framework" (GA expected Q1 2026) with production SLAs and multi-language support

**OpenAI Agents SDK** (replaced Swarm in March 2025) -- **Lightweight tool-centric model.** Agents are defined with roles, tools, and triggers. The SDK provides a minimal runtime focused on handoffs between agents.
- **Key abstraction:** Agent with tools and handoff functions
- **Orchestration:** Simple Python-based; strong in agent handoffs but lacks built-in parallel execution
- **Error recovery:** Manual; relies on developer-implemented logic
- **Best for:** Simple multi-agent pipelines, rapid prototyping, OpenAI ecosystem integration

### How Requirements Are Communicated

Requirements are typically communicated programmatically:
- Agent definitions include system prompts describing their role and capabilities
- Task descriptions are passed as structured inputs to the orchestration layer
- Inter-agent communication happens via messages, shared state, or tool outputs
- Human-in-the-loop can inject requirements or corrections at defined checkpoints

### How Quality Is Ensured

- **Specialization:** Each agent focuses on a narrow domain, reducing the scope for errors
- **Iterative refinement:** Multiple agents review and critique each other's output (e.g., writer + reviewer pattern)
- **State management:** Frameworks like LangGraph maintain explicit state, enabling rollback and checkpointing
- **Tool integration:** Agents can invoke external validators, linters, test suites, and APIs
- **MCP (Model Context Protocol):** Provides a universal protocol for agents to connect to any tool through a single interface

### Human Oversight

- **LangGraph:** Human approval nodes can be inserted at any point in the graph
- **CrewAI:** Manager agent can escalate to human; human proxy agents participate as crew members
- **AutoGen:** Human proxy agent participates in conversations; humans can inject messages at any turn
- **OpenAI SDK:** Developer-defined escalation points through handoff functions

### Reproducibility and Auditability

- **LangGraph:** Strongest auditability -- graph structure is explicit, state transitions are logged, checkpoints enable replay
- **CrewAI:** Task logs trace agent actions; role definitions are auditable
- **AutoGen:** Conversation logs provide audit trail; however, asynchronous messaging can make reasoning harder to follow
- **OpenAI SDK:** Minimal built-in logging; depends on developer instrumentation

### Strengths

- Handles tasks too complex for a single agent through decomposition
- Enables parallel execution (multiple agents working simultaneously)
- Natural fit for review/critique workflows (writer + reviewer)
- Specialization reduces per-agent cognitive load
- Framework-level error handling and recovery
- Growing ecosystem of integrations (MCP, tool APIs, observability platforms)

### Weaknesses

- Significant engineering overhead to set up and maintain agent pipelines
- Debugging multi-agent interactions is fundamentally harder than debugging a single agent
- Inter-agent communication can introduce cascading errors or infinite loops
- Frameworks are rapidly evolving and not yet stable (API-breaking changes are common)
- Orchestration complexity can exceed the task complexity it's meant to manage
- Cost multiplier: N agents = N times the LLM inference cost
- Most frameworks are designed for backend/pipeline tasks, not interactive coding in an IDE
- Lack of standardization: migrating between frameworks requires rewriting orchestration logic

---

## 5. Vibes-Based Coding (Vibe Coding)

### Core Philosophy and Workflow

Vibe coding is the most informal approach: the developer describes what they want to a large language model in natural language, accepts the generated code without closely reviewing its internal structure, and iterates by testing the output and prompting for changes. The term was coined by Andrej Karpathy (co-founder of OpenAI) in February 2025: "fully give in to the vibes, embrace exponentials, and forget that the code even exists."

The workflow is conversational and iterative:
1. Describe what you want in natural language
2. Let the AI generate code
3. Run it and see if it works
4. If not, describe the problem or paste the error message
5. Accept the fix and repeat

There is no specification, no formal plan, no structured requirements document. The "spec" is the running conversation. The developer evaluates output through rapid scanning and application testing, not code review.

### How Requirements Are Communicated

Requirements are communicated through **conversational prompts** -- informal natural language descriptions of desired behavior. There is no structured format. Context accumulates in the conversation history but is lost between sessions. Requirements are implicit, evolving, and often discovered through interaction with the output.

Example: "I need this dashboard to feel 'snappy' and handle real-time data spikes without lagging. Use whatever stack makes that happen."

### How Quality Is Ensured

Quality assurance is minimal by design:
- **Output testing:** Does the application work when you run it? If yes, proceed.
- **Error-driven iteration:** Paste error messages back to the LLM for correction.
- **No code review:** The developer explicitly does not read through the generated code in detail.
- **No formal testing:** Tests are not part of the standard vibe coding workflow.

This is the core tension of vibe coding: it optimizes for speed of initial output at the explicit cost of code understanding and quality assurance.

### Human Oversight

Minimal. The human acts as a tester ("does it work?") rather than a reviewer ("is the code correct?"). The human can redirect the AI through follow-up prompts but does not inspect the implementation. Karpathy himself described the result: "The code grows beyond my usual comprehension, I'd have to really read through it for a while."

### Reproducibility and Auditability

Essentially zero. There is no persistent specification, no structured requirements, no design documentation. The conversation history may be lost between sessions. The code itself becomes the only record of what was built, but the rationale behind decisions is not captured. Reproducing the same output from scratch is not feasible.

### Strengths

- Lowest barrier to entry: anyone who can describe what they want can build software
- Fastest time to initial prototype: no upfront specification or planning required
- Excellent for throwaway projects, proofs of concept, and personal tools
- Democratizes software creation for non-engineers
- Good for learning and experimentation
- Named Collins English Dictionary Word of the Year 2025; reported to be used by 92% of US developers daily (though this likely conflates informal AI use with the strict Karpathy definition)

### Weaknesses

- **Maintainability crisis:** Code duplication increased 4x; code churn nearly doubled in AI-assisted codebases
- **Security vulnerabilities:** 2.74x higher rates of security issues in AI co-authored code. Lovable (a vibe coding platform) exposed personal data in 170 of 1,645 generated applications.
- **Debugging hell:** When the developer doesn't understand the code, debugging requires feeding symptoms back to the LLM, which may fail on complex or subtle bugs
- **Scalability collapse:** Works for simple applications but breaks down with multiple files, complex state, and system integration
- **The inventor's retreat:** Karpathy himself abandoned vibe coding for his Nanochat project, writing it "basically entirely hand-written" because AI agents were "net unhelpful"
- **Professional risk:** Senior engineers report "development hell" when working with vibe-coded codebases (Fast Company, September 2025)
- **No institutional knowledge:** Nothing is captured about why the code works the way it does
- **Terminology drift:** The industry is already moving away from "vibe coding" toward "agentic engineering" for professional work, suggesting the approach is recognized as insufficient for production software

---

## Comparative Analysis

| Dimension | Spec-Driven (SDD) | Rules-Based | Agentic Coding | Multi-Agent Frameworks | Vibe Coding |
|---|---|---|---|---|---|
| **Upfront effort** | High (write specs) | Medium (write rules) | Low (describe task) | High (design agents) | None |
| **Requirements formality** | Structured (EARS, user stories) | Implicit (coding standards) | Conversational | Programmatic | Conversational |
| **Traceability** | Full (req to code) | Partial (rules to patterns) | Git history only | Framework logs | None |
| **Reproducibility** | High (same spec, same output) | Moderate (consistent style) | Low (non-deterministic) | Moderate (graph replay) | None |
| **Quality assurance** | Acceptance criteria, drift detection | Linters, style consistency | Tests + human review | Agent cross-review | "Does it run?" |
| **Human oversight** | Gate reviews per phase | Rules maintenance | Diff review, permission model | Checkpoint approvals | Minimal |
| **Greenfield suitability** | Excellent | Good | Good | Good (if pre-designed) | Good (prototypes only) |
| **Brownfield suitability** | Weak | Good | Excellent | Weak | Weak |
| **Task complexity ceiling** | High (if well-specified) | N/A (augments, not drives) | Medium-High | Highest (decomposition) | Low |
| **Learning curve** | High (spec writing skill) | Low | Low-Medium | High (framework-specific) | None |
| **Cost** | Human time upfront, saves later | Low maintenance burden | Per-query LLM cost | N x LLM cost | Per-query LLM cost |
| **Best for** | Regulated/enterprise, teams | Any project, any stage | Feature development | Complex pipelines | Prototypes, demos |

---

## Key Observations

1. **These approaches are complementary, not competing.** The most effective teams in 2026 combine SDD for requirements, rules files for consistency, and agentic coding for execution. Multi-agent frameworks serve as infrastructure for complex pipelines. Vibe coding has a role in prototyping and exploration.

2. **The industry is moving from vibes to structure.** Karpathy's own trajectory -- coining "vibe coding" in February 2025 then abandoning it for hand-written code -- mirrors the broader industry arc. The replacement term "agentic engineering" signals a shift toward disciplined AI-assisted development.

3. **Specification is the bottleneck.** Whether through SDD specs, rules files, or conversational prompts, the quality of AI output is bounded by the quality of human input. The methods differ in how they structure and preserve that input, but none eliminate the need for clear human intent.

4. **Auditability correlates inversely with speed.** Vibe coding is fastest but leaves no trace. SDD is slowest to start but provides complete traceability. Teams must choose where they sit on this spectrum based on their regulatory, quality, and maintenance requirements.

5. **No approach solves the "hard task" problem.** Even the best agentic coding tools achieve only 16% accuracy on hard tasks (Terminal-Bench). Multi-agent decomposition helps but introduces coordination complexity. Complex software still requires human architectural judgment.
