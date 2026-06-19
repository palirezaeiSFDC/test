<!--
HOW TO USE THIS COMMAND
=======================
Description: Comprehensive Salesforce org security audit covering sharing model, profile/permission-set
             over-provisioning, FLS audit, connected apps/OAuth, named credentials, guest user access,
             IP restrictions, session settings, Shield encryption evaluation, and WAF Security Pillar
             alignment. Runs in Plan mode and outputs findings inline.
Mode: Plan mode
Model: Capable (Claude Sonnet / Gemini 2.5 Pro)

REQUIRED INPUTS:
  [FILL: Target org alias]       -> e.g., TeamDev

OPTIONAL INPUTS:
  [FILL: Scope]                  -> sharing | permissions | fls | connected-apps | session | shield | all (default: all)
  [FILL-LIST: Objects in scope]  -> specific objects for FLS/sharing analysis (e.g., Account, LoyaltyProgramMember)

EXAMPLE:
  Org: TeamDev
  Scope: all

EXAMPLE (TARGETED):
  Org: TeamDev
  Scope: permissions, fls
  Objects: LoyaltyProgramMember, TransactionJournal

NOTES:
  - Target org alias should be pre-authorized; verify with sf org list before invoking.
  - Output is inline in this plan session. At the end you will be told to switch to Agent mode to save the output to a file.
  - Retrieval of security metadata (profiles, permission sets, sharing rules) may take several minutes.
-->

[SECURITY AUDIT WORKFLOW]

Context:
- Target org alias: [FILL: Target org alias]
- Scope: [FILL: Scope] (default: all)
- Objects in scope (optional): [FILL-LIST: Objects in scope]

Instructions:
0. Input review and clarification:
   - Review the Context section above and detect placeholders or blank values.
   - Before launching subagents, confirm received inputs and ask for the org alias if missing (required).
   - Scope defaults to "all" if not provided. Objects in scope are optional for broad audit.
   - Post a one-line progress update at the start of each phase.

1. Load these before execution:
   - Workflow: .cursor/skills/sf-workflow-templates-skill/security-audit.md
   - Skill: .cursor/skills/sf-analysis-design-skill/SKILL.md
   - Skill: .cursor/skills/sf-shared-reference/SKILL.md (Section 2 for error handling)
   - Rule: .cursor/rules/doc-standards-rule.mdc
   - Note: Glob-scoped coding standards rules activate automatically when relevant files are open.

2. Execute the `security-audit` workflow exactly as defined in the workflow file, passing:
   - Target org: [FILL: Target org alias]
   - Scope: [FILL: Scope]
   - Objects in scope: [FILL-LIST: Objects in scope]

Expected output:
- Security Audit Report (inline): Executive Summary, Sharing Model, Profile/PermSet Over-Provisioning,
  FLS Audit, Connected Apps/OAuth, Named Credentials, Guest User Access, IP Restrictions, Session Settings,
  Shield Encryption, WAF Security Pillar Assessment, and Prioritized Remediation Backlog
- Instruction to copy output and switch to Agent mode to save to a file
