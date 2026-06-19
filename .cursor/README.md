# Cursor Artifacts

This repository is intended to be checked out directly at a project workspace's `.cursor/` directory.

That layout is intentional:
- Cursor uses these files in place under `.cursor/`.
- Many rules, commands, and agent definitions reference paths like `.cursor/skills/...`.
- Keeping the Git working tree at `.cursor/` avoids copy/sync overhead for every developer.

## Repository Layout

When this repository is checked out correctly, the repository root is the local `.cursor/` folder and contains:
- `rules/`
- `skills/`
- `agents/`
- `commands/`
- `README.md`
- `.gitignore`

## Shared Artifacts In Scope

The following categories are intended to be versioned here:
- Shared rules for Salesforce and documentation workflows
- Shared `sf-*` skills and their supporting reference files
- Shared `sf-*` agent definitions
- Shared `sf-*` command definitions

Current tracked rule set:
- `rules/cost-efficiency-rule.mdc`
- `rules/doc-standards-rule.mdc`
- `rules/sf-apex-standards-rule.mdc`
- `rules/sf-flow-standards-rule.mdc`
- `rules/sf-lwc-standards-rule.mdc`
- `rules/sf-mcp-routing-rule.mdc`
- `rules/sf-metadata-standards-rule.mdc`

Current tracked agent set:
- `agents/salesforce-review-agent.md`
- `agents/sf-dev-agent.md`
- `agents/sf-flow-optimizer-agent.md`
- `agents/sf-org-agent.md`
- `agents/sf-research-agent.md`
- `agents/sf-review-agent.md`
- `agents/sf-soql-optimizer-agent.md`

Current tracked command set:
- `commands/sf-data-model-analysis-command.md`
- `commands/sf-feature-implement-command.md`
- `commands/sf-impact-assessment-command.md`
- `commands/sf-ldv-performance-review-command.md`
- `commands/sf-org-health-check-command.md`
- `commands/sf-peer-review-command.md`
- `commands/sf-security-audit-command.md`
- `commands/sf-self-review-command.md`
- `commands/sf-solution-design-command.md`

Current tracked skill directories:
- `skills/sf-analysis-design-skill/`
- `skills/sf-cost-efficiency-reference/`
- `skills/sf-doc-standards-skill/`
- `skills/sf-integration-patterns-skill/`
- `skills/sf-loyalty-management-skill/`
- `skills/sf-review-checklist-reference/`
- `skills/sf-shared-reference/`
- `skills/sf-workflow-templates-skill/`

## Out Of Scope

Do not commit local-only or generated artifacts such as:
- `plans/`
- `.DS_Store`
- local Cursor config such as `settings.json`, `mcp.json`, `hooks/`, `memory/`, `scratch/`, or other user-specific scratch artifacts unless the team explicitly decides to share them

## Initial Setup

Recommended local model:
1. Open the project workspace normally.
2. Ensure this repository is checked out at the workspace `.cursor/` directory.
3. Work on shared Cursor configuration files directly in place.
4. Use normal Git branches and pull requests for changes.

## Daily Workflow

For any shared config change:
1. `cd .cursor`
2. `git pull --ff-only origin <default-branch>`
3. `git switch -c <short-branch-name>`
4. Make and test the config changes locally in Cursor.
5. Review `git diff` and `git status` to confirm only shared artifacts changed.
6. Commit and open a pull request to `cursor-artifacts`.
7. After merge, other developers pull the updated branch into their local `.cursor/`.

## Contribution Guidance

Use small, focused pull requests:
- one rule change
- one command enhancement
- one skill update
- one agent behavior adjustment

Review expectations:
- Always review changes to always-applied rules carefully.
- Preserve existing path conventions and relative references.
- If a skill depends on supporting markdown files, include those changes in the same pull request.
- Keep generated or user-specific artifacts out of the repository.

## Change Log

### 2026-05-27 — Object Migration, Apex Standards, Context Continuity

**Member_Partner_Link__c → LoyaltyPgmMbrLinkedPtnr migration**

The custom junction object `Member_Partner_Link__c` has been superseded by the standard `LoyaltyPgmMbrLinkedPtnr` object (API 66.0+). All references across rules, skills, agents, and commands have been updated:

| File | Change |
|---|---|
| `skills/sf-loyalty-management-skill/SKILL.md` | Removed from custom objects list; added as standard object with deprecation note |
| `skills/sf-loyalty-management-skill/objects-reference.md` | Marked as ~~DEPRECATED~~ with pointer to standard `LoyaltyPgmMbrLinkedPtnr` |
| `skills/sf-loyalty-management-skill/org-context.md` | Marked as ~~DEPRECATED~~ with pointer to standard object |
| `skills/sf-analysis-design-skill/impact-assessment-reference.md` | Generalized dependency map example (no longer hardcoded to MPL migration) |
| `commands/sf-impact-assessment-command.md` | Updated all examples to use `LoyaltyPgmMbrLinkedPtnr` with current field names (`IsActive`, `LinkDate`, `UnlinkDate`, `External_ID__c`) |
| `skills/sf-cost-efficiency-reference/SKILL.md` | Updated parallel prompt example to remove MPL-specific reference |

**Apex coding standards — two new sections in `rules/sf-apex-standards-rule.mdc`**

1. **Null Handling** — Prefer the null coalescing operator (`??`) over explicit `!= null` ternaries for default values. Use safe navigation (`?.`) for nullable chains. Includes correct/incorrect code examples and guidance on when `??` is appropriate vs. when an explicit guard is needed. Reference: [Apex Null Coalescing Operator docs](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_NullCoalescingOperator.htm).

2. **Collection & Loop Efficiency (Non-Negotiable)** — Build `Map<Key, Value>` upfront from query results before iterating. Never nest loops to find matching records; use `Map.get()`. Includes correct O(n+m) pattern and wrong O(n*m) anti-pattern, plus composite key guidance for multi-field correlations.

**Context continuity — prevent "amnesia" after skill loading**

- `rules/cost-efficiency-rule.mdc` (always-applied): Added a **Context Continuity** section enforcing: no re-reading files already in context, no re-asking clarified questions, treat conversation summaries as authoritative.
- `skills/sf-cost-efficiency-reference/SKILL.md`: Added **Skill Loading and Chat Context Preservation** subsection with 6 explicit rules and an anti-pattern callout to prevent the "load skill → re-read everything → re-ask user" cycle.

**Backup:** Pre-change state preserved in `.cursor-backup-20260527_*` at the workspace root.

---

## Notes

- The file `rules/doc-standards-rule.mdc` is the current documentation standards rule in this workspace.
- There is no separate `sug-agents/` directory in this configuration set; shared agent definitions live in `agents/`.
- If the remote repository already contains bootstrap files or branch protections, follow the remote repository's conventions over this document.
