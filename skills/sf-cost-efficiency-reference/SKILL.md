---
name: sf-cost-efficiency-reference
description: >-
  Detailed cost efficiency guidance for Medium/High complexity Salesforce tasks — skill loading strategy,
  token-conscious patterns, thread lifecycle management, and parallel agent orchestration. Load when the
  pre-execution complexity assessment is Medium or High (as instructed by cost-efficiency-rule.mdc).
  INFRASTRUCTURE REFERENCE SKILL: Loaded indirectly by cost-efficiency-rule.mdc — not invoked directly by
  user prompts. The omission of the -skill suffix is intentional to distinguish infrastructure reference
  files from user-facing domain skills.
---

# Cursor Cost Efficiency — Detailed Reference

This file contains detailed guidance for Medium/High complexity tasks. The lean always-applied core (`cost-efficiency-rule.mdc`) instructs agents to load this file when complexity is **Medium** or **High**.

---

## 1. Skill Loading Strategy

Skills provide domain context but loading all skill files for every interaction is expensive. Load only what the task needs.

### sf-loyalty-management-skill Skill

| Task Scope | Files to Load | Skip |
|---|---|---|
| **Object name/field lookup** | `objects-reference.md` only | SKILL.md, reference.md, sources.md, api-reference.md |
| **Org-verified metadata check** | `org-context.md` only | Everything else |
| **API class or endpoint lookup** | `api-reference.md` only | SKILL.md, reference.md |
| **Design or architecture** | `SKILL.md` (it links to supporting files as needed) | Load linked files on demand, not upfront |
| **Full comprehensive assessment** | `SKILL.md` + `reference.md` + `org-context.md` + `sources.md` | Load linked files on demand, not upfront |

**Key rule:** All Loyalty API content is available in the skill's `.md` files (`api-reference.md`, `objects-reference.md`). For any field definitions or method signatures not covered there, use the online [Apex Reference](https://developer.salesforce.com/docs/atlas.en-us.loyalty.meta/loyalty/loyalty_apex_reference.htm). No PDF exists in the skill directory.

### sf-integration-patterns-skill Skill

| Task Scope | Files to Load |
|---|---|
| **Pattern selection (which integration mechanism?)** | `SKILL.md` only |
| **Platform Event vs CDC vs REST tradeoffs** | `SKILL.md` + `integration-reference.md` |
| **LDV query optimization, async scaling** | `ldv-performance-reference.md` only |
| **Full integration architecture design** | `SKILL.md` + both reference files |

### sf-analysis-design-skill Skill

| Task Scope | Files to Load |
|---|---|
| **Code review criteria** | `SKILL.md` (contains review checklist) |
| **Flow analysis** | `SKILL.md` + `flow-analysis-reference.md` |
| **Test strategy** | `SKILL.md` + `test-strategy-reference.md` |
| **Well-Architected alignment** | `SKILL.md` + `well-architected-reference.md` |
| **Impact assessment methodology** | `SKILL.md` + `impact-assessment-reference.md` |

---

## 2. Token-Conscious Patterns

### File Reading

- **Use `Grep` or `SemanticSearch`** instead of full-file `Read` for large files (>200 lines)
- **Don't re-read files** already provided in context or recently read in the same thread
- **Use `Read` with `offset` and `limit`** for targeted sections of large files
- **For Loyalty API lookups**, use `api-reference.md` (searchable markdown). For anything not there, use the online Apex Reference via `WebFetch`

### Context Scoping

- Use `@file` for 1-3 specific files that are directly relevant
- Use `@folder` only when the entire folder's contents are needed
- **Never use `@Codebase`** unless the user explicitly requests global analysis or cross-project impact
- For Salesforce documentation, prefer `WebSearch`/`WebFetch` with specific queries over indexing entire doc sets

### Subagent Context

- Each subagent starts with a fresh context -- provide only the information it needs in the prompt
- Don't pass entire file contents in subagent prompts; tell the subagent which files to read
- For `sf-org-agent` tasks, include: target org alias, list of components to check, read-only vs write
- For `sf-research-agent` tasks, include: the design question, constraints, and which skill files to reference
- For `sf-dev-agent` tasks, include: the feature/change description, relevant Jira/Confluence references, which existing components to read, and whether the task is new development, enhancement, review, or refactoring

---

## 3. Thread Lifecycle

### When to Continue the Current Thread

- Mid-design with accumulated context that would be costly to rebuild
- Iterating on the same set of files with feedback
- Sequential steps of an approved plan

### When to Suggest a New Chat

- A discrete subtask is complete (design doc delivered, deployment done, audit finished)
- Switching from design/analysis to implementation (different model tier may be needed)
- The thread has accumulated many large file reads and the user starts a **new, unrelated topic**
- Context has become stale (referencing outdated file contents after many edits)

**Don't** suggest a new chat mid-design just because of turn count. Accumulated context in a design thread is valuable.

### Skill Loading and Chat Context Preservation

When loading new skills mid-conversation, follow these rules to avoid losing accumulated context:

1. **Never re-read files the parent already has in context.** If the parent conversation already read `org-context.md`, don't read it again just because a new skill was loaded — reference the existing context.
2. **Skill files are additive, not resetting.** Loading a new skill (e.g., `sf-integration-patterns-skill`) does not invalidate or replace context from previously loaded skills (e.g., `sf-loyalty-management-skill`). Both remain active.
3. **Subagents don't inherit parent context** — but the parent retains all prior context when synthesizing subagent results. After subagent completion, the parent should reference its own accumulated knowledge, not re-discover it.
4. **Don't re-ask clarifying questions** that were already answered earlier in the thread. Consult prior assistant turns and tool results first.
5. **When resuming after a long conversation or model switch:** If context seems stale, re-read only the specific files that were modified since last read (check timestamps via `ls -la` or use `git diff`). Do not reload the entire skill directory.
6. **Conversation summary preservation:** When the system provides a conversation summary (e.g., after context compaction), treat it as authoritative context. Do not re-derive conclusions or re-read files that the summary already covers unless the user explicitly asks to re-verify.

**Anti-pattern to avoid:** Loading a skill, then re-reading all skill files from scratch, then asking the user to re-confirm information that was already established in earlier turns. This creates a frustrating "amnesia" experience.

---

## 4. Parallel Agent Orchestration

Launching multiple subagents simultaneously is the primary lever for throughput. Use the patterns below rather than executing agents sequentially.

### When to Parallelize

| Scenario | Agents to Launch in Parallel | Then Synthesize |
|---|---|---|
| **Impact Assessment** | `explore` (codebase scan for usages) + `sf-org-agent` (metadata verify) + `sf-research-agent` (dependency analysis) | Parent synthesizes findings directly into impact doc |
| **New Feature Design** | `sf-research-agent` (design options + docs) + `sf-org-agent` (prerequisite metadata verify) | Parent or dev-agent consumes both outputs for implementation plan |
| **Code Review (full)** | `sf-review-agent` (mechanical first-pass) + `sf-research-agent` (architecture/security audit) | Parent merges findings into final review report |
| **Solution Verification** | `sf-org-agent` (object/field existence) + `explore` (local codebase check for existing implementations) | Research or dev-agent reconciles against design |
| **Partner Code Intake** | `sf-review-agent` (mechanical) + `sf-org-agent` (retrieve from org for latest version) | dev-agent plans refactoring after both complete |
| **Technical Design + Backlog** | `sf-research-agent` (produce design doc) + `sf-org-agent` (verify feasibility in org) | Parent publishes doc to Confluence, creates Jira tickets in parallel |

### Fan-Out / Fan-In Pattern

```
Parent (Capable model)
  ├── [parallel] sf-org-agent (fast)    → org facts
  ├── [parallel] sf-research-agent       → design analysis
  └── [parallel] explore (fast)          → codebase context
        ↓ all complete
  Fan-in: parent synthesizes directly (or delegates to dev-agent for complex implementation plans)
        ↓
  Output: implementation plan / design doc / review report
```

### Rules for Parallel Orchestration

1. **Independent inputs:** Only parallelize agents whose inputs do not depend on each other's outputs.
2. **Provide scoped prompts:** Each parallel agent receives only the context it needs — do not pass full file contents; tell agents which files/objects to read.
3. **Designate a synthesizer:** Identify upfront which agent (or the parent) will synthesize results. The synthesizer runs after all parallel agents complete. **Prefer parent-direct synthesis** over spawning an additional agent for consolidation.
4. **Avoid redundancy:** Do not ask two agents to perform the same describe or SOQL. Split work so each agent owns a distinct portion.
5. **Cap parallelism at 3–4 agents per fan-out:** Beyond this, context management and synthesis complexity outweigh throughput gains.

### Synthesis Ownership (Critical for Avoiding Unnecessary Sub-Agent Spawns)

| Synthesis Task | Owner | Rationale |
|---|---|---|
| Consolidating parallel agent outputs | **Parent directly** | Parent already has all outputs in context; spawning dev-agent adds overhead |
| Confluence page read for backlog | **Parent directly** (via `user-atlassian` MCP) | Direct MCP call is faster and cheaper than spawning research-agent |
| Writing Impact Assessment or Solution Design doc | **Parent directly** (inline output) | Parent synthesizes; only write to file after user confirms |
| Handling Critical/Warning code review findings | **dev-agent** (conditional) | Complex remediation requires capable reasoning |
| Handling Suggestion-only review findings | **Parent directly** | Low-complexity synthesis |

### Example Parallel Prompt (Impact Assessment)

> "Run the following in parallel:
> 1. Use sf-org-agent to verify that LoyaltyProgramMember, Loyalty_Stay__c, and LoyaltyPgmMbrLinkedPtnr exist and describe their key fields.
> 2. Use explore to find all Apex classes and flows that reference LoyaltyProgramMember and Loyalty_Stay__c.
> 3. Use sf-research-agent to analyze the architectural impact of the proposed change on LoyaltyPgmMbrLinkedPtnr and cite relevant Salesforce docs.
> When all three complete, synthesize the Impact Assessment directly (do not spawn sf-dev-agent for this step)."

### Sequential vs Parallel Decision

| Use sequential when | Use parallel when |
|---|---|
| Agent B needs Agent A's output as input | Agents need different inputs from the same source |
| Single fast org command (direct call instead) | Multiple independent investigations needed |
| Mid-implementation with tight dependency chain | Discovery / analysis phase |
| Confirmation gates between steps (org writes) | Read-only multi-angle analysis |
