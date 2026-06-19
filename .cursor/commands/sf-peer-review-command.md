<!--
HOW TO USE THIS COMMAND
=======================
Description: Quality gate review of code delivered by a team member. Retrieves
             components from org (or uses provided files), runs parallel mechanical
             and architecture reviews, and produces a prioritized remediation plan.
             Use /sf-self-review-command for reviewing your own implementation.
Mode: Agent mode
Model: Capable (Claude Sonnet / Gemini 2.5 Pro)

REQUIRED INPUTS:
  [FILL: Delivery description]  -> e.g., "Stay accrual trigger and handler"
  [FILL: Source]                -> "Retrieve from org" OR local file paths
  [FILL: Target org alias]      -> e.g., TeamDev

OPTIONAL INPUTS:
  [FILL: Developer name]        -> e.g., Jane Smith
  [FILL-LIST: Component names]  -> e.g., LoyaltyStayTrigger, LoyaltyStayTriggerHandler
  [FILL: Jira ticket]           -> e.g., LYLT-1234
  [FILL: Expected volume]       -> e.g., 500K Platform Event messages/day

EXAMPLE:
  Developer: Jane Smith
  Delivery: Stay accrual trigger + handler + test class for LYLT-1234
  Source: Retrieve from org TeamDev
  Components: LoyaltyStayTrigger, LoyaltyStayTriggerHandler, LoyaltyStayTriggerHandlerTest
  Jira: LYLT-1234
  Expected volume: 500K Platform Event messages per day

NOTES:
  - Target org alias should be pre-authorized; verify with sf org list before invoking.
  - For local file review, save all local edits before running this command.
  - All orchestration logic, source resolution, phase sequencing, and conditional synthesis are
    defined in the workflow `peer-review` in .cursor/skills/sf-workflow-templates-skill/peer-review.md.
-->

[PEER CODE INTAKE AND REVIEW WORKFLOW]

Context:
- Developer: [FILL: Developer name]
- Delivery: [FILL: Delivery description]
- Source: [FILL: Source]
- Components: [FILL-LIST: Component names]
- Jira: [FILL: Jira ticket]
- Expected volume: [FILL: Expected volume]
- Target org alias: [FILL: Target org alias]

Instructions:
0. Input review and clarification:
   - Review the Context section above and detect missing placeholders or blank values.
   - Before launching subagents, send one consolidated clarification message:
     a) confirm received inputs,
     b) ask for missing optional inputs and explain why each helps,
     c) state that optional fields can be skipped and the workflow will proceed with best effort.
   - Wait for the user response, then continue with available data.
   - Post a one-line progress update at the start of each phase.

1. Load these before execution:
   - Workflow: .cursor/skills/sf-workflow-templates-skill/peer-review.md
   - Skill: .cursor/skills/sf-analysis-design-skill/SKILL.md
   - Rule: .cursor/rules/doc-standards-rule.mdc
   - Conditionally load .cursor/skills/sf-loyalty-management-skill/SKILL.md when the delivery context is Loyalty-related.
   - Conditionally load .cursor/skills/sf-integration-patterns-skill/SKILL.md when the delivery involves integrations, APIs, Platform Events, CDC, data migration, async patterns, or LDV context.
   - Note: Glob-scoped coding standards rules (Apex, LWC, metadata) activate automatically when relevant files are open.

2. Execute the `peer-review` workflow exactly as defined in the workflow file, passing the Context above as parameters.
   All phase sequencing, source resolution, agent selection, and conditional synthesis logic are defined in the workflow — follow them precisely.

Expected output:
- Consolidated peer review report
- Prioritized remediation plan with actionable fixes
