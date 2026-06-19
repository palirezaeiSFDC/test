<!--
HOW TO USE THIS COMMAND
=======================
Description: Architecture decision workflow - research 2+ design options, verify
             prerequisites in org, produce a Solution Design document, optionally
             publish to Confluence after explicit confirmation.
Mode: Plan mode
Model: Capable (Claude Sonnet / Gemini 2.5 Pro)

REQUIRED INPUTS:
  [FILL: Design question]               -> e.g., "How should POS stay data integrate for real-time accrual?"
  [FILL: Target org alias]              -> e.g., Marriott-TeamDev

OPTIONAL INPUTS:
  [FILL: Constraints]                   -> e.g., "Real-time, 500K events/day, no MuleSoft license"
  [FILL: Reference]                     -> e.g., LYLT-Epic-9 / Confluence URL
  [FILL-LIST: Prerequisites to verify]  -> e.g., Loyalty_Stay_Event__e, LoyaltyProgram.Program_Code__c
  [FILL-OPT: Confluence space]          -> confirm before publishing (remove if not publishing)

EXAMPLE:
  Design question: How should we integrate hotel POS stay data with Loyalty Management for real-time accrual?
  Constraints: Real-time preferred, 500K events/day, no MuleSoft license, must use existing Platform Events
  Reference: LYLT-Epic-9 / https://confluence.marriott.com/display/LYLT/POS+Integration
  Prerequisites: Loyalty_Stay_Event__e, LoyaltyProgram.Program_Code__c, TransactionJournal

EXAMPLE (NON-LOYALTY):
  Design question: How should customer profile updates from an external CRM sync into Sales Cloud?
  Constraints: Near real-time, 2M updates/day, no middleware expansion in this quarter
  Reference: CRM-Epic-44
  Prerequisites: Account, Contact, Platform Event schema for incoming updates

NOTES:
  - Target org alias should be pre-authorized; verify with sf org list before invoking.
  - Optional inputs improve quality but are not blockers for this workflow.
-->

[SOLUTION DESIGN WORKFLOW]

Context:
- Design question: [FILL: Design question]
- Constraints: [FILL: Constraints]
- Reference: [FILL: Reference]
- Prerequisites to verify: [FILL-LIST: Prerequisites to verify]
- Confluence space (optional): [FILL-OPT: Confluence space]
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
   - Workflow: .cursor/skills/sf-workflow-templates-skill/solution-design.md
   - Skill: .cursor/skills/sf-analysis-design-skill/SKILL.md
   - Rule: .cursor/rules/doc-standards-rule.mdc
   - Conditionally load .cursor/skills/sf-loyalty-management-skill/SKILL.md only when design context is Loyalty-related.
   - Conditionally load .cursor/skills/sf-integration-patterns-skill/SKILL.md when constraints or design context mention integrations, APIs, events, migration, or LDV.
   - Note: Glob-scoped coding standards rules activate automatically when relevant files are open.

2. Execute the `solution-design` workflow exactly as defined in the workflow file, passing the Context above as parameters.
   All phase sequencing, agent selection, and synthesis rules are defined in the workflow — follow them precisely.

   As a reminder, the workflow runs these in PARALLEL:
   - Post progress: "Phase 2 - parallel design and org verification started."
   a) Use sf-research-agent to:
      - Produce at least 2 viable architecture options
      - For each option include: approach, pros, cons, governor-limit considerations, licensing implications, and Salesforce docs links
      - Include a Mermaid high-level architecture diagram
      - Provide recommendation with rationale
      - If Prerequisites to verify are missing, derive a candidate prerequisite list and share it before org verification.
   b) Use sf-org-agent to (independently, do NOT wait for research-agent output):
      - Verify [FILL-LIST: Prerequisites to verify] in [FILL: Target org alias] when provided.
      - If prerequisites are not provided, derive a candidate prerequisite list directly from the Design question and Constraints inputs (do not wait for research-agent — derive independently based on the topic domain).
      - Check existing Flows/Apex/Platform Events that may impact design.
      - Report org gaps and enabled feature constraints.
      - If org verification fails (authorization/alias/timeout), report skipped checks and continue with design-only analysis.

3. Finalization:
   - Post progress: "Phase 3 - finalizing solution design output."
   - Using outputs from Phase 2, synthesize the final Solution Design document directly inline in this conversation. Do NOT spawn a sub-agent for this step.
   - Enforce exact sectioning from doc-standards-rule for Solution Design docs.
   - After outputting the complete document, tell the user:
     "The Solution Design is complete. This session is in Plan mode — copy the output above and switch to Agent mode to save it to a file (suggested filename: docs/Solution_Design_[DerivedSlug].md)."
   - Derive the filename slug from the design question (remove special chars, use underscores, max 5-6 words).
   - If Confluence publish requested: note this for the user to action after switching to Agent mode, with explicit confirmation before any Confluence write action.

Expected output:
- Complete Solution Design document rendered inline in plan output
- Recommended option with rationale
- Org verification summary and open gaps
- User prompt for optional file write and optional Confluence publish at the end
