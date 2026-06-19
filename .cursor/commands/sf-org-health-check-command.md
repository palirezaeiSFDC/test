<!--
HOW TO USE THIS COMMAND
=======================
Description: Org health check covering platform limits audit, security review,
             performance assessment, and technical debt scan. Runs in Plan mode
             and outputs findings inline before asking for file-write preference.
Mode: Plan mode
Model: Capable (Claude Sonnet / Gemini 2.5 Pro)

REQUIRED INPUTS:
  [FILL: Target org alias]       -> e.g., TeamDev

OPTIONAL INPUTS:
  [FILL: Scope]                  -> limits | security | performance | technical-debt | entitlements | all (default: all)
  [FILL-LIST: Objects in scope]  -> e.g., LoyaltyProgramMember, TransactionJournal (for targeted assessment)

EXAMPLE:
  Org: TeamDev
  Scope: all

EXAMPLE (TARGETED):
  Org: TeamDev
  Scope: performance, technical-debt
  Objects: LoyaltyProgramMember, TransactionJournal, Loyalty_Stay__c

NOTES:
  - Target org alias should be pre-authorized; verify with sf org list before invoking.
  - Output is inline in this plan session. At the end you will be told to switch to Agent mode to save the output to a file.
-->

[ORG HEALTH CHECK WORKFLOW]

Context:
- Target org alias: [FILL: Target org alias]
- Scope: [FILL: Scope] (default: all)
- Objects in scope (optional): [FILL-LIST: Objects in scope]

Instructions:
0. Input review and clarification:
   - Review the Context section above and detect placeholders or blank values.
   - Before launching subagents, confirm received inputs and ask for the org alias if missing (required).
   - Scope defaults to "all" if not provided. Objects in scope are optional for broad health check.
   - Post a one-line progress update at the start of each phase.

1. Load these before execution:
   - Workflow: .cursor/skills/sf-workflow-templates-skill/org-health-check.md
   - Skill: .cursor/skills/sf-analysis-design-skill/SKILL.md
   - Rule: .cursor/rules/doc-standards-rule.mdc
   - Conditionally load .cursor/skills/sf-loyalty-management-skill/SKILL.md when objects in scope include Loyalty objects.
   - Note: Glob-scoped coding standards rules activate automatically when relevant files are open.

2. Execute the `org-health-check` workflow exactly as defined in the workflow file, passing:
   - Target org: [FILL: Target org alias]
   - Scope: [FILL: Scope]
   - Objects in scope: [FILL-LIST: Objects in scope]

Expected output:
- Org Health Check Report (inline): Executive Summary, Platform Limits, Security, Performance, Technical Debt, Entitlements & Licenses (if in scope) sections
- Instruction to copy output and switch to Agent mode to save to a file
