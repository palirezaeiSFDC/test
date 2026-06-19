<!--
HOW TO USE THIS COMMAND
=======================
Description: LDV & performance review covering query-plan selectivity, skinny-table
             eligibility, custom-index candidacy, async-pattern fit, and volume
             projections for high-volume objects (TransactionJournal, LoyaltyLedger,
             Loyalty_Stay__c, or any user-specified LDV-candidate object). Runs in
             Plan mode and outputs findings inline.
Mode: Plan mode
Model: Capable (Claude Sonnet / Gemini 2.5 Pro)

REQUIRED INPUTS:
  [FILL: Target org alias]         -> e.g., TeamDev
  [FILL-LIST: Objects in scope]    -> e.g., TransactionJournal, LoyaltyLedger, Loyalty_Stay__c

OPTIONAL INPUTS:
  [FILL: Expected volume]          -> e.g., "500K TransactionJournals/day; 12mo ~ 180M rows"
  [FILL-LIST: Hotspot queries]     -> SOQL strings users want assessed for selectivity
  [FILL: Time horizon]             -> months (default: 12)

EXAMPLE:
  Org: TeamDev
  Objects: TransactionJournal, LoyaltyLedger
  Expected volume: 500K TransactionJournals per day
  Hotspot queries:
    - SELECT Id FROM TransactionJournal WHERE LoyaltyProgramMemberId = :memberId AND CreatedDate = LAST_N_DAYS:30
    - SELECT Id FROM LoyaltyLedger WHERE MemberCurrencyId = :currencyId
  Time horizon: 12

EXAMPLE (NON-LOYALTY):
  Org: TeamDev
  Objects: Account_Mapping__c, Opportunity_Event__e
  Expected volume: 10M Account_Mapping__c records after 12mo
  Time horizon: 24

NOTES:
  - Target org alias should be pre-authorized; verify with sf org list before invoking.
  - Output is inline in this plan session. At the end you will be told to switch to Agent mode to save the output to a file.
  - Actual Query Plan output requires Dev Console (Query Editor > Query Plan); the workflow flags which queries require manual verification.
  - Custom-index and skinny-table provisioning requires a Salesforce Support request; the report includes ready-to-use templates.
-->

[LDV & PERFORMANCE REVIEW WORKFLOW]

Context:
- Target org alias: [FILL: Target org alias]
- Objects in scope: [FILL-LIST: Objects in scope]
- Expected volume (optional): [FILL: Expected volume]
- Hotspot queries (optional): [FILL-LIST: Hotspot queries]
- Time horizon (optional): [FILL: Time horizon] (default: 12 months)

Instructions:
0. Input review and clarification:
   - Review the Context section above and detect placeholders or blank values.
   - Before launching subagents, confirm received inputs and ask for the org alias + at least one object if missing (required).
   - Time horizon defaults to 12 months if not provided.
   - Post a one-line progress update at the start of each phase.

1. Load these before execution:
   - Workflow: .cursor/skills/sf-workflow-templates-skill/ldv-performance-review.md
   - Skill: .cursor/skills/sf-integration-patterns-skill/SKILL.md (and the ldv-performance-reference.md supporting file)
   - Skill: .cursor/skills/sf-analysis-design-skill/SKILL.md
   - Rule: .cursor/rules/doc-standards-rule.mdc
   - Conditionally load .cursor/skills/sf-loyalty-management-skill/SKILL.md when objects in scope include Loyalty objects (TransactionJournal, LoyaltyLedger, LoyaltyMemberCurrency, LoyaltyProgramMember, Loyalty_Stay__c, etc.).
   - Note: Glob-scoped coding standards rules activate automatically when relevant files are open.

2. Execute the `ldv-performance-review` workflow exactly as defined in the workflow file, passing:
   - Target org: [FILL: Target org alias]
   - Objects in scope: [FILL-LIST: Objects in scope]
   - Expected volume: [FILL: Expected volume]
   - Hotspot queries: [FILL-LIST: Hotspot queries]
   - Time horizon: [FILL: Time horizon]

Expected output:
- LDV & Performance Review Report (inline): Executive Summary, Object Inventory, Query Plan Assessment, Skinny Table Eligibility, Custom Index Candidates, Async Pattern Review, Archiving & Data Lifecycle Plan, Prioritized Remediation Backlog
- Instruction to copy output and switch to Agent mode to save to a file (suggested filename: docs/LDV_Performance_Review_[OrgAlias]_[date]_v1.md)
