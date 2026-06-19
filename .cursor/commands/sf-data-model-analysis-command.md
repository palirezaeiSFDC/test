<!--
HOW TO USE THIS COMMAND
=======================
Description: Data model analysis covering relationship mapping, field usage audit,
             object assessment, and junction object optimization. Runs in Plan mode
             and outputs findings inline before asking for file-write preference.
Mode: Plan mode
Model: Capable (Claude Sonnet / Gemini 2.5 Pro)

REQUIRED INPUTS:
  [FILL: Target org alias]         -> e.g., TeamDev

OPTIONAL INPUTS:
  [FILL-LIST: Objects in scope]    -> e.g., LoyaltyProgramMember, TransactionJournal, Loyalty_Stay__c
                                      (if blank, agent will derive from domain/feature context)
  [FILL: Analysis focus]           -> relationship-analysis | field-usage-audit | object-assessment |
                                      junction-optimization | all (default: all)
  [FILL: Domain context]           -> e.g., "Loyalty stay accrual processing" (helps scope if objects not listed)

EXAMPLE:
  Org: TeamDev
  Objects: LoyaltyProgramMember, TransactionJournal, Loyalty_Stay__c, LoyaltyPgmMbrLinkedPtnr
  Focus: all

EXAMPLE (TARGETED):
  Org: TeamDev
  Focus: junction-optimization
  Domain: Loyalty partner linking and member-to-partner relationship management

NOTES:
  - Target org alias should be pre-authorized; verify with sf org list before invoking.
  - Output is inline in this plan session. At the end you will be told to switch to Agent mode to save the output to a file.
  - If objects are not specified, the agent will derive candidate objects from the domain context.
-->

[DATA MODEL ANALYSIS WORKFLOW]

Context:
- Target org alias: [FILL: Target org alias]
- Objects in scope: [FILL-LIST: Objects in scope]
- Analysis focus: [FILL: Analysis focus] (default: all)
- Domain context (optional): [FILL: Domain context]

Instructions:
0. Input review and clarification:
   - Review the Context section above and detect placeholders or blank values.
   - Before launching subagents, confirm received inputs and ask for the org alias if missing (required).
   - If Objects in scope are not provided, derive candidate objects from Domain context or ask the user.
   - Analysis focus defaults to "all" if not provided.
   - Post a one-line progress update at the start of each phase.

1. Load these before execution:
   - Workflow: .cursor/skills/sf-workflow-templates-skill/data-model-analysis.md
   - Skill: .cursor/skills/sf-analysis-design-skill/SKILL.md
   - Rule: .cursor/rules/doc-standards-rule.mdc
   - Conditionally load .cursor/skills/sf-loyalty-management-skill/SKILL.md when objects in scope include Loyalty objects.
   - Conditionally load .cursor/skills/sf-integration-patterns-skill/SKILL.md when analysis focus includes LDV, junction-optimization, or migration patterns.
   - Note: Glob-scoped coding standards rules activate automatically when relevant files are open.

2. Execute the `data-model-analysis` workflow exactly as defined in the workflow file, passing:
   - Target org: [FILL: Target org alias]
   - Objects in scope: [FILL-LIST: Objects in scope]
   - Analysis focus: [FILL: Analysis focus]

Expected output:
- Data Model Analysis Report (inline): Executive Summary, Object Inventory, Relationship Map, Field Usage, LDV Risks, Junction Object Assessment, Recommendations
- Instruction to copy output and switch to Agent mode to save to a file
