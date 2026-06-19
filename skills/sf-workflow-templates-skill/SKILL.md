---
name: sf-workflow-templates-skill
description: >-
  Pre-composed multi-agent workflow templates for common Salesforce senior architect
  tasks. Provides ready-to-use prompt chains for feature implementation cycles,
  impact assessments, code reviews, solution designs, and partner code intake.
  Use when you want to maximize efficiency and throughput by orchestrating multiple
  agents in parallel rather than composing prompts from scratch.
---

# Salesforce Workflow Templates

## How to Use

Each workflow is in a separate file. Load only the workflow file you need — do not load all files at once.

For model selection guidance, see the `cost-efficiency-rule` (always active).
For the agent quick-reference and parallelization rules, see [workflow-reference.md](workflow-reference.md).

## Workflow Commands Quick Reference

| Slash Command | Workflow | Mode |
|---|---|---|
| `/sf-feature-implement-command` | `feature-implementation` | Agent |
| `/sf-impact-assessment-command` | `impact-assessment` | Plan |
| `/sf-self-review-command` | `code-review` | Plan |
| `/sf-peer-review-command` | `peer-review` | Agent |
| `/sf-solution-design-command` | `solution-design` | Plan |
| `/sf-org-health-check-command` | `org-health-check` | Plan |
| `/sf-data-model-analysis-command` | `data-model-analysis` | Plan |
| `/sf-security-audit-command` | `security-audit` | Plan |
| `/sf-ldv-performance-review-command` | `ldv-performance-review` | Plan |

## Workflow Index

| Workflow ID | File | Use When | Agents | Mode |
|---|---|---|---|---|
| `feature-implementation` | [feature-implementation.md](feature-implementation.md) | Implementing a new feature end-to-end | research + org → dev → review | Agent |
| `impact-assessment` | [impact-assessment.md](impact-assessment.md) | Assessing blast radius of a change | explore + org + research → parent | Plan |
| `code-review` | [code-review.md](code-review.md) | Pre-merge review of own code | review + research → parent | Plan |
| `solution-design` | [solution-design.md](solution-design.md) | Architecture decision for a new requirement | research + org → parent | Plan |
| `peer-review` | [peer-review.md](peer-review.md) | Quality gate review of team deliveries | org → review + research → dev | Agent |
| `org-context-refresh` | [org-context-refresh.md](org-context-refresh.md) | Refresh org-context.md after org changes | org → parent | Agent |
| `backlog-generation` | [backlog-generation.md](backlog-generation.md) | Break Confluence spec into Jira tickets | parent (Atlassian MCP) | Agent |
| `org-health-check` | [org-health-check.md](org-health-check.md) | Platform limits, security, perf, debt scan | org + research → parent | Plan |
| `data-model-analysis` | [data-model-analysis.md](data-model-analysis.md) | Object relationships, field usage, LDV risks | org + research → parent | Plan |
| `security-audit` | [security-audit.md](security-audit.md) | Comprehensive org security review | org + research → parent | Plan |
| `ldv-performance-review` | [ldv-performance-review.md](ldv-performance-review.md) | Query selectivity, skinny-table eligibility, custom-index candidates, async-pattern fit, volume projections | org + research → parent | Plan |

## Key Rules

Parallelization caps, synthesizer designation, sequential-vs-parallel decision rules, and fan-out/fan-in patterns live in `.cursor/skills/sf-cost-efficiency-reference/SKILL.md` Section 4 (Parallel Agent Orchestration). The review-remediation cycle cap of 2 is enforced per-agent in `sf-dev-agent.md` and `sf-review-agent.md`.
