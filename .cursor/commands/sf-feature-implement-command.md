<!--
HOW TO USE THIS COMMAND
=======================
Description: End-to-end feature implementation cycle - design, org verification,
             implementation, and code review. Uses parallel agents for efficiency.
Mode: Agent mode
Model: Capable (Claude Sonnet / Gemini 2.5 Pro)

REQUIRED INPUTS:
  [FILL: Feature description]    -> e.g., "Implement night accrual from POS stay events"
  [FILL: Target org alias]       -> e.g., TeamDev

OPTIONAL INPUTS:
  [FILL-OPT: Jira ticket]        -> e.g., LYLT-1234
  [FILL-OPT: Confluence URL]     -> e.g., https://confluence.marriott.com/... (or N/A)
  [FILL-OPT: Objects/fields]     -> e.g., LoyaltyProgramMember, Loyalty_Stay__c
  [FILL-OPT: Search keywords]    -> e.g., StayAccrual, EarnTransaction

EXAMPLE:
  Feature: Implement night accrual processing from POS hotel stay events
  Jira: LYLT-1234
  Confluence: https://confluence.marriott.com/display/LYLT/Stay+Accrual+v2
  Objects: LoyaltyProgramMember, Loyalty_Stay__c, TransactionJournal
  Keywords: StayAccrual, NightEarning, LoyaltyStayEvent__e
  Org: TeamDev

NOTES:
  - Target org alias should be pre-authorized; verify with sf org list before invoking.
  - Optional context improves quality and speed but is not required to start.
  - All orchestration logic, guard rails, and phase sequencing are defined in the
    workflow `feature-implementation` in .cursor/skills/sf-workflow-templates-skill/feature-implementation.md.
-->

[FEATURE IMPLEMENTATION WORKFLOW]

Context:
- Feature: [FILL: Feature description]
- Jira ticket (optional): [FILL-OPT: Jira ticket]
- Confluence link (optional): [FILL-OPT: Confluence URL]
- Objects/fields to verify (optional): [FILL-LIST: Objects/fields]
- Search keywords (optional): [FILL-LIST: Search keywords]
- Target org alias: [FILL: Target org alias]

Instructions:
0. Input review and clarification:
   - Review the Context section above and detect placeholders or blank values.
   - Before launching subagents, send one consolidated clarification message:
     a) confirm received required inputs,
     b) ask for missing optional inputs and explain why each helps,
     c) state optional fields can be skipped and workflow will proceed with best effort.
   - Post a one-line progress update at the start of each phase.

1. Load these before execution:
   - Workflow: .cursor/skills/sf-workflow-templates-skill/feature-implementation.md
   - Skill: .cursor/skills/sf-analysis-design-skill/SKILL.md
   - Rule: .cursor/rules/doc-standards-rule.mdc
   - Conditionally load .cursor/skills/sf-loyalty-management-skill/SKILL.md when feature context is Loyalty-related.
   - Conditionally load .cursor/skills/sf-integration-patterns-skill/SKILL.md when feature involves integrations, APIs, Platform Events, CDC, data migration, async patterns, or LDV context.
   - Note: Glob-scoped coding standards rules (Apex, LWC, metadata) activate automatically when relevant files are open.

2. Execute the `feature-implementation` workflow exactly as defined in the workflow file, passing the Context above as parameters.
   All phase sequencing, agent selection, guard rails, iteration caps, and failure handling are defined in the workflow — follow them precisely.

Expected output:
- Implementation Plan (awaiting user approval before code changes)
- Code changes in force-app/main/default/
- Technical Design document in docs/
- Post-implementation review findings (Critical/Warning/Suggestion)
- Residual Issues list if iteration cap reached
