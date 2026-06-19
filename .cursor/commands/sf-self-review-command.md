<!--
HOW TO USE THIS COMMAND
=======================
Description: Pre-merge / pre-push review of your own code. Parallel mechanical
             checklist (review-agent) + architecture and security audit (research-agent).
             Use /sf-peer-review-command for reviewing team member deliveries.
Mode: Plan mode
Model: Capable (Claude Sonnet / Gemini 2.5 Pro)

REQUIRED INPUTS:
  [FILL-LIST: File paths]       -> e.g., force-app/main/default/classes/LoyaltyStayTriggerHandler.cls

OPTIONAL INPUTS:
  [FILL: Context description]   -> e.g., "Stay accrual handler triggered by Platform Events"
  [FILL: Jira ticket]           -> e.g., LYLT-1234
  [FILL: Review type]           -> Pre-merge | Pre Org push | Periodic quality review
  [FILL-OPT: Target org alias]  -> e.g., TeamDev (optional metadata verification)

EXAMPLE:
  Files:
  - force-app/main/default/classes/LoyaltyStayTriggerHandler.cls
  - force-app/main/default/triggers/LoyaltyStayTrigger.trigger
  - force-app/main/default/classes/LoyaltyStayTriggerHandlerTest.cls
  Context: Stay accrual triggered by Loyalty_Stay_Event__e Platform Events
  Jira: LYLT-1234
  Review type: Pre-merge
  Org: TeamDev

NOTES:
  - Save local files before invoking this command.
  - Plan mode is intentional: this command produces a review report and does not auto-remediate code.
  - All orchestration logic is defined in the workflow `code-review` in
    .cursor/skills/sf-workflow-templates-skill/code-review.md.
-->

[FULL CODE REVIEW WORKFLOW - SELF REVIEW]

Context:
- Files: [FILL-LIST: File paths]
- Context: [FILL: Context description]
- Jira: [FILL: Jira ticket]
- Review type: [FILL: Review type]
- Target org alias (optional): [FILL-OPT: Target org alias]

Instructions:
0. Input review and clarification:
   - Review the Context section above and detect placeholders or blank values.
   - Before launching subagents, send one clarification message:
     a) confirm required inputs received,
     b) ask for missing optional inputs and explain why each helps,
     c) state optional fields can be skipped and review will proceed with best effort.
   - If Context is absent, proceed and infer context from code.
   - If Review type is absent, default to Pre-merge.
   - Post a one-line progress update at the start of each phase.

1. Load these before execution:
   - Workflow: .cursor/skills/sf-workflow-templates-skill/code-review.md
   - Skill: .cursor/skills/sf-analysis-design-skill/SKILL.md
   - Rule: .cursor/rules/doc-standards-rule.mdc
   - Conditionally load .cursor/skills/sf-loyalty-management-skill/SKILL.md when file context is Loyalty-related.
   - Note: Glob-scoped coding standards rules (Apex, LWC, metadata) activate automatically when relevant files are open.

2. Execute the `code-review` workflow exactly as defined in the workflow file, passing the Context above as parameters.
   All phase sequencing, agent selection, consolidation rules, and escalation logic are defined in the workflow — follow them precisely.

Expected output:
- Consolidated review report with prioritized findings and recommended fixes
