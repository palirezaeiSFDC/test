# Workflow Templates — Quick Reference

## Workflow Selection Matrix

| Situation | Workflow ID | Agents | Est. Time Saved |
|---|---|---|---|
| New Jira ticket, need to implement from scratch | `feature-implementation` | research + org (parallel) → dev → review | 40–60% vs sequential |
| Change incoming, need to assess blast radius | `impact-assessment` | explore + org + research (parallel) → parent synthesizes | 50% vs sequential |
| Pre-merge review of own code | `code-review` | review + research (parallel) → parent consolidates | 40% vs using only dev-agent |
| New requirement needing architecture decision | `solution-design` | research + org (parallel) → parent synthesizes | 30–40% vs sequential |
| Peer/Partner deliverable review | `peer-review` | org (retrieve) → review + research (parallel) → conditional dev-agent → Jira | 50% vs sequential |
| Org schema has changed, refresh context | `org-context-refresh` | org-agent | Prevents future rework from stale context |
| Confluence spec needs Jira breakdown | `backlog-generation` | parent reads Confluence directly + user-atlassian MCP | 60–70% vs manual ticket creation |
| Org-wide health check (limits, security, perf, debt) | `org-health-check` | org + research (parallel) → parent synthesizes | 50–60% vs sequential |
| Analyze data model, relationships, LDV risks | `data-model-analysis` | org + research (parallel) → parent synthesizes | 40–50% vs sequential |
| LDV & performance review (selectivity, skinny tables, custom indexes, async fit) | `ldv-performance-review` | org + research (parallel) → parent synthesizes | 40–50% vs sequential |

## Agent Quick Reference

| Agent | Model | Primary Use | Cost |
|---|---|---|---|
| sf-dev-agent | inherit (Capable) | Code gen, planning, nuanced review, refactoring | Medium-High |
| sf-research-agent | inherit (Capable) | Architecture, design, audit, documentation research | Medium-High |
| sf-org-agent | fast | Org describe, SOQL, retrieve, deploy, data ops | Low |
| sf-review-agent | fast | Mechanical code review (bulkification, FLS, naming, test patterns) | Low |
| explore | fast | File discovery, codebase search | Low |
| shell | fast | CLI commands, file ops | Low |

## Parallelization Rules

> Parallelization rules, fan-out caps, synthesizer designation, and sequential-vs-parallel decision table live in `.cursor/skills/sf-cost-efficiency-reference/SKILL.md` Section 4 (Parallel Agent Orchestration). This file is a quick lookup for workflow → agent mapping only.

## Key File Paths

For workspace structure (`force-app/main/default/` subpaths, `manifest/`, `sfdx-project.json`, `.cursor/` assets) see `.cursor/skills/sf-shared-reference/SKILL.md` Section 3.

## Common Parallel Prompt Patterns

### Impact Assessment (3-way parallel)
```
Run in parallel:
- explore: find all references to [Object/Field] in force-app/
- sf-org-agent: describe [Object] in org, verify [FieldList]
- sf-research-agent: analyze architectural impact of [Change]
Then: parent synthesizes directly into Impact Assessment (inline); ask user for file write preference
```

### New Feature (2-way parallel)
```
Run in parallel:
- sf-research-agent: design options for [Feature], cite docs
- sf-org-agent: verify prerequisites [ObjectList] in org
Then: sf-dev-agent: implementation plan → implementation → save to force-app/
```

### Full Code Review (2-way parallel)
```
Run in parallel:
- sf-review-agent: mechanical checklist on [FileList]
- sf-research-agent: architecture + security audit on [FileList]
Then: consolidate findings, create Jira tickets for Critical items
```
