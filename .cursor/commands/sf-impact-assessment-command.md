<!--
HOW TO USE THIS COMMAND
=======================
Description: Assess the blast radius of a proposed change - affected components,
             risks, and deployment considerations. Produces an Impact Assessment document.
Mode: Plan mode
Model: Capable (Claude Sonnet / Gemini 2.5 Pro)

REQUIRED INPUTS:
  [FILL: Change description]       -> e.g., "Add custom fields to LoyaltyPgmMbrLinkedPtnr for partner integration"
  [FILL: Target org alias]         -> e.g., Marriott-TeamDev

OPTIONAL INPUTS:
  [FILL: Reference]                -> e.g., LYLT-5678 or Confluence URL
  [FILL-LIST: Affected objects]    -> e.g., LoyaltyPgmMbrLinkedPtnr, LoyaltyProgramMember
  [FILL-LIST: Fields to describe]  -> e.g., IsActive, LinkDate, UnlinkDate, External_ID__c
  [FILL-OPT: Confluence URL]       -> publish destination (remove if not publishing)

EXAMPLE:
  Change: Add partner geographic area field to LoyaltyPgmMbrLinkedPtnr
  Reference: LYLT-5678
  Affected objects: LoyaltyPgmMbrLinkedPtnr, LoyaltyProgramMember, LoyaltyProgramPartner
  Fields: IsActive, LinkDate, UnlinkDate, Partner_Geographic_Area__c

EXAMPLE (NON-LOYALTY):
  Change: Replace legacy Account_Mapping__c usage with standard AccountContactRelation mapping
  Reference: CRM-5588
  Affected objects: Account_Mapping__c, AccountContactRelation, Account
  Fields: AccountId, ContactId, IsDirect

NOTES:
  - Target org alias should be pre-authorized; verify with sf org list before invoking.
  - Optional inputs improve speed and precision but are not required to start.
-->

[IMPACT ASSESSMENT WORKFLOW]

Context:
- Change: [FILL: Change description]
- Reference: [FILL: Reference]
- Affected objects: [FILL-LIST: Affected objects]
- Fields to describe: [FILL-LIST: Fields to describe]
- Confluence URL (optional): [FILL-OPT: Confluence URL]
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
   - Workflow: .cursor/skills/sf-workflow-templates-skill/impact-assessment.md
   - Skill: .cursor/skills/sf-analysis-design-skill/SKILL.md
   - Rule: .cursor/rules/doc-standards-rule.mdc
   - Conditionally load .cursor/skills/sf-loyalty-management-skill/SKILL.md only when change context is Loyalty-related.
   - Conditionally load .cursor/skills/sf-integration-patterns-skill/SKILL.md when change context includes integration, migration, API/event flow, or LDV concerns.
   - Note: Glob-scoped coding standards rules activate automatically when relevant files are open.

2. Execute the `impact-assessment` workflow exactly as defined in the workflow file, passing the Context above as parameters.
   All phase sequencing, agent selection, and synthesis rules are defined in the workflow — follow them precisely.

   As a reminder, the workflow runs these in PARALLEL:
   - Post progress: "Phase 2 - parallel impact discovery started."
   a) Use explore to:
      - If Affected objects are provided, scan force-app/main/default/ for Apex, triggers, flows, and LWC references to [FILL-LIST: Affected objects].
      - If Affected objects are not provided, derive candidate objects from Change description using semantic search before scanning.
      - Return file paths and context for each reference
   b) Use sf-org-agent to:
      - Verify [FILL-LIST: Affected objects] and [FILL-LIST: Fields to describe] in [FILL: Target org alias] when provided.
      - If Affected objects are missing, derive candidate objects from Change description and verify those first.
      - If Fields to describe are missing, infer key fields from described objects and include relationships.
      - Describe key fields and relationships
      - Query representative records to confirm data presence
      - If org verification fails (authorization/alias/timeout), report skipped checks and continue with local/code discovery only.
   c) Use sf-research-agent to:
      - Assess architecture, dependency, integration, and governor-limit impacts
      - Cite Salesforce documentation for relevant platform constraints

3. Synthesis:
   - Post progress: "Phase 3 - synthesizing impact report."
   - Synthesize the final Impact Assessment directly from the Phase 2 outputs. Do NOT spawn sf-dev-agent for this step.
   - Output the complete Impact Assessment inline in this conversation, following the exact section order per doc-standards-rule:
     Executive Summary, Scope, Affected Components, Risk Analysis, Testing Scope, Deployment Notes, References
   - Risk matrix format: Risk Description | Likelihood [High/Med/Low] | Impact [High/Med/Low] | Mitigation Strategy
   - After outputting the complete report, tell the user:
     "The Impact Assessment is complete. This session is in Plan mode — copy the output above and switch to Agent mode to save it to a file (suggested filename: docs/Impact_Assessment_[DerivedSlug].md)."
   - Derive the filename slug from Change description (remove special chars, use underscores, max 5-6 words).

Expected output:
- Complete Impact Assessment rendered inline in plan output
- Explicit list of impacted metadata and code components
- Risk matrix with likelihood, impact, and mitigation for each risk
- User prompt for optional file write at the end
